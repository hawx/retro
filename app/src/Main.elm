port module Main exposing (main)

import Bulma
import Debug
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import String
import Dict exposing (Dict)
import Array exposing (Array)
import WebSocket
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Column exposing (Column)
import Card exposing (Card, Content)
import Retro exposing (Retro)

main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

-- Model

type Stage = Thinking | Presenting | Voting | Discussing

type alias CardDragging = Maybe (String, String)
type alias CardOver = Maybe (String, Maybe String)

type alias Model =
    { user : String
    , joined : Bool
    , stage : Stage
    , retro : Retro
    , input : String
    , cardDragging : CardDragging
    , cardOver : CardOver
    }

init : (Model, Cmd msg)
init =
    { user = ""
    , joined = False
    , stage = Thinking
    , retro = Retro.empty
    , input = ""
    , cardDragging = Nothing
    , cardOver = Nothing
    } ! [ storageGet "id" ]

-- Update

port storageSet : (String, String) -> Cmd msg
port storageGet : String -> Cmd msg
port storageGot : (Maybe String -> msg) -> Sub msg

type Msg = SetId (Maybe String)
         | Socket String
         | ChangeInput String String
         | MouseOver String String
         | MouseOut String String
         | DragStart
         | DragOver (String, Maybe String)
         | DragLeave (String, Maybe String)
         | Drop
         | SetStage Stage
         | Reveal String String
         | ChangeName String
         | Join
         | Vote String String

type alias SocketMsg =
    { id : String
    , op : String
    , args : List String
    }

socketMsgDecoder : Decode.Decoder SocketMsg
socketMsgDecoder =
    Pipeline.decode SocketMsg
        |> Pipeline.required "id" Decode.string
        |> Pipeline.required "op" Decode.string
        |> Pipeline.required "args" (Decode.list Decode.string)

socketMsgEncoder : SocketMsg -> Encode.Value
socketMsgEncoder value =
    Encode.object
        [ ("id", Encode.string value.id)
        , ("op", Encode.string value.op)
        , ("args", Encode.list (List.map Encode.string value.args))
        ]

sendMsg : String -> String -> List String -> Cmd Msg
sendMsg id op args =
    SocketMsg id op args
        |> socketMsgEncoder
        |> Encode.encode 0
        |> WebSocket.send "ws://localhost:8080/ws"

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Vote columnId cardId ->
            model ! [ sendMsg model.user "vote" [columnId, cardId] ]

        ChangeName name ->
            { model | user = name } ! []
        Join ->
            { model | joined = True } ! [ sendMsg model.user "init" [model.user] ]

        SetId id ->
            case id of
                Just v -> { model | user = v, joined = True } ! [ sendMsg v "init" [v] ]
                Nothing -> model ! [ ]

        SetStage stage ->
            { model | stage = stage } ! [ sendMsg model.user "stage" [toString stage] ]

        Reveal columnId cardId ->
            model ! [ sendMsg model.user "reveal" [columnId, cardId] ]

        MouseOver columnId cardId ->
            { model | cardDragging = Just (columnId, cardId) } ! []
        MouseOut columnId cardId ->
            { model | cardDragging = Nothing } ! []

        DragStart -> model ! []
        DragOver over ->
            { model | cardOver = Just over } ! []
        DragLeave _ ->
            { model | cardOver = Nothing } ! []
        Drop ->
            case model.stage of
                Thinking ->
                    let
                        move (columnFrom, cardId) (columnTo, _) = { model
                                                                      | cardOver = Nothing
                                                                      , cardDragging = Nothing
                                                                  } ! [ sendMsg model.user "move" [columnFrom, columnTo, cardId] ]
                    in
                        Maybe.map2 move model.cardDragging model.cardOver
                            |> Maybe.withDefault (model, Cmd.none)

                Voting ->
                    let
                        move (columnFrom, cardFrom) (columnTo, maybeCardTo) =
                            case maybeCardTo of
                                Just cardTo -> { model
                                                   | cardOver = Nothing
                                                   , cardDragging = Nothing
                                               } ! [ sendMsg model.user "group" [columnFrom, cardFrom, columnTo, cardTo] ]
                                Nothing -> (model, Cmd.none)
                    in
                        Maybe.map2 move model.cardDragging model.cardOver
                            |> Maybe.withDefault (model, Cmd.none)

                _ ->
                    (model, Cmd.none)

        ChangeInput columnId input ->
            if String.contains "\n" input then
                { model | input = "" } ! [ sendMsg model.user "add" [columnId, model.input] ]
            else
                { model | input = input } ! []

        Socket data ->
            case Decode.decodeString socketMsgDecoder data of
                Ok socketMsg -> socketUpdate socketMsg model
                Err _ -> model ! []


socketUpdate : SocketMsg -> Model -> (Model, Cmd Msg)
socketUpdate msg model =
    case msg.op of
        "stage" ->
            case msg.args of
                [stage] ->
                    case stage of
                        "Thinking" -> { model | stage = Thinking } ! []
                        "Presenting" -> { model | stage = Presenting } ! []
                        "Voting" -> { model | stage = Voting } ! []
                        "Discussing" -> { model | stage = Discussing } ! []
                        _ -> model ! []

                _ ->
                    model ! []

        "card" ->
            case msg.args of
                [columnId, cardId, cardRevealed] ->
                    let
                        card =
                            { id = cardId
                            , votes = 0
                            , revealed = cardRevealed == "true"
                            , contents = [ ]
                            }
                    in
                        { model | retro = Retro.addCard columnId card model.retro } ! []
                _ ->
                    model ! []

        "content" ->
            case msg.args of
                [columnId, cardId, _, contentText] ->
                    let content =
                            { id = ""
                            , text = contentText
                            , author = msg.id
                            }
                    in
                        { model | retro = Retro.addContent columnId cardId content model.retro } ! []

                _ ->
                    model ! []

        "column" ->
            case msg.args of
                [columnId, columnName] ->
                    let
                        column = { id = columnId, name = columnName, cards = Dict.empty }
                    in
                        { model | retro = Retro.addColumn column model.retro } ! []
                _ ->
                    model ! []

        "move" ->
            case msg.args of
                [columnFrom, columnTo, cardId] ->
                    { model | retro = Retro.moveCard columnFrom columnTo cardId model.retro } ! []
                _ ->
                    model ! []

        "reveal" ->
            case msg.args of
                [columnId, cardId] ->
                    { model | retro = Retro.revealCard columnId cardId model.retro } ! []
                _ ->
                    model ! []

        "group" ->
            case msg.args of
                [columnFrom, cardFrom, columnTo, cardTo] ->
                    { model | retro = Retro.groupCards (columnFrom, cardFrom) (columnTo, cardTo) model.retro } ! []
                _ ->
                    model ! []

        "vote" ->
            case msg.args of
                [columnId, cardId] ->
                    { model | retro = Retro.voteCard columnId cardId model.retro } ! []
                _ ->
                    model ! []

        _ ->
            model ! []

-- View

view : Model -> Html Msg
view model =
    let
        tabs =
            Html.section [ Attr.class "section" ]
                [ Html.div [ Attr.class "container is-fluid" ]
                      [ tabsView model.stage
                      , columnsView model.user model.stage model.cardDragging model.cardOver model.retro.columns
                      ]
                ]

        footer =
          Html.footer [ Attr.class "footer" ]
            [ Html.div [ Attr.class "container" ]
                  [ Html.div [ Attr.class "content has-text-centered" ]
                        [ Html.text "A link to github?"
                        ]
                  ]
            ]

        modal =
          Bulma.modal
            [ Bulma.box []
                  [ Bulma.label "Name"
                  , Bulma.input [ Event.onInput ChangeName ]
                  , Bulma.button [ Attr.class "is-primary", Event.onClick Join ] [ Html.text "Join" ]
                  ]
            ]
    in
        if model.joined then
            Html.div [] [ tabs, footer ]
        else
            Html.div [] [ tabs, footer, modal ]


tabsView : Stage -> Html Msg
tabsView stage =
    let
        tab s =
            Html.li [ Attr.classList [("is-active", stage == s)]
                    , Event.onClick (SetStage s)
                    ]
                [ Html.a [] [ Html.text (toString s) ]
                ]
    in
        Bulma.tabs [ Attr.class "is-toggle" ]
            [ Html.ul [ Attr.class "is-left" ]
                  [ tab Thinking
                  , tab Presenting
                  , tab Voting
                  , tab Discussing
                  ]
            , Html.ul [ Attr.class "is-right" ]
                [ Html.li []
                      [ Html.a [] [ Html.text "05:03 remaining" ]
                      ]
                ]
            ]

columnsView : String -> Stage -> CardDragging -> CardOver -> Dict String Column -> Html Msg
columnsView connId stage cardDragging cardOver columns =
    Bulma.columns [ ]
        <| List.map (columnView connId stage cardDragging cardOver)
        <| Dict.toList columns

columnView : String -> Stage -> CardDragging -> CardOver -> (String, Column) -> Html Msg
columnView connId stage cardDragging cardOver (columnId, column) =
    let
        title = [titleCardView column.name]
        list =
            Dict.toList column.cards
                |> List.map (cardView connId stage cardDragging cardOver columnId)
                |> List.concat
        add = [addCardView columnId]
    in
        case stage of
            Thinking ->
                Bulma.column [ Attr.classList [ ("over", cardOver == Just (columnId, Nothing))
                                              ]
                             , onDragOver (DragOver (columnId, Nothing))
                             , onDragLeave (DragLeave (columnId, Nothing))
                             , onDrop (Drop)
                             ]
                    (title ++ list ++ add)

            _ ->
                Html.div [ Attr.class "column" ]
                    (title ++ list)

contentView : Content -> Html Msg
contentView content =
    Bulma.content []
        [ Html.p [ Attr.class "title is-6" ] [ Html.text content.author ]
        , Html.p [] [ Html.text content.text ]
        ]

contentsView : List Content -> Html Msg
contentsView contents =
    contents
        |> List.map (contentView)
        |> List.intersperse (Html.hr [] [])
        |> Bulma.content []

cardView : String -> Stage -> CardDragging -> CardOver -> String -> (String, Card) -> List (Html Msg)
cardView connId stage cardDragging cardOver columnId (cardId, card) =
    let
        content = contentsView card.contents
    in
        case stage of
            Thinking ->
                if Card.authored connId card then
                    [ Bulma.card [ Attr.draggable "true"
                                 , onDragStart (DragStart)
                                 , Event.onMouseOver (MouseOver columnId cardId)
                                 , Event.onMouseOut (MouseOut columnId cardId)
                                 ]
                          [ Bulma.cardContent [] [ content ] ]
                    ]
                else
                    []

            Presenting ->
                if not card.revealed then
                    if Card.authored connId card then
                        [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed) ]
                                     , Event.onClick (Reveal columnId cardId)
                                     ]
                              [ Bulma.cardContent [] [ content ] ]
                        ]
                    else
                        []
                else
                    [ Bulma.card []
                          [ Bulma.cardContent [] [ content ] ]
                    ]

            Voting ->
                [ Bulma.card [ Attr.draggable "true"
                             , onDragStart (DragStart)
                             , Event.onMouseOver (MouseOver columnId cardId)
                             , Event.onMouseOut (MouseOut columnId cardId)
                             , Attr.classList [ ("over", cardOver == Just (columnId, Just cardId))
                                              ]
                             , onDragOver (DragOver (columnId, Just cardId))
                             , onDragLeave (DragOver (columnId, Just cardId))
                             , onDrop (Drop)
                             ]
                      [ Bulma.cardContent []
                            [ content ]
                      , Bulma.cardFooter []
                          [ Bulma.cardFooterItem [] (toString card.votes)
                          , Bulma.cardFooterItem [ Event.onClick (Vote columnId cardId) ] "Vote"
                          ]
                      ]
                ]

            _ ->
                [ Bulma.card []
                      [ Bulma.cardContent [] [ content ] ]
                ]


titleCardView : String -> Html Msg
titleCardView title =
    Html.div [ Attr.class "not-card card-content has-text-centered" ]
        [ Html.div [ Attr.class "content" ]
              [ Html.h1 []
                    [ Html.text title
                    ]
              ]
        ]

addCardView : String -> Html Msg
addCardView columnId =
    Bulma.card []
        [ Bulma.cardContent []
              [ Bulma.content []
                    [ Html.textarea [ Event.onInput (ChangeInput columnId), Attr.placeholder "Add a card..." ] [ ]
                    ]
              ]
        ]

onDragLeave : msg -> Html.Attribute msg
onDragLeave tagger =
    Event.on "dragleave" (Decode.succeed tagger)

onDragOver : msg -> Html.Attribute msg
onDragOver tagger =
    Event.onWithOptions "dragover" { preventDefault = True, stopPropagation = False } (Decode.succeed tagger)

onDrop : msg -> Html.Attribute msg
onDrop tagger =
    Event.onWithOptions "drop" { preventDefault = True, stopPropagation = False } (Decode.succeed tagger)

onDragStart : msg -> Html.Attribute msg
onDragStart tagger =
    Attr.attribute "ondragstart" "event.dataTransfer.setData('text/html', event.target.innerHTML)"

-- Subscriptions

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen "ws://localhost:8080/ws" Socket
        , storageGot SetId
        ]

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
import Card exposing (Card)
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

type alias Model =
    { id : String
    , user : String
    , joined : Bool
    , stage : Stage
    , retro : Retro
    , input : String
    , cardOver : Maybe (String, String)
    , columnOver : Maybe String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , user = ""
    , joined = False
    , stage = Thinking
    , retro = Retro.empty
    , input = ""
    , cardOver = Nothing
    , columnOver = Nothing
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
         | DragOver String
         | DragLeave String
         | Drop
         | SetStage Stage
         | Reveal String String
         | ChangeName String
         | Join

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

sendMsg msg =
    WebSocket.send "ws://localhost:8080/ws"
        <| Encode.encode 0
        <| socketMsgEncoder msg

sendSetId connId =
    SocketMsg connId "init" []
        |> sendMsg

sendGetId =
    SocketMsg "" "init" []
        |> sendMsg

sendAddCard connId columnId cardText =
    SocketMsg connId "add" [columnId, cardText]
        |> sendMsg

sendMoveCard connId columnFrom columnTo cardId =
    SocketMsg connId "move" [columnFrom, columnTo, cardId]
        |> sendMsg

sendSetStage connId stage =
    SocketMsg connId "stage" [toString stage]
        |> sendMsg

sendReveal connId columnId cardId =
    SocketMsg connId "reveal" [columnId, cardId]
        |> sendMsg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        ChangeName name ->
            { model | user = name } ! []
        Join ->
            { model | joined = True } ! [ sendSetId model.user ]

        SetId id ->
            case id of
                Just v -> { model | user = v, joined = True } ! [ sendSetId v ]
                Nothing -> model ! [ sendGetId ]

        SetStage stage ->
            { model | stage = stage } ! [ sendSetStage model.id stage ]

        Reveal columnId cardId ->
            model ! [ sendReveal model.id columnId cardId ]

        MouseOver columnId cardId ->
            { model | cardOver = Just (columnId, cardId) } ! []
        MouseOut columnId cardId ->
            { model | cardOver = Nothing } ! []

        DragStart -> model ! []
        DragOver columnId ->
            { model | columnOver = Just columnId } ! []
        DragLeave _ ->
            { model | columnOver = Nothing } ! []
        Drop ->
            let
                move (columnFrom, cardId) columnTo = { model | columnOver = Nothing , cardOver = Nothing
                                                     } ! [ sendMoveCard model.id columnFrom columnTo cardId ]
            in
                Maybe.map2 move model.cardOver model.columnOver
                    |> Maybe.withDefault (model, Cmd.none)

        ChangeInput columnId input ->
            if String.contains "\n" input then
                { model | input = "" } ! [ sendAddCard model.id columnId model.input ]
            else
                { model | input = input } ! []

        Socket data ->
            case Decode.decodeString socketMsgDecoder data of
                Ok socketMsg -> socketUpdate socketMsg model
                Err _ -> model ! []


socketUpdate : SocketMsg -> Model -> (Model, Cmd Msg)
socketUpdate msg model =
    case msg.op of
        "init" ->
            case msg.args of
                [connId] ->
                    { model | id = connId } ! [ storageSet ("id", connId) ]
                _ ->
                    model ! []

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

        "add" ->
            case msg.args of
                [columnId, cardId, cardText, cardRevealed] ->
                    let
                        card =
                            { id = cardId
                            , author = msg.id
                            , votes = 0
                            , text = cardText
                            , revealed = cardRevealed == "true"
                            }
                    in
                        { model | retro = Retro.addCard columnId card model.retro } ! []
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
                      , columnsView model.id model.stage model.cardOver model.columnOver model.retro.columns
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

columnsView : String -> Stage -> Maybe (String, String) -> Maybe String -> Dict String Column -> Html Msg
columnsView connId stage cardOver columnOver columns =
    Bulma.columns [ ]
        <| List.map (columnView connId stage cardOver columnOver)
        <| Dict.toList columns

columnView : String -> Stage -> Maybe (String, String) -> Maybe String -> (String, Column) -> Html Msg
columnView connId stage cardOver columnOver (columnId, column) =
    let
        title = [titleCardView column.name]
        list =
            Dict.toList column.cards
                |> List.map (cardView connId stage cardOver columnId)
                |> List.concat
        add = [addCardView columnId]
    in
        case stage of
            Thinking ->
                Bulma.column [ Attr.classList [ ("over", columnOver == Just columnId)
                                              ]
                             , onDragOver (DragOver columnId)
                             , onDragLeave (DragLeave columnId)
                             , onDrop (Drop)
                             ]
                    (title ++ list ++ add)

            _ ->
                Html.div [ Attr.class "column" ]
                    (title ++ list)

cardView : String -> Stage -> Maybe (String, String) -> String -> (String, Card) -> List (Html Msg)
cardView connId stage cardOver columnId (cardId, card) =
    let
        content =
            Bulma.content []
                [ Html.p [ Attr.class "title is-6" ] [ Html.text card.author ]
                , Html.p [] [ Html.text card.text ]
                ]
    in
        case stage of
            Thinking ->
                if connId == card.author then
                    [ Bulma.card [ Attr.draggable "true"
                                 , onDragStart (DragStart)
                                 , Event.onMouseOver (MouseOver columnId cardId)
                                 , Event.onMouseOut (MouseOut columnId cardId)
                                 ]
                          [ content ]
                    ]
                else
                    []

            Presenting ->
                if not card.revealed then
                    if connId == card.author then
                        [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed) ]
                                     , Event.onClick (Reveal columnId cardId)
                                     ]
                              [ content ]
                        ]
                    else
                        []
                else
                    [ Bulma.card []
                          [ content ]
                    ]

            _ ->
                [ Bulma.card []
                      [ content ]
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
        [ Bulma.content []
              [ Html.textarea [ Event.onInput (ChangeInput columnId), Attr.placeholder "Add a card..." ] [ ]
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

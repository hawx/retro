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
import Column exposing (Column, Card)
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
    , stage : Stage
    , retro : Retro
    , input : String
    , cardOver : Maybe (String, String)
    , columnOver : Maybe String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , stage = Thinking
    , retro = Retro.empty
    , input = ""
    , cardOver = Nothing
    , columnOver = Nothing
    } ! []

-- Update

type Msg = Socket String
         | ChangeInput String String
         | MouseOver String String
         | MouseOut String String
         | DragStart
         | DragOver String
         | DragLeave String
         | Drop
         | SetStage Stage

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

sendAddCard connId columnId cardText =
    WebSocket.send "ws://localhost:8080/ws"
        <| Encode.encode 0
        <| socketMsgEncoder
        <| SocketMsg connId "add" [columnId, cardText]

sendMoveCard connId columnFrom columnTo cardId =
    WebSocket.send "ws://localhost:8080/ws"
        <| Encode.encode 0
        <| socketMsgEncoder
        <| SocketMsg connId "move" [columnFrom, columnTo, cardId]

sendSetStage connId stage =
    WebSocket.send "ws://localhost:8080/ws"
        <| Encode.encode 0
        <| socketMsgEncoder
        <| SocketMsg connId "stage" [toString stage]

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SetStage stage ->
            { model | stage = stage } ! [ sendSetStage model.id stage ]

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
            { model | id = msg.id } ! []

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
                        card = { id = cardId, author = model.id, votes = 0, text = cardText, revealed = cardRevealed == "true" }
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

        _ ->
            model ! []

-- View

view : Model -> Html Msg
view model =
    Html.div []
        [ Html.section [ Attr.class "section" ]
              [ Html.div [ Attr.class "container is-fluid" ]
                    [ tabsView model.stage
                    , columnsView model.stage model.cardOver model.columnOver model.retro.columns
                  ]
            ]
        , Html.footer [ Attr.class "footer" ]
            [ Html.div [ Attr.class "container" ]
                  [ Html.div [ Attr.class "content has-text-centered" ]
                        [ Html.text "A link to github?"
                        ]
                  ]
            ]
        ]

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

columnsView : Stage -> Maybe (String, String) -> Maybe String -> Dict String Column -> Html Msg
columnsView stage cardOver columnOver columns =
    Bulma.columns [ ]
        <| List.map (columnView stage cardOver columnOver)
        <| Dict.toList columns

columnView : Stage -> Maybe (String, String) -> Maybe String -> (String, Column) -> Html Msg
columnView stage cardOver columnOver (columnId, column) =
    let
        title = [titleCardView column.name]
        list = List.map (cardView stage cardOver columnId) (Dict.toList column.cards)
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

cardView : Stage -> Maybe (String, String) -> String -> (String, Card) -> Html Msg
cardView stage cardOver columnId (cardId, card) =
    case stage of
        Thinking ->
            Bulma.card [ Attr.draggable "true"
                     , onDragStart (DragStart)
                     , Event.onMouseOver (MouseOver columnId cardId)
                     , Event.onMouseOut (MouseOut columnId cardId)
                     ]
                [ Bulma.content [ Attr.classList [ ("over", cardOver == Just (columnId, cardId))
                                                 ]
                                ]
                      [ Html.text card.text ]
                ]

        _ ->
            Bulma.card []
                [ Bulma.content []
                      [ Html.text card.text ]
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
    WebSocket.listen "ws://localhost:8080/ws" Socket

port module Main exposing (main)

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

type alias Model =
    { id : String
    , retro : Retro
    , input : String
    , cardOver : Maybe (String, String)
    , columnOver : Maybe String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , retro = Retro.empty
    , input = ""
    , cardOver = Nothing
    , columnOver = Nothing
    } ! []

-- Update

type Msg = Socket String
         | AddCard String
         | ChangeInput String
         | MouseOver String String
         | MouseOut String String
         | DragStart
         | DragOver String
         | DragLeave String
         | Drop

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

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
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

        AddCard columnId ->
            model ! [ sendAddCard model.id columnId model.input ]

        ChangeInput input ->
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

        "add" ->
            case msg.args of
                [columnId, cardId, cardText] ->
                    let
                        card = { id = cardId, author = model.id, votes = 0, text = cardText }
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
    Html.div [ Attr.class "container is-fluid" ]
        [ columnsView model.cardOver model.columnOver model.retro.columns
        ]

columnsView : Maybe (String, String) -> Maybe String -> Dict String Column -> Html Msg
columnsView cardOver columnOver columns =
    Html.div [ Attr.class "columns" ]
        <| List.map (columnView cardOver columnOver)
        <| Dict.toList columns

columnView : Maybe (String, String) -> Maybe String -> (String, Column) -> Html Msg
columnView cardOver columnOver (columnId, column) =
    let
        a = [titleCardView column.name]
        b = List.map (cardView cardOver columnId) (Dict.toList column.cards)
        c = [addCardView columnId]
    in
        Html.div [ Attr.classList [ ("column", True)
                                  , ("over", columnOver == Just columnId)
                                  ]
                 , onDragOver (DragOver columnId)
                 , onDragLeave (DragLeave columnId)
                 , onDrop (Drop)
                 ]
            <| a ++ b ++ c

cardView : Maybe (String, String) -> String -> (String, Card) -> Html Msg
cardView cardOver columnId (cardId, card) =
    Html.div [ Attr.class "card"
             , Attr.draggable "true"
             , onDragStart (DragStart)
             , Event.onMouseOver (MouseOver columnId cardId)
             , Event.onMouseOut (MouseOut columnId cardId)
             ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.classList [ ("content", True)
                                          , ("over", cardOver == Just (columnId, cardId))
                                          ]
                         ]
                    [ Html.text card.text ]
              ]
        ]

titleCardView : String -> Html Msg
titleCardView title =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
                    [ Html.text title ]
              ]
        ]

addCardView : String -> Html Msg
addCardView columnId =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
                    [ Html.input [ Event.onInput ChangeInput ] [ ]
                    , Html.button [ Event.onClick (AddCard columnId) ] [ Html.text "Add" ]
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
    WebSocket.listen "ws://localhost:8080/ws" Socket

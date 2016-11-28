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

main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

-- Model

type alias Card =
    { id : String
    , text : String
    , votes : Int
    , author : String
    }

type alias Column =
    { id : String
    , name : String
    , cards : Dict String Card
    }

type alias Model =
    { id : String
    , columns : Dict String Column
    , input : String
    , cardOver : Maybe (String, String)
    , columnOver : Maybe String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , columns = Dict.empty
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
            case model.cardOver of
                Nothing -> model ! []
                Just (columnFrom, cardId) ->
                    case model.columnOver of
                        Nothing -> model ! []
                        Just columnTo ->
                            { model
                                | columnOver = Nothing
                                , cardOver = Nothing
                            } ! [ sendMoveCard model.id columnFrom columnTo cardId ]

        AddCard columnId ->
            model ! [ sendAddCard model.id columnId model.input ]

        ChangeInput input ->
            { model | input = input } ! []

        Socket data ->
            let
                socketMsg = Debug.log "" <| Decode.decodeString socketMsgDecoder data
            in
                case socketMsg of
                    Ok v ->
                        case v.op of
                            "init" ->
                                { model | id = v.id } ! []

                            "add" ->
                                { model | columns = addCard model.columns v.args } ! []

                            "column" ->
                                { model | columns = addColumn model.columns v.args } ! []

                            "move" ->
                                { model | columns = moveCard model.columns v.args } ! []

                            _  ->
                                model ! []
                    Err _ ->
                        model ! []

getCard : String -> String -> Dict String Column -> Maybe Card
getCard columnId cardId columns =
    case Dict.get columnId columns of
        Nothing -> Nothing
        Just column ->
            Dict.get cardId column.cards

addColumn : Dict String Column -> List String -> Dict String Column
addColumn columns args =
    case args of
        [columnId, columnName] ->
            let
                column : Column
                column = { id = columnId, name = columnName, cards = Dict.empty }
            in
                Dict.insert columnId column columns
        _ -> columns

addCard : Dict String Column -> List String -> Dict String Column
addCard columns args =
    case args of
        [columnId, cardId, cardText] ->
            let
                card : Card
                card = { id = cardId, text = cardText, author = "", votes = 0 }

                insertCard : Column -> Column
                insertCard column = { column | cards = Dict.insert cardId card column.cards }
            in
                Dict.update columnId (Maybe.map insertCard) columns

        _ ->
            columns

moveCard : Dict String Column -> List String -> Dict String Column
moveCard columns args =
    case args of
        [columnFrom, columnTo, cardId] ->
            let
                card = getCard columnFrom cardId columns

                removeCard : Column -> Column
                removeCard column = { column | cards = Dict.remove cardId column.cards }

                insertCard : Card -> Column -> Column
                insertCard c column = { column | cards = Dict.insert cardId c column.cards }
            in
                Dict.update columnTo (Maybe.map2 insertCard card)
                    <| Dict.update columnFrom (Maybe.map removeCard) columns

        _ ->
            columns

-- View

view : Model -> Html Msg
view model =
    Html.div [ Attr.class "container is-fluid" ]
        [ columnsView model.cardOver model.columnOver model.columns
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

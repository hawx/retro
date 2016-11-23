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
    { text : String
    , votes : Int
    , author : String
    }

type alias Model =
    { id : String
    , columns : Dict String (List Card)
    , input : String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , columns = Dict.empty
    , input = ""
    } ! []

-- Update

type Msg = Socket String | AddCard String | ChangeInput String

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

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        AddCard columnName ->
            model ! [WebSocket.send "ws://localhost:8080/ws"
                         <| Encode.encode 0
                         <| socketMsgEncoder
                         <| SocketMsg model.id "add" [columnName, model.input]
                    ]

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

                            _  ->
                                model ! []
                    Err _ ->
                        model ! []

mapOrJust : (a -> b) -> b -> Maybe a -> Maybe b
mapOrJust f value maybe =
    case maybe of
        Just _ -> Maybe.map f maybe
        Nothing -> Just value

addColumn : Dict String (List Card) -> List String -> Dict String (List Card)
addColumn columns args =
    case List.head args of
        Nothing -> columns
        Just name -> Dict.insert name [] columns

addCard : Dict String (List Card) -> List String -> Dict String (List Card)
addCard columns cardDetails =
    let
        cardArray = Array.fromList cardDetails
        columnName = Array.get 0 cardArray
        cardText = Array.get 1 cardArray
        cardFromText text = { text = text, author = "", votes = 0 }
        addToColumn column text =
            Dict.update column (\x -> mapOrJust (\l -> (cardFromText text) :: l) [cardFromText text] x
                               ) columns
    in
        Maybe.withDefault columns
            <| Maybe.map2 (addToColumn) columnName cardText

-- View

view : Model -> Html Msg
view model =
    Html.div [ Attr.class "container is-fluid" ]
        [ columnsView model.columns
        ]

columnsView : Dict String (List Card) -> Html Msg
columnsView columns =
    Html.div [ Attr.class "columns" ]
        <| List.map columnView
        <| Dict.toList columns

columnView : (String, List Card) -> Html Msg
columnView (columnName, cards) =
    Html.div [ Attr.class "column" ]
        <| [titleCardView columnName] ++ List.map cardView cards ++ [addCardView columnName]

cardView : Card -> Html Msg
cardView card =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
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

addCardView columnName =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
                    [ Html.input [ Event.onInput ChangeInput ] [ ]
                    , Html.button [ Event.onClick (AddCard columnName) ] [ Html.text "Add" ]
                    ]
              ]
        ]

-- Subscriptions

subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen "ws://localhost:8080/ws" Socket

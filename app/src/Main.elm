import Debug
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import String
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

type alias Model =
    { id : String
    , cards : List String
    , input : String
    }

init : (Model, Cmd msg)
init =
    { id = ""
    , cards = []
    , input = ""
    } ! []

-- Update

type Msg = Socket String | AddCard | ChangeInput String

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
        AddCard ->
            model ! [WebSocket.send "ws://localhost:8080/ws"
                         <| Encode.encode 0
                         <| socketMsgEncoder
                         <| SocketMsg model.id "add" [model.input]
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
                                { model
                                    | cards = (model.cards ++ v.args)
                                    , id = v.id } ! []

                            "add" ->
                                { model | cards = (model.cards ++ v.args) } ! []

                            _  ->
                                model ! []
                    Err _ ->
                        model ! []

-- View

view : Model -> Html Msg
view model =
    Html.div [ Attr.class "container" ]
        [ cardsView model.cards
        ]

cardsView cards =
    Html.div [ Attr.class "columns" ]
        [ Html.div [ Attr.class "column" ] <|
              (List.map cardView cards) ++ [addCardView]
        ]

cardView text =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
                    [ Html.text text ]
              ]
        ]

addCardView =
    Html.div [ Attr.class "card" ]
        [ Html.div [ Attr.class "card-content" ]
              [ Html.div [ Attr.class "content" ]
                    [ Html.input [ Event.onInput ChangeInput ] [ ]
                    , Html.button [ Event.onClick AddCard ] [ Html.text "Add" ]
                    ]
              ]
        ]

-- Subscriptions

subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen "ws://localhost:8080/ws" Socket

module Sock exposing ( listen
                     , update
                     , init
                     , add
                     , move
                     , stage
                     , reveal
                     , group
                     , vote
                     , MsgData(..))

import WebSocket
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Dict

type alias SocketMsg =
    { id : String
    , op : String
    , data : String
    }

socketMsgDecoder : Decode.Decoder SocketMsg
socketMsgDecoder =
    Pipeline.decode SocketMsg
        |> Pipeline.required "id" Decode.string
        |> Pipeline.required "op" Decode.string
        |> Pipeline.required "data" Decode.string

type MsgData = Error ErrorData
             | Stage StageData
             | Column ColumnData
             | Card CardData
             | Content ContentData
             | Move MoveData
             | Reveal RevealData
             | Group GroupData
             | Vote VoteData

type alias ErrorData = { error : String }

errorDecoder : Decode.Decoder ErrorData
errorDecoder =
    Pipeline.decode ErrorData
        |> Pipeline.required "error" Decode.string

type alias StageData = { stage : String }

stageDecoder : Decode.Decoder StageData
stageDecoder =
    Pipeline.decode StageData
        |> Pipeline.required "stage" Decode.string

type alias ColumnData = { columnId : String, columnName : String }

columnDecoder : Decode.Decoder ColumnData
columnDecoder =
    Pipeline.decode ColumnData
        |> Pipeline.required "columnId" Decode.string
        |> Pipeline.required "columnName" Decode.string

type alias CardData = { columnId : String, cardId : String, revealed : Bool, votes : Int }

cardDecoder : Decode.Decoder CardData
cardDecoder =
    Pipeline.decode CardData
        |> Pipeline.required "columnId" Decode.string
        |> Pipeline.required "cardId" Decode.string
        |> Pipeline.required "revealed" Decode.bool
        |> Pipeline.required "votes" Decode.int

type alias ContentData = { columnId : String, cardId : String, cardText : String }

contentDecoder : Decode.Decoder ContentData
contentDecoder =
    Pipeline.decode ContentData
        |> Pipeline.required "columnId" Decode.string
        |> Pipeline.required "cardId" Decode.string
        |> Pipeline.required "cardText" Decode.string

type alias MoveData = { columnFrom : String, columnTo : String, cardId : String }

moveDecoder : Decode.Decoder MoveData
moveDecoder =
    Pipeline.decode MoveData
        |> Pipeline.required "columnFrom" Decode.string
        |> Pipeline.required "columnTo" Decode.string
        |> Pipeline.required "cardId" Decode.string

type alias RevealData = { columnId : String, cardId : String }

revealDecoder : Decode.Decoder RevealData
revealDecoder =
    Pipeline.decode RevealData
        |> Pipeline.required "columnId" Decode.string
        |> Pipeline.required "cardId" Decode.string

type alias GroupData = { columnFrom : String, cardFrom : String, columnTo : String, cardTo : String }

groupDecoder : Decode.Decoder GroupData
groupDecoder =
    Pipeline.decode GroupData
        |> Pipeline.required "columnFrom" Decode.string
        |> Pipeline.required "cardFrom" Decode.string
        |> Pipeline.required "columnTo" Decode.string
        |> Pipeline.required "cardTo" Decode.string

type alias VoteData = { columnId : String, cardId : String }

voteDecoder : Decode.Decoder VoteData
voteDecoder =
    Pipeline.decode VoteData
        |> Pipeline.required "columnId" Decode.string
        |> Pipeline.required "cardId" Decode.string

socketMsgEncoder : SocketMsg -> Encode.Value
socketMsgEncoder value =
    Encode.object
        [ ("id", Encode.string value.id)
        , ("op", Encode.string value.op)
        , ("data", Encode.string value.data)
        ]

send : String -> String -> String -> Encode.Value -> Cmd msg
send url id op data =
    SocketMsg id op (Encode.encode 0 data)
        |> socketMsgEncoder
        |> Encode.encode 0
        |> WebSocket.send url

listen : String -> (String -> msg) -> Sub msg
listen url tagger =
    WebSocket.listen url tagger

update : String -> model -> ((String, MsgData) -> model -> (model, Cmd msg)) -> (model, Cmd msg)
update data model f =
    let
        runOp decoder tagger d id m =
            case Decode.decodeString decoder d of
                Ok thing -> f (id, tagger thing) m
                Err e -> f (id, Error (ErrorData e)) m

        mux = Dict.fromList
              [ ("stage", runOp stageDecoder Stage)
              , ("card", runOp cardDecoder Card)
              , ("content", runOp contentDecoder Content)
              , ("column", runOp columnDecoder Column)
              , ("move", runOp moveDecoder Move)
              , ("reveal", runOp revealDecoder Reveal)
              , ("group", runOp groupDecoder Group)
              , ("vote", runOp voteDecoder Vote)
              , ("error", runOp errorDecoder Error)
              ]

        runMux { id, op, data } model =
            case Dict.get op mux of
                Just guy ->
                    guy data id model

                Nothing ->
                    (model, Cmd.none)
    in
        case Decode.decodeString socketMsgDecoder data of
            Ok socketMsg -> runMux socketMsg model
            Err _ -> (model, Cmd.none)

init : String -> String -> String -> String -> Cmd msg
init url id name token =
    send url id "init" <|
        Encode.object
            [ ("name", Encode.string name)
            , ("token", Encode.string token)
            ]

add : String -> String -> String -> String -> Cmd msg
add url id columnId cardText =
    send url id "add" <|
        Encode.object
            [ ("columnId", Encode.string columnId)
            , ("cardText", Encode.string cardText)
            ]

move : String -> String -> String -> String -> String -> Cmd msg
move url id columnFrom columnTo cardId =
    send url id "move" <|
        Encode.object
            [ ("columnFrom", Encode.string columnFrom)
            , ("columnTo", Encode.string columnTo)
            , ("cardId", Encode.string cardId)
            ]

stage : String -> String -> String -> Cmd msg
stage url id stage =
    send url id "stage" <|
        Encode.object
            [ ("stage", Encode.string stage)
            ]

reveal : String -> String -> String -> String -> Cmd msg
reveal url id columnId cardId =
    send url id "reveal" <|
        Encode.object
            [ ("columnId", Encode.string columnId)
            , ("cardId", Encode.string cardId)
            ]

group : String -> String -> String -> String -> String -> String -> Cmd msg
group url id columnFrom cardFrom columnTo cardTo =
    send url id "group" <|
        Encode.object
            [ ("columnFrom", Encode.string columnFrom)
            , ("cardFrom", Encode.string cardFrom)
            , ("columnTo", Encode.string columnTo)
            , ("cardTo", Encode.string cardTo)
            ]

vote : String -> String -> String -> String -> Cmd msg
vote url id columnId cardId =
    send url id "vote" <|
        Encode.object
            [ ("columnId", Encode.string columnId)
            , ("cardId", Encode.string cardId)
            ]

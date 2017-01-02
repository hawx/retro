module Sock exposing ( listen
                     , update
                     , SocketMsg
                     , init
                     , add
                     , move
                     , stage
                     , reveal
                     , group
                     , vote)

import WebSocket
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline

type alias SocketMsg =
    { id : String
    , op : String
    , args : List String
    , data : String
    }

socketMsgDecoder : Decode.Decoder SocketMsg
socketMsgDecoder =
    Pipeline.decode SocketMsg
        |> Pipeline.required "id" Decode.string
        |> Pipeline.required "op" Decode.string
        |> Pipeline.required "args" (Decode.list Decode.string)
        |> Pipeline.required "data" Decode.string

socketMsgEncoder : SocketMsg -> Encode.Value
socketMsgEncoder value =
    Encode.object
        [ ("id", Encode.string value.id)
        , ("op", Encode.string value.op)
        , ("args", Encode.list (List.map Encode.string value.args))
        , ("data", Encode.string value.data)
        ]

send : String -> String -> String -> List String -> Cmd msg
send url id op args =
    SocketMsg id op args ""
        |> socketMsgEncoder
        |> Encode.encode 0
        |> WebSocket.send url

send2 : String -> String -> String -> Encode.Value -> Cmd msg
send2 url id op data =
    SocketMsg id op [] (Encode.encode 0 data)
        |> socketMsgEncoder
        |> Encode.encode 0
        |> WebSocket.send url

listen : String -> (String -> msg) -> Sub msg
listen url tagger =
    WebSocket.listen url tagger

update : String -> model -> (SocketMsg -> model -> (model, Cmd msg)) -> (model, Cmd msg)
update data model f =
    case Decode.decodeString socketMsgDecoder data of
        Ok socketMsg -> f socketMsg model
        Err _ -> (model, Cmd.none)

init : String -> String -> String -> String -> Cmd msg
init url id name token =
    send2 url id "init" (initOp name token)

initOp name token =
    Encode.object
        [ ("name", Encode.string name)
        , ("token", Encode.string token)
        ]

add : String -> String -> String -> String -> Cmd msg
add url id columnId cardText =
    send2 url id "add" (addOp columnId cardText)

addOp columnId cardText =
    Encode.object
        [ ("columnId", Encode.string columnId)
        , ("cardText", Encode.string cardText)
        ]

move : String -> String -> String -> String -> String -> Cmd msg
move url id columnFrom columnTo cardId =
    send2 url id "move" (moveOp columnFrom columnTo cardId)

moveOp columnFrom columnTo cardId =
    Encode.object
        [ ("columnFrom", Encode.string columnFrom)
        , ("columnTo", Encode.string columnTo)
        , ("cardId", Encode.string cardId)
        ]

stage : String -> String -> String -> Cmd msg
stage url id stage =
    send2 url id "stage" (stageOp stage)

stageOp stage =
    Encode.object
        [ ("stage", Encode.string stage)
        ]

reveal : String -> String -> String -> String -> Cmd msg
reveal url id columnId cardId =
    send2 url id "reveal" (revealOp columnId cardId)

revealOp columnId cardId =
    Encode.object
        [ ("columnId", Encode.string columnId)
        , ("cardId", Encode.string cardId)
        ]

group : String -> String -> String -> String -> String -> String -> Cmd msg
group url id columnFrom cardFrom columnTo cardTo =
    send2 url id "group" (groupOp columnFrom cardFrom columnTo cardTo)

groupOp columnFrom cardFrom columnTo cardTo =
    Encode.object
        [ ("columnFrom", Encode.string columnFrom)
        , ("cardFrom", Encode.string cardFrom)
        , ("columnTo", Encode.string columnTo)
        , ("cardTo", Encode.string cardTo)
        ]

vote : String -> String -> String -> String -> Cmd msg
vote url id columnId cardId =
    send2 url id "vote" (voteOp columnId cardId)

voteOp : String -> String -> Encode.Value
voteOp columnId cardId =
    Encode.object
        [ ("columnId", Encode.string columnId)
        , ("cardId", Encode.string cardId)
        ]

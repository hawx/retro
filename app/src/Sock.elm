module Sock exposing (send, listen, update, SocketMsg)

import WebSocket
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline

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

send : String -> String -> String -> List String -> Cmd msg
send url id op args =
    SocketMsg id op args
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

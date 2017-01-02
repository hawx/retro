module Sock.LowLevel exposing ( listen
                              , send
                              , update)

{-| This module provides a basic format for passing websocket messages with.  It
contains the generic parts of the implementation that define a JSON object with
"id", "op" and "data" properties.
-}

import WebSocket
import Json.Encode as Encode
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline

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

update : String -> model -> (SocketMsg -> model -> (model, Cmd msg)) -> (model, Cmd msg)
update data model f =
    case Decode.decodeString socketMsgDecoder data of
        Ok socketMsg -> f socketMsg model
        Err _ -> (model, Cmd.none)

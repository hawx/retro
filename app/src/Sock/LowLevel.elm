module Sock.LowLevel exposing (listen, send)

{-| This module provides a basic format for passing websocket messages with. It
contains the generic parts of the implementation that define a JSON object with
"id", "op" and "data" properties.
-}

import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import WebSocket


type alias SocketMsg =
    { id : String
    , op : String
    , data : String
    }


type alias AuthenticatedMsg =
    { id : String
    , op : String
    , data : String
    , username : String
    , token : String
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
        [ ( "id", Encode.string value.id )
        , ( "op", Encode.string value.op )
        , ( "data", Encode.string value.data )
        ]


authenticatedMsgEncoder : AuthenticatedMsg -> Encode.Value
authenticatedMsgEncoder value =
    Encode.object
        [ ( "id", Encode.string value.id )
        , ( "auth"
          , Encode.object
                [ ( "username", Encode.string value.username )
                , ( "token", Encode.string value.token )
                ]
          )
        , ( "op", Encode.string value.op )
        , ( "data", Encode.string value.data )
        ]


send : String -> String -> String -> String -> Encode.Value -> Cmd msg
send url id token op data =
    AuthenticatedMsg id op (Encode.encode 0 data) id token
        |> authenticatedMsgEncoder
        |> Encode.encode 0
        |> WebSocket.send url


listen : String -> Sub (Result String SocketMsg)
listen url =
    WebSocket.listen url identity |> Sub.map (Decode.decodeString socketMsgDecoder)

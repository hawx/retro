module Data.Content
    exposing
        ( Content
        , Id
        , decodeId
        , encodeId
        )

import Json.Decode as Decode
import Json.Encode as Encode


type Id
    = Id String


decodeId : Decode.Decoder Id
decodeId =
    Decode.string |> Decode.map Id


encodeId : Id -> Encode.Value
encodeId (Id id) =
    Encode.string id


type alias Content =
    { id : Id
    , text : String
    , author : String
    }

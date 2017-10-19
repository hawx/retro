module Data.IdToken exposing (IdToken, decode)

import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Jwt


type alias IdToken =
    { raw : String
    , username : String
    }


decode : String -> Maybe IdToken
decode raw =
    Jwt.decodeToken (decodeJson raw) raw |> Result.toMaybe


decodeJson : String -> Decode.Decoder IdToken
decodeJson raw =
    Pipeline.decode IdToken
        |> Pipeline.hardcoded raw
        |> Pipeline.required "sub" Decode.string

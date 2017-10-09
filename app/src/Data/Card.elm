module Data.Card
    exposing
        ( Card
        , Id
        , authored
        , create
        , decodeId
        , encodeId
        )

import Data.Content exposing (Content)
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


type alias Card =
    { id : Id
    , revealed : Bool
    , votes : Int
    , totalVotes : Int
    , contents : List Content
    , editing : Bool
    }


create : String -> Int -> Int -> Bool -> Card
create id votes totalVotes revealed =
    { id = Id id
    , votes = votes
    , totalVotes = totalVotes
    , revealed = revealed
    , contents = []
    , editing = False
    }


authored : String -> Card -> Bool
authored author card =
    List.any (\x -> x.author == author) card.contents

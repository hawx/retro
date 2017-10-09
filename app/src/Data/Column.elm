module Data.Column
    exposing
        ( Column
        , Id
        , addCard
        , cardsByVote
        , create
        , decodeId
        , encodeId
        , getCard
        , removeCard
        , updateCard
        )

import Data.Card as Card exposing (Card)
import Dict exposing (Dict)
import EveryDict exposing (EveryDict)
import Json.Decode as Decode
import Json.Encode as Encode
import List


type Id
    = Id String


decodeId : Decode.Decoder Id
decodeId =
    Decode.string |> Decode.map Id


encodeId : Id -> Encode.Value
encodeId (Id id) =
    Encode.string id


type alias Column =
    { id : Id
    , name : String
    , order : Int
    , cards : EveryDict Card.Id Card
    }


create : String -> String -> Int -> Column
create id name order =
    { id = Id id, name = name, order = order, cards = EveryDict.empty }


getCard : Card.Id -> Column -> Maybe Card
getCard cardId column =
    EveryDict.get cardId column.cards


addCard : Card -> Column -> Column
addCard card column =
    { column | cards = EveryDict.insert card.id card column.cards }


removeCard : Card.Id -> Column -> Column
removeCard cardId column =
    { column | cards = EveryDict.remove cardId column.cards }


updateCard : Card.Id -> (Card -> Card) -> Column -> Column
updateCard cardId f column =
    { column | cards = EveryDict.update cardId (Maybe.map f) column.cards }


cardsByVote : EveryDict Id Column -> List ( Int, List Card )
cardsByVote columns =
    EveryDict.values columns
        |> List.map (.cards >> EveryDict.values)
        |> List.concat
        |> List.filter .revealed
        |> groupBy .totalVotes
        |> Dict.toList
        |> List.sortBy (\( a, _ ) -> -a)


groupBy : (a -> comparable) -> List a -> Dict comparable (List a)
groupBy classifier list =
    let
        insert_ x maybe =
            Maybe.withDefault [] maybe
                |> (::) x
                |> Just

        into el acc =
            Dict.update (classifier el) (insert_ el) acc
    in
    List.foldl into Dict.empty list

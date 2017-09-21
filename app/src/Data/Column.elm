module Data.Column
    exposing
        ( Column
        , addCard
        , cardsByVote
        , getCard
        , removeCard
        , updateCard
        )

import Data.Card exposing (Card)
import Dict exposing (Dict)
import List


type alias Column =
    { id : String
    , name : String
    , order : Int
    , cards : Dict String Card
    }


getCard : String -> Column -> Maybe Card
getCard cardId column =
    Dict.get cardId column.cards


addCard : Card -> Column -> Column
addCard card column =
    { column | cards = Dict.insert card.id card column.cards }


removeCard : String -> Column -> Column
removeCard cardId column =
    { column | cards = Dict.remove cardId column.cards }


updateCard : String -> (Card -> Card) -> Column -> Column
updateCard cardId f column =
    { column | cards = Dict.update cardId (Maybe.map f) column.cards }


cardsByVote : Dict String Column -> List ( Int, List Card )
cardsByVote columns =
    Dict.values columns
        |> List.map (.cards >> Dict.values)
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

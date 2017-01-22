module Column exposing ( Column
                       , getCard
                       , addCard
                       , removeCard
                       , updateCard
                       , cardsByVote)

import Dict exposing (Dict)
import Card exposing (Card)

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


cardsByVote : Dict String Column -> List (Int, List Card)
cardsByVote columns =
    let
        getList dict =
            Dict.toList dict |> List.map (\(_,b) -> b)

        groupInsert x maybe =
            case maybe of
                Just list -> Just (x :: list)
                Nothing -> Just [x]

        group res list =
            case list of
                (x :: xs) -> group (Dict.update x.votes (groupInsert x) res) xs
                [] -> res
    in
        getList columns
            |> List.map (.cards)
            |> List.map getList
            |> List.concat
            |> List.filter (.revealed)
            |> group Dict.empty
            |> Dict.toList
            |> List.sortBy (\(a,_) -> a)
            |> List.reverse

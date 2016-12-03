module Column exposing ( Column
                       , getCard
                       , addCard
                       , removeCard
                       , updateCard)

import Dict exposing (Dict)
import Card exposing (Card)

type alias Column =
    { id : String
    , name : String
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

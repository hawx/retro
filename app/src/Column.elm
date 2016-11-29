module Column exposing ( Column
                       , Card
                       , getCard
                       , addCard
                       , removeCard)

import Dict exposing (Dict)

type alias Card =
    { id : String
    , text : String
    , votes : Int
    , author : String
    }

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

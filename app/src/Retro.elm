module Retro exposing (..)

import Dict exposing (Dict)
import Column exposing (Column, Card)

type alias Retro =
    { columns : Dict String Column
    }

empty : Retro
empty =
    { columns = Dict.empty
    }

getCard : String -> String -> Retro -> Maybe Card
getCard columnId cardId retro =
    case Dict.get columnId retro.columns of
        Nothing -> Nothing

        Just column ->
            Dict.get cardId column.cards


addColumn : Column -> Retro -> Retro
addColumn column retro =
    { retro | columns = Dict.insert column.id column retro.columns }


addCard : String -> Card -> Retro -> Retro
addCard columnId card retro =
    { retro | columns = Dict.update columnId (Maybe.map (Column.addCard card)) retro.columns }

moveCard : String -> String -> String -> Retro -> Retro
moveCard columnFrom columnTo cardId retro =
    let
        card = getCard columnFrom cardId retro
    in
        { retro
            | columns = Dict.update columnTo (Maybe.map2 Column.addCard card)
              (Dict.update columnFrom (Maybe.map (Column.removeCard cardId)) retro.columns)
        }

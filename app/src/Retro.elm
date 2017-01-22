module Retro exposing (..)

import Dict exposing (Dict)
import Column exposing (Column)
import Card exposing (Card, Content)

type Stage = Thinking | Presenting | Voting | Discussing

type alias Retro =
    { columns : Dict String Column
    , stage : Stage
    }

empty : Retro
empty =
    { columns = Dict.empty
    , stage = Thinking
    }

setStage : Stage -> Retro -> Retro
setStage stage retro =
    { retro | stage = stage }

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

removeCard : String -> String -> Retro -> Retro
removeCard columnId cardId =
    updateColumn columnId (Column.removeCard cardId)

moveCard : String -> String -> String -> Retro -> Retro
moveCard columnFrom columnTo cardId retro =
    let
        card = getCard columnFrom cardId retro
    in
        { retro
            | columns = Dict.update columnTo (Maybe.map2 Column.addCard card)
              (Dict.update columnFrom (Maybe.map (Column.removeCard cardId)) retro.columns)
        }

updateColumn : String -> (Column -> Column) -> Retro -> Retro
updateColumn columnId f retro =
    { retro | columns = Dict.update columnId (Maybe.map f) retro.columns }

updateCard : String -> String -> (Card -> Card) -> Retro -> Retro
updateCard columnId cardId f  =
    let
        updateHelp column = Column.updateCard cardId f column
    in
        updateColumn columnId updateHelp

revealCard : String -> String -> Retro -> Retro
revealCard columnId cardId =
    updateCard columnId cardId (\card -> { card | revealed = True })

voteCard : String -> String -> Retro -> Retro
voteCard columnId cardId =
    updateCard columnId cardId (\card -> { card | votes = card.votes + 1 })

addContent : String -> String -> Content -> Retro -> Retro
addContent columnId cardId content =
    updateCard columnId cardId (\card -> { card | contents = card.contents ++ [content] })

groupCards : (String, String) -> (String, String) -> Retro -> Retro
groupCards (columnFrom, cardFrom) (columnTo, cardTo) retro =
    let
        updateHelp b =
            case getCard columnFrom cardFrom retro of
                Just a ->
                    { b | votes = a.votes + b.votes
                    , revealed = a.revealed || b.revealed
                    , contents = List.concat [a.contents, b.contents]
                    }
                Nothing ->
                    b
    in
        retro
            |> removeCard columnFrom cardFrom
            |> updateCard columnTo cardTo updateHelp

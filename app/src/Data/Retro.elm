module Data.Retro exposing (..)

import Data.Card as Card exposing (Card)
import Data.Column as Column exposing (Column)
import Data.Content exposing (Content)
import Dict exposing (Dict)
import EveryDict exposing (EveryDict)


type Stage
    = Thinking
    | Presenting
    | Voting
    | Discussing


type alias Retro =
    { columns : EveryDict Column.Id Column
    , stage : Stage
    }


empty : Retro
empty =
    { columns = EveryDict.empty
    , stage = Thinking
    }


setStage : Stage -> Retro -> Retro
setStage stage retro =
    { retro | stage = stage }


getCard : Column.Id -> Card.Id -> Retro -> Maybe Card
getCard columnId cardId retro =
    case EveryDict.get columnId retro.columns of
        Nothing ->
            Nothing

        Just column ->
            EveryDict.get cardId column.cards


addColumn : Column -> Retro -> Retro
addColumn column retro =
    { retro | columns = EveryDict.insert column.id column retro.columns }


addCard : Column.Id -> Card -> Retro -> Retro
addCard columnId card retro =
    { retro | columns = EveryDict.update columnId (Maybe.map (Column.addCard card)) retro.columns }


removeCard : Column.Id -> Card.Id -> Retro -> Retro
removeCard columnId cardId =
    updateColumn columnId (Column.removeCard cardId)


moveCard : Column.Id -> Column.Id -> Card.Id -> Retro -> Retro
moveCard columnFrom columnTo cardId retro =
    let
        card =
            getCard columnFrom cardId retro
    in
    { retro
        | columns =
            EveryDict.update columnTo
                (Maybe.map2 Column.addCard card)
                (EveryDict.update columnFrom (Maybe.map (Column.removeCard cardId)) retro.columns)
    }


updateColumn : Column.Id -> (Column -> Column) -> Retro -> Retro
updateColumn columnId f retro =
    { retro | columns = EveryDict.update columnId (Maybe.map f) retro.columns }


updateCard : Column.Id -> Card.Id -> (Card -> Card) -> Retro -> Retro
updateCard columnId cardId f =
    let
        updateHelp column =
            Column.updateCard cardId f column
    in
    updateColumn columnId updateHelp


revealCard : Column.Id -> Card.Id -> Retro -> Retro
revealCard columnId cardId =
    updateCard columnId cardId (\card -> { card | revealed = True })


voteCard : Int -> Column.Id -> Card.Id -> Retro -> Retro
voteCard count columnId cardId =
    updateCard columnId cardId (\card -> { card | votes = card.votes + count, totalVotes = card.totalVotes + count })


totalVoteCard : Int -> Column.Id -> Card.Id -> Retro -> Retro
totalVoteCard count columnId cardId =
    updateCard columnId cardId (\card -> { card | totalVotes = card.totalVotes + count })


addContent : Column.Id -> Card.Id -> Content -> Retro -> Retro
addContent columnId cardId content =
    let
        alreadyContainsContent contents =
            List.any (\x -> x.id == content.id) contents

        contents c =
            if alreadyContainsContent c.contents then
                List.map
                    (\x ->
                        if x.id == content.id then
                            { x | text = content.text }
                        else
                            x
                    )
                    c.contents
            else
                c.contents ++ [ content ]
    in
    updateCard columnId cardId (\card -> { card | contents = contents card })


groupCards : ( Column.Id, Card.Id ) -> ( Column.Id, Card.Id ) -> Retro -> Retro
groupCards ( columnFrom, cardFrom ) ( columnTo, cardTo ) retro =
    let
        updateHelp b =
            case getCard columnFrom cardFrom retro of
                Just a ->
                    { b
                        | votes = a.votes + b.votes
                        , revealed = a.revealed || b.revealed
                        , contents = List.concat [ a.contents, b.contents ]
                    }

                Nothing ->
                    b
    in
    retro
        |> removeCard columnFrom cardFrom
        |> updateCard columnTo cardTo updateHelp


editingCard : Column.Id -> Card.Id -> Bool -> Retro -> Retro
editingCard columnId cardId editing =
    updateCard columnId cardId (\card -> { card | editing = editing })

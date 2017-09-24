module Data.Retro exposing (..)

import Data.Card exposing (Card, Content)
import Data.Column as Column exposing (Column)
import Dict exposing (Dict)


type Stage
    = Thinking
    | Presenting
    | Voting
    | Discussing


type alias Retro =
    { columns : Dict String Column
    , stage : Stage
    , leader : Maybe String
    }


empty : Retro
empty =
    { columns = Dict.empty
    , stage = Thinking
    , leader = Nothing
    }


setStage : Stage -> Retro -> Retro
setStage stage retro =
    { retro | stage = stage }


setLeader : String -> Retro -> Retro
setLeader leader retro =
    { retro | leader = Just leader }


getCard : String -> String -> Retro -> Maybe Card
getCard columnId cardId retro =
    case Dict.get columnId retro.columns of
        Nothing ->
            Nothing

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
        card =
            getCard columnFrom cardId retro
    in
    { retro
        | columns =
            Dict.update columnTo
                (Maybe.map2 Column.addCard card)
                (Dict.update columnFrom (Maybe.map (Column.removeCard cardId)) retro.columns)
    }


updateColumn : String -> (Column -> Column) -> Retro -> Retro
updateColumn columnId f retro =
    { retro | columns = Dict.update columnId (Maybe.map f) retro.columns }


updateCard : String -> String -> (Card -> Card) -> Retro -> Retro
updateCard columnId cardId f =
    let
        updateHelp column =
            Column.updateCard cardId f column
    in
    updateColumn columnId updateHelp


revealCard : String -> String -> Retro -> Retro
revealCard columnId cardId =
    updateCard columnId cardId (\card -> { card | revealed = True })


voteCard : Int -> String -> String -> Retro -> Retro
voteCard count columnId cardId =
    updateCard columnId cardId (\card -> { card | votes = card.votes + count, totalVotes = card.totalVotes + count })


totalVoteCard : Int -> String -> String -> Retro -> Retro
totalVoteCard count columnId cardId =
    updateCard columnId cardId (\card -> { card | totalVotes = card.totalVotes + count })


addContent : String -> String -> Content -> Retro -> Retro
addContent columnId cardId content =
    updateCard columnId cardId (\card -> { card | contents = card.contents ++ [ content ] })


groupCards : ( String, String ) -> ( String, String ) -> Retro -> Retro
groupCards ( columnFrom, cardFrom ) ( columnTo, cardTo ) retro =
    let
        updateHelp b =
            case getCard columnFrom cardFrom retro of
                Just a ->
                    { b
                        | votes = a.votes + b.votes
                        , totalVotes = a.totalVotes + b.totalVotes
                        , revealed = a.revealed || b.revealed
                        , contents = List.concat [ a.contents, b.contents ]
                    }

                Nothing ->
                    b
    in
    retro
        |> removeCard columnFrom cardFrom
        |> updateCard columnTo cardTo updateHelp

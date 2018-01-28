module Page.RetroModel exposing (CardDragging, CardOver, Model)

import Data.Card as Card
import Data.Column as Column
import Data.Retro exposing (Retro)
import DragAndDrop
import EveryDict exposing (EveryDict)


type alias CardDragging =
    ( Column.Id, Card.Id )


type alias CardOver =
    ( Column.Id, Maybe Card.Id )


type alias Model =
    { retro : Retro
    , inputs : EveryDict Column.Id String
    , dnd : DragAndDrop.Model CardDragging CardOver
    , lastRevealed : Maybe Card.Id
    }

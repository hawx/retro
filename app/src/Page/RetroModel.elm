module Page.RetroModel exposing (CardDragging, CardOver, Model)

import Data.Card as Card
import Data.Column as Column
import Data.Retro exposing (Retro)
import DragAndDrop


type alias CardDragging =
    ( Column.Id, Card.Id )


type alias CardOver =
    ( Column.Id, Maybe Card.Id )


type alias Model =
    { retro : Retro
    , input : String
    , dnd : DragAndDrop.Model CardDragging CardOver
    , lastRevealed : Maybe Card.Id
    }

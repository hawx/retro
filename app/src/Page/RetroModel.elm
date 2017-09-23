module Page.RetroModel exposing (CardDragging, CardOver, Model)

import Data.Retro exposing (Retro)
import DragAndDrop


type alias CardDragging =
    ( String, String )


type alias CardOver =
    ( String, Maybe String )


type alias Model =
    { retro : Retro
    , input : String
    , dnd : DragAndDrop.Model CardDragging CardOver
    , lastRevealed : Maybe String
    }

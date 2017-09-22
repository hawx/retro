module Page.RetroMsg exposing (Msg(..))

import Data.Retro as Retro
import DragAndDrop


type Msg
    = ChangeInput String String
    | CreateCard String
    | DeleteCard String String
    | SetStage Retro.Stage
    | Reveal String String
    | Vote String String
    | Unvote String String
    | DnD (DragAndDrop.Msg ( String, String ) ( String, Maybe String ))

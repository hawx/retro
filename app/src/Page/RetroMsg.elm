module Page.RetroMsg exposing (Msg(..))

import Data.Retro as Retro
import DragAndDrop
import Route exposing (Route)


type Msg
    = ChangeInput String String
    | CreateCard String
    | UpdateCard String String String 
    | DeleteCard String String
    | DiscardEditCard String String
    | EditCard String String
    | SetStage Retro.Stage
    | Reveal String String
    | Vote String String
    | Unvote String String
    | DnD (DragAndDrop.Msg ( String, String ) ( String, Maybe String ))
    | Navigate Route

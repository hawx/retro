module Page.RetroMsg exposing (Msg(..))

import Data.Card as Card
import Data.Column as Column
import Data.Content as Content
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
    | Reveal Column.Id Card.Id
    | Vote Column.Id Card.Id
    | Unvote Column.Id Card.Id
    | DnD (DragAndDrop.Msg ( Column.Id, Card.Id ) ( Column.Id, Maybe Card.Id ))
    | Navigate Route

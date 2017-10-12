module Page.RetroMsg exposing (Msg(..))

import Data.Card as Card
import Data.Column as Column
import Data.Content as Content
import Data.Retro as Retro
import DragAndDrop
import Route exposing (Route)


type Msg
    = ChangeInput Column.Id String
    | CreateCard Column.Id
    | UpdateCard Column.Id Card.Id Content.Id 
    | DeleteCard Column.Id Card.Id
    | DiscardEditCard Column.Id Card.Id
    | EditCard Column.Id Card.Id
    | SetStage Retro.Stage
    | Reveal Column.Id Card.Id
    | Vote Column.Id Card.Id
    | Unvote Column.Id Card.Id
    | DnD (DragAndDrop.Msg ( Column.Id, Card.Id ) ( Column.Id, Maybe Card.Id ))
    | Navigate Route

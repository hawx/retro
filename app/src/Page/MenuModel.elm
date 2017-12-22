module Page.MenuModel exposing (Model, Retro)

import Data.Retro exposing (Id)
import Date exposing (Date)
import EveryDict exposing (EveryDict)


type alias Retro =
    { id : Id
    , name : String
    , createdAt : Date
    , participants : List String
    }


type alias Model =
    { retros : EveryDict Id Retro
    , retroName : String
    , possibleParticipants : List String
    , participant : String
    , currentChoice : Maybe Id
    , showNewRetro : Bool
    }

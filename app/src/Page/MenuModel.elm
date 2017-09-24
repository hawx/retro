module Page.MenuModel exposing (Model, Retro)

import Date exposing (Date)


type alias Model =
    { retroList : List Retro
    , retroName : String
    , possibleParticipants : List String
    , participants : List String
    , participant : String
    , currentChoice : Maybe Retro
    }


type alias Retro =
    { id : String
    , name : String
    , leader : String
    , createdAt : Date
    , participants : List String
    }

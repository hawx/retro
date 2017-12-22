module Page.MenuMsg exposing (Msg(..))

import Data.Retro exposing (Id)
import Route exposing (Route)


type Msg
    = CreateRetro
    | NewRetro
    | SetRetroName String
    | AddParticipant
    | SetParticipant String
    | DeleteParticipant String
    | ShowRetroDetails Id
    | Navigate Route
    | SignOut

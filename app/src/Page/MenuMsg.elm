module Page.MenuMsg exposing (Msg(..))

import Route exposing (Route)


type Msg
    = CreateRetro
    | SetRetroName String
    | AddParticipant
    | SetParticipant String
    | DeleteParticipant String
    | SelectParticipant String
    | ShowRetroDetails String
    | Navigate Route
    | SignOut

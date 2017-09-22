module Page.MenuMsg exposing (Msg(..))


type Msg
    = CreateRetro
    | SetRetroName String
    | AddParticipant
    | SetParticipant String
    | DeleteParticipant String
    | SelectParticipant String
    | ShowRetroDetails String

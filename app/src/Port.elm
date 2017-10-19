port module Port exposing (..)


port storageGet : String -> Cmd msg


port signOut : () -> Cmd msg


port storageGot : (Maybe String -> msg) -> Sub msg

port module Port exposing (..)


port storageSet : ( String, String ) -> Cmd msg


port storageGet : String -> Cmd msg


port signOut : () -> Cmd msg


port storageGot : (Maybe String -> msg) -> Sub msg

module Card exposing (Card)

type alias Card =
    { id : String
    , text : String
    , votes : Int
    , author : String
    , revealed : Bool
    }

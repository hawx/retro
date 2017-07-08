module Data.Card
    exposing
        ( Card
        , Content
        , authored
        )


type alias Card =
    { id : String
    , votes : Int
    , revealed : Bool
    , contents : List Content
    }


type alias Content =
    { id : String
    , text : String
    , author : String
    }


authored : String -> Card -> Bool
authored author card =
    List.any (\x -> x.author == author) card.contents

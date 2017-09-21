module Data.Card
    exposing
        ( Card
        , Content
        , authored
        )


type alias Card =
    { id : String
    , revealed : Bool
    , votes : Int
    , totalVotes : Int
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

module Route
    exposing
        ( Route(..)
        , parse
        , toUrl
        )

import Navigation exposing (Location)
import UrlParser exposing ((</>), Parser, map, oneOf, parseHash, s, string, top)


type Route
    = Menu
    | Retro String


route : Parser (Route -> a) a
route =
    oneOf
        [ map Menu top
        , map Retro string
        ]


parse : Location -> Maybe Route
parse location =
    parseHash route location


toUrl : Route -> String
toUrl r =
    case r of
        Menu ->
            "#/"

        Retro retroId ->
            "#/" ++ retroId

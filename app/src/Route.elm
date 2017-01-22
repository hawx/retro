module Route exposing (Route(..)
                      , parse
                      , toUrl
                      )

import UrlParser exposing (Parser, (</>), s, top, string, map, oneOf, parseHash)
import Navigation exposing (Location)

type Route = Menu | Retro String

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
        Menu -> "#/"
        Retro retroId -> "#/" ++ retroId

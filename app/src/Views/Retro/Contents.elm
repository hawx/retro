module Views.Retro.Contents exposing (view)

import Bitwise
import Bulma
import Char
import Data.Content exposing (Content)
import Html exposing (Html)
import Html.Attributes as Attr


view : List Content -> Html msg
view contents =
    contents
        |> List.map contentView
        |> List.intersperse (Html.hr [] [])
        |> Bulma.content []


contentView : Content -> Html msg
contentView content =
    Bulma.content []
        [ Html.p [ Attr.class "title is-6" ]
            [ Html.span
                [ Attr.class "tag"
                , Attr.style [ ( "background-color", stringToColour content.author ) ]
                ]
                []
            , Html.span [] [ Html.text "  " ]
            , Html.text content.author
            ]
        , Html.p [] [ Html.text content.text ]
        ]


stringToColour : String -> String
stringToColour str =
    let
        hashChar char prev =
            Char.toCode char + (Bitwise.shiftLeftBy 5 prev - prev)

        hash =
            String.foldl hashChar 0 str

        part i =
            Bitwise.and (Bitwise.shiftRightBy (i * 8) hash) 0xFF
                |> toString
                |> String.padLeft 2 '0'
                |> (\x -> String.slice -2 (String.length x) x)
    in
    "#" ++ part 0 ++ part 1 ++ part 2

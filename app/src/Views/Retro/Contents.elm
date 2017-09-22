module Views.Retro.Contents exposing (view)

import Bulma
import Data.Card as Card exposing (Content)
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
        [ Html.p [ Attr.class "title is-6" ] [ Html.text content.author ]
        , Html.p [] [ Html.text content.text ]
        ]

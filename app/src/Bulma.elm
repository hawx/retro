module Bulma exposing (..)

import Html exposing (Html)
import Html.Attributes as Attr

tabs : List (Html.Attribute msg) -> List (Html msg) -> Html msg
tabs attrs =
    Html.div ([ Attr.class "tabs" ] ++ attrs)

columns : List (Html.Attribute msg) -> List (Html msg) -> Html msg
columns attrs =
    Html.div ([ Attr.class "columns" ] ++ attrs)

column : List (Html.Attribute msg) -> List (Html msg) -> Html msg
column attrs =
    Html.div ([ Attr.class "column" ] ++ attrs)

card : List (Html.Attribute msg) -> List (Html msg) -> Html msg
card attrs body =
    Html.div ([ Attr.class "card" ] ++ attrs)
        [ Html.div [ Attr.class "card-content" ]
              body
        ]

content : List (Html.Attribute msg) -> List (Html msg) -> Html msg
content attrs =
    Html.div ([ Attr.class "content" ] ++ attrs)

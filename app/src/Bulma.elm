module Bulma exposing (..)

import Html exposing (Html)
import Html.Attributes as Attr

modal : List (Html msg) -> Html msg
modal body =
    Html.div [ Attr.class "modal is-active" ]
        [ Html.div [ Attr.class "modal-background" ] []
        , Html.div [ Attr.class "modal-content" ] body
        , Html.button [ Attr.class "modal-close" ] []
        ]

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

box : List (Html.Attribute msg) -> List (Html msg) -> Html msg
box attrs =
    Html.div ([ Attr.class "box" ] ++ attrs)

button : List (Html.Attribute msg) -> List (Html msg) -> Html msg
button attrs body =
    Html.p [ Attr.class "control" ]
        [ Html.button ([ Attr.class "button" ] ++ attrs) body
        ]

label : String -> Html msg
label name =
    Html.label [ Attr.class "label" ] [ Html.text name ]

input : List (Html.Attribute msg) -> Html msg
input attrs =
    Html.p [ Attr.class "control" ]
        [ Html.input ([ Attr.class "input", Attr.type_ "text" ] ++ attrs) []
        ]

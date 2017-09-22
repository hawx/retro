module Views.Menu.Header exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr


view : Html msg
view =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.title "Retro" ]
            ]
        ]

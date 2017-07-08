module Views.SignIn exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr


view : Html msg
view =
    Bulma.modal
        [ Bulma.box []
            [ Html.a
                [ Attr.class "button is-primary"
                , Attr.href "/oauth/login"
                ]
                [ Html.text "Sign-in with GitHub" ]
            ]
        ]

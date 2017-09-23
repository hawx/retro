module Page.SignIn exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Views.Footer


view : Html msg
view =
    Html.div []
        [ Html.section [ Attr.class "hero is-dark is-bold is-large" ]
            [ Html.div [ Attr.class "hero-body" ]
                [ Bulma.container
                    [ Bulma.title "Retro"
                    , Html.a
                        [ Attr.class "button is-primary is-outlined"
                        , Attr.href "/oauth/login"
                        ]
                        [ Html.text "Sign-in with GitHub" ]
                    ]
                ]
            ]
        , Views.Footer.view
        ]

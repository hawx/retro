module Views.Footer exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr


view : Html msg
view =
    Html.footer [ Attr.class "footer" ]
        [ Html.div [ Attr.class "container" ]
            [ Html.div [ Attr.class "content has-text-centered" ]
                [ Html.p []
                    [ Html.text "Retro by "
                    , Html.a [ Attr.href "https://hawx.me" ]
                        [ Html.text "Joshua Hawxwell" ]
                    , Html.text "."
                    ]
                , Html.p []
                    [ Html.a [ Attr.class "icon", Attr.href "https://github.com/hawx/retro" ]
                        [ Html.i [ Attr.class "fa fa-github" ] []
                        ]
                    ]
                ]
            ]
        ]

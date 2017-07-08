module Views.Footer exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr


view : Html msg
view =
    Html.footer [ Attr.class "footer" ]
        [ Html.div [ Attr.class "container" ]
            [ Html.div [ Attr.class "content has-text-centered" ]
                [ Html.text "A link to github?"
                ]
            ]
        ]

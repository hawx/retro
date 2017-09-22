module Views.Retro.TitleCard exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr


view : String -> Html msg
view title =
    Html.div [ Attr.class "not-card card-content has-text-centered" ]
        [ Html.div [ Attr.class "content" ]
            [ Html.h1 []
                [ Html.text title
                ]
            ]
        ]

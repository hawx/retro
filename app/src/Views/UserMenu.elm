module Views.UserMenu exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event


view : String -> msg -> Html msg
view currentUser signOut =
    Html.div [ Attr.class "dropdown is-hoverable" ]
        [ Html.div [ Attr.class "dropdown-trigger" ]
            [ Html.button [ Attr.class "button is-white is-outlined" ]
                [ Html.span [] [ Html.text currentUser ]
                , Html.span [ Attr.class "icon is-small" ]
                    [ Html.i [ Attr.class "fa fa-angle-down" ] []
                    ]
                ]
            ]
        , Html.div [ Attr.class "dropdown-menu" ]
            [ Html.div [ Attr.class "dropdown-content" ]
                [ Html.a [ Attr.class "dropdown-item", Event.onClick signOut ]
                    [ Html.text "Sign-out" ]
                ]
            ]
        ]

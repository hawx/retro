module Views.Menu.Header exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuMsg exposing (Msg(SignOut))


view : String -> Html Msg
view currentUser =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.level
                    [ Bulma.levelLeft
                        [ [ Bulma.title "Retro" ]
                        ]
                    , Bulma.levelRight
                        [ [ Html.span [ Attr.class "tag is-rounded is-medium" ]
                                [ Html.text currentUser ]
                          ]
                        , [ Html.a [ Attr.class "button is-outlined is-white", Event.onClick SignOut ]
                                [ Html.text "Sign-out" ]
                          ]
                        ]
                    ]
                ]
            ]
        ]

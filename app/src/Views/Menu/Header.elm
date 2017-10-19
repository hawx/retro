module Views.Menu.Header exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuMsg exposing (Msg(SignOut))
import Views.UserMenu as UserMenu


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
                        [ [ UserMenu.view currentUser SignOut ]
                        ]
                    ]
                ]
            ]
        ]

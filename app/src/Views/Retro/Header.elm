module Views.Retro.Header exposing (view)

import Bulma
import Data.Retro as Retro
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.RetroMsg exposing (Msg(..))
import Route
import Views.UserMenu as UserMenu


view : String -> Retro.Stage -> Html Msg
view currentUser currentStage =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.level
                    [ Bulma.levelLeft
                        [ [ Bulma.title "Retro" ]
                        ]
                    , Bulma.levelRight
                        [ [ Html.a [ Attr.class "button is-outlined is-white", Event.onClick (Navigate Route.Menu) ]
                                [ Html.text "Menu" ]
                          ]
                        , [ UserMenu.view currentUser SignOut ]
                        ]
                    ]
                ]
            ]
        , Html.div [ Attr.class "hero-foot" ]
            [ Bulma.container
                [ Bulma.tabs [ Attr.class "is-boxed is-fullwidth" ]
                    [ Html.ul []
                        [ tab currentStage Retro.Thinking
                        , tab currentStage Retro.Presenting
                        , tab currentStage Retro.Voting
                        , tab currentStage Retro.Discussing
                        ]
                    ]
                ]
            ]
        ]


tab : Retro.Stage -> Retro.Stage -> Html Msg
tab current stage =
    Html.li
        [ Attr.classList [ ( "is-active", current == stage ) ]
        , Event.onClick (SetStage stage)
        ]
        [ Html.a [] [ Html.text (toString stage) ]
        ]

module Views.Retro.Header exposing (view)

import Bulma
import Data.Retro as Retro
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.RetroMsg exposing (Msg(..))
import Route


view : Retro.Stage -> Html Msg
view current =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.level
                    [ Bulma.levelLeft
                        [ [ Bulma.title "Retro" ]
                        ]
                    , Bulma.levelRight
                        [ [ Html.a [ Attr.class "button is-outlined is-white", Event.onClick (Navigate Route.Menu) ]
                                [ Html.text "Back" ]
                          ]
                        ]
                    ]
                ]
            ]
        , Html.div [ Attr.class "hero-foot" ]
            [ Bulma.container
                [ Bulma.tabs [ Attr.class "is-boxed is-fullwidth" ]
                    [ Html.ul []
                        [ tab current Retro.Thinking
                        , tab current Retro.Presenting
                        , tab current Retro.Voting
                        , tab current Retro.Discussing
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

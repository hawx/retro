module Views.Retro.Header exposing (view)

import Bulma
import Data.Retro as Retro
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.RetroMsg exposing (Msg(..))
import Route


view : String -> Maybe String -> Retro.Stage -> Html Msg
view userId leader current =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.level
                    [ Bulma.levelLeft
                        [ [ Bulma.title "Retro" ]
                        ]
                    , Bulma.levelRight
                        [ [ Html.span
                                [ Attr.class "tag is-rounded is-medium"
                                , Attr.classList [ ( "is-info", leader == Just userId ) ]
                                ]
                                [ Html.text userId
                                ]
                          ]
                        , [ Html.a [ Attr.class "button is-outlined is-white", Event.onClick (Navigate Route.Menu) ]
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
                        [ tab (leader == Just userId) current Retro.Thinking
                        , tab (leader == Just userId) current Retro.Presenting
                        , tab (leader == Just userId) current Retro.Voting
                        , tab (leader == Just userId) current Retro.Discussing
                        ]
                    ]
                ]
            ]
        ]


tab : Bool -> Retro.Stage -> Retro.Stage -> Html Msg
tab isLeader current stage =
    Html.li
        (if isLeader then
            [ Attr.classList [ ( "is-active", current == stage ) ]
            , Event.onClick (SetStage stage)
            ]
         else
            [ Attr.classList [ ( "is-active", current == stage ) ] ]
        )
        [ Html.a [] [ Html.text (toString stage) ]
        ]

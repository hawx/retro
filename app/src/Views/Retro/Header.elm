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
    Bulma.tabs [ Attr.class "is-toggle" ]
        [ Html.ul [ Attr.class "is-left" ]
            [ tab current Retro.Thinking
            , tab current Retro.Presenting
            , tab current Retro.Voting
            , tab current Retro.Discussing
            ]
        , Html.ul [ Attr.class "is-right" ]
            [ Html.li []
                [ Html.a [ Attr.href (Route.toUrl Route.Menu) ]
                    [ Html.text "Quit" ]
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

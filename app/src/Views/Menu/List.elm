module Views.Menu.List exposing (view)

import Data.Retro exposing (Id)
import EveryDict exposing (EveryDict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (Model, Retro)
import Page.MenuMsg exposing (..)


view : Maybe Id -> EveryDict Id Retro -> Html Msg
view current retros =
    Html.div [ Attr.class "menu" ]
        [ Html.ul [ Attr.class "menu-list" ]
            [ Html.li []
                [ Html.a [ Event.onClick NewRetro ]
                    [ Html.text "+ New Retro" ]
                ]
            ]
        , Html.p [ Attr.class "menu-label" ]
            [ Html.text "Your Retros" ]
        , Html.ul [ Attr.class "menu-list" ]
            (EveryDict.values retros
                |> List.map (choice current)
            )
        ]


choice : Maybe Id -> Retro -> Html Msg
choice current { id, name } =
    Html.li []
        [ Html.a
            [ Event.onClick (ShowRetroDetails id)
            , Attr.classList [ ( "is-active", Just id == current ) ]
            ]
            [ Html.text name ]
        ]

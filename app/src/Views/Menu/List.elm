module Views.Menu.List exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (Model)
import Page.MenuMsg exposing (..)


view : Model -> Html Msg
view model =
    let
        choice current { id, name } =
            Html.li []
                [ Html.a
                    [ Event.onClick (ShowRetroDetails id)
                    , Attr.classList [ ( "is-active", Just id == Maybe.map .id model.currentChoice ) ]
                    ]
                    [ Html.text name ]
                ]
    in
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ] [ Html.text "Your Retros" ]
        , Html.div [ Attr.class "menu" ]
            [ Html.ul [ Attr.class "menu-list" ] (List.map (choice model.currentChoice) model.retroList)
            ]
        ]

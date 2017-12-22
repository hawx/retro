module Views.Menu.New exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (..)
import Page.MenuMsg exposing (..)


view : String -> Model -> Html Msg
view currentUser model =
    Html.div []
        [ Html.div [ Attr.class "field is-grouped" ]
            [ Bulma.expandedInput
                [ Event.onInput SetRetroName
                , Attr.placeholder "Name"
                ]
            , Bulma.button [ Event.onClick CreateRetro ] [ Html.text "Create" ]
            ]
        ]

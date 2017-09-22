module Views.Menu.Current exposing (view)

import Bulma
import Date exposing (Date)
import Date.Format
import Html exposing (Html)
import Html.Attributes as Attr
import Page.MenuModel exposing (Retro)
import Route


view : Retro -> Html msg
view retro =
    let
        formatDate date =
            Date.Format.format "%d %B, %Y at %I:%M%P" date
    in
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ] [ Html.text retro.name ]
        , Html.h3 [ Attr.class "subtitle is-6" ] [ Html.text (formatDate retro.createdAt) ]
        , Html.div [ Attr.class "control" ] <| List.map Bulma.tag retro.participants
        , Html.div [ Attr.class "control" ]
            [ Html.a
                [ Attr.class "button is-primary"
                , Attr.href (Route.toUrl (Route.Retro retro.id))
                ]
                [ Html.text "Open" ]
            ]
        ]

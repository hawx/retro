module Views.Menu.Current exposing (view)

import Bulma
import Date exposing (Date)
import Date.Format
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (Retro)
import Page.MenuMsg exposing (Msg(Navigate))
import Route


view : Retro -> Html Msg
view retro =
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ]
            [ Html.text retro.name ]
        , Html.h3 [ Attr.class "subtitle is-6" ]
            [ Html.text (formatDate retro.createdAt) ]
        , Html.div [ Attr.class "field" ]
            [ Html.div [ Attr.class "control" ]
                [ Html.div [ Attr.class "tags" ]
                    (List.map (participantView retro.leader) retro.participants)
                ]
            ]
        , Html.div [ Attr.class "field" ]
            [ Html.div [ Attr.class "control" ]
                [ Html.a
                    [ Attr.class "button is-primary"
                    , Event.onClick (Navigate (Route.Retro retro.id))
                    ]
                    [ Html.text "Open" ]
                ]
            ]
        ]


participantView : String -> String -> Html msg
participantView leader participant =
    Html.span
        [ Attr.class "tag is-medium is-rounded"
        , Attr.classList [ ( "is-info", leader == participant ) ]
        ]
        [ Html.text participant ]


formatDate : Date -> String
formatDate date =
    Date.Format.format "%d %B, %Y at %I:%M%P" date

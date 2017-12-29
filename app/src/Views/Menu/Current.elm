module Views.Menu.Current exposing (view)

import Bulma
import Data.Retro as Retro
import Date exposing (Date)
import Date.Format
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (Model, Retro)
import Page.MenuMsg exposing (Msg(..))
import Route


view : String -> Model -> Retro -> Html Msg
view currentUser model retro =
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ]
            [ Html.text retro.name ]
        , Html.h3 [ Attr.class "subtitle is-6" ]
            [ Html.text (formatDate retro.createdAt) ]
        , Html.div [ Attr.class "field" ]
            [ Html.div [ Attr.class "control" ]
                [ Html.div [ Attr.class "tags" ]
                    (participantsView currentUser retro.participants)
                ]
            ]
        , Html.div [ Attr.class "field is-grouped" ]
            [ Html.p [ Attr.class "control is-expanded" ]
                [ Html.input
                    [ Attr.class "input"
                    , Event.onInput SetParticipant
                    , Attr.list "participant-suggestions"
                    ]
                    []
                ]
            , participantSuggestions currentUser retro model
            , Html.button
                [ Attr.class "button is-info"
                , Event.onClick AddParticipant
                ]
                [ Html.text "Add" ]
            ]
        , Html.div [ Attr.class "field" ]
            [ Html.div [ Attr.class "control" ]
                [ Html.a
                    [ Attr.id "open"
                    , Attr.class "button is-primary"
                    , Event.onClick (Navigate (Retro.idToRoute retro.id))
                    ]
                    [ Html.text "Open" ]
                ]
            ]
        ]


participantSuggestions : String -> Retro -> Model -> Html Msg
participantSuggestions currentUser { participants } { participant, possibleParticipants } =
    possibleParticipants
        |> List.filter (\x -> not (List.member x participants) && x /= currentUser && String.contains (String.toLower participant) (String.toLower x))
        |> List.map (\name -> Html.option [ Attr.value name ] [])
        |> Html.datalist [ Attr.id "participant-suggestions" ]


participantsView : String -> List String -> List (Html Msg)
participantsView currentUser participants =
    List.map (participantView currentUser) participants


participantView : String -> String -> Html Msg
participantView currentUser name =
    Html.span [ Attr.class "tag is-medium is-rounded" ]
        [ Html.text name
        , if name /= currentUser then
            Html.button [ Attr.class "delete is-small", Event.onClick (DeleteParticipant name) ] []
          else
            Html.text ""
        ]


currentUserParticipant : String -> Html msg
currentUserParticipant currentUser =
    Html.span [ Attr.class "tag is-medium is-rounded" ]
        [ Html.text currentUser ]


formatDate : Date -> String
formatDate date =
    Date.Format.format "%d %B, %Y at %I:%M%P" date

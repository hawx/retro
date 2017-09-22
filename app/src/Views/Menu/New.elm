module Views.Menu.New exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.MenuModel exposing (..)
import Page.MenuMsg exposing (..)


acceptablePeople : String -> Model -> List String
acceptablePeople currentUser { participant, participants, possibleParticipants } =
    possibleParticipants
        |> List.filter (\x -> not (List.member x participants))
        |> List.filter ((/=) currentUser)
        |> List.filter (String.contains (String.toLower participant) << String.toLower)


view : String -> Model -> Html Msg
view currentUser model =
    let
        currentUserParticipant =
            Html.span [ Attr.class "tag is-medium" ]
                [ Html.text currentUser ]

        participant name =
            Html.span [ Attr.class "tag is-medium" ]
                [ Html.text name
                , Html.button
                    [ Attr.class "delete is-small"
                    , Event.onClick (DeleteParticipant name)
                    ]
                    []
                ]

        participants =
            Html.div [ Attr.class "control" ]
                (currentUserParticipant :: List.map participant model.participants)

        participantItem name =
            Html.li []
                [ Html.a [ Event.onClick (SelectParticipant name) ]
                    [ Html.text name ]
                ]

        participantSuggestions =
            List.map participantItem (acceptablePeople currentUser model)
                |> Html.ul [ Attr.class "autocomplete-list" ]
    in
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ] [ Html.text "Create New" ]
        , Bulma.label "Name"
        , Bulma.input [ Event.onInput SetRetroName ]
        , Bulma.label "Participants"
        , participants
        , Html.div [ Attr.class "control is-grouped" ]
            [ Html.p [ Attr.class "control is-expanded" ]
                [ Html.input
                    [ Attr.class "input"
                    , Event.onInput SetParticipant
                    ]
                    []
                ]
            , if model.participant == "" || acceptablePeople currentUser model == [] then
                Html.text ""
              else
                participantSuggestions
            , Html.button
                [ Attr.class "button is-info"
                , Event.onClick AddParticipant
                ]
                [ Html.text "Add" ]
            ]
        , Html.div [ Attr.class "level" ]
            [ Html.div [ Attr.class "level-left" ] []
            , Html.div [ Attr.class "level-right" ]
                [ Html.button
                    [ Attr.class "button is-primary"
                    , Event.onClick CreateRetro
                    , Attr.disabled (model.retroName == "" || model.participants == [])
                    ]
                    [ Html.text "Create" ]
                ]
            ]
        ]

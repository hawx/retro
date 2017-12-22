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


view2 : String -> Model -> Html Msg
view2 currentUser model =
    Html.div []
        [ Html.h2 [ Attr.class "title is-4" ] [ Html.text "Create New" ]
        , Html.div [ Attr.class "field" ]
            [ Bulma.label "Name"
            , Bulma.input [ Event.onInput SetRetroName ]
            ]
        , Html.div [ Attr.class "field" ]
            [ Bulma.label "Participants"
            , Html.div [ Attr.class "tags" ] [ participantsView currentUser model ]
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
            , participantSuggestions currentUser model
            , Html.button
                [ Attr.class "button is-info"
                , Event.onClick AddParticipant
                ]
                [ Html.text "Add" ]
            ]
        , Html.div [ Attr.class "field" ]
            [ Html.div [ Attr.class "control" ]
                [ Html.button
                    [ Attr.class "button is-primary"
                    , Event.onClick CreateRetro
                    , Attr.disabled (model.retroName == "" || model.participants == [])
                    ]
                    [ Html.text "Create" ]
                ]
            ]
        ]


participantSuggestions : String -> Model -> Html Msg
participantSuggestions currentUser { participant, participants, possibleParticipants } =
    possibleParticipants
        |> List.filter (\x -> not (List.member x participants) && x /= currentUser && String.contains (String.toLower participant) (String.toLower x))
        |> List.map (\name -> Html.option [ Attr.value name ] [])
        |> Html.datalist [ Attr.id "participant-suggestions" ]


participantsView : String -> Model -> Html Msg
participantsView currentUser model =
    Html.div [ Attr.class "control" ]
        (currentUserParticipant currentUser :: List.map participantView model.participants)


participantView : String -> Html Msg
participantView name =
    Html.span [ Attr.class "tag is-medium is-rounded" ]
        [ Html.text name
        , Html.button [ Attr.class "delete is-small", Event.onClick (DeleteParticipant name) ] []
        ]


currentUserParticipant : String -> Html msg
currentUserParticipant currentUser =
    Html.span [ Attr.class "tag is-medium is-rounded" ]
        [ Html.text currentUser ]

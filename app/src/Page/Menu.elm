module Page.Menu
    exposing
        ( Model
        , Msg
        , empty
        , mount
        , socketUpdate
        , update
        , view
        )

import Bulma
import Date exposing (Date)
import Date.Format
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Route
import Sock


type alias Retro =
    { id : String
    , name : String
    , createdAt : Date
    , participants : List String
    }


type alias Model =
    { retroList : List Retro
    , retroName : String
    , possibleParticipants : List String
    , participants : List String
    , participant : String
    , currentChoice : Maybe Retro
    }


empty : Model
empty =
    { retroList = []
    , retroName = ""
    , possibleParticipants = []
    , participants = []
    , participant = ""
    , currentChoice = Nothing
    }


mount : Sock.Sender Msg -> Cmd Msg
mount sender =
    Sock.menu sender


type Msg
    = CreateRetro
    | SetRetroName String
    | AddParticipant
    | SetParticipant String
    | DeleteParticipant String
    | SelectParticipant String
    | ShowRetroDetails String


update : Sock.Sender Msg -> Msg -> Model -> ( Model, Cmd Msg )
update sender msg model =
    case msg of
        SetRetroName input ->
            { model | retroName = input } ! []

        CreateRetro ->
            model ! [ Sock.createRetro sender model.retroName model.participants ]

        SetParticipant input ->
            { model | participant = input } ! []

        AddParticipant ->
            { model
                | participant = ""
                , participants = model.participant :: model.participants
            }
                ! []

        DeleteParticipant name ->
            { model | participants = List.filter ((/=) name) model.participants } ! []

        SelectParticipant name ->
            { model | participants = name :: model.participants } ! []

        ShowRetroDetails retroId ->
            { model | currentChoice = List.head <| List.filter (\x -> x.id == retroId) model.retroList } ! []


socketUpdate : ( String, Sock.MsgData ) -> Model -> ( Model, Cmd Msg )
socketUpdate ( id, msgData ) model =
    case msgData of
        Sock.User { username } ->
            { model | possibleParticipants = username :: model.possibleParticipants } ! []

        Sock.Retro { id, name, createdAt, participants } ->
            let
                newRetro =
                    Retro id name createdAt participants
            in
            { model
                | retroList = newRetro :: model.retroList
                , currentChoice = Just newRetro
            }
                ! []

        _ ->
            model ! []


acceptablePeople : String -> Model -> List String
acceptablePeople currentUser { participant, participants, possibleParticipants } =
    possibleParticipants
        |> List.filter (\x -> not (List.member x participants))
        |> List.filter ((/=) currentUser)
        |> List.filter (String.contains (String.toLower participant) << String.toLower)


view : String -> Model -> Html Msg
view currentUser model =
    Html.div []
        [ title
        , Bulma.section
            [ Bulma.container
                [ Bulma.columns []
                    [ Bulma.column []
                        [ choices model ]
                    , Bulma.column []
                        [ Maybe.map currentChoice model.currentChoice
                            |> Maybe.withDefault (Html.text "")
                        ]
                    , Bulma.column []
                        [ Bulma.box []
                            [ createNew currentUser model ]
                        ]
                    ]
                ]
            ]
        ]


title : Html msg
title =
    Html.section [ Attr.class "hero is-dark is-bold" ]
        [ Html.div [ Attr.class "hero-body" ]
            [ Bulma.container
                [ Bulma.title "Retro" ]
            ]
        ]


choices : Model -> Html Msg
choices model =
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


currentChoice : Retro -> Html msg
currentChoice retro =
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


createNew : String -> Model -> Html Msg
createNew currentUser model =
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

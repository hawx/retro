module Page.Menu
    exposing
        ( empty
        , mount
        , socketUpdate
        , update
        , view
        )

import Bulma
import EveryDict exposing (EveryDict)
import Html exposing (Html)
import Html.Attributes as Attr
import Page.MenuModel exposing (..)
import Page.MenuMsg exposing (..)
import Port
import Route
import Sock
import Views.Footer
import Views.Menu.Current
import Views.Menu.Header
import Views.Menu.List
import Views.Menu.New


empty : Model
empty =
    { retros = EveryDict.empty
    , retroName = ""
    , possibleParticipants = []
    , participant = ""
    , currentChoice = Nothing
    , showNewRetro = False
    }


mount : Sock.Sender Msg -> Cmd Msg
mount sender =
    Sock.menu sender


update : Sock.Sender Msg -> Msg -> Model -> ( Model, Cmd Msg )
update sender msg model =
    case msg of
        SetRetroName input ->
            { model | retroName = input } ! []

        NewRetro ->
            { model | showNewRetro = True, currentChoice = Nothing } ! []

        CreateRetro ->
            model ! [ Sock.createRetro sender model.retroName [] ]

        SetParticipant input ->
            { model | participant = input } ! []

        AddParticipant ->
            { model | participant = "" }
                ! [ Maybe.map (\retro -> Sock.addParticipant sender retro model.participant) model.currentChoice
                        |> Maybe.withDefault Cmd.none
                  ]

        DeleteParticipant name ->
            model
                ! [ Maybe.map (\retro -> Sock.deleteParticipant sender retro name) model.currentChoice
                        |> Maybe.withDefault Cmd.none
                  ]

        ShowRetroDetails retroId ->
            { model
                | currentChoice = Just retroId
                , showNewRetro = False
            }
                ! []

        Navigate route ->
            model ! [ Route.navigate route ]

        SignOut ->
            model ! [ Port.signOut () ]


socketUpdate : Sock.Msg -> Model -> ( Model, Cmd Msg )
socketUpdate msg model =
    case msg of
        Sock.User { username } ->
            { model | possibleParticipants = username :: model.possibleParticipants } ! []

        Sock.AddParticipant { retroId, participant } ->
            { model | retros = EveryDict.update retroId (Maybe.map (addParticipant participant)) model.retros } ! []

        Sock.DeleteParticipant { retroId, participant } ->
            { model | retros = EveryDict.update retroId (Maybe.map (deleteParticipant participant)) model.retros } ! []

        Sock.Retro { id, name, createdAt, participants } ->
            let
                newRetro =
                    Retro id name createdAt participants
            in
            { model
                | retros = EveryDict.insert id newRetro model.retros
                , currentChoice = Just id
                , showNewRetro = False
            }
                ! []

        _ ->
            model ! []


addParticipant : String -> Retro -> Retro
addParticipant participant retro =
    { retro | participants = retro.participants ++ [ participant ] }


deleteParticipant : String -> Retro -> Retro
deleteParticipant participant retro =
    { retro | participants = List.filter ((/=) participant) retro.participants }


view : String -> Model -> Html Msg
view currentUser model =
    Html.div [ Attr.class "site-content" ]
        [ Views.Menu.Header.view currentUser
        , Bulma.section [ Attr.class "fill-height" ]
            [ Bulma.container
                [ Bulma.columns []
                    [ Bulma.column [ Attr.class "is-one-third" ]
                        [ Views.Menu.List.view model ]
                    , Bulma.column []
                        [ if model.showNewRetro then
                            Views.Menu.New.view currentUser model
                          else
                            model.currentChoice
                                |> Maybe.andThen (\current -> EveryDict.get current model.retros)
                                |> Maybe.map (Views.Menu.Current.view currentUser model)
                                |> Maybe.withDefault (Html.text "")
                        ]
                    ]
                ]
            ]
        , Views.Footer.view
        ]

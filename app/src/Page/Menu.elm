module Page.Menu
    exposing
        ( empty
        , mount
        , socketUpdate
        , update
        , view
        )

import Bulma
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

        Navigate route ->
            model ! [ Route.navigate route ]

        SignOut ->
            model ! [ Port.signOut () ]


socketUpdate : ( String, Sock.MsgData ) -> Model -> ( Model, Cmd Msg )
socketUpdate ( _, msgData ) model =
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


view : String -> Model -> Html Msg
view currentUser model =
    Html.div [ Attr.class "site-content" ]
        [ Views.Menu.Header.view currentUser
        , Bulma.section [ Attr.class "fill-height" ]
            [ Bulma.container
                [ Bulma.columns []
                    [ Bulma.column []
                        [ Views.Menu.List.view model ]
                    , Bulma.column []
                        [ Maybe.map Views.Menu.Current.view model.currentChoice
                            |> Maybe.withDefault (Html.text "")
                        ]
                    , Bulma.column []
                        [ Bulma.box []
                            [ Views.Menu.New.view currentUser model ]
                        ]
                    ]
                ]
            ]
        , Views.Footer.view
        ]

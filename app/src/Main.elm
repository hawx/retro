port module Main exposing (main)

import Http
import Bulma
import Debug
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import String
import Dict exposing (Dict)
import Array exposing (Array)
import WebSocket
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Sock
import DragAndDrop
import Html.Events.Extra as ExtraEvent
import Navigation
import Route
import Page.Menu as Menu
import Page.Retro as Retro

main =
    Navigation.programWithFlags UrlChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

type alias Flags =
    { host : String
    , isSecure : Bool
    }

webSocketUrl : Flags -> String
webSocketUrl flags =
    if flags.isSecure then
        "wss://" ++ flags.host ++ "/ws"
    else
        "ws://" ++ flags.host ++ "/ws"

-- Model

type alias Model =
    { user : Maybe String
    , token : Maybe String
    , retroId : Maybe String
    , flags : Flags
    , menu : Menu.Model
    , retro : Retro.Model
    }

init : Flags -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
    let
        (menuModel, menuCmd) =
            Menu.init

        (retroModel, retroCmd) =
            Retro.init

        (initModel, initCmd) =
            urlChange
                location
                { user = Nothing
                , token = Nothing
                , retroId = Nothing
                , flags = flags
                , menu = menuModel
                , retro = retroModel
                }
    in
        initModel !
            [ initCmd
            , storageGet "id"
            , Cmd.map MenuMsg menuCmd
            , Cmd.map RetroMsg retroCmd
            ]

-- Update

port storageSet : (String, String) -> Cmd msg
port storageGet : String -> Cmd msg
port storageGot : (Maybe String -> msg) -> Sub msg

type Msg = SetId (Maybe String)
         | Socket String
         | UrlChange Navigation.Location
         | MenuMsg Menu.Msg
         | RetroMsg Retro.Msg

joinRetro : Model -> (Model, Cmd Msg)
joinRetro model =
    let
        f id retroId token =
            Sock.init (webSocketUrl model.flags) id retroId id token
    in
        case Maybe.map3 f model.user model.retroId model.token of
            Just cmd -> (model, cmd)
            Nothing -> (model, Cmd.none)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        MenuMsg subMsg ->
            let
                (menuModel, menuMsg) = Menu.update subMsg model.menu
            in
                { model | menu = menuModel } ! [ Cmd.map MenuMsg menuMsg ]

        RetroMsg subMsg ->
            case model.user of
                Just userId ->
                    let
                        (retroModel, retroMsg) = Retro.update (webSocketUrl model.flags) userId subMsg model.retro
                    in
                        { model | retro = retroModel } ! [ Cmd.map RetroMsg retroMsg ]

                Nothing ->
                    model ! []

        SetId (Just parts) ->
            case String.split ";" parts of
                [id, token] ->
                    joinRetro { model | user = Just id, token = Just token }
                _ ->
                    { model | user = Nothing } ! []

        Socket data ->
            let
                (retroModel, retroCmd) =
                    Sock.update data model.retro Retro.socketUpdate

                (newModel, newCmd) =
                    Sock.update data model socketUpdate
            in
                { newModel | retro = retroModel } ! [ newCmd, Cmd.map RetroMsg retroCmd ]

        UrlChange location ->
            urlChange location model

        _ ->
            model ! []

urlChange : Navigation.Location -> Model -> (Model, Cmd Msg)
urlChange location model =
    case Route.parse location of
        Just Route.Menu ->
            { model | retroId = Nothing, retro = Retro.empty } ! []

        Just (Route.Retro retroId) ->
            joinRetro { model | retroId = Just retroId, retro = Retro.empty }

        _ ->
            model ! []


socketUpdate : (String, Sock.MsgData) -> Model -> (Model, Cmd Msg)
socketUpdate (id, msgData) model =
    case msgData of
        Sock.Error { error } ->
            handleError error model

        _ ->
            model ! []


handleError : String -> Model -> (Model, Cmd Msg)
handleError error model =
    case error of
        "unknown_user" ->
            { model | user = Nothing } ! []

        _ ->
            model ! []



-- View

view : Model -> Html Msg
view model =
    case model.user of
        Just userId ->
            if model.retroId == Nothing then
                Html.div []
                    [ Html.map RetroMsg (Retro.view userId model.retro)
                    , footer
                    , retroListModal model
                    ]
            else
                Html.div []
                    [ Html.map RetroMsg (Retro.view userId model.retro)
                    , footer
                    ]
        Nothing ->
            Html.div []
                [ footer
                , signInModal
                ]


retroListModal : Model -> Html Msg
retroListModal model =
    Html.map MenuMsg (Menu.view model.menu)


signInModal : Html msg
signInModal =
    Bulma.modal
        [ Bulma.box []
              [ Html.a [ Attr.class "button is-primary"
                       , Attr.href "/oauth/login"
                       ]
                    [ Html.text "Sign-in with GitHub" ]
              ]
        ]


footer : Html msg
footer =
    Html.footer [ Attr.class "footer" ]
        [ Html.div [ Attr.class "container" ]
              [ Html.div [ Attr.class "content has-text-centered" ]
                    [ Html.text "A link to github?"
                    ]
              ]
        ]


-- Subscriptions

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sock.listen (webSocketUrl model.flags) Socket
        , storageGot SetId
        ]

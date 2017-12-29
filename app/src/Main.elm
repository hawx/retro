module Main exposing (main)

import Data.IdToken as IdToken exposing (IdToken)
import Html exposing (Html)
import Navigation
import Page.Menu as Menu
import Page.MenuModel as Menu
import Page.MenuMsg as Menu
import Page.Retro as Retro
import Page.RetroModel as Retro
import Page.RetroMsg as Retro
import Page.SignIn as SignIn
import Port
import Route exposing (Route)
import Sock
import String
import Views.Footer


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
    { route : Route
    , token : Maybe IdToken
    , flags : Flags
    , menu : Menu.Model
    , retro : Retro.Model
    , connected : Bool
    , hasTest : Bool
    , hasGitHub : Bool
    , hasOffice365 : Bool
    }


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        ( initModel, initCmd ) =
            urlChange
                location
                { route = Route.Menu
                , token = Nothing
                , flags = flags
                , menu = Menu.empty
                , retro = Retro.empty
                , connected = False
                , hasTest = False
                , hasGitHub = False
                , hasOffice365 = False
                }
    in
    initModel
        ! [ initCmd
          , Port.storageGet "idToken"
          ]



-- Update


type Msg
    = SetId (Maybe String)
    | Socket Sock.Msg
    | UrlChange Navigation.Location
    | MenuMsg Menu.Msg
    | RetroMsg Retro.Msg


sockSender : Flags -> String -> IdToken -> Sock.Sender msg
sockSender flags username token =
    Sock.send (webSocketUrl flags) username token


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MenuMsg subMsg ->
            case model.token of
                Just token ->
                    let
                        ( menuModel, menuMsg ) =
                            Menu.update (sockSender model.flags token.username token) subMsg model.menu
                    in
                    { model | menu = menuModel } ! [ Cmd.map MenuMsg menuMsg ]

                Nothing ->
                    model ! []

        RetroMsg subMsg ->
            case model.token of
                Just token ->
                    let
                        ( retroModel, retroMsg ) =
                            Retro.update (sockSender model.flags token.username token) subMsg model.retro
                    in
                    { model | retro = retroModel } ! [ Cmd.map RetroMsg retroMsg ]

                Nothing ->
                    model ! []

        SetId (Just idToken) ->
            routeChange model.route { model | token = IdToken.decode idToken }

        SetId Nothing ->
            { model | token = Nothing, connected = True } ! []

        Socket data ->
            let
                ( retroModel, retroCmd ) =
                    Retro.socketUpdate (Maybe.map .username model.token) data model.retro

                ( menuModel, menuCmd ) =
                    Menu.socketUpdate data model.menu

                ( newModel, newCmd ) =
                    socketUpdate data model
            in
            { newModel
                | retro = retroModel
                , menu = menuModel
                , connected = True
            }
                ! [ newCmd, Cmd.map RetroMsg retroCmd, Cmd.map MenuMsg menuCmd ]

        UrlChange location ->
            urlChange location model


urlChange : Navigation.Location -> Model -> ( Model, Cmd Msg )
urlChange location model =
    case Route.parse location of
        Just route ->
            routeChange route model

        Nothing ->
            model ! []


routeChange : Route -> Model -> ( Model, Cmd Msg )
routeChange route model =
    case route of
        Route.Menu ->
            { model
                | route = route
                , retro = Retro.empty
                , menu = Menu.empty
            }
                ! [ Cmd.map MenuMsg (runWithSockSender model Menu.mount) ]

        Route.Retro retroId ->
            { model
                | route = route
                , retro = Retro.empty
                , menu = Menu.empty
            }
                ! [ Cmd.map RetroMsg (runWithSockSender model (Retro.mount retroId)) ]


runWithSockSender : Model -> (Sock.Sender msg -> Cmd msg) -> Cmd msg
runWithSockSender model f =
    case model.token of
        Just token ->
            f (sockSender model.flags token.username token)

        Nothing ->
            Cmd.none


socketUpdate : Sock.Msg -> Model -> ( Model, Cmd Msg )
socketUpdate msg model =
    case msg of
        Sock.Error { error } ->
            handleError error model

        Sock.Hello { hasTest, hasGitHub, hasOffice365 } ->
            { model | hasTest = hasTest, hasGitHub = hasGitHub, hasOffice365 = hasOffice365 } ! []

        _ ->
            model ! []


handleError : String -> Model -> ( Model, Cmd Msg )
handleError error model =
    case error of
        "bad_auth" ->
            { model | token = Nothing, connected = True } ! []

        _ ->
            model ! []



-- View


view : Model -> Html Msg
view model =
    case ( model.connected, model.token ) of
        ( True, Just token ) ->
            innerView token.username model

        _ ->
            SignIn.view model


innerView : String -> Model -> Html Msg
innerView username model =
    case model.route of
        Route.Menu ->
            Html.map MenuMsg (Menu.view username model.menu)

        Route.Retro retroId ->
            Html.map RetroMsg (Retro.view username model.retro)



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sock.listen (webSocketUrl model.flags) Socket
        , Port.storageGot SetId
        ]

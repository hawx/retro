port module Main exposing (main)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Navigation
import Page.Menu as Menu
import Page.Retro as Retro
import Route exposing (Route)
import Sock
import String
import Views.Footer
import Views.SignIn


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
    , user : Maybe String
    , token : Maybe String
    , flags : Flags
    , menu : Menu.Model
    , retro : Retro.Model
    }


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        ( initModel, initCmd ) =
            urlChange
                location
                { route = Route.Menu
                , user = Nothing
                , token = Nothing
                , flags = flags
                , menu = Menu.empty
                , retro = Retro.empty
                }
    in
    initModel
        ! [ initCmd
          , storageGet "id"
          ]



-- Update


port storageSet : ( String, String ) -> Cmd msg


port storageGet : String -> Cmd msg


port storageGot : (Maybe String -> msg) -> Sub msg


type Msg
    = SetId (Maybe String)
    | Socket String
    | UrlChange Navigation.Location
    | MenuMsg Menu.Msg
    | RetroMsg Retro.Msg


sockSender : Flags -> String -> String -> Sock.Sender msg
sockSender flags userId token =
    Sock.send (webSocketUrl flags) userId token


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MenuMsg subMsg ->
            case Maybe.map2 (,) model.user model.token of
                Just ( userId, token ) ->
                    let
                        ( menuModel, menuMsg ) =
                            Menu.update (sockSender model.flags userId token) subMsg model.menu
                    in
                    { model | menu = menuModel } ! [ Cmd.map MenuMsg menuMsg ]

                Nothing ->
                    model ! []

        RetroMsg subMsg ->
            case Maybe.map2 (,) model.user model.token of
                Just ( userId, token ) ->
                    let
                        ( retroModel, retroMsg ) =
                            Retro.update (sockSender model.flags userId token) subMsg model.retro
                    in
                    { model | retro = retroModel } ! [ Cmd.map RetroMsg retroMsg ]

                Nothing ->
                    model ! []

        SetId (Just parts) ->
            case String.split ";" parts of
                [ id, token ] ->
                    routeChange model.route
                        { model
                            | user = Just id
                            , token = Just token
                        }

                _ ->
                    { model | user = Nothing } ! []

        Socket data ->
            let
                ( retroModel, retroCmd ) =
                    Sock.update data model.retro Retro.socketUpdate

                ( menuModel, menuCmd ) =
                    Sock.update data model.menu Menu.socketUpdate

                ( newModel, newCmd ) =
                    Sock.update data model socketUpdate
            in
            { newModel
                | retro = retroModel
                , menu = menuModel
            }
                ! [ newCmd, Cmd.map RetroMsg retroCmd, Cmd.map MenuMsg menuCmd ]

        UrlChange location ->
            urlChange location model

        _ ->
            model ! []


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
    case Maybe.map2 (,) model.user model.token of
        Just ( userId, token ) ->
            f (sockSender model.flags userId token)

        Nothing ->
            Cmd.none


socketUpdate : ( String, Sock.MsgData ) -> Model -> ( Model, Cmd Msg )
socketUpdate ( id, msgData ) model =
    case msgData of
        Sock.Error { error } ->
            handleError error model

        _ ->
            model ! []


handleError : String -> Model -> ( Model, Cmd Msg )
handleError error model =
    case error of
        "bad_auth" ->
            { model | user = Nothing, token = Nothing } ! []

        _ ->
            model ! []



-- View


view : Model -> Html Msg
view model =
    case model.user of
        Just userId ->
            Html.div []
                [ innerView userId model
                , Views.Footer.view
                ]

        Nothing ->
            Html.div []
                [ Views.SignIn.view
                , Views.Footer.view
                ]


innerView : String -> Model -> Html Msg
innerView userId model =
    case model.route of
        Route.Menu ->
            Html.map MenuMsg (Menu.view userId model.menu)

        Route.Retro retroId ->
            Html.map RetroMsg (Retro.view userId model.retro)



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sock.listen (webSocketUrl model.flags) Socket
        , storageGot SetId
        ]

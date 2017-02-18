module Page.Menu exposing ( Model
                          , init
                          , mount
                          , Msg
                          , update
                          , socketUpdate
                          , view
                          , subscriptions)

import Debug
import Sock
import Http
import Html exposing (Html)
import Html.Events as Event
import Html.Attributes as Attr
import Bulma
import Route
import Json.Decode as Decode
import Json.Encode as Encode
import Autocomplete

type alias Model =
    { retroList : List String
    , retroName : String
    , possibleParticipants : List String
    , participants : List String
    , participant : String
    , autocompleteState : Autocomplete.State
    }

updateConfig : Autocomplete.UpdateConfig Msg String
updateConfig =
    Autocomplete.updateConfig
        { toId = identity
        , onKeyDown =
              \code maybeId ->
                  if code == 13 then
                      Maybe.map SelectParticipant maybeId
                  else
                      Nothing
        , onTooLow = Nothing
        , onTooHigh = Nothing
        , onMouseEnter = \_ -> Nothing
        , onMouseLeave = \_ -> Nothing
        , onMouseClick = \id -> Just <| SelectParticipant id
        , separateSelections = False
        }

init : (Model, Cmd Msg)
init =
    { retroList = []
    , retroName = ""
    , possibleParticipants = []
    , participants = []
    , participant = ""
    , autocompleteState = Autocomplete.empty
    } ! []

mount : Sock.Sender Msg -> Cmd Msg
mount sender =
    Cmd.batch
        [ Sock.menu sender
        ]

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map SetAutoState Autocomplete.subscription


type Msg = GotRetros (Result Http.Error (List String))
         | CreateRetro
         | SetRetroName String
         | AddParticipant
         | SetParticipant String
         | DeleteParticipant String
         | SetAutoState Autocomplete.Msg
         | SelectParticipant String


update : Sock.Sender Msg -> Msg -> Model -> (Model, Cmd Msg)
update sender msg model =
    case msg of
        SetRetroName input ->
            { model | retroName = input } ! []

        CreateRetro ->
            model ! [ Sock.createRetro sender model.retroName model.participants ]

        GotRetros resp ->
            case resp of
                Ok retros ->
                    { model | retroList = retros } ! []

                _ ->
                    model ! []

        SetParticipant input ->
            { model | participant = input } ! []

        AddParticipant ->
            { model
                | participant = ""
                , participants = model.participant :: model.participants }
            ! []

        DeleteParticipant name ->
            { model | participants = List.filter ((/=) name) model.participants } ! []

        SelectParticipant name ->
            { model | participants = name :: model.participants } ! []

        SetAutoState autoMsg ->
            let
                (newState, maybeMsg) =
                    Autocomplete.update
                        updateConfig
                        autoMsg
                        5
                        model.autocompleteState
                        (acceptablePeople model)

                newModel =
                    { model | autocompleteState = newState }
            in
                case maybeMsg of
                    Just newMsg ->
                        update sender newMsg newModel
                    Nothing ->
                        newModel ! []

socketUpdate : (String, Sock.MsgData) -> Model -> (Model, Cmd Msg)
socketUpdate (id, msgData) model =
    case msgData of
        Sock.User { username } ->
            { model | possibleParticipants = username :: model.possibleParticipants } ! []

        Sock.Retro { id } ->
            { model | retroList = id :: model.retroList } ! []

        _ ->
            model ! []

acceptablePeople : Model -> List String
acceptablePeople { participant, participants, possibleParticipants } =
    possibleParticipants
        |> List.filter (\x -> not (List.member x participants))
        |> List.filter (String.contains (String.toLower participant) << String.toLower)

viewConfig : Autocomplete.ViewConfig String
viewConfig =
    let
        customizedLi keySelected mouseSelected person =
            { attributes = [ Attr.classList [ ("autocomplete-item", True)
                                            , ("is-selected", keySelected || mouseSelected)
                                            ]
                           ]
            , children = [ Html.text person ]
            }
    in
        Autocomplete.viewConfig
            { toId = identity
            , ul = [ Attr.class "autocomplete-list" ]
            , li = customizedLi
            }

view : Model -> Html Msg
view model =
    let
        title =
            Html.h1 [ Attr.class "title" ]
                [ Html.text "Retro" ]


        choice name =
            Html.a [ Attr.class "button"
                   , Attr.href (Route.toUrl (Route.Retro name))
                   ]
                [ Html.text name ]

        choices =
            Html.div [ Attr.class "section" ]
                [ Html.h2 [ Attr.class "subtitle" ] [ Html.text "Your Retros" ]
                , Html.ul [] (List.map choice model.retroList)
                ]

        participant name =
            Html.span [ Attr.class "tag is-medium" ]
                [ Html.text name
                , Html.button [ Attr.class "delete is-small"
                              , Event.onClick (DeleteParticipant name) ] []
                ]

        participants =
            Html.div [ Attr.class "control" ]
                (List.map participant model.participants)

        autocomplete =
            Html.map SetAutoState
                (Autocomplete.view
                     viewConfig
                     5
                     model.autocompleteState
                     (acceptablePeople model))


        createNew =
            Html.div [ Attr.class "section" ]
                [ Html.h2 [ Attr.class "subtitle" ] [ Html.text "Create New" ]
                , Html.label [ Attr.class "label" ] [ Html.text "Name" ]
                , Html.p [ Attr.class "control" ]
                    [ Html.input [ Event.onInput SetRetroName
                                 , Attr.class "input"
                                 ] []
                    ]
                , Html.label [ Attr.class "label" ] [ Html.text "Participants" ]
                , participants
                , Html.div [ Attr.class "control has-addons" ] <| List.filterMap identity
                    [ Just <| Html.p [ Attr.class "control" ]
                          [ Html.input [ Attr.class "input"
                                       , Event.onInput SetParticipant
                                       ] []
                          ]
                    , if model.participant == "" || acceptablePeople model == [] then
                          Nothing
                      else
                          Just autocomplete
                    , Just <| Html.button [ Attr.class "button is-info"
                                  , Event.onClick AddParticipant
                                  ]
                        [ Html.text "Add" ]
                    ]
                , Html.div [ Attr.class "level" ]
                    [ Html.div [ Attr.class "level-left" ] []
                    , Html.div [ Attr.class "level-right" ]
                        [ Html.button [ Attr.class "button is-primary"
                                      , Event.onClick CreateRetro
                                      , Attr.disabled (model.retroName == "" || model.participants == [])
                                      ]
                              [ Html.text "Create" ]
                        ]
                    ]
                ]

    in
        Bulma.modal
            [ Bulma.box []
                  [ title
                  , choices
                  , createNew
                  ]
            ]

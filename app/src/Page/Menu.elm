module Page.Menu exposing ( Model
                          , empty
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
import Date exposing (Date)
import Date.Format

type alias Retro = { id : String
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
    , autocompleteState : Autocomplete.State
    , currentChoice : Maybe Retro
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

empty : Model
empty =
    { retroList = []
    , retroName = ""
    , possibleParticipants = []
    , participants = []
    , participant = ""
    , autocompleteState = Autocomplete.empty
    , currentChoice = Nothing
    }

mount : Sock.Sender Msg -> Cmd Msg
mount sender =
    Sock.menu sender

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map SetAutoState Autocomplete.subscription


type Msg = CreateRetro
         | SetRetroName String
         | AddParticipant
         | SetParticipant String
         | DeleteParticipant String
         | SetAutoState Autocomplete.Msg
         | SelectParticipant String
         | ShowRetroDetails String


update : Sock.Sender Msg -> Msg -> Model -> (Model, Cmd Msg)
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
                , participants = model.participant :: model.participants }
            ! []

        DeleteParticipant name ->
            { model | participants = List.filter ((/=) name) model.participants } ! []

        SelectParticipant name ->
            { model | participants = name :: model.participants } ! []

        ShowRetroDetails retroId ->
            { model | currentChoice = List.head <| List.filter (\x -> x.id == retroId) model.retroList } ! []

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

        Sock.Retro { id, name, createdAt, participants } ->
            let
                newRetro = Retro id name createdAt participants
            in
                { model
                    | retroList = newRetro :: model.retroList
                    , currentChoice = Just newRetro
                } ! []

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
            Html.section [ Attr.class "hero is-dark is-bold" ]
                [ Html.div [ Attr.class "hero-body" ]
                      [ Html.div [ Attr.class "container" ]
                            [ Html.h1 [ Attr.class "title" ]
                                  [ Html.text "Retro" ]
                            ]
                      ]
                ]


        choice current { id, name } =
            Html.li []
                [ Html.a [ Event.onClick (ShowRetroDetails id)
                         , Attr.classList [ ("is-active", Just id == Maybe.map .id current) ]
                         ]
                      [ Html.text name ]
                ]

        choices current =
            Html.div []
                [ Html.h2 [ Attr.class "title is-4" ] [ Html.text "Your Retros" ]
                , Html.div [ Attr.class "menu" ]
                    [ Html.ul [ Attr.class "menu-list" ] (List.map (choice current) model.retroList)
                    ]
                ]

        formatDate date =
            Date.Format.format "%d %B, %Y at %I:%M%P" date

        currentChoice retro =
            Html.div []
                [ Html.h2 [ Attr.class "title is-4" ] [ Html.text retro.name ]
                , Html.h3 [ Attr.class "subtitle is-6" ] [ Html.text (formatDate retro.createdAt) ]
                , Html.div [ Attr.class "control" ] <| List.map Bulma.tag retro.participants
                , Html.div [ Attr.class "control" ]
                    [ Html.a [ Attr.class "button is-primary"
                             , Attr.href (Route.toUrl (Route.Retro retro.id))
                             ]
                          [ Html.text "Open" ]
                    ]
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
            Html.div []
                [ Html.h2 [ Attr.class "title is-4" ] [ Html.text "Create New" ]
                , Html.label [ Attr.class "label" ] [ Html.text "Name" ]
                , Html.p [ Attr.class "control" ]
                    [ Html.input [ Event.onInput SetRetroName
                                 , Attr.class "input"
                                 ] []
                    ]
                , Html.label [ Attr.class "label" ] [ Html.text "Participants" ]
                , participants
                , Html.div [ Attr.class "control is-grouped" ] <| List.filterMap identity
                    [ Just <| Html.p [ Attr.class "control is-expanded" ]
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
        Html.div []
            [ title
            , Html.section [ Attr.class "section" ]
                [ Html.div [ Attr.class "container" ]
                      [ Html.div [ Attr.class "columns" ]
                          [ Html.div [ Attr.class "column is-one-third" ]
                                [ choices model.currentChoice ]
                          , Html.div [ Attr.class "column is-one-third" ] <|
                              case model.currentChoice of
                                  Just retro ->
                                      [ currentChoice retro ]

                                  Nothing ->
                                      []

                          , Html.div [ Attr.class "column is-one-third" ]
                              [ Html.div [ Attr.class "box" ]
                                    [ createNew ]
                              ]
                          ]
                      ]
                ]
            ]

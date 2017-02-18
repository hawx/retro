module Page.Menu exposing ( Model
                          , init
                          , Msg
                          , update
                          , view)

import Http
import Html exposing (Html)
import Html.Events as Event
import Html.Attributes as Attr
import Bulma
import Route
import Json.Decode as Decode
import Json.Encode as Encode

type alias Model =
    { retroList : Maybe (List String)
    , retroName : String
    , participants : List String
    , participant : String
    }

init : (Model, Cmd Msg)
init =
    { retroList = Nothing
    , retroName = ""
    , participants = []
    , participant = ""
    } ! [ getRetros ]

type Msg = GotRetros (Result Http.Error (List String))
         | CreateRetro
         | SetRetroName String
         | AddParticipant
         | SetParticipant String
         | DeleteParticipant String

getRetros : Cmd Msg
getRetros =
     Http.get "/retros" (Decode.list Decode.string)
         |> Http.send GotRetros

createRetro : String -> List String -> Cmd Msg
createRetro name users =
    Http.post "/retros"
        (Http.jsonBody <| Encode.object
            [ ("name", Encode.string name)
            , ("users", Encode.list (List.map Encode.string users))
            ])
        (Decode.list Decode.string)
            |> Http.send GotRetros

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SetRetroName input ->
            { model | retroName = input } ! []

        CreateRetro ->
            model ! [ createRetro model.retroName [] ]

        GotRetros resp ->
            case resp of
                Ok retros ->
                    { model | retroList = Just retros } ! []

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
                , Html.ul [] (List.map choice (Maybe.withDefault [] model.retroList))
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
                , Html.div [ Attr.class "control has-addons" ]
                    [ Html.p [ Attr.class "control" ]
                          [ Html.input [ Attr.class "input"
                                       , Event.onInput SetParticipant
                                       ] []
                          ]
                    , Html.button [ Attr.class "button is-info"
                                  , Event.onClick AddParticipant
                                  ]
                        [ Html.text "Add" ]
                    ]
                , Html.div [ Attr.class "level" ]
                    [ Html.div [ Attr.class "level-left" ] []
                    , Html.div [ Attr.class "level-right" ]
                        [ Html.button [ Attr.class "button is-primary"
                                      , Event.onClick CreateRetro
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

module Menu exposing (..)

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
    }

init : (Model, Cmd Msg)
init =
    { retroList = Nothing
    , retroName = ""
    } ! [ getRetros ]

type Msg = GotRetros (Result Http.Error (List String))
         | CreateRetro
         | SetRetroName String

getRetros : Cmd Msg
getRetros =
     Http.get "/retros" (Decode.list Decode.string)
         |> Http.send GotRetros

createRetro : String -> Cmd Msg
createRetro name =
    Http.post "/retros" (Http.jsonBody (Encode.string name)) (Decode.list Decode.string)
        |> Http.send GotRetros

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        SetRetroName input ->
            { model | retroName = input } ! []

        CreateRetro ->
            model ! [ createRetro model.retroName ]

        GotRetros resp ->
            case resp of
                Ok retros ->
                    { model | retroList = Just retros } ! []

                _ ->
                    model ! []

view : Model -> Html Msg
view model =
    let
        title =
            Html.h1 [ Attr.class "title" ]
                [ Html.text "Retros" ]

        choice name =
            Html.a [ Attr.class "button"
                   , Attr.href (Route.toUrl (Route.Retro name))
                   ]
                [ Html.text name ]

        choices =
            List.map choice (Maybe.withDefault [] model.retroList)

    in
        Bulma.modal
            [ Bulma.box []
                  ( title :: choices )
            , Bulma.box []
                [ Html.input [ Event.onInput SetRetroName
                             ]
                      [ ]
                , Html.button [ Attr.class "button"
                              , Event.onClick CreateRetro
                              ]
                    [ Html.text "Create" ]
                ]
            ]

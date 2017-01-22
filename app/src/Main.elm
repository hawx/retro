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
import Column exposing (Column)
import Card exposing (Card, Content)
import Retro exposing (Retro)
import Sock
import DragAndDrop
import Html.Events.Extra as ExtraEvent
import Navigation

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

type Stage = Thinking | Presenting | Voting | Discussing

type alias CardDragging = (String, String)
type alias CardOver = (String, Maybe String)

type alias Model =
    { user : Maybe String
    , token : Maybe String
    , retroId : Maybe String
    , retroList : Maybe (List String)
    , retroName : String
    , stage : Stage
    , retro : Retro
    , input : String
    , dnd : DragAndDrop.Model CardDragging CardOver
    , flags : Flags
    }

init : Flags -> Navigation.Location -> (Model, Cmd Msg)
init flags location =
    let
        (initModel, initCmd) =
            urlChange
                location
                { user = Nothing
                , token = Nothing
                , retroId = Nothing
                , retroList = Nothing
                , retroName = ""
                , stage = Thinking
                , retro = Retro.empty
                , input = ""
                , dnd = DragAndDrop.empty
                , flags = flags
                }
    in
        initModel ! [ initCmd, storageGet "id", getRetros ]

-- Update

port storageSet : (String, String) -> Cmd msg
port storageGet : String -> Cmd msg
port storageGot : (Maybe String -> msg) -> Sub msg

type Msg = SetId (Maybe String)
         | SetRetroName String
         | CreateRetro
         | GotRetros (Result Http.Error (List String))
         | SetRetro String
         | ClearRetro
         | Socket String
         | ChangeInput String String
         | CreateCard String
         | SetStage Stage
         | Reveal String String
         | Vote String String
         | DnD (DragAndDrop.Msg (String, String) (String, Maybe String))
         | UrlChange Navigation.Location

getRetros : Cmd Msg
getRetros =
     Http.get "/retros" (Decode.list Decode.string)
         |> Http.send GotRetros

createRetro : String -> Cmd Msg
createRetro name =
    Http.post "/retros" (Http.jsonBody (Encode.string name)) (Decode.list Decode.string)
        |> Http.send GotRetros

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
        ClearRetro ->
            { model | retroId = Nothing, retro = Retro.empty } ! []

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

        SetRetro retroId ->
            joinRetro { model | retroId = Just retroId }

        Vote columnId cardId ->
            case model.user of
                Just userId ->
                    model ! [ Sock.vote (webSocketUrl model.flags) userId columnId cardId ]
                _ ->
                    model ! []

        SetId (Just parts) ->
            case String.split ";" parts of
                [id, token] ->
                    joinRetro { model | user = Just id, token = Just token }
                _ ->
                    { model | user = Nothing } ! []

        SetStage stage ->
            case model.user of
                Just userId ->
                    { model | stage = stage } ! [ Sock.stage (webSocketUrl model.flags) userId (toString stage) ]
                _ ->
                    model ! []

        Reveal columnId cardId ->
            case model.user of
                Just userId ->
                    model ! [ Sock.reveal (webSocketUrl model.flags) userId columnId cardId ]
                _ ->
                    model ! []

        DnD subMsg ->
            case model.user of
                Just userId ->
                    case DragAndDrop.isDrop subMsg model.dnd of
                        Just ((columnFrom, cardFrom), (columnTo, maybeCardTo)) ->
                            case model.stage of
                                Thinking ->
                                    if columnFrom /= columnTo then
                                        { model | dnd = DragAndDrop.empty } ! [ Sock.move (webSocketUrl model.flags) userId columnFrom columnTo cardFrom ]
                                    else
                                        model ! []

                                Voting ->
                                    case maybeCardTo of
                                        Just cardTo ->
                                            if cardFrom /= cardTo then
                                                { model | dnd = DragAndDrop.empty } ! [ Sock.group (webSocketUrl model.flags) userId columnFrom cardFrom columnTo cardTo ]
                                            else
                                                model ! []
                                        Nothing ->
                                            model ! []

                                _ ->
                                    model ! []

                        Nothing ->
                            { model | dnd = DragAndDrop.update subMsg model.dnd } ! []

                _ ->
                    model ! []

        ChangeInput columnId input ->
            { model | input = String.trim input } ! []

        CreateCard columnId ->
            case model.user of
                Just userId ->
                    { model | input = "" } ! [ Sock.add (webSocketUrl model.flags) userId columnId model.input ]
                Nothing ->
                    model ! []

        Socket data ->
            Sock.update data model socketUpdate

        UrlChange location ->
            urlChange location model

        _ ->
            model ! []

urlChange : Navigation.Location -> Model -> (Model, Cmd Msg)
urlChange location model =
    let
        path = String.dropLeft 2 location.hash
    in
        if path == "" then
            { model | retroId = Nothing, retro = Retro.empty } ! []

        else
            joinRetro { model | retroId = Just path, retro = Retro.empty }


socketUpdate : (String, Sock.MsgData) -> Model -> (Model, Cmd Msg)
socketUpdate (id, msgData) model =
    case msgData of
        Sock.Stage { stage } ->
            case stage of
                "Thinking" -> { model | stage = Thinking } ! []
                "Presenting" -> { model | stage = Presenting } ! []
                "Voting" -> { model | stage = Voting } ! []
                "Discussing" -> { model | stage = Discussing } ! []
                _ -> model ! []

        Sock.Card { columnId, cardId, revealed, votes } ->
            let
                card =
                    { id = cardId
                    , votes = votes
                    , revealed = revealed
                    , contents = [ ]
                    }
            in
                { model | retro = Retro.addCard columnId card model.retro } ! []

        Sock.Content { columnId, cardId, cardText } ->
            let content =
                    { id = ""
                    , text = cardText
                    , author = id
                    }
            in
                { model | retro = Retro.addContent columnId cardId content model.retro } ! []

        Sock.Column { columnId, columnName, columnOrder } ->
            let
                column = { id = columnId, name = columnName, order = columnOrder, cards = Dict.empty }
            in
                { model | retro = Retro.addColumn column model.retro } ! []

        Sock.Move { columnFrom, columnTo, cardId } ->
            { model | retro = Retro.moveCard columnFrom columnTo cardId model.retro } ! []

        Sock.Reveal { columnId, cardId } ->
            { model | retro = Retro.revealCard columnId cardId model.retro } ! []

        Sock.Group { columnFrom, cardFrom, columnTo, cardTo } ->
            { model | retro = Retro.groupCards (columnFrom, cardFrom) (columnTo, cardTo) model.retro } ! []

        Sock.Vote { columnId, cardId } ->
            { model | retro = Retro.voteCard columnId cardId model.retro } ! []

        Sock.Error { error } ->
            handleError error model


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
                    [ retroView userId model
                    , footer
                    , retroListModal model
                    ]
            else
                Html.div []
                    [ retroView userId model
                    , footer
                    ]
        Nothing ->
            Html.div []
                [ footer
                , signInModal
                ]

retroView : String -> Model -> Html Msg
retroView userId model =
    Html.section [ Attr.class "section" ]
        [ Html.div [ Attr.class "container is-fluid" ]
              [ tabsView model.stage
              , columnsView userId model.stage model.dnd model.retro.columns
              ]
        ]


retroListModal : Model -> Html Msg
retroListModal model =
    let
        title =
            Html.h1 [ Attr.class "title" ]
                [ Html.text "Retros" ]

        choice name =
            Html.a [ Attr.class "button"
                   , Attr.href ("#/" ++ name)
                   ]
                [ Html.text name ]

        choices =
            List.map choice (Maybe.withDefault [] model.retroList)
    in
        Bulma.modal
            [ Bulma.box []
                  (title :: choices)
            , Bulma.box []
                [ Html.input [ Event.onInput SetRetroName ]
                      [ ]
                , Html.button [ Attr.class "button"
                              , Event.onClick CreateRetro ]
                    [ Html.text "Create" ]
                ]
            ]


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


tabsView : Stage -> Html Msg
tabsView stage =
    let
        tab s =
            Html.li [ Attr.classList [("is-active", stage == s)]
                    , Event.onClick (SetStage s)
                    ]
                [ Html.a [] [ Html.text (toString s) ]
                ]
    in
        Bulma.tabs [ Attr.class "is-toggle" ]
            [ Html.ul [ Attr.class "is-left" ]
                  [ tab Thinking
                  , tab Presenting
                  , tab Voting
                  , tab Discussing
                  ]
            , Html.ul [ Attr.class "is-right" ]
                [ Html.li []
                      [ Html.a [ Attr.href "#/" ]
                            [ Html.text "Quit" ]
                      ]
                ]
            ]

fst (a, b) = a
snd (a, b) = b

columnsView : String -> Stage -> DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView connId stage dnd columns =
    if stage == Discussing then
        let
            getList : Dict comparable a -> List a
            getList dict = Dict.toList dict |> List.map snd

            cards : List Card
            cards = getList columns
                  |> List.map (.cards)
                  |> List.map getList
                  |> List.concat

            cardsByVote : List (Int, List Card)
            cardsByVote = cards
                        |> group Dict.empty
                        |> Dict.toList
                        |> List.sortBy fst
                        |> List.reverse

            cardToView card =
                Bulma.card []
                      [ Bulma.cardContent [] [ contentsView card.contents ]
                      ]

            groupInsert : a -> Maybe (List a) -> Maybe (List a)
            groupInsert x maybe =
                case maybe of
                    Just list -> Just (x :: list)
                    Nothing -> Just [x]

            group : Dict Int (List Card) -> List Card -> Dict Int (List Card)
            group res list =
                case list of
                    (x :: xs) -> group (Dict.update x.votes (groupInsert x) res) xs
                    [] -> res

            columnView : (Int, List Card) -> Html Msg
            columnView (vote, cards) =
                Bulma.column []
                    (titleCardView (toString vote) :: List.map cardToView cards)

        in
            cardsByVote
                |> List.map columnView
                |> Bulma.columns [ Attr.class "is-multiline" ]

    else
        Dict.toList columns
            |> List.sortBy (snd >> .order)
            |> List.map (columnView connId stage dnd)
            |> Bulma.columns [ ]

columnView : String -> Stage -> DragAndDrop.Model CardDragging CardOver -> (String, Column) -> Html Msg
columnView connId stage dnd (columnId, column) =
    let
        title = [titleCardView column.name]
        list =
            Dict.toList column.cards
                |> List.map (cardView connId stage dnd columnId)
                |> List.concat
        add = [addCardView columnId]
    in
        case stage of
            Thinking ->
                Bulma.column ([ Attr.classList [ ("over", dnd.over == Just (columnId, Nothing))
                                              ]
                             ] ++ DragAndDrop.dropzone DnD (columnId, Nothing))
                    (title ++ list ++ add)

            _ ->
                Html.div [ Attr.class "column" ]
                    (title ++ list)

contentView : Content -> Html Msg
contentView content =
    Bulma.content []
        [ Html.p [ Attr.class "title is-6" ] [ Html.text content.author ]
        , Html.p [] [ Html.text content.text ]
        ]

contentsView : List Content -> Html Msg
contentsView contents =
    contents
        |> List.map (contentView)
        |> List.intersperse (Html.hr [] [])
        |> Bulma.content []

cardView : String -> Stage -> DragAndDrop.Model CardDragging CardOver -> String -> (String, Card) -> List (Html Msg)
cardView connId stage dnd columnId (cardId, card) =
    let
        content = contentsView card.contents
    in
        case stage of
            Thinking ->
                if Card.authored connId card then
                    [ Bulma.card (DragAndDrop.draggable DnD (columnId, cardId))
                          [ Bulma.cardContent [] [ content ] ]
                    ]
                else
                    []

            Presenting ->
                if not card.revealed then
                    if Card.authored connId card then
                        [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed)
                                                      , ("can-reveal", True)
                                                      ]
                                     , Event.onClick (Reveal columnId cardId)
                                     ]
                              [ Bulma.cardContent [] [ content ] ]
                        ]
                    else
                        []
                else
                    [ Bulma.card []
                          [ Bulma.cardContent [] [ content ] ]
                    ]

            Voting ->
                [ Bulma.card (List.concat
                                  [ DragAndDrop.draggable DnD (columnId, cardId)
                                  , DragAndDrop.dropzone DnD (columnId, Just cardId)
                                  , [ Attr.classList [ ("over", dnd.over == Just (columnId, Just cardId))
                                                     , ("not-revealed", not card.revealed)
                                                     ]
                                    ]
                                  ])

                      [ Bulma.cardContent []
                            [ content ]
                      , Bulma.cardFooter []
                          [ Bulma.cardFooterItem [] (toString card.votes)
                          , Bulma.cardFooterItem [ Event.onClick (Vote columnId cardId) ] "Vote"
                          ]
                      ]
                ]

            _ ->
                if card.revealed || Card.authored connId card then
                    [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed) ]
                                 ]
                          [ Bulma.cardContent [] [ content ] ]
                    ]
                else
                    []


titleCardView : String -> Html Msg
titleCardView title =
    Html.div [ Attr.class "not-card card-content has-text-centered" ]
        [ Html.div [ Attr.class "content" ]
              [ Html.h1 []
                    [ Html.text title
                    ]
              ]
        ]

addCardView : String -> Html Msg
addCardView columnId =
    Bulma.card []
        [ Bulma.cardContent []
              [ Bulma.content []
                    [ Html.textarea [ Event.onInput (ChangeInput columnId)
                                    , ExtraEvent.onEnter (CreateCard columnId)
                                    , Attr.placeholder "Add a card..."
                                    ]
                          [ ]
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

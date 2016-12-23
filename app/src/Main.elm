port module Main exposing (main)

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

main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

-- Model

type Stage = Thinking | Presenting | Voting | Discussing

type alias CardDragging = (String, String)
type alias CardOver = (String, Maybe String)

type alias Model =
    { user : String
    , joined : Bool
    , stage : Stage
    , retro : Retro
    , input : String
    , dnd : DragAndDrop.Model CardDragging CardOver
    }

init : (Model, Cmd msg)
init =
    { user = ""
    , joined = False
    , stage = Thinking
    , retro = Retro.empty
    , input = ""
    , dnd = DragAndDrop.empty
    } ! [ storageGet "id" ]

-- Update

port storageSet : (String, String) -> Cmd msg
port storageGet : String -> Cmd msg
port storageGot : (Maybe String -> msg) -> Sub msg

type Msg = SetId (Maybe String)
         | Socket String
         | ChangeInput String String
         | SetStage Stage
         | Reveal String String
         | ChangeName String
         | Join
         | Vote String String
         | DnD (DragAndDrop.Msg (String, String) (String, Maybe String))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        Vote columnId cardId ->
            model ! [ Sock.send model.user "vote" [columnId, cardId] ]

        ChangeName name ->
            { model | user = name } ! []
        Join ->
            { model | joined = True } ! [ Sock.send model.user "init" [model.user] ]

        SetId id ->
            case id of
                Just v -> { model | user = v, joined = True } ! [ Sock.send v "init" [v] ]
                Nothing -> model ! [ ]

        SetStage stage ->
            { model | stage = stage } ! [ Sock.send model.user "stage" [toString stage] ]

        Reveal columnId cardId ->
            model ! [ Sock.send model.user "reveal" [columnId, cardId] ]

        DnD subMsg ->
            case DragAndDrop.isDrop subMsg model.dnd of
                Just ((columnFrom, cardFrom), (columnTo, maybeCardTo)) ->
                    case model.stage of
                        Thinking ->
                            { model | dnd = DragAndDrop.empty } ! [ Sock.send model.user "move" [columnFrom, columnTo, cardFrom] ]

                        Voting ->
                            case maybeCardTo of
                                Just cardTo ->
                                    { model | dnd = DragAndDrop.empty } ! [ Sock.send model.user "group" [columnFrom, cardFrom, columnTo, cardTo ] ]
                                Nothing ->
                                    model ! []

                        _ ->
                            model ! []

                Nothing ->
                    { model | dnd = DragAndDrop.update subMsg model.dnd } ! []

        ChangeInput columnId input ->
            if String.contains "\n" input then
                { model | input = "" } ! [ Sock.send model.user "add" [columnId, model.input] ]
            else
                { model | input = input } ! []

        Socket data ->
            Sock.update data model socketUpdate

socketUpdate : Sock.SocketMsg -> Model -> (Model, Cmd Msg)
socketUpdate msg model =
    case msg.op of
        "stage" ->
            case msg.args of
                [stage] ->
                    case stage of
                        "Thinking" -> { model | stage = Thinking } ! []
                        "Presenting" -> { model | stage = Presenting } ! []
                        "Voting" -> { model | stage = Voting } ! []
                        "Discussing" -> { model | stage = Discussing } ! []
                        _ -> model ! []

                _ ->
                    model ! []

        "card" ->
            case msg.args of
                [columnId, cardId, cardRevealed] ->
                    let
                        card =
                            { id = cardId
                            , votes = 0
                            , revealed = cardRevealed == "true"
                            , contents = [ ]
                            }
                    in
                        { model | retro = Retro.addCard columnId card model.retro } ! []
                _ ->
                    model ! []

        "content" ->
            case msg.args of
                [columnId, cardId, _, contentText] ->
                    let content =
                            { id = ""
                            , text = contentText
                            , author = msg.id
                            }
                    in
                        { model | retro = Retro.addContent columnId cardId content model.retro } ! []

                _ ->
                    model ! []

        "column" ->
            case msg.args of
                [columnId, columnName] ->
                    let
                        column = { id = columnId, name = columnName, cards = Dict.empty }
                    in
                        { model | retro = Retro.addColumn column model.retro } ! []
                _ ->
                    model ! []

        "move" ->
            case msg.args of
                [columnFrom, columnTo, cardId] ->
                    { model | retro = Retro.moveCard columnFrom columnTo cardId model.retro } ! []
                _ ->
                    model ! []

        "reveal" ->
            case msg.args of
                [columnId, cardId] ->
                    { model | retro = Retro.revealCard columnId cardId model.retro } ! []
                _ ->
                    model ! []

        "group" ->
            case msg.args of
                [columnFrom, cardFrom, columnTo, cardTo] ->
                    { model | retro = Retro.groupCards (columnFrom, cardFrom) (columnTo, cardTo) model.retro } ! []
                _ ->
                    model ! []

        "vote" ->
            case msg.args of
                [columnId, cardId] ->
                    { model | retro = Retro.voteCard columnId cardId model.retro } ! []
                _ ->
                    model ! []

        "error" ->
            case msg.args of
                [error] ->
                    handleError error model
                _ ->
                    model ! []

        _ ->
            model ! []

handleError : String -> Model -> (Model, Cmd Msg)
handleError error model =
    case error of
        "unknown_user" ->
            { model | user = "", joined = False } ! []

        _ ->
            model ! []

-- View

view : Model -> Html Msg
view model =
    let
        tabs =
            Html.section [ Attr.class "section" ]
                [ Html.div [ Attr.class "container is-fluid" ]
                      [ tabsView model.stage
                      , columnsView model.user model.stage model.dnd model.retro.columns
                      ]
                ]

        footer =
          Html.footer [ Attr.class "footer" ]
            [ Html.div [ Attr.class "container" ]
                  [ Html.div [ Attr.class "content has-text-centered" ]
                        [ Html.text "A link to github?"
                        ]
                  ]
            ]

        modal =
          Bulma.modal
            [ Bulma.box []
                  [ Html.a [ Attr.class "button is-primary"
                           , Attr.href "/oauth/login"
                           ]
                        [ Html.text "Sign-in with GitHub" ]
                  ]
            ]
    in
        if model.joined then
            Html.div [] [ tabs, footer ]
        else
            Html.div [] [ tabs, footer, modal ]


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
                      [ Html.a [] [ Html.text "05:03 remaining" ]
                      ]
                ]
            ]

columnsView : String -> Stage -> DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView connId stage dnd columns =
    Bulma.columns [ ]
        <| List.map (columnView connId stage dnd)
        <| Dict.toList columns

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
                        [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed) ]
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
                [ Bulma.card []
                      [ Bulma.cardContent [] [ content ] ]
                ]


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
        [ Sock.listen "ws://localhost:8080/ws" Socket
        , storageGot SetId
        ]

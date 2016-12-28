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

        SetId (Just parts) ->
            case String.split ";" parts of
                [id, token] ->
                    { model | user = id, joined = True } ! [ Sock.send id "init" [id, token] ]
                _ ->
                    { model | user = "", joined = False } ! []

        SetStage stage ->
            { model | stage = stage } ! [ Sock.send model.user "stage" [toString stage] ]

        Reveal columnId cardId ->
            model ! [ Sock.send model.user "reveal" [columnId, cardId] ]

        DnD subMsg ->
            case DragAndDrop.isDrop subMsg model.dnd of
                Just ((columnFrom, cardFrom), (columnTo, maybeCardTo)) ->
                    case model.stage of
                        Thinking ->
                            if columnFrom /= columnTo then
                                { model | dnd = DragAndDrop.empty } ! [ Sock.send model.user "move" [columnFrom, columnTo, cardFrom] ]
                            else
                                model ! []

                        Voting ->
                            case maybeCardTo of
                                Just cardTo ->
                                    if cardFrom /= cardTo then
                                        { model | dnd = DragAndDrop.empty } ! [ Sock.send model.user "group" [columnFrom, cardFrom, columnTo, cardTo ] ]
                                    else
                                        model ! []
                                Nothing ->
                                    model ! []

                        _ ->
                            model ! []

                Nothing ->
                    { model | dnd = DragAndDrop.update subMsg model.dnd } ! []

        ChangeInput columnId input ->
            if String.endsWith "\n" input && String.trim model.input /= "" then
                { model | input = "" } ! [ Sock.send model.user "add" [columnId, model.input] ]
            else
                { model | input = String.trim input } ! []

        Socket data ->
            Sock.update data model socketUpdate

        _ ->
            model ! []

socketUpdate : Sock.SocketMsg -> Model -> (Model, Cmd Msg)
socketUpdate msg model =
    case (msg.op, msg.args) of
        ("stage", [stage]) ->
            case stage of
                "Thinking" -> { model | stage = Thinking } ! []
                "Presenting" -> { model | stage = Presenting } ! []
                "Voting" -> { model | stage = Voting } ! []
                "Discussing" -> { model | stage = Discussing } ! []
                _ -> model ! []

        ("card", [columnId, cardId, cardRevealed, cardVotes]) ->
            case String.toInt cardVotes of
                Ok votes ->
                    let
                        card =
                            { id = cardId
                            , votes = votes
                            , revealed = cardRevealed == "true"
                            , contents = [ ]
                            }
                    in
                        { model | retro = Retro.addCard columnId card model.retro } ! []
                Err e ->
                    Debug.log (toString e) (model ! [])

        ("content", [columnId, cardId, contentText]) ->
            let content =
                    { id = ""
                    , text = contentText
                    , author = msg.id
                    }
            in
                { model | retro = Retro.addContent columnId cardId content model.retro } ! []

        ("column", [columnId, columnName]) ->
            let
                column = { id = columnId, name = columnName, cards = Dict.empty }
            in
                { model | retro = Retro.addColumn column model.retro } ! []

        ("move", [columnFrom, columnTo, cardId]) ->
            { model | retro = Retro.moveCard columnFrom columnTo cardId model.retro } ! []

        ("reveal", [columnId, cardId]) ->
            { model | retro = Retro.revealCard columnId cardId model.retro } ! []

        ("group",[columnFrom, cardFrom, columnTo, cardTo]) ->
            { model | retro = Retro.groupCards (columnFrom, cardFrom) (columnTo, cardTo) model.retro } ! []

        ("vote", [columnId, cardId]) ->
            { model | retro = Retro.voteCard columnId cardId model.retro } ! []

        ("error", [error]) ->
            handleError error model

        missing ->
            Debug.log (toString missing) (model ! [])

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
    if stage == Discussing then
        let
            fst (a, b) = a
            snd (a, b) = b

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

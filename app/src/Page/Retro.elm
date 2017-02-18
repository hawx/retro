module Page.Retro exposing ( empty
                           , mount
                           , Model
                           , Msg
                           , update
                           , socketUpdate
                           , view
                           )

import Debug
import Retro exposing (Retro)
import DragAndDrop
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Html.Events.Extra as ExtraEvent
import Bulma
import Column exposing (Column)
import Card exposing (Card, Content)
import Dict exposing (Dict)
import Route
import Sock

type alias CardDragging = (String, String)
type alias CardOver = (String, Maybe String)

type alias Model =
    { retro : Retro
    , input : String
    , dnd : DragAndDrop.Model CardDragging CardOver
    }

empty : Model
empty =
    { retro = Retro.empty
    , input = ""
    , dnd = DragAndDrop.empty
    }

mount : Sock.Sender Msg -> String -> Cmd Msg
mount sender retroId =
    Sock.joinRetro sender retroId

type Msg = ChangeInput String String
         | CreateCard String
         | DeleteCard String String
         | SetStage Retro.Stage
         | Reveal String String
         | Vote String String
         | DnD (DragAndDrop.Msg (String, String) (String, Maybe String))

update : Sock.Sender Msg -> Msg -> Model -> (Model, Cmd Msg)
update sender msg model =
    case Debug.log "msg" msg of
        Vote columnId cardId ->
            model ! [ Sock.vote sender columnId cardId ]

        SetStage stage ->
            { model | retro = Retro.setStage stage model.retro } !
                [ Sock.stage sender (toString stage) ]

        Reveal columnId cardId ->
            model ! [ Sock.reveal sender columnId cardId ]

        DnD subMsg ->
            case DragAndDrop.isDrop subMsg model.dnd of
                Just ((columnFrom, cardFrom), (columnTo, maybeCardTo)) ->
                    case model.retro.stage of
                        Retro.Thinking ->
                            if columnFrom /= columnTo then
                                { model | dnd = DragAndDrop.empty } ! [ Sock.move sender columnFrom columnTo cardFrom ]
                            else
                                model ! []

                        Retro.Voting ->
                            case maybeCardTo of
                                Just cardTo ->
                                    if cardFrom /= cardTo then
                                        { model | dnd = DragAndDrop.empty } ! [ Sock.group sender columnFrom cardFrom columnTo cardTo ]
                                    else
                                        model ! []
                                Nothing ->
                                    model ! []

                        _ ->
                            model ! []

                Nothing ->
                    { model | dnd = DragAndDrop.update subMsg model.dnd } ! []

        ChangeInput columnId input ->
            { model | input = String.trim input } ! []

        CreateCard columnId ->
            { model | input = "" } ! [ Sock.add sender columnId model.input ]

        DeleteCard columnId cardId ->
            model ! [ Sock.delete sender columnId cardId ]




parseStage : String -> Maybe Retro.Stage
parseStage s =
    case s of
        "Thinking" -> Just Retro.Thinking
        "Presenting" -> Just Retro.Presenting
        "Voting" -> Just Retro.Voting
        "Discussing" -> Just Retro.Discussing
        _ -> Nothing


socketUpdate : (String, Sock.MsgData) -> Model -> (Model, Cmd Msg)
socketUpdate (id, msgData) model =
    case msgData of
        Sock.Stage { stage } ->
            case parseStage stage of
                Just s ->
                    { model | retro = Retro.setStage s model.retro } ! []

                Nothing ->
                    model ! []

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

        Sock.Delete { columnId, cardId } ->
            { model | retro = Retro.removeCard columnId cardId model.retro } ! []

        _ ->
            model ! []

view : String -> Model -> Html Msg
view userId model =
    Html.section [ Attr.class "section" ]
        [ Html.div [ Attr.class "container is-fluid" ]
              [ tabsView model.retro.stage
              , columnsView userId model.retro.stage model.dnd model.retro.columns
              ]
        ]

tabsView : Retro.Stage -> Html Msg
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
                  [ tab Retro.Thinking
                  , tab Retro.Presenting
                  , tab Retro.Voting
                  , tab Retro.Discussing
                  ]
            , Html.ul [ Attr.class "is-right" ]
                [ Html.li []
                      [ Html.a [ Attr.href (Route.toUrl Route.Menu) ]
                            [ Html.text "Quit" ]
                      ]
                ]
            ]


columnsView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView connId stage dnd columns =
    if stage == Retro.Discussing then
        let
            cardToView card =
                Bulma.card []
                      [ Bulma.cardContent [] [ contentsView card.contents ]
                      ]

            columnView (vote, cards) =
                Bulma.column []
                    (titleCardView (toString vote) :: List.map cardToView cards)

        in
            Column.cardsByVote columns
                |> List.map columnView
                |> Bulma.columns [ Attr.class "is-multiline" ]

    else
        Dict.toList columns
            |> List.sortBy (\(_,b) -> b.order)
            |> List.map (columnView connId stage dnd)
            |> Bulma.columns [ ]

columnView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> (String, Column) -> Html Msg
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
            Retro.Thinking ->
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

cardView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> String -> (String, Card) -> List (Html Msg)
cardView connId stage dnd columnId (cardId, card) =
    case stage of
        Retro.Thinking ->
            if Card.authored connId card then
                [ Bulma.card (DragAndDrop.draggable DnD (columnId, cardId))
                      [ Bulma.delete [ Event.onClick (DeleteCard columnId cardId) ]
                      , Bulma.cardContent [] [ contentsView card.contents ]
                      ]
                ]
            else
                []

        Retro.Presenting ->
            if card.revealed then
                [ Bulma.card []
                      [ Bulma.cardContent [] [ contentsView card.contents ] ]
                ]
            else if Card.authored connId card then
                [ Bulma.card [ Attr.classList [ ("not-revealed", not card.revealed)
                                              , ("can-reveal", True)
                                              ]
                             , Event.onClick (Reveal columnId cardId)
                             ]
                      [ Bulma.cardContent [] [ contentsView card.contents ] ]
                ]
            else
                []

        Retro.Voting ->
            if card.revealed then
                [ Bulma.card (List.concat
                                  [ DragAndDrop.draggable DnD (columnId, cardId)
                                  , DragAndDrop.dropzone DnD (columnId, Just cardId)
                                  , [ Attr.classList [ ("over", dnd.over == Just (columnId, Just cardId))
                                                     , ("not-revealed", not card.revealed)
                                                     ]
                                    ]
                                  ])

                      [ Bulma.cardContent []
                            [ contentsView card.contents ]
                      , Bulma.cardFooter []
                          [ Bulma.cardFooterItem [] (toString card.votes)
                          , Bulma.cardFooterItem [ Event.onClick (Vote columnId cardId) ] "Vote"
                          ]
                      ]
                ]
            else
                []

        Retro.Discussing ->
            [ Bulma.card []
                [ Bulma.cardContent [] [ contentsView card.contents ]
                ]
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
                                    , ExtraEvent.onEnter (CreateCard columnId)
                                    , Attr.placeholder "Add a card..."
                                    ]
                          [ ]
                    ]
              ]
        ]

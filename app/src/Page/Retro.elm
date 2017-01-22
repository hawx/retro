module Page.Retro exposing (..)

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

init : (Model, Cmd Msg)
init = empty ! []

empty : Model
empty =
    { retro = Retro.empty
    , input = ""
    , dnd = DragAndDrop.empty
    }

type Msg = ChangeInput String String
         | CreateCard String
         | SetStage Retro.Stage
         | Reveal String String
         | Vote String String
         | DnD (DragAndDrop.Msg (String, String) (String, Maybe String))

update : String -> String -> Msg -> Model -> (Model, Cmd Msg)
update sockUrl userId msg model =
    case msg of
        Vote columnId cardId ->
            model ! [ Sock.vote sockUrl userId columnId cardId ]

        SetStage stage ->
            { model | retro = Retro.setStage stage model.retro } !
                [ Sock.stage sockUrl userId (toString stage) ]

        Reveal columnId cardId ->
            model ! [ Sock.reveal sockUrl userId columnId cardId ]

        DnD subMsg ->
            case DragAndDrop.isDrop subMsg model.dnd of
                Just ((columnFrom, cardFrom), (columnTo, maybeCardTo)) ->
                    case model.retro.stage of
                        Retro.Thinking ->
                            if columnFrom /= columnTo then
                                { model | dnd = DragAndDrop.empty } ! [ Sock.move sockUrl userId columnFrom columnTo cardFrom ]
                            else
                                model ! []

                        Retro.Voting ->
                            case maybeCardTo of
                                Just cardTo ->
                                    if cardFrom /= cardTo then
                                        { model | dnd = DragAndDrop.empty } ! [ Sock.group sockUrl userId columnFrom cardFrom columnTo cardTo ]
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
            { model | input = "" } ! [ Sock.add sockUrl userId columnId model.input ]



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

fst (a, b) = a
snd (a, b) = b

columnsView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView connId stage dnd columns =
    if stage == Retro.Discussing then
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
    let
        content = contentsView card.contents
    in
        case stage of
            Retro.Thinking ->
                if Card.authored connId card then
                    [ Bulma.card (DragAndDrop.draggable DnD (columnId, cardId))
                          [ Bulma.cardContent [] [ content ] ]
                    ]
                else
                    []

            Retro.Presenting ->
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

            Retro.Voting ->
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

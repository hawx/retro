module Views.Retro.Thinking exposing (view)

import Bulma
import Data.Card as Card exposing (Card)
import Data.Column as Column exposing (Column)
import Data.Retro as Retro
import Dict exposing (Dict)
import DragAndDrop
import EveryDict exposing (EveryDict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Html.Events.Extra as ExtraEvent
import Page.RetroModel exposing (..)
import Page.RetroMsg exposing (Msg(..))
import Views.Retro.Contents
import Views.Retro.EditContents
import Views.Retro.TitleCard


view : String -> Model -> Html Msg
view username model =
    columnsView username model.retro.stage model.dnd model.retro.columns


columnsView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> EveryDict Column.Id Column -> Html Msg
columnsView username stage dnd columns =
    EveryDict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView username stage dnd)
        |> Bulma.columns []


columnView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> ( Column.Id, Column ) -> Html Msg
columnView username stage dnd ( columnId, column ) =
    let
        title =
            [ Views.Retro.TitleCard.view column.name ]

        list =
            EveryDict.toList column.cards
                |> List.map (cardView username stage dnd columnId)

        add =
            [ addCardView columnId ]
    in
    Bulma.column
        (Attr.classList [ ( "over", dnd.over == Just ( columnId, Nothing ) ) ]
            :: DragAndDrop.dropzone DnD ( columnId, Nothing )
        )
        (title ++ list ++ add)


cardView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> Column.Id -> ( Card.Id, Card ) -> Html Msg
cardView username stage dnd columnId ( cardId, card ) =
    if Card.authored username card then
        if not card.editing then
            Bulma.card (DragAndDrop.draggable DnD ( columnId, cardId ))
                [ Bulma.delete [ Event.onClick (DeleteCard columnId cardId) ]
                , Bulma.cardContent [ Event.onDoubleClick (EditCard columnId cardId) ] [ Views.Retro.Contents.view card.contents ]
                ]
        else
            Bulma.card []
                [ Bulma.discard [ Event.onClick (DiscardEditCard columnId cardId) ]
                , Bulma.cardContent [] [ Views.Retro.EditContents.view columnId card ]
                ]
    else
        Html.text ""


addCardView : Column.Id -> Html Msg
addCardView columnId =
    Bulma.card [ Attr.class "add-card" ]
        [ Bulma.cardContent []
            [ Bulma.content []
                [ Html.textarea
                    [ Event.onInput (ChangeInput columnId)
                    , ExtraEvent.onEnter (CreateCard columnId)
                    , Attr.placeholder "Something constructive..."
                    ]
                    []
                ]
            ]
        , Bulma.cardFooter []
            [ Bulma.cardFooterItem [ Event.onClick (CreateCard columnId) ] "Add"
            ]
        ]

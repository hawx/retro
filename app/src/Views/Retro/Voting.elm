module Views.Retro.Voting exposing (view)

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
import Page.RetroModel exposing (..)
import Page.RetroMsg exposing (Msg(..))
import Views.Retro.Contents
import Views.Retro.TitleCard


view : Model -> Html Msg
view model =
    columnsView model.dnd model.retro.columns


columnsView : DragAndDrop.Model CardDragging CardOver -> EveryDict Column.Id Column -> Html Msg
columnsView dnd columns =
    EveryDict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView dnd)
        |> Bulma.columns []


columnView : DragAndDrop.Model CardDragging CardOver -> ( Column.Id, Column ) -> Html Msg
columnView dnd ( columnId, column ) =
    Html.div [ Attr.class "column" ] <|
        Views.Retro.TitleCard.view column.name
            :: (EveryDict.toList column.cards
                    |> List.map (cardView dnd columnId)
               )


cardView : DragAndDrop.Model CardDragging CardOver -> Column.Id -> ( Card.Id, Card ) -> Html Msg
cardView dnd columnId ( cardId, card ) =
    if card.revealed then
        Bulma.card
            (List.concat
                [ DragAndDrop.draggable DnD ( columnId, cardId )
                , DragAndDrop.dropzone DnD ( columnId, Just cardId )
                , [ Attr.classList
                        [ ( "over", dnd.over == Just ( columnId, Just cardId ) )
                        , ( "not-revealed", not card.revealed )
                        ]
                  ]
                ]
            )
            [ Bulma.cardContent []
                [ Views.Retro.Contents.view card.contents ]
            , Bulma.cardFooter []
                [ Bulma.cardFooterItem [] (toString card.votes)
                , Bulma.cardFooterItem [ Event.onClick (Vote columnId cardId) ] "+"
                , if card.votes > 0 then
                    Bulma.cardFooterItem [ Event.onClick (Unvote columnId cardId) ] "-"
                  else
                    Bulma.cardFooterItem [] "-"
                ]
            ]
    else
        Html.text ""

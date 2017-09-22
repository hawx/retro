module Views.Retro.Voting exposing (view)

import Bulma
import Data.Card exposing (Card)
import Data.Column exposing (Column)
import Data.Retro as Retro
import Dict exposing (Dict)
import DragAndDrop
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Page.RetroModel exposing (..)
import Page.RetroMsg exposing (Msg(..))
import Views.Retro.Contents
import Views.Retro.TitleCard


view : String -> Model -> Html Msg
view userId model =
    columnsView model.dnd model.retro.columns


columnsView : DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView dnd columns =
    Dict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView dnd)
        |> Bulma.columns []


columnView : DragAndDrop.Model CardDragging CardOver -> ( String, Column ) -> Html Msg
columnView dnd ( columnId, column ) =
    Html.div [ Attr.class "column" ] <|
        Views.Retro.TitleCard.view column.name
            :: (Dict.toList column.cards
                    |> List.map (cardView dnd columnId)
               )


cardView : DragAndDrop.Model CardDragging CardOver -> String -> ( String, Card ) -> Html Msg
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

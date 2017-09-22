module Views.Retro.Voting exposing (view)

import Bulma
import Data.Card as Card exposing (Card, Content)
import Data.Column as Column exposing (Column)
import Data.Retro as Retro exposing (Retro)
import Dict exposing (Dict)
import DragAndDrop
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Html.Events.Extra as ExtraEvent
import Page.RetroModel exposing (..)
import Page.RetroMsg exposing (Msg(..))
import Route
import Sock
import Views.Retro.Contents
import Views.Retro.TitleCard


view : String -> Model -> Html Msg
view userId model =
    columnsView userId model.retro.stage model.dnd model.retro.columns


columnsView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> Dict String Column -> Html Msg
columnsView connId stage dnd columns =
    Dict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView connId stage dnd)
        |> Bulma.columns []


columnView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> ( String, Column ) -> Html Msg
columnView connId stage dnd ( columnId, column ) =
    Html.div [ Attr.class "column" ] <|
        Views.Retro.TitleCard.view column.name
            :: (Dict.toList column.cards
                    |> List.map (cardView connId stage dnd columnId)
               )


cardView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> String -> ( String, Card ) -> Html Msg
cardView connId stage dnd columnId ( cardId, card ) =
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

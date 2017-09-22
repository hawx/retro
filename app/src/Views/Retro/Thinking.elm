module Views.Retro.Thinking exposing (view)

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
    let
        title =
            [ Views.Retro.TitleCard.view column.name ]

        list =
            Dict.toList column.cards
                |> List.map (cardView connId stage dnd columnId)

        add =
            [ addCardView columnId ]
    in
    Bulma.column
        ([ Attr.classList
            [ ( "over", dnd.over == Just ( columnId, Nothing ) )
            ]
         ]
            ++ DragAndDrop.dropzone DnD ( columnId, Nothing )
        )
        (title ++ list ++ add)


cardView : String -> Retro.Stage -> DragAndDrop.Model CardDragging CardOver -> String -> ( String, Card ) -> Html Msg
cardView connId stage dnd columnId ( cardId, card ) =
    if Card.authored connId card then
        Bulma.card (DragAndDrop.draggable DnD ( columnId, cardId ))
            [ Bulma.delete [ Event.onClick (DeleteCard columnId cardId) ]
            , Bulma.cardContent [] [ Views.Retro.Contents.view card.contents ]
            ]
    else
        Html.text ""


addCardView : String -> Html Msg
addCardView columnId =
    Bulma.card []
        [ Bulma.cardContent []
            [ Bulma.content []
                [ Html.textarea
                    [ Event.onInput (ChangeInput columnId)
                    , ExtraEvent.onEnter (CreateCard columnId)
                    , Attr.placeholder "Add a card..."
                    ]
                    []
                ]
            ]
        ]

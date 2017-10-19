module Views.Retro.Presenting exposing (view)

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


view : String -> Model -> Html Msg
view username model =
    columnsView username model.lastRevealed model.retro.columns


columnsView : String -> Maybe Card.Id -> EveryDict Column.Id Column -> Html Msg
columnsView username lastRevealed columns =
    EveryDict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView username lastRevealed)
        |> Bulma.columns []


columnView : String -> Maybe Card.Id -> ( Column.Id, Column ) -> Html Msg
columnView username lastRevealed ( columnId, column ) =
    Html.div [ Attr.class "column" ] <|
        Views.Retro.TitleCard.view column.name
            :: (EveryDict.toList column.cards
                    |> List.map (cardView username columnId lastRevealed)
               )


cardView : String -> Column.Id -> Maybe Card.Id -> ( Card.Id, Card ) -> Html Msg
cardView username columnId lastRevealed ( cardId, card ) =
    if card.revealed then
        Bulma.card [ Attr.classList [ ( "last-revealed", lastRevealed == Just cardId ) ] ]
            [ Bulma.cardContent []
                [ Views.Retro.Contents.view card.contents
                ]
            ]
    else if Card.authored username card then
        Bulma.card
            [ Attr.classList
                [ ( "not-revealed", not card.revealed )
                , ( "can-reveal", True )
                ]
            , Event.onClick (Reveal columnId cardId)
            ]
            [ Bulma.cardContent [ Attr.class "front" ]
                [ Views.Retro.Contents.view card.contents
                ]
            , Bulma.cardContent [ Attr.class "reverse" ]
                [ Html.p [] [ Html.text "Reveal" ]
                ]
            ]
    else
        Html.text ""

module Views.Retro.Presenting exposing (view)

import Bulma
import Data.Card as Card exposing (Card)
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
    columnsView userId model.lastRevealed model.retro.columns


columnsView : String -> Maybe String -> Dict String Column -> Html Msg
columnsView connId lastRevealed columns =
    Dict.toList columns
        |> List.sortBy (\( _, b ) -> b.order)
        |> List.map (columnView connId lastRevealed)
        |> Bulma.columns []


columnView : String -> Maybe String -> ( String, Column ) -> Html Msg
columnView connId lastRevealed ( columnId, column ) =
    Html.div [ Attr.class "column" ] <|
        Views.Retro.TitleCard.view column.name
            :: (Dict.toList column.cards
                    |> List.map (cardView connId columnId lastRevealed)
               )


cardView : String -> String -> Maybe String -> ( String, Card ) -> Html Msg
cardView connId columnId lastRevealed ( cardId, card ) =
    if card.revealed then
        Bulma.card [ Attr.classList [ ( "last-revealed", lastRevealed == Just cardId ) ] ]
            [ Bulma.cardContent []
                [ Views.Retro.Contents.view card.contents
                ]
            ]
    else if Card.authored connId card then
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

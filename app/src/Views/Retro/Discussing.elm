module Views.Retro.Discussing exposing (view)

import Bulma
import Data.Card exposing (Card)
import Data.Column as Column exposing (Column)
import Dict exposing (Dict)
import EveryDict exposing (EveryDict)
import Html exposing (Html)
import Html.Attributes as Attr
import Page.RetroModel exposing (..)
import Page.RetroMsg exposing (Msg(..))
import Views.Retro.Contents
import Views.Retro.TitleCard


view : Model -> Html msg
view model =
    columnsView model.retro.columns


columnsView : EveryDict Column.Id Column -> Html msg
columnsView columns =
    Column.cardsByVote columns
        |> List.map columnView
        |> Bulma.columns [ Attr.class "is-multiline" ]


columnView : ( Int, List Card ) -> Html msg
columnView ( vote, cards ) =
    Bulma.column []
        (Views.Retro.TitleCard.view (toString vote) :: List.map cardView cards)


cardView : Card -> Html msg
cardView card =
    Bulma.card []
        [ Bulma.cardContent [] [ Views.Retro.Contents.view card.contents ]
        ]

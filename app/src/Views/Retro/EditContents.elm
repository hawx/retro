module Views.Retro.EditContents exposing (view)

import Bulma
import Data.Card as Card exposing (Card)
import Data.Column as Column
import Data.Content exposing (Content)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Event
import Html.Events.Extra as ExtraEvent
import Page.RetroMsg exposing (Msg(..))


view : Column.Id -> Card -> Html Msg
view columnId card =
    card.contents
        |> List.map (editContentView columnId card.id)
        |> List.intersperse (Html.hr [] [])
        |> Bulma.content []


editContentView : Column.Id -> Card.Id -> Content -> Html Msg
editContentView columnId cardId content =
    Bulma.content []
        [ Html.p [ Attr.class "title is-6" ] [ Html.text content.author ]
        , Html.textarea
            [ Event.onInput (ChangeInput columnId)
            , ExtraEvent.onEnter (UpdateCard columnId cardId content.id)
            ]
            [ Html.text content.text ]
        ]

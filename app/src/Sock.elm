module Sock
    exposing
        ( Msg(..)
        , Sender
        , add
        , addParticipant
        , createRetro
        , delete
        , deleteParticipant
        , edit
        , group
        , joinRetro
        , listen
        , menu
        , move
        , reveal
        , send
        , stage
        , unvote
        , vote
        )

{-| This module provides a domain wrapper on top of the websocket format for the
purposes of retro.
-}

import Data.Card as Card
import Data.Column as Column
import Data.Content as Content
import Data.IdToken exposing (IdToken)
import Data.Retro as Retro
import Date exposing (Date)
import Dict
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Sock.LowLevel


type Msg
    = Error ErrorData
    | Hello HelloData
    | Stage StageData
    | Column ColumnData
    | Card CardData
    | Content ContentData
    | Move MoveData
    | Reveal RevealData
    | Group GroupData
    | Vote VoteData
    | Unvote VoteData
    | Delete DeleteData
    | User UserData
    | Retro RetroData
    | AddParticipant ParticipantData
    | DeleteParticipant ParticipantData


type alias ErrorData =
    { error : String }


errorDecoder : Decode.Decoder ErrorData
errorDecoder =
    Pipeline.decode ErrorData
        |> Pipeline.required "error" Decode.string


type alias HelloData =
    { hasGitHub : Bool
    , hasOffice365 : Bool
    , hasTest : Bool
    }


helloDecoder : Decode.Decoder HelloData
helloDecoder =
    Pipeline.decode HelloData
        |> Pipeline.required "hasGitHub" Decode.bool
        |> Pipeline.required "hasOffice365" Decode.bool
        |> Pipeline.required "hasTest" Decode.bool


type alias StageData =
    { stage : String }


stageDecoder : Decode.Decoder StageData
stageDecoder =
    Pipeline.decode StageData
        |> Pipeline.required "stage" Decode.string


type alias ColumnData =
    { columnId : Column.Id
    , columnName : String
    , columnOrder : Int
    }


columnDecoder : Decode.Decoder ColumnData
columnDecoder =
    Pipeline.decode ColumnData
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "columnName" Decode.string
        |> Pipeline.required "columnOrder" Decode.int


type alias CardData =
    { columnId : Column.Id
    , cardId : Card.Id
    , revealed : Bool
    , votes : Int
    , totalVotes : Int
    }


cardDecoder : Decode.Decoder CardData
cardDecoder =
    Pipeline.decode CardData
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId
        |> Pipeline.required "revealed" Decode.bool
        |> Pipeline.required "votes" Decode.int
        |> Pipeline.required "totalVotes" Decode.int


type alias ContentData =
    { columnId : Column.Id
    , cardId : Card.Id
    , contentId : Content.Id
    , author : String
    , cardText : String
    }


contentDecoder : String -> Decode.Decoder ContentData
contentDecoder author =
    Pipeline.decode ContentData
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId
        |> Pipeline.required "contentId" Content.decodeId
        |> Pipeline.hardcoded author
        |> Pipeline.required "cardText" Decode.string


type alias MoveData =
    { columnFrom : Column.Id
    , columnTo : Column.Id
    , cardId : Card.Id
    }


moveDecoder : Decode.Decoder MoveData
moveDecoder =
    Pipeline.decode MoveData
        |> Pipeline.required "columnFrom" Column.decodeId
        |> Pipeline.required "columnTo" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId


type alias RevealData =
    { columnId : Column.Id
    , cardId : Card.Id
    }


revealDecoder : Decode.Decoder RevealData
revealDecoder =
    Pipeline.decode RevealData
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId


type alias GroupData =
    { columnFrom : Column.Id
    , cardFrom : Card.Id
    , columnTo : Column.Id
    , cardTo : Card.Id
    }


groupDecoder : Decode.Decoder GroupData
groupDecoder =
    Pipeline.decode GroupData
        |> Pipeline.required "columnFrom" Column.decodeId
        |> Pipeline.required "cardFrom" Card.decodeId
        |> Pipeline.required "columnTo" Column.decodeId
        |> Pipeline.required "cardTo" Card.decodeId


type alias VoteData =
    { userId : String
    , columnId : Column.Id
    , cardId : Card.Id
    }


voteDecoder : Decode.Decoder VoteData
voteDecoder =
    Pipeline.decode VoteData
        |> Pipeline.required "userId" Decode.string
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId


type alias DeleteData =
    { columnId : Column.Id
    , cardId : Card.Id
    }


deleteDecoder : Decode.Decoder DeleteData
deleteDecoder =
    Pipeline.decode DeleteData
        |> Pipeline.required "columnId" Column.decodeId
        |> Pipeline.required "cardId" Card.decodeId


type alias UserData =
    { username : String }


userDecoder : Decode.Decoder UserData
userDecoder =
    Pipeline.decode UserData
        |> Pipeline.required "username" Decode.string


type alias ParticipantData =
    { retroId : Retro.Id
    , participant : String
    }


participantDecoder : Decode.Decoder ParticipantData
participantDecoder =
    Pipeline.decode ParticipantData
        |> Pipeline.required "retroId" Retro.decodeId
        |> Pipeline.required "participant" Decode.string


type alias RetroData =
    { id : Retro.Id
    , name : String
    , createdAt : Date
    , participants : List String
    }


retroDecoder : Decode.Decoder RetroData
retroDecoder =
    Pipeline.decode RetroData
        |> Pipeline.required "id" Retro.decodeId
        |> Pipeline.required "name" Decode.string
        |> Pipeline.required "createdAt" decodeDate
        |> Pipeline.required "participants" (Decode.list Decode.string)


listen : String -> (Msg -> msg) -> Sub msg
listen addr tagger =
    Sock.LowLevel.listen addr
        |> Sub.map (decodeData >> tagger)


decodeData : Result String { id : String, op : String, data : String } -> Msg
decodeData result =
    case result of
        Ok { id, op, data } ->
            case op of
                "hello" ->
                    decodeOperation Hello helloDecoder data

                "stage" ->
                    decodeOperation Stage stageDecoder data

                "card" ->
                    decodeOperation Card cardDecoder data

                "content" ->
                    decodeOperation Content (contentDecoder id) data

                "column" ->
                    decodeOperation Column columnDecoder data

                "move" ->
                    decodeOperation Move moveDecoder data

                "reveal" ->
                    decodeOperation Reveal revealDecoder data

                "group" ->
                    decodeOperation Group groupDecoder data

                "vote" ->
                    decodeOperation Vote voteDecoder data

                "unvote" ->
                    decodeOperation Unvote voteDecoder data

                "delete" ->
                    decodeOperation Delete deleteDecoder data

                "user" ->
                    decodeOperation User userDecoder data

                "addParticipant" ->
                    decodeOperation AddParticipant participantDecoder data

                "deleteParticipant" ->
                    decodeOperation DeleteParticipant participantDecoder data

                "retro" ->
                    decodeOperation Retro retroDecoder data

                "error" ->
                    decodeOperation Error errorDecoder data

                _ ->
                    Error { error = "unknown operation: " ++ op }

        Err err ->
            Error { error = err }


decodeOperation : (value -> Msg) -> Decode.Decoder value -> String -> Msg
decodeOperation tagger decoder data =
    case Decode.decodeString decoder data of
        Ok x ->
            tagger x

        Err e ->
            Error (ErrorData e)


type alias Sender msg =
    String -> Encode.Value -> Cmd msg


send : String -> String -> IdToken -> Sender msg
send url id token =
    Sock.LowLevel.send url id token.raw


joinRetro : Sender msg -> String -> Cmd msg
joinRetro sender retroId =
    sender "joinRetro" <|
        Encode.object
            [ ( "retroId", Encode.string retroId )
            ]


add : Sender msg -> Column.Id -> String -> Cmd msg
add sender columnId cardText =
    sender "add" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "cardText", Encode.string cardText )
            ]


move : Sender msg -> Column.Id -> Column.Id -> Card.Id -> Cmd msg
move sender columnFrom columnTo cardId =
    sender "move" <|
        Encode.object
            [ ( "columnFrom", Column.encodeId columnFrom )
            , ( "columnTo", Column.encodeId columnTo )
            , ( "cardId", Card.encodeId cardId )
            ]


stage : Sender msg -> String -> Cmd msg
stage sender stage =
    sender "stage" <|
        Encode.object
            [ ( "stage", Encode.string stage )
            ]


reveal : Sender msg -> Column.Id -> Card.Id -> Cmd msg
reveal sender columnId cardId =
    sender "reveal" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "cardId", Card.encodeId cardId )
            ]


group : Sender msg -> Column.Id -> Card.Id -> Column.Id -> Card.Id -> Cmd msg
group sender columnFrom cardFrom columnTo cardTo =
    sender "group" <|
        Encode.object
            [ ( "columnFrom", Column.encodeId columnFrom )
            , ( "cardFrom", Card.encodeId cardFrom )
            , ( "columnTo", Column.encodeId columnTo )
            , ( "cardTo", Card.encodeId cardTo )
            ]


vote : Sender msg -> Column.Id -> Card.Id -> Cmd msg
vote sender columnId cardId =
    sender "vote" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "cardId", Card.encodeId cardId )
            ]


unvote : Sender msg -> Column.Id -> Card.Id -> Cmd msg
unvote sender columnId cardId =
    sender "unvote" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "cardId", Card.encodeId cardId )
            ]


delete : Sender msg -> Column.Id -> Card.Id -> Cmd msg
delete sender columnId cardId =
    sender "delete" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "cardId", Card.encodeId cardId )
            ]


edit : Sender msg -> Content.Id -> Column.Id -> Card.Id -> String -> Cmd msg
edit sender contentId columnId cardId cardText =
    sender "edit" <|
        Encode.object
            [ ( "columnId", Column.encodeId columnId )
            , ( "contentId", Content.encodeId contentId )
            , ( "cardId", Card.encodeId cardId )
            , ( "cardText", Encode.string cardText )
            ]


menu : Sender msg -> Cmd msg
menu sender =
    sender "menu" <|
        Encode.string ""


createRetro : Sender msg -> String -> List String -> Cmd msg
createRetro sender name users =
    sender "createRetro" <|
        Encode.object
            [ ( "name", Encode.string name )
            , ( "users", Encode.list (List.map Encode.string users) )
            ]


addParticipant : Sender msg -> Retro.Id -> String -> Cmd msg
addParticipant sender retroId participant =
    sender "addParticipant" <|
        Encode.object
            [ ( "retroId", Retro.encodeId retroId )
            , ( "participant", Encode.string participant )
            ]


deleteParticipant : Sender msg -> Retro.Id -> String -> Cmd msg
deleteParticipant sender retroId participant =
    sender "deleteParticipant" <|
        Encode.object
            [ ( "retroId", Retro.encodeId retroId )
            , ( "participant", Encode.string participant )
            ]


decodeDate : Decode.Decoder Date
decodeDate =
    let
        run x =
            case x of
                Ok date ->
                    Decode.succeed date

                Err err ->
                    Decode.fail err
    in
    Decode.string |> Decode.map Date.fromString |> Decode.andThen run

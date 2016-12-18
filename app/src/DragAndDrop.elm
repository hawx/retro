module DragAndDrop exposing ( Msg
                            , Model
                            , update
                            , isDrop
                            , empty
                            , dropzone
                            , draggable)

import Html
import Html.Attributes as Attr
import Html.Events as Event
import Json.Decode as Decode

type Msg a b = MouseOver a
           | MouseOut a
           | DragStart
           | DragOver b
           | DragLeave b
           | Drop

type alias Model a b =
    { dragging : Maybe a
    , over : Maybe b
    }

empty : Model a b
empty = { dragging = Nothing, over = Nothing }

isDrop : Msg a b -> Model a b -> Maybe (a, b)
isDrop msg model =
    case msg of
        Drop -> Maybe.map2 (,) model.dragging model.over
        _ -> Nothing

update : Msg a b -> Model a b -> Model a b
update msg model =
    case msg of
        MouseOver a ->
            { model | dragging = Just a }
        MouseOut a ->
            { model | dragging = Nothing }

        DragOver b ->
            { model | over = Just b }
        DragLeave b ->
            { model | over = Nothing }

        _ ->
            model


onDragLeave : (Msg a b -> msg) -> b -> Html.Attribute msg
onDragLeave tagger value =
    Event.on "dragleave"
        (Decode.succeed (tagger (DragLeave value)))

onDragOver : (Msg a b -> msg) -> b -> Html.Attribute msg
onDragOver tagger value =
    Event.onWithOptions "dragover" { preventDefault = True, stopPropagation = False }
        (Decode.succeed (tagger (DragOver value)))

onDrop : (Msg a b -> msg) -> Html.Attribute msg
onDrop tagger =
    Event.onWithOptions "drop" { preventDefault = True, stopPropagation = False }
        (Decode.succeed (tagger Drop))

onDragStart : Html.Attribute msg
onDragStart =
    Attr.attribute
        "ondragstart"
        "event.dataTransfer.setData('text/html', event.target.innerHTML)"

onMouseOver : (Msg a b -> msg) -> a -> Html.Attribute msg
onMouseOver tagger value =
    Event.onMouseOver (tagger (MouseOver value))

onMouseOut : (Msg a b -> msg) -> a -> Html.Attribute msg
onMouseOut tagger value =
    Event.onMouseOut (tagger (MouseOut value))

dropzone : (Msg a b -> msg) -> b -> List (Html.Attribute msg)
dropzone tagger value =
    [ onDragOver tagger value
    , onDragLeave tagger value
    , onDrop tagger
    ]

draggable : (Msg a b -> msg) -> a -> List (Html.Attribute msg)
draggable tagger value =
    [ Attr.draggable "true"
    , onDragStart
    , onMouseOver tagger value
    , onMouseOut tagger value
    ]

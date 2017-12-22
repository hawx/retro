module Page.SignIn exposing (view)

import Bulma
import Html exposing (Html)
import Html.Attributes as Attr
import Views.Footer


view : { a | hasTest : Bool, hasGitHub : Bool, hasOffice365 : Bool, connected : Bool } -> Html msg
view { hasTest, hasGitHub, hasOffice365, connected } =
    Html.div [ Attr.class "site-content" ]
        [ Html.section [ Attr.class "hero is-dark is-bold is-large fill-height" ]
            [ Html.div [ Attr.class "hero-body" ]
                [ Bulma.container
                    [ Bulma.title "Retro"
                    , Bulma.subtitle "For running retrospectives remotely"
                    , if connected then
                        Html.div [ Attr.class "field is-grouped" ]
                            [ if hasTest then
                                Html.p [ Attr.class "control" ]
                                    [ Html.a
                                        [ Attr.class "button is-primary is-outlined"
                                        , Attr.href "/oauth/test/login"
                                        ]
                                        [ Html.text "Sign-in with Test" ]
                                    ]
                              else
                                Html.text ""
                            , if hasGitHub then
                                Html.p [ Attr.class "control" ]
                                    [ Html.a
                                        [ Attr.class "button is-primary is-outlined"
                                        , Attr.href "/oauth/github/login"
                                        ]
                                        [ Html.text "Sign-in with GitHub" ]
                                    ]
                              else
                                Html.text ""
                            , if hasOffice365 then
                                Html.p [ Attr.class "control" ]
                                    [ Html.a
                                        [ Attr.class "button is-danger is-outlined"
                                        , Attr.href "/oauth/office365/login"
                                        ]
                                        [ Html.text "Sign-in with Office365" ]
                                    ]
                              else
                                Html.text ""
                            ]
                      else
                        Html.div []
                            [ Html.span [ Attr.class "icon" ]
                                [ Html.i [ Attr.class "fa fa-refresh fa-spin" ] [] ]
                            , Html.text "Gathering sorrow..."
                            ]
                    ]
                ]
            ]
        , Views.Footer.view
        ]

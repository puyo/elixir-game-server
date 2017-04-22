module App exposing (..)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Html exposing (Html, div, span, li, ul, text, form, input, textarea, button, h1, h2, h3, h4)
import Html.Events exposing (onInput, onSubmit)
import Html.Attributes exposing (value, class, style, type_, placeholder, disabled)
import Json.Encode as JsEncode
import Json.Decode as JsDecode
import Array exposing (Array)


type alias Model =
    { phxSocket : Phoenix.Socket.Socket Msg
    , currentUserIndex : Int
    , users : Array User
    , chatInputText : String
    , chatMessages : List String
    }


type alias User =
    { id : Int
    , name : String
    , state : UserState
    , papers : List Paper
    , currentWordInputText : String
    , currentQuestionInputText : String
    , currentPoemInputText : String
    }


type UserState
    = UserNotPlaying
    | UserReady
    | UserWritingWord
    | UserWritingQuestion
    | UserWritingPoem
    | UserReadingResults


type alias Paper =
    { word : String
    , question : String
    , poem : String
    }


type Msg
    = PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ChatSetMessage String
    | ChatSendMessage
    | ChatReceiveMessage JsEncode.Value
    | ChatHandleSendError JsEncode.Value
    | CurrentUserSetWord String
    | CurrentUserSetQuestion String
    | CurrentUserSetPoem String
    | SubmitPaper
    | SubmitPaperOk JsEncode.Value
    | SubmitPaperError JsEncode.Value


type alias ChatMessagePayload =
    { message : String
    }


socketServer : String
socketServer =
    "ws://localhost:4000/socket/websocket"


init : ( Model, Cmd Msg )
init =
    let
        channel =
            Phoenix.Channel.init "room:lobby"

        ( initSocket, phxCmd ) =
            Phoenix.Socket.init socketServer
                |> Phoenix.Socket.withDebug
                |> Phoenix.Socket.on "shout" "room:lobby" ChatReceiveMessage
                |> Phoenix.Socket.join channel

        model =
            { phxSocket = initSocket
            , chatInputText = ""
            , chatMessages = []
            , currentUserIndex = 0
            , users =
                Array.fromList
                    [ { id = 1
                      , name = "A"
                      , state = UserNotPlaying
                      , currentWordInputText = ""
                      , currentQuestionInputText = ""
                      , currentPoemInputText = ""
                      , papers =
                            [ { word = ""
                              , question = ""
                              , poem = ""
                              }
                            , { word = ""
                              , question = ""
                              , poem = ""
                              }
                            ]
                      }
                    , { id = 2
                      , name = "B"
                      , state = UserNotPlaying
                      , currentWordInputText = ""
                      , currentQuestionInputText = ""
                      , currentPoemInputText = ""
                      , papers = []
                      }
                    , { id = 3
                      , name = "C"
                      , state = UserNotPlaying
                      , currentWordInputText = ""
                      , currentQuestionInputText = ""
                      , currentPoemInputText = ""
                      , papers = []
                      }
                    ]
            }
    in
        ( model, Cmd.map PhoenixMsg phxCmd )


userDegrees : Int -> Int -> Int
userDegrees userCount userIndex =
    round ((toFloat userIndex) * 360.0 / (toFloat userCount))


userStyle : Int -> Int -> Html.Attribute Msg
userStyle userCount userIndex =
    style
        [
        ]
        -- [ ( "transform", "rotate(" ++ (toString (userDegrees userCount userIndex)) ++ "deg)" )


viewWord : String -> Html Msg
viewWord word =
    case word of
        "" ->
            div [] []

        _ ->
            div [] []


viewCurrentPaper : Bool -> Maybe Paper -> Html Msg
viewCurrentPaper isCurrent paper =
    case paper of
        Just p ->
            div [ class "current-paper" ]
                [ form [ class "form", onSubmit SubmitPaper ]
                    [ div [ class "word" ]
                        [ if p.word == "" then
                            input
                                [ type_ "text"
                                , class "form-control input-sm"
                                , placeholder "Word"
                                , onInput CurrentUserSetWord
                                ]
                                []
                          else
                            text ("Word: " ++ p.word)
                        ]
                    , div [ class "question" ]
                        [ if p.question == "" then
                            input
                                [ type_ "text"
                                , class "form-control input-sm"
                                , disabled ( p.word == "" )
                                , placeholder "Question"
                                , onInput CurrentUserSetQuestion
                                ]
                                []
                          else
                            text ("Question: " ++ p.question)
                        ]
                    , div [ class "poem" ]
                        [ if p.poem == "" then
                            textarea
                                [ class "form-control input-sm"
                                , disabled ( p.word == "" || p.question == "" )
                                , placeholder "Poem"
                                , onInput CurrentUserSetPoem
                                ]
                                []
                          else
                            div []
                                [ text "Poem:"
                                , div [ class "poem-rendered" ]
                                    [ text p.poem ]
                                ]
                        ]
                    , div [ class "buttons" ]
                        [ button [ class "btn btn-sm btn-primary" ] [ text "Submit" ] ]
                    ]
                ]

        Nothing ->
            div [ class "current-paper" ]
                [ text "No paper!" ]


viewUser : Int -> Int -> User -> Html Msg
viewUser userCount userIndex user =
    let
        currentPaper =
            List.head user.papers

        isCurrentUser =
            userIndex == 0
    in
        div [ class "user", userStyle userCount userIndex ]
            [ div [ class "name" ]
                [ text user.name ]
            , div [ class "paper-area" ]
                [ div [ class "papers" ]
                    (user.papers
                        |> List.map (\p -> span [ class "paper-icon" ] [])
                        |> (List.intersperse (text " "))
                    )
                , viewCurrentPaper isCurrentUser currentPaper
                ]
            ]


view : Model -> Html Msg
view model =
    let
        viewUser_ =
            viewUser (Array.length (model.users))
    in
        div []
            [ h1 [] [ text "Poetry" ]
            , div [ class "game" ]
                [ div [ class "users" ]
                    (model.users
                        |> Array.indexedMap (viewUser_)
                        |> Array.toList
                        |> List.intersperse (text " ")
                    )
                ]
            , div [ class "chat" ]
                [ form [ class "form form-inline", onSubmit ChatSendMessage ]
                    [ div [ class "form-group" ]
                        [ input
                            [ type_ "text"
                            , class "form-control"
                            , onInput ChatSetMessage
                            , value model.chatInputText
                            ]
                            []
                        , button [ class "btn btn-default" ] [ text "Send" ]
                        ]
                    ]
                , ul [ class "chat-log" ]
                    (model.chatMessages |> List.map (\m -> li [] [ text m ]))
                ]
            ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        currentUser =
            Array.get model.currentUserIndex model.users
    in
        case ( currentUser, msg ) of
            ( Nothing, _ ) ->
                ( model, Cmd.none )

            -- SUBMIT PAPER
            ( Just user, SubmitPaper ) ->
                let
                    payload =
                        JsEncode.object
                            [ ( "word", JsEncode.string user.currentWordInputText )
                            , ( "question", JsEncode.string user.currentQuestionInputText )
                            , ( "poem", JsEncode.string user.currentPoemInputText )
                            , ( "user", JsEncode.int model.currentUserIndex )
                            ]

                    phxPush =
                        Phoenix.Push.init "paper" "room:lobby"
                            |> Phoenix.Push.withPayload payload
                            |> Phoenix.Push.onOk SubmitPaperOk
                            |> Phoenix.Push.onError SubmitPaperError

                    ( phxSocket, phxCmd ) =
                        Phoenix.Socket.push phxPush model.phxSocket
                in
                    ( { model
                        | chatInputText = ""
                        , phxSocket = phxSocket
                      }
                    , Cmd.map PhoenixMsg phxCmd
                    )

            ( Just user, SubmitPaperOk status ) ->
                ( model, Cmd.none )

            ( Just user, SubmitPaperError err ) ->
                ( model, Cmd.none )

            -- USER TYPING
            ( Just user, CurrentUserSetWord word ) ->
                let
                    newUser =
                        { user | currentWordInputText = word }

                    newUsers =
                        Array.set model.currentUserIndex newUser model.users
                in
                    ( { model | users = newUsers }, Cmd.none )

            ( Just user, CurrentUserSetQuestion question ) ->
                let
                    newUser =
                        { user | currentQuestionInputText = question }

                    newUsers =
                        Array.set model.currentUserIndex newUser model.users
                in
                    ( { model | users = newUsers }, Cmd.none )

            ( Just user, CurrentUserSetPoem poem ) ->
                let
                    newUser =
                        { user | currentPoemInputText = poem }

                    newUsers =
                        Array.set model.currentUserIndex newUser model.users
                in
                    ( { model | users = newUsers }, Cmd.none )

            -- CHAT
            ( _, ChatSetMessage message ) ->
                ( { model | chatInputText = message }, Cmd.none )

            ( _, ChatSendMessage ) ->
                let
                    payload =
                        JsEncode.object
                            [ ( "message", JsEncode.string model.chatInputText )
                            ]

                    phxPush =
                        Phoenix.Push.init "shout" "room:lobby"
                            |> Phoenix.Push.withPayload payload
                            |> Phoenix.Push.onOk ChatReceiveMessage
                            |> Phoenix.Push.onError ChatHandleSendError

                    ( phxSocket, phxCmd ) =
                        Phoenix.Socket.push phxPush model.phxSocket
                in
                    ( { model
                        | chatInputText = ""
                        , phxSocket = phxSocket
                      }
                    , Cmd.map PhoenixMsg phxCmd
                    )

            ( _, ChatReceiveMessage raw ) ->
                let
                    messageDecoder =
                        JsDecode.field "message" JsDecode.string

                    somePayload =
                        JsDecode.decodeValue messageDecoder raw
                in
                    case somePayload of
                        Ok payload ->
                            ( { model | chatMessages = payload :: model.chatMessages }
                            , Cmd.none
                            )

                        Err error ->
                            ( { model | chatMessages = "Failed to receive message" :: model.chatMessages }
                            , Cmd.none
                            )

            ( _, ChatHandleSendError err ) ->
                let
                    message = "Failed to Send Message"
                in
                    ( { model | chatMessages = message :: model.chatMessages }, Cmd.none )

            -- PHOENIX CONTROL MESSAGES (heartbeats, pings)
            ( _, PhoenixMsg msg ) ->
                let
                    ( phxSocket, phxCmd ) =
                        Phoenix.Socket.update msg model.phxSocket
                in
                    ( { model | phxSocket = phxSocket }
                    , Cmd.map PhoenixMsg phxCmd
                    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phxSocket PhoenixMsg


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

module App exposing (..)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Html exposing (Html, div, span, li, ul, text, form, input, textarea, button, h1, h2, h3, h4)
import Html.Events exposing (onInput, onSubmit)
import Html.Attributes exposing (value, class, style, type_, placeholder, disabled)
import Json.Encode as JE
import Json.Decode as JD
import Array exposing (Array)
import Debug


type alias Model =
    { phxSocket : Phoenix.Socket.Socket Msg
    , users : Array User
    , chatInputText : String
    , chatMessages : List ChatMessage
    , name : String
    , currentWordInputText : String
    , currentQuestionInputText : String
    , currentPoemInputText : String
    }


type alias User =
    { name : String
    , state : String
    , papers : List Paper
    }


type alias Paper =
    { word : Maybe String
    , question : Maybe String
    , poem : Maybe String
    }


type alias ChatMessage =
    { from : String
    , message : String
    }


type Msg
    = PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ChatSetMessage String
    | ChatSendMessage
    | ChatReceiveMessage JE.Value
    | ChatHandleSendError JE.Value
    | CurrentUserSetWord String
    | CurrentUserSetQuestion String
    | CurrentUserSetPoem String
    | SubmitWord
    | SubmitWordOk JE.Value
    | SubmitWordError JE.Value
    | SubmitQuestion
    | SubmitQuestionOk JE.Value
    | SubmitQuestionError JE.Value
    | SubmitPoem
    | SubmitPoemOk JE.Value
    | SubmitPoemError JE.Value
    | NameMessage JE.Value
    | StateMessage JE.Value


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
                |> Phoenix.Socket.on "name" "room:lobby" NameMessage
                |> Phoenix.Socket.on "state" "room:lobby" StateMessage
                |> Phoenix.Socket.join channel

        model =
            { phxSocket = initSocket
            , name = ""
            , chatInputText = ""
            , chatMessages = []
            , currentWordInputText = ""
            , currentQuestionInputText = ""
            , currentPoemInputText = ""
            , users = Array.fromList []
            }
    in
        ( model, Cmd.map PhoenixMsg phxCmd )


userDegrees : Int -> Int -> Int
userDegrees userCount userIndex =
    round ((toFloat userIndex) * 360.0 / (toFloat userCount))


userStyle : Int -> Int -> Html.Attribute Msg
userStyle userCount userIndex =
    style
        []



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
                [ form [ class "form word", onSubmit SubmitWord ]
                    [ case ( p.word, p.question ) of
                        ( Nothing, _ ) ->
                            input
                                [ type_ "text"
                                , class "form-control input-sm"
                                , placeholder "Word"
                                , onInput CurrentUserSetWord
                                ]
                                []

                        ( Just w, Nothing ) ->
                            text "(Word entered)"

                        -- hide the word while entering the question
                        ( Just w, Just q ) ->
                            text ("Word: " ++ w)
                    ]
                , form [ class "form question", onSubmit SubmitQuestion ]
                    [ case ( p.word, p.question ) of
                        ( Nothing, _ ) ->
                            input
                                [ type_ "text"
                                , class "form-control input-sm"
                                , disabled True
                                , placeholder "Question"
                                , onInput CurrentUserSetQuestion
                                ]
                                []

                        ( Just w, Nothing ) ->
                            input
                                [ type_ "text"
                                , class "form-control input-sm"
                                , placeholder "Question"
                                , onInput CurrentUserSetQuestion
                                ]
                                []

                        ( Just w, Just q ) ->
                            text ("Question: " ++ q)
                    ]
                , form [ class "form poem", onSubmit SubmitPoem ]
                    [ (case p.poem of
                        Just poem ->
                            div []
                                [ text "Poem:"
                                , div [ class "poem-rendered" ]
                                    [ text poem ]
                                ]

                        Nothing ->
                            textarea
                                [ class "form-control input-sm"
                                , disabled (p.word == Nothing || p.question == Nothing)
                                , placeholder "Poem"
                                , onInput CurrentUserSetPoem
                                ]
                                []
                      )
                    , button [ class "btn btn-sm btn-primary" ] [ text "Send" ]
                    ]
                ]

        Nothing ->
            div [ class "current-paper" ]
                [ text "No paper!" ]


isFinished : Maybe Paper -> Bool
isFinished paper =
    case paper of
        Nothing ->
            False
        Just p ->
            case (p.word, p.question, p.poem) of
                (Just w, Just q, Just p) -> True
                (_, _, _) -> False

viewUser : String -> Int -> Int -> User -> Html Msg
viewUser name userCount userIndex user =
    let
        currentPaper =
            List.head user.papers

        isCurrentUser =
            name == user.name

        htmlClass =
            if isCurrentUser then
                "user me"
            else
                "user other"
    in
        div [ class htmlClass, userStyle userCount userIndex ]
            [ div [ class "name" ]
                [ text user.name ]
            , div [ class "paper-area" ]
                [ div [ class "papers" ]
                    (user.papers
                        |> List.map (\p -> span [ class "paper-icon" ] [])
                        |> (List.intersperse (text " "))
                    )
                , (if isCurrentUser || (isFinished currentPaper) then
                    viewCurrentPaper isCurrentUser currentPaper
                   else
                    div [ class "current-paper" ]
                        [ text "(Hidden)" ]
                  )
                ]
            ]


view : Model -> Html Msg
view model =
    let
        viewUser_ =
            viewUser model.name (Array.length (model.users))
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
                    (model.chatMessages
                        |> List.map (\m -> li [] [ text (m.from ++ ": " ++ m.message) ])
                    )
                ]
            ]


type alias ServerState =
    { users : Array User
    }


decodeServerPaper : JD.Decoder Paper
decodeServerPaper =
    JD.map3 Paper
        (JD.maybe (JD.field "word" JD.string))
        (JD.maybe (JD.field "question" JD.string))
        (JD.maybe (JD.field "poem" JD.string))


decodeServerUser : JD.Decoder User
decodeServerUser =
    JD.map3 User
        (JD.field "name" JD.string)
        (JD.field "state" JD.string)
        (JD.field "papers" (JD.list decodeServerPaper))


decodeServerState : JD.Decoder ServerState
decodeServerState =
    JD.map ServerState
        (JD.field "users" (JD.array decodeServerUser))


decodeChatMessage : JD.Decoder ChatMessage
decodeChatMessage =
    JD.map2 ChatMessage
        (JD.field "from" JD.string)
        (JD.field "message" JD.string)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- JSON MESSAGES FROM SERVER
        StateMessage json ->
            let
                log =
                    Debug.log "resp" response

                response =
                    JD.decodeValue decodeServerState json
            in
                case response of
                    Ok state ->
                        -- TODO: update model with state msg
                        ( { model | users = state.users }, Cmd.none )

                    Err error ->
                        ( { model | chatMessages = { message = "Failed to receive state", from = "Server" } :: model.chatMessages }
                        , Cmd.none
                        )

        NameMessage json ->
            let
                response =
                    JD.decodeValue (JD.field "name" JD.string) json
            in
                case response of
                    Ok message ->
                        ( { model | name = message }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | chatMessages = { message = "Failed to receive message", from = "Server" } :: model.chatMessages }
                        , Cmd.none
                        )

        -- SUBMIT
        SubmitWord ->
            let
                payload =
                    JE.object
                        [ ( "word", JE.string model.currentWordInputText )
                        ]

                phxPush =
                    Phoenix.Push.init "set_word" "room:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk SubmitWordOk
                        |> Phoenix.Push.onError SubmitWordError

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push phxPush model.phxSocket
            in
                ( { model | currentWordInputText = "", phxSocket = phxSocket }, Cmd.map PhoenixMsg phxCmd )

        SubmitWordOk status ->
            ( model, Cmd.none )

        SubmitWordError err ->
            ( model, Cmd.none )

        SubmitQuestion ->
            let
                payload =
                    JE.object
                        [ ( "question", JE.string model.currentQuestionInputText )
                        ]

                phxPush =
                    Phoenix.Push.init "set_question" "room:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk SubmitQuestionOk
                        |> Phoenix.Push.onError SubmitQuestionError

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push phxPush model.phxSocket
            in
                ( { model | currentQuestionInputText = "", phxSocket = phxSocket }, Cmd.map PhoenixMsg phxCmd )

        SubmitQuestionOk status ->
            ( model, Cmd.none )

        SubmitQuestionError err ->
            ( model, Cmd.none )

        SubmitPoem ->
            let
                payload =
                    JE.object
                        [ ( "poem", JE.string model.currentPoemInputText )
                        ]

                phxPush =
                    Phoenix.Push.init "set_poem" "room:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk SubmitPoemOk
                        |> Phoenix.Push.onError SubmitPoemError

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push phxPush model.phxSocket
            in
                ( { model | currentPoemInputText = "", phxSocket = phxSocket }, Cmd.map PhoenixMsg phxCmd )

        SubmitPoemOk status ->
            ( model, Cmd.none )

        SubmitPoemError err ->
            ( model, Cmd.none )

        -- USER TYPING
        CurrentUserSetWord word ->
            ( { model | currentWordInputText = word }, Cmd.none )

        CurrentUserSetQuestion question ->
            ( { model | currentQuestionInputText = question }, Cmd.none )

        CurrentUserSetPoem poem ->
            ( { model | currentPoemInputText = poem }, Cmd.none )

        -- CHAT
        ChatSetMessage message ->
            ( { model | chatInputText = message }, Cmd.none )

        ChatSendMessage ->
            let
                payload =
                    JE.object
                        [ ( "from", JE.string model.name )
                        , ( "message", JE.string model.chatInputText )
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

        ChatReceiveMessage json ->
            let
                somePayload =
                    JD.decodeValue decodeChatMessage json
            in
                case somePayload of
                    Ok payload ->
                        ( { model | chatMessages = payload :: model.chatMessages }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | chatMessages = { message = "Failed to receive message", from = "Server" } :: model.chatMessages }
                        , Cmd.none
                        )

        ChatHandleSendError err ->
            let
                message =
                    { message = "Failed to Send Message", from = "Server" }
            in
                ( { model | chatMessages = message :: model.chatMessages }, Cmd.none )

        -- PHOENIX CONTROL MESSAGES (heartbeats, pings)
        PhoenixMsg msg ->
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

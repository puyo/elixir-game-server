module Poetry exposing (..)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Html exposing (Html, div, span, li, ul, text, strong, form, input, button, h1, h2, h3, h4, p)
import Html.Events exposing (onInput, onSubmit, onClick, on)
import Html.Attributes exposing (value, class, style, type_, placeholder, disabled, contenteditable, attribute)
import Json.Encode as JE
import Json.Decode as JD
import Array exposing (Array)
import Debug
import Navigation
import UrlParser
import Regex
import Dict exposing (Dict)


type alias Model =
    { phxSocket : Phoenix.Socket.Socket Msg
    , name : String
    , chatInputText : String
    , currentWordInputText : String
    , currentQuestionInputText : String
    , currentPoemInputText : String
    , game : GameState
    , room : RoomState
    }


type alias RoomState =
    { messages : List ChatMessage
    , members : Dict String ChatMember
    }


type alias ChatMember =
    { name : String
    }


type alias ChatMessage =
    { from : String
    , message : String
    }


type alias Player =
    { name : String
    , papers : List Paper
    }


type alias Paper =
    { word : Maybe String
    , question : Maybe String
    , poem : Maybe String
    }


type alias ServerState =
    { game : GameState
    , room : RoomState
    }


type alias GameState =
    { players : Array Player
    }


type Msg
    = PhoenixMsg (Phoenix.Socket.Msg Msg)
    | LocationChange Navigation.Location
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
    | SavePoem String
    | SubmitPoemOk JE.Value
    | SubmitPoemError JE.Value
    | NameMessage JE.Value
    | StateMessage JE.Value



-- ----------------------------------------------------------------------


type Route
    = HomeRoute
    | NotFoundRoute


matchers : UrlParser.Parser (Route -> a) a
matchers =
    UrlParser.oneOf
        [ UrlParser.map HomeRoute UrlParser.top
        ]


parseLocation : Navigation.Location -> Route
parseLocation location =
    case (UrlParser.parsePath matchers location) of
        Just route ->
            route

        Nothing ->
            NotFoundRoute


wsOrigin : Navigation.Location -> String
wsOrigin location =
    Regex.replace
        (Regex.AtMost 1)
        (Regex.regex "^http")
        (\_ -> "ws")
        location.origin


websocketServerAddress : Navigation.Location -> String
websocketServerAddress location =
    [ wsOrigin location
    , "/socket/websocket"
    ]
        |> String.join ""



-- ----------------------------------------------------------------------


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        currentRoute =
            parseLocation location

        socketServerAddress =
            websocketServerAddress location

        channel =
            Phoenix.Channel.init "room:lobby"

        ( initSocket, phxCmd ) =
            Phoenix.Socket.init socketServerAddress
                |> Phoenix.Socket.withDebug
                |> Phoenix.Socket.on "shout" "room:lobby" ChatReceiveMessage
                |> Phoenix.Socket.on "name" "room:lobby" NameMessage
                |> Phoenix.Socket.on "state" "room:lobby" StateMessage
                |> Phoenix.Socket.join channel

        model =
            { phxSocket = initSocket
            , name = ""
            , chatInputText = ""
            , currentWordInputText = ""
            , currentQuestionInputText = ""
            , currentPoemInputText = ""
            , game =
                { players = Array.empty
                }
            , room =
                { members = Dict.empty
                , messages = []
                }
            }
    in
        ( model, Cmd.map PhoenixMsg phxCmd )



-- ----------------------------------------------------------------------


viewCurrentPaper : Bool -> Maybe Paper -> Html Msg
viewCurrentPaper isCurrent paper =
    case paper of
        Just p ->
            div [ class "paper" ]
                [ form [ onSubmit SubmitWord ]
                    [ case ( p.word, p.question ) of
                        ( Nothing, _ ) ->
                            input
                                [ type_ "text"
                                , placeholder "Word"
                                , onInput CurrentUserSetWord
                                ]
                                []

                        ( Just w, Nothing ) ->
                            text "(Word entered)"

                        -- hide the word while entering the question
                        ( Just w, Just q ) ->
                            span []
                                [ strong [] [ text "Word: " ]
                                , text w
                                ]
                    ]
                , form [ onSubmit SubmitQuestion ]
                    [ case ( p.word, p.question ) of
                        ( Nothing, _ ) ->
                            div [] []

                        -- input
                        --     [ type_ "text"
                        --     , disabled True
                        --     , placeholder "Question"
                        --     , onInput CurrentUserSetQuestion
                        --     ]
                        --     []
                        ( Just w, Nothing ) ->
                            input
                                [ type_ "text"
                                , placeholder "Question"
                                , onInput CurrentUserSetQuestion
                                ]
                                []

                        ( Just w, Just q ) ->
                            span []
                                [ strong [] [ text "Question: " ]
                                , text q
                                ]
                    ]
                , viewPoem p
                ]

        Nothing ->
            div [ class "current-paper" ]
                [ text "No paper!" ]


viewPoem : Paper -> Html Msg
viewPoem paper =
    let
        readyToInput =
            paper.word /= Nothing && paper.question /= Nothing
    in
        (case paper.poem of
            Just poem ->
                div []
                    [ strong [] [ text "Poem:" ]
                    , div [ class "poem-rendered" ]
                        [ text poem ]
                    ]

            Nothing ->
                form [ onSubmit SubmitPoem ]
                    [ div
                        [ class "poem"
                        , contenteditable readyToInput
                        , attribute "placeholder" "Poem"
                        , on "input"
                            (JD.map
                                SavePoem
                                targetTextContent
                            )
                        ]
                        []
                    , (if readyToInput then
                        button
                            [ class "btn btn-sm btn-default btn-reveal"
                            ]
                            [ text "Reveal" ]
                       else
                        span [] []
                      )
                    ]
        )


targetTextContent : JD.Decoder String
targetTextContent =
    JD.at [ "target", "innerText" ] JD.string


isFinished : Maybe Paper -> Bool
isFinished paper =
    case paper of
        Nothing ->
            False

        Just p ->
            case ( p.word, p.question, p.poem ) of
                ( Just w, Just q, Just p ) ->
                    True

                ( _, _, _ ) ->
                    False


viewPlayer : String -> Int -> Int -> Player -> Html Msg
viewPlayer name userCount userIndex user =
    let
        currentPaper =
            List.head user.papers

        isCurrentUser =
            name == user.name

        noPaper =
            List.length (user.papers) == 0

        htmlClass =
            (String.join " "
                [ "player"
                , (if noPaper then
                    "no-paper"
                   else
                    "has-paper"
                  )
                , (if isCurrentUser then
                    "me"
                   else
                    "other"
                  )
                ]
            )
    in
        div [ class htmlClass ]
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
                    div [ class "status" ]
                        [ text "(Hidden)" ]
                  )
                ]
            ]


viewChat : Model -> Html Msg
viewChat model =
    div [ class "chat" ]
        [ form [ class "form", onSubmit ChatSendMessage ]
            [ input
                [ type_ "text"
                , class "form-control"
                , onInput ChatSetMessage
                , value model.chatInputText
                ]
                []
            , div [ class "log" ]
                (model.room.messages
                    |> List.map (\m -> p [] [ text (m.from ++ ": " ++ m.message) ])
                )
            ]
        , div [ class "members" ]
            [ ul []
                (List.map viewMemberItem (Dict.values model.room.members))
            ]
        ]


viewMemberItem : ChatMember -> Html Msg
viewMemberItem member =
    li [] [ text member.name ]


viewGame : Model -> Html Msg
viewGame model =
    if (Array.length model.game.players) < 3 then
        text "The game will start when there are 3 players"
    else
        let
            viewPlayer_ =
                viewPlayer model.name (Array.length model.game.players)
        in
            div [ class "game" ]
                [ div [ class "players" ]
                    (model.game.players
                        |> Array.indexedMap (viewPlayer_)
                        |> Array.toList
                        |> List.intersperse (text " ")
                    )
                ]


view : Model -> Html Msg
view model =
    div []
        [ viewGame model
        , viewChat model
        ]



-- ----------------------------------------------------------------------


decodeServerPaper : JD.Decoder Paper
decodeServerPaper =
    JD.map3 Paper
        (JD.maybe (JD.field "word" JD.string))
        (JD.maybe (JD.field "question" JD.string))
        (JD.maybe (JD.field "poem" JD.string))


decodeServerPlayer : JD.Decoder Player
decodeServerPlayer =
    JD.map2 Player
        (JD.field "name" JD.string)
        (JD.field "papers" (JD.list decodeServerPaper))


decodeGameState : JD.Decoder GameState
decodeGameState =
    JD.map GameState
        (JD.field "players" (JD.array decodeServerPlayer))


decodeServerState : JD.Decoder ServerState
decodeServerState =
    JD.map2 ServerState
        (JD.field "game" decodeGameState)
        (JD.field "room" decodeRoomState)


decodeRoomState : JD.Decoder RoomState
decodeRoomState =
    JD.map2 RoomState
        (JD.field "messages" decodeChatMessages)
        (JD.field "members" decodeChatMembers)


decodeChatMembers : JD.Decoder (Dict String ChatMember)
decodeChatMembers =
    JD.dict decodeChatMember


decodeChatMember : JD.Decoder ChatMember
decodeChatMember =
    JD.map ChatMember
        (JD.field "name" JD.string)


decodeChatMessages : JD.Decoder (List ChatMessage)
decodeChatMessages =
    JD.list decodeChatMessage


decodeChatMessage : JD.Decoder ChatMessage
decodeChatMessage =
    JD.map2 ChatMessage
        (JD.field "from" JD.string)
        (JD.field "message" JD.string)



-- ----------------------------------------------------------------------


appendChatMessage : Model -> String -> String -> Model
appendChatMessage model from message =
    let
        newMessages =
            { message = message, from = from } :: model.room.messages

        oldChat =
            model.room

        newChat =
            { oldChat | messages = newMessages }
    in
        { model | room = newChat }

updateRoom : Model -> RoomState -> Model
updateRoom model chatState =
    let
        room = model.room
        newRoom = { room | members = chatState.members }
    in
        { model | room = newRoom }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- JSON MESSAGES FROM SERVER
        StateMessage json ->
            let
                log =
                    Debug.log "state update" response

                response =
                    JD.decodeValue decodeServerState json
            in
                case response of
                    Ok state ->
                        ( (updateRoom { model | game = state.game } state.room), Cmd.none )

                    Err error ->
                        ( appendChatMessage model "Server" "Failed to receive state", Cmd.none )

        LocationChange location ->
            ( model, Cmd.none )

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
                        ( appendChatMessage model "Server" "Failed to receive name message", Cmd.none )

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

        SavePoem str ->
            ( { model | currentPoemInputText = str }, Cmd.none )

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
                        ( appendChatMessage model payload.from payload.message, Cmd.none )

                    Err error ->
                        ( appendChatMessage model "Server" "Failed to receive chat message", Cmd.none )

        ChatHandleSendError err ->
            ( appendChatMessage model "Server" "Failed to send chat message", Cmd.none )

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
    Navigation.program LocationChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

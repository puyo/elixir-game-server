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


type alias ChatMessagePayload =
    { message : String
    }


type alias ServerState =
    { users : Array User
    }



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
            , chatMessages = []
            , currentWordInputText = ""
            , currentQuestionInputText = ""
            , currentPoemInputText = ""
            , users = Array.fromList []
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
        readyToInput = paper.word /= Nothing && paper.question /= Nothing
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
                                    , on "input" (
                                                   JD.map
                                                       SavePoem
                                                       targetTextContent
                                                  )

                                    ]
                                    []
                                , (if readyToInput then
                                    button [
                                         class "btn btn-sm btn-default btn-reveal"
                                        ]
                                       [ text "Reveal" ]
                                   else
                                    span [] []
                                  )
                                ]
                      )


targetTextContent : JD.Decoder String
targetTextContent =
  JD.at ["target", "innerText"] JD.string


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


viewUser : String -> Int -> Int -> User -> Html Msg
viewUser name userCount userIndex user =
    let
        currentPaper =
            List.head user.papers

        isCurrentUser =
            name == user.name

        noPaper =
            List.length (user.papers) == 0

        htmlClass =
            (String.join " "
                [ "user"
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
                (model.chatMessages
                    |> List.map (\m -> p [] [ text (m.from ++ ": " ++ m.message) ])
                )
            ]
        , div [ class "members" ]
            [ ul []
                (Array.toList (Array.map viewMemberItem model.users))
            ]
        ]

viewMemberItem : User -> Html Msg
viewMemberItem user =
    li [] [ text user.name ]

view : Model -> Html Msg
view model =
    let
        viewUser_ =
            viewUser model.name (Array.length (model.users))
    in
        div []
            [ div [ class "game" ]
                [ div [ class "users" ]
                    (model.users
                        |> Array.indexedMap (viewUser_)
                        |> Array.toList
                        |> List.intersperse (text " ")
                    )
                ]
            , viewChat model
            ]



-- ----------------------------------------------------------------------


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



-- ----------------------------------------------------------------------

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- JSON MESSAGES FROM SERVER
        StateMessage json ->
            let
                log =
                    Debug.log "response" response

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

        SavePoem str ->
            let
                log = Debug.log "SAVING POEM" str
            in
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
    Navigation.program LocationChange
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

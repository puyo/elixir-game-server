module App exposing (..)

import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Html exposing (Html, div, li, ul, text, form, input, button)
import Html.Events exposing (onInput, onSubmit)
import Html.Attributes exposing (value)
import Json.Encode as JsEncode
import Json.Decode as JsDecode


type alias ChatMessagePayload =
    { message : String
    }


type alias Model =
    { phxSocket : Phoenix.Socket.Socket Msg
    , chat :
        { inputText : String
        , messages : List String
        }
    }


type Msg
    = PhoenixMsg (Phoenix.Socket.Msg Msg)
    | SetMessage String
    | SendMessage
    | ReceiveChatMessage JsEncode.Value
    | HandleSendError JsEncode.Value


init : ( Model, Cmd Msg )
init =
    let
        channel =
            Phoenix.Channel.init "room:lobby"

        ( initSocket, phxCmd ) =
            Phoenix.Socket.init "ws://localhost:4000/socket/websocket"
                |> Phoenix.Socket.withDebug
                |> Phoenix.Socket.on "shout" "room:lobby" ReceiveChatMessage
                |> Phoenix.Socket.join channel

        model =
            { phxSocket = initSocket
            , chat =
                { inputText = ""
                , messages = []
                }
            }
    in
        ( model, Cmd.map PhoenixMsg phxCmd )


chatDrawMessage : String -> Html Msg
chatDrawMessage message =
    li []
        [ text message
        ]


chatDrawMessages : List String -> List (Html Msg)
chatDrawMessages chatMessages =
    chatMessages |> List.map chatDrawMessage


view : Model -> Html Msg
view model =
    div []
        [ ul [] (model.chat.messages |> chatDrawMessages)
        , form [ onSubmit SendMessage ]
            [ input
                [ onInput SetMessage
                , value model.chat.inputText
                ]
                []
            , button []
                [ text "Submit"
                ]
            ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )

        SetMessage message ->
            let
                { chat } =
                    model
            in
                ( { model | chat = { chat | inputText = message } }, Cmd.none )

        SendMessage ->
            let
                payload =
                    JsEncode.object
                        [ ( "message", JsEncode.string model.chat.inputText )
                        ]

                phxPush =
                    Phoenix.Push.init "shout" "room:lobby"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk ReceiveChatMessage
                        |> Phoenix.Push.onError HandleSendError

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push phxPush model.phxSocket

                { chat } =
                    model
            in
                ( { model
                    | chat = { chat | inputText = "" }
                    , phxSocket = phxSocket
                  }
                , Cmd.map PhoenixMsg phxCmd
                )

        ReceiveChatMessage raw ->
            let
                messageDecoder =
                    JsDecode.field "message" JsDecode.string

                somePayload =
                    JsDecode.decodeValue messageDecoder raw

                { chat } =
                    model
            in
                case somePayload of
                    Ok payload ->
                        ( { model | chat = { chat | messages = payload :: model.chat.messages } }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | chat = { chat | messages = "Failed to receive message" :: model.chat.messages } }
                        , Cmd.none
                        )

        HandleSendError err ->
            let
                message =
                    "Failed to Send Message"

                { chat } =
                    model
            in
                ( { model | chat = { chat | messages = message :: model.chat.messages } }, Cmd.none )


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

module WebSocket exposing
    ( WebSocket, Whole, Streamed, Message(..), StreamedMessage(..)
    , readable, readableStreamed, writable, sendText, sendBinary
    , protocol, compression, Negotiated, localEndpoint, remoteEndpoint
    , onMessage, onClose, ping, close, awaitClose
    , CloseCode(..), CloseInfo, Heartbeat
    , ConnectOptions, ClientCompression, defaultConnectOptions, connect, connectStreamed
    , Upgrade, receiveUpgrade, upgradeTarget, upgradeHeaders, upgradeProtocols, upgradeOrigin
    , upgradeRemote, AcceptOptions, ServerCompression, defaultAcceptOptions
    , accept, acceptStreamed, reject
    , errorIsHandshakeFailed, errorHandshakeStatus
    )

{-| WebSockets (RFC 6455): message-based, full-duplex connections, as a client and as a server.

A client [`connect`](#connect)s to a `ws://` or `wss://` URL. A server receives an opening request
as an [`Upgrade`](#Upgrade), either on a [`Socket.Connection`](Socket#Connection) it accepted
([`receiveUpgrade`](#receiveUpgrade)) or from an HTTP server
([`Http.Server.upgradeRequest`](Http-Server#upgradeRequest)), and answers it with
[`accept`](#accept) or [`reject`](#reject).

    WebSocket.connect (WebSocket.defaultConnectOptions "wss://example.com/chat")
        |> Task.andThen
            (\ws ->
                Stream.write (WebSocket.Text "hello") (WebSocket.writable ws)
                    |> Task.mapError (\_ -> ...)
            )

Several modules define functions such as `close`, `accept` and `readable`, so import this module
qualified:

    import WebSocket

**Messages.** Text and binary [`Message`](#Message)s arrive in order on [`readable`](#readable),
or through [`onMessage`](#onMessage); write them to [`writable`](#writable). A message is always
delivered whole, up to `maxMessageSize`. To send or receive messages too large to hold in memory,
use the streamed mode ([`connectStreamed`](#connectStreamed), [`acceptStreamed`](#acceptStreamed)):
then every message is a stream of its own ([`StreamedMessage`](#StreamedMessage)). A streamed
message must be read to the end (`Closed`) or cancelled: the connection delivers nothing else until
it is, so a message that is dropped unread stalls the connection. [`sendText`](#sendText) and
[`sendBinary`](#sendBinary) send a message from a stream in either mode.

**Liveness.** Both ends send a ping every 30 seconds by default and close the connection when the
pong does not come within 30 seconds ([`Heartbeat`](#Heartbeat)); pings from the peer are always
answered.

**Compression.** permessage-deflate (RFC 7692) is offered by clients and accepted by servers by
default, without context takeover: each message is compressed on its own, which keeps the memory per
connection small (the compression state is reset after every message). Context takeover
(`contextTakeover = True` on both sides) compresses better but keeps about 300 KB of compression
state per connection. Messages shorter than `threshold` are sent uncompressed; streamed messages are
always compressed. [`compression`](#compression) tells what was agreed. Do not mix secrets and
attacker-controlled data in one compressed connection (CRIME/BREACH).

**Differences from browsers.** A client opens one connection per [`connect`](#connect), even to a
host it is already connecting to (RFC 6455 §4.1 asks clients to queue them); redirects and proxies
are not followed.


## Connections

@docs WebSocket, Whole, Streamed, Message, StreamedMessage
@docs readable, readableStreamed, writable, sendText, sendBinary
@docs protocol, compression, Negotiated, localEndpoint, remoteEndpoint


## Events and closing

@docs onMessage, onClose, ping, close, awaitClose
@docs CloseCode, CloseInfo, Heartbeat


## Clients

@docs ConnectOptions, ClientCompression, defaultConnectOptions, connect, connectStreamed


## Servers

@docs Upgrade, receiveUpgrade, upgradeTarget, upgradeHeaders, upgradeProtocols, upgradeOrigin
@docs upgradeRemote, AcceptOptions, ServerCompression, defaultAcceptOptions
@docs accept, acceptStreamed, reject


## Errors

@docs errorIsHandshakeFailed, errorHandshakeStatus

-}

import Bytes exposing (Bytes)
import Bytes.Encode
import Dict exposing (Dict)
import Platform
import Process
import Socket
import Socket.Address as Address exposing (Endpoint)
import Socket.Tls
import Stream
import Task exposing (Task)


{-| An open WebSocket connection. `mode` is [`Whole`](#Whole) when every message arrives in one
piece, [`Streamed`](#Streamed) when every message is a stream.
-}
type WebSocket mode
    = WebSocket


{-| The mode of a connection whose messages arrive whole (no values: only used in types).
-}
type Whole
    = Whole


{-| The mode of a connection whose messages arrive as streams (no values: only used in types).
-}
type Streamed
    = Streamed


{-| A message: UTF-8 text or binary data. Both kinds can be sent and received on one connection,
in any order.
-}
type Message
    = Text String
    | Binary Bytes


{-| A message received in the streamed mode: its content arrives as a stream, chunk by chunk, as
the peer sends it (decompressed, and for text checked as UTF-8: invalid text fails the connection
with `InvalidData`). A text message's chunks are always whole characters.

Read it to `Closed` (or cancel it with `Stream.cancelReadable`, which skips the rest of the
message) before the next message can arrive. When the connection closes or fails in the middle of
a message, its stream fails with `Cancelled`.

-}
type StreamedMessage
    = StreamedText (Stream.Readable String)
    | StreamedBinary (Stream.Readable Bytes)


{-| The messages the peer sends, in order.

The readable is `Closed` once the connection closed cleanly (both sides exchanged Close frames);
when it ends otherwise, reads fail with `Cancelled` and a reason such as
`"ERR_WS_PROTOCOL: <details>"`. Use [`awaitClose`](#awaitClose) for the close code and reason.

While the connection has an [`onMessage`](#onMessage) subscription, messages go to the
subscription instead and `Stream.read` fails with `Locked`.

-}
readable : WebSocket Whole -> Stream.Readable Message
readable =
    Debug.todo "Implement System API"


{-| The messages of a streamed connection, each a [`StreamedMessage`](#StreamedMessage). Closing
and errors behave as for [`readable`](#readable).

This was `streamedReadable`.

-}
readableStreamed : WebSocket Streamed -> Stream.Readable StreamedMessage
readableStreamed =
    Debug.todo "Implement System API"


{-| Send messages: each value written is one message. Closing the writable with
`Stream.closeWritable` closes the connection with `Normal` and no reason.
-}
writable : WebSocket mode -> Stream.Writable Message
writable =
    Debug.todo "Implement System API"


{-| Send one text message whose content is read from a stream, as it arrives: for messages too
large to build in memory. The task completes when the stream ended and the message was sent.

Messages written to [`writable`](#writable) meanwhile, and other streamed messages, are sent after
it (pings and pongs are not held up). An empty stream sends an empty message. Each chunk is sent
as it arrives (compressed, when the connection uses compression), so the peer receives the message
in pieces it puts back together, unless it reads it streamed too.

If the stream fails after part of the message was sent, the message cannot be completed: the
connection fails with `InternalError`. A stream that fails before anything was sent just sends
nothing.

-}
sendText : Stream.Readable String -> WebSocket mode -> Task Socket.Error ()
sendText =
    Debug.todo "Implement System API"


{-| Send one binary message whose content is read from a stream; as [`sendText`](#sendText).
-}
sendBinary : Stream.Readable Bytes -> WebSocket mode -> Task Socket.Error ()
sendBinary =
    Debug.todo "Implement System API"


{-| The subprotocol the handshake agreed on (`Sec-WebSocket-Protocol`), if any.
-}
protocol : WebSocket mode -> Maybe String
protocol =
    Debug.todo "Implement System API"


{-| The permessage-deflate parameters the handshake agreed on, or `Nothing` when messages are
not compressed.
-}
compression : WebSocket mode -> Maybe Negotiated
compression =
    Debug.todo "Implement System API"


{-| Negotiated permessage-deflate parameters (RFC 7692): whether each side resets its compression
state after every message (no context takeover), and each side's LZ77 window size in bits (8 to
15).
-}
type alias Negotiated =
    { serverNoContextTakeover : Bool
    , clientNoContextTakeover : Bool
    , serverMaxWindowBits : Int
    , clientMaxWindowBits : Int
    }


{-| This end of the connection.
-}
localEndpoint : WebSocket mode -> Endpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| The peer's end of the connection.
-}
remoteEndpoint : WebSocket mode -> Endpoint
remoteEndpoint =
    Debug.todo "Implement System API"


{-| Subscribe to the messages of a connection.

While a connection has subscribers, every message goes to all of them, in subscription order, and
is not left on [`readable`](#readable) (which then fails `Locked`). Without subscribers, messages
wait on the readable. A subscription made while a `Stream.read` is waiting starts once that read
completes.

A connection with an `onMessage` subscription keeps the program running.

-}
onMessage : WebSocket Whole -> (Message -> msg) -> Sub msg
onMessage =
    Debug.todo "Implement System API"


{-| Subscribe to the end of a connection: the [`CloseInfo`](#CloseInfo) arrives once. When the
connection ended before anyone subscribed, the first subscription receives it.
-}
onClose : WebSocket mode -> (CloseInfo -> msg) -> Sub msg
onClose =
    Debug.todo "Implement System API"


{-| Send a ping and wait for its pong: the round trip time in milliseconds. Fails with
`ECANCELED` when the connection closes first and `ETIMEDOUT` after the heartbeat timeout.
-}
ping : WebSocket mode -> Task Socket.Error Int
ping =
    Debug.todo "Implement System API"


{-| Start the closing handshake with a code and a reason. The reason is cut to 123 bytes (of
UTF-8, at a character boundary). Messages that arrive afterwards are dropped; the connection is
gone once the peer answered (or after 30 seconds).

Fails with `EINVAL` for a code that cannot be sent: only 1000–1003, 1007–1014 and 3000–4999 can
(`NoStatus` and `Abnormal` describe a received close only). Closing twice is fine.

-}
close : CloseCode -> String -> WebSocket mode -> Task Socket.Error ()
close =
    Debug.todo "Implement System API"


{-| Wait until the connection is gone, then get how it ended. A connection that ends without a
Close frame from the peer reports `Abnormal` and `clean = False`.

This was `closed`.

-}
awaitClose : WebSocket mode -> Task x CloseInfo
awaitClose =
    Debug.todo "Implement System API"


{-| The close codes of RFC 6455 §7.4.

  - `Normal` (1000), `GoingAway` (1001), `ProtocolError` (1002), `UnsupportedData` (1003),
    `InvalidData` (1007), `PolicyViolation` (1008), `MessageTooBig` (1009),
    `MandatoryExtension` (1010), `InternalError` (1011);
  - `NoStatus` (1005): the peer's Close frame had no code; `Abnormal` (1006): the connection
    ended without a Close frame. These two are never sent.
  - `Other n`: any other code, for example an application's code from 4000 to 4999.

-}
type CloseCode
    = Normal
    | GoingAway
    | ProtocolError
    | UnsupportedData
    | NoStatus
    | Abnormal
    | InvalidData
    | PolicyViolation
    | MessageTooBig
    | MandatoryExtension
    | InternalError
    | Other Int


{-| How a connection ended: the close code and reason (from the peer's Close frame, or ours when
we failed the connection), and whether both sides exchanged Close frames.
-}
type alias CloseInfo =
    { code : CloseCode
    , reason : String
    , clean : Bool
    }


{-| Liveness checking, in milliseconds: when nothing arrived for `interval`, send a ping; when
still nothing arrived after another `timeout`, the connection is closed (with `GoingAway`) and
reported `Abnormal`. Any data received counts, not only pongs.
-}
type alias Heartbeat =
    { interval : Int
    , timeout : Int
    }


{-| How to connect.

  - `url`: `ws://host[:port]/path?query` or `wss://...` (TLS). IPv6 addresses are bracketed;
    a zone is written `%25` (`ws://[fe80::1%25eth0]/`).
  - `headers`: extra request headers, such as `Origin` or `Authorization`. Headers the handshake
    sets itself (`Host`, `Upgrade`, `Connection`, `Sec-WebSocket-*`) are not allowed.
  - `protocols`: the subprotocols to offer, in order of preference ([`protocol`](#protocol) tells
    which one the server chose).
  - `verification`: which server certificates `wss` accepts.
  - `timeout`: the time allowed for the whole handshake (connecting, TLS and the HTTP exchange; the
    name lookup comes first and is not limited), in milliseconds.
  - `maxMessageSize`: the largest message accepted, in bytes (after decompression); a larger one
    closes the connection with `MessageTooBig`. Streamed connections do not limit messages.
  - `heartbeat`: see [`Heartbeat`](#Heartbeat); `Nothing` turns it off.
  - `compression`: the permessage-deflate offer, or `Nothing` to offer none.
  - `http2`: try a WebSocket over HTTP/2 (RFC 8441) first, for `wss` URLs (`ws` always uses
    HTTP/1.1): the TLS handshake offers `h2`; when the server chooses it and its settings allow
    WebSockets (`SETTINGS_ENABLE_CONNECT_PROTOCOL`), the WebSocket runs on one stream of an HTTP/2
    connection of its own. A server that chooses HTTP/1.1 gets the usual HTTP/1.1 handshake on the
    same connection; an HTTP/2 server without WebSockets is left (`GOAWAY`) and dialed again over
    HTTP/1.1, within the same `timeout`. Frames, masking and the close handshake are the same either
    way.

-}
type alias ConnectOptions =
    { url : String
    , headers : List ( String, String )
    , protocols : List String
    , verification : Socket.Tls.Verification
    , timeout : Maybe Int
    , maxMessageSize : Int
    , heartbeat : Maybe Heartbeat
    , compression : Maybe ClientCompression
    , http2 : Bool
    }


{-| What a client offers for permessage-deflate.

  - `clientMaxWindowBits`: `Just Nothing` tells the server it may limit our window
    (`client_max_window_bits` without a value); `Just (Just n)` limits our window to `n` bits
    (8 to 15); `Nothing` says nothing.
  - `serverMaxWindowBits`: ask the server to use at most this window.
  - `contextTakeover`: `False` (the default) offers `client_no_context_takeover` and
    `server_no_context_takeover`: every message is compressed on its own.
  - `threshold`: messages shorter than this many bytes are sent uncompressed.

-}
type alias ClientCompression =
    { clientMaxWindowBits : Maybe (Maybe Int)
    , serverMaxWindowBits : Maybe Int
    , contextTakeover : Bool
    , threshold : Int
    }


{-| Options for a URL: no extra headers or protocols, the system's certificate authorities, a 30
second timeout, messages up to 16 MiB, the default heartbeat (30 s / 30 s), permessage-deflate
without context takeover (threshold 64 bytes), and HTTP/1.1.
-}
defaultConnectOptions : String -> ConnectOptions
defaultConnectOptions =
    Debug.todo "Implement System API"


{-| Open a WebSocket connection. The host name is looked up first, then each of its addresses is
tried in order.

Fails with `EINVAL` for an invalid URL or header, the usual socket and TLS errors, and
`ERR_WS_HANDSHAKE` ([`errorIsHandshakeFailed`](#errorIsHandshakeFailed)) when the server does not
accept the connection: [`errorHandshakeStatus`](#errorHandshakeStatus) then tells the HTTP status it
answered, if any.

-}
connect : ConnectOptions -> Task Socket.Error (WebSocket Whole)
connect =
    Debug.todo "Implement System API"


{-| Open a WebSocket connection in the streamed mode; as [`connect`](#connect).
-}
connectStreamed : ConnectOptions -> Task Socket.Error (WebSocket Streamed)
connectStreamed =
    Debug.todo "Implement System API"


{-| An opening request from a client, received but not yet answered. Answer it with
[`accept`](#accept), [`acceptStreamed`](#acceptStreamed) or [`reject`](#reject).
-}
type Upgrade
    = Upgrade


{-| Read an opening request on a connection a server accepted (`Socket.Tcp.listen`,
`Socket.Tls.listen`). The connection must not have a pending read or write; from then on it belongs
to the WebSocket, and its streams fail with `Cancelled "upgraded to WebSocket"`.

Fails with `ETIMEDOUT` when the request does not arrive within 30 seconds, with `EBUSY` while a
read, write or close is in progress on the connection's streams, and with `ERR_WS_HANDSHAKE` when
the client sends something else than an HTTP request (it is answered 400 and the connection
closed). Bytes the client sent right behind its request (an early first frame) are kept for the
WebSocket.

This was `upgradeRequest`.

-}
receiveUpgrade : Socket.Connection -> Task Socket.Error Upgrade
receiveUpgrade =
    Debug.todo "Implement System API"


{-| The request target: the path and the query, for example `"/chat?room=1"`.
-}
upgradeTarget : Upgrade -> String
upgradeTarget =
    Debug.todo "Implement System API"


{-| The request headers in order, with lower-case names; a repeated header appears once per
occurrence.
-}
upgradeHeaders : Upgrade -> List ( String, String )
upgradeHeaders =
    Debug.todo "Implement System API"


{-| The subprotocols the client offers, in its order of preference.
-}
upgradeProtocols : Upgrade -> List String
upgradeProtocols =
    Debug.todo "Implement System API"


{-| The `Origin` header, sent by browsers: check it to refuse pages from other sites.
-}
upgradeOrigin : Upgrade -> Maybe String
upgradeOrigin =
    Debug.todo "Implement System API"


{-| The client's end of the connection.
-}
upgradeRemote : Upgrade -> Endpoint
upgradeRemote =
    Debug.todo "Implement System API"


{-| How to accept a connection.

  - `protocol`: the subprotocol to use; it must be one the client offers
    ([`upgradeProtocols`](#upgradeProtocols)).
  - `headers`: extra response headers.
  - `maxMessageSize`, `heartbeat`: as in [`ConnectOptions`](#ConnectOptions).
  - `compression`: the server's permessage-deflate policy, or `Nothing` to decline every offer.

The opening request itself is read by [`receiveUpgrade`](#receiveUpgrade), within 30 seconds.

-}
type alias AcceptOptions =
    { protocol : Maybe String
    , headers : List ( String, String )
    , maxMessageSize : Int
    , heartbeat : Maybe Heartbeat
    , compression : Maybe ServerCompression
    }


{-| A server's permessage-deflate policy.

  - `maxWindowBits`: the largest window the server compresses with (8 to 15).
  - `contextTakeover`: `False` (the default) answers with `server_no_context_takeover` and
    `client_no_context_takeover`: every message is compressed on its own. `True` allows context
    takeover in each direction the client does not restrict.
  - `threshold`: messages shorter than this many bytes are sent uncompressed.

-}
type alias ServerCompression =
    { maxWindowBits : Int
    , contextTakeover : Bool
    , threshold : Int
    }


{-| No protocol, no extra headers, messages up to 16 MiB, the default heartbeat (30 s / 30 s), and
permessage-deflate accepted without context takeover (15 bits, threshold 64 bytes).
-}
defaultAcceptOptions : AcceptOptions
defaultAcceptOptions =
    Debug.todo "Implement System API"


{-| Accept an opening request: check it (RFC 6455 §4.2.1), agree on the protocol and the
compression, and answer it.

An invalid request is answered with 400 (or 426 for an unsupported WebSocket version) and the task
fails with `ERR_WS_HANDSHAKE`. A `protocol` the client did not offer, or an invalid header, fails
with `EINVAL` (the request stays unanswered).

-}
accept : AcceptOptions -> Upgrade -> Task Socket.Error (WebSocket Whole)
accept =
    Debug.todo "Implement System API"


{-| Accept an opening request in the streamed mode; as [`accept`](#accept).
-}
acceptStreamed : AcceptOptions -> Upgrade -> Task Socket.Error (WebSocket Streamed)
acceptStreamed =
    Debug.todo "Implement System API"


{-| Refuse an opening request with an HTTP status, headers and a body, for example
`reject 403 [] "Forbidden"`. The connection is closed afterwards.
-}
reject : Int -> List ( String, String ) -> String -> Upgrade -> Task x ()
reject =
    Debug.todo "Implement System API"


{-| `True` if the opening handshake failed (`ERR_WS_HANDSHAKE`): the server refused the connection
or answered something else than a WebSocket handshake, or a client's request was invalid.
-}
errorIsHandshakeFailed : Socket.Error -> Bool
errorIsHandshakeFailed =
    Debug.todo "Implement System API"


{-| The HTTP status a server answered a refused opening request with, for example `Just 403`.
`Nothing` for other errors.

This was `handshakeStatus`.

-}
errorHandshakeStatus : Socket.Error -> Maybe Int
errorHandshakeStatus =
    Debug.todo "Implement System API"

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

{-| A WebSocket (RFC 6455) is a full-duplex connection that carries messages rather than bytes
and is opened by an HTTP request, and this module opens WebSockets as a client and answers them
as a server.

A client [`connect`](#connect)s to a `ws://` or `wss://` URL. A server receives a client's
opening request as an [`Upgrade`](#Upgrade), either on a [`Socket.Connection`](Socket#Connection)
it accepted ([`receiveUpgrade`](#receiveUpgrade)) or from an HTTP server
([`Http.Server.upgradeRequest`](Http-Server#upgradeRequest)), and answers it with
[`accept`](#accept) or [`reject`](#reject). Either way an open connection is a
[`WebSocket`](#WebSocket).

    WebSocket.connect (WebSocket.defaultConnectOptions "wss://example.com/chat")
        |> Task.andThen
            (\ws ->
                Stream.write (WebSocket.Text "hello") (WebSocket.writable ws)
                    |> Task.mapError (\_ -> ...)
            )

Several modules define functions such as `close`, `accept` and `readable`, so import this module
qualified:

    import WebSocket

**Messages.** A message is text or binary data ([`Message`](#Message)). A connection is opened in
one of two _modes_, and its type says which. In the _whole_ mode ([`connect`](#connect),
[`accept`](#accept)) every message arrives in one piece, on [`readable`](#readable) or through
[`onMessage`](#onMessage), and a message larger than the `maxMessageSize` of its options fails
the connection. In the _streamed_ mode ([`connectStreamed`](#connectStreamed),
[`acceptStreamed`](#acceptStreamed)) every message arrives as a stream of its own
([`StreamedMessage`](#StreamedMessage)), whatever its size. A streamed message must be read to
its end (`Closed`) or cancelled, because the connection delivers nothing after it until then. In
both modes each value written to [`writable`](#writable) is one message, and
[`sendText`](#sendText) and [`sendBinary`](#sendBinary) send one message whose content is read
from a stream. While 1 MiB of received messages, or 1024 of them, wait unread, the connection
stops reading from the network.

**Ending.** A connection normally ends with a _closing handshake_: one end sends a Close frame
carrying a [`CloseCode`](#CloseCode) and a reason, the other answers with its own, and the
connection is then gone. This end can also _fail_ a connection, for example on a protocol error,
an invalid or oversized message, or a silent peer: it sends a Close frame with a code saying why
and closes the connection without waiting for an answer. And the network connection can simply
be lost. [`awaitClose`](#awaitClose) and [`onClose`](#onClose) report how a connection ended, as
a [`CloseInfo`](#CloseInfo).

The tasks of this module that can fail fail with a [`Socket.Error`](Socket#Error), which
`Socket`'s predicates and [`errorIsHandshakeFailed`](#errorIsHandshakeFailed) classify. Once a
connection is open, a failure of the connection itself arrives on its streams instead, as the
[`Stream`](Stream) module describes: a read of [`readable`](#readable) fails with
`Stream.Cancelled` and a reason such as `"ERR_WS_PROTOCOL: <details>"`.

**Liveness.** By default this end checks that the peer is still there: when nothing has arrived
for 30 seconds it sends a ping, and when still nothing at all has arrived 30 seconds later it
fails the connection ([`Heartbeat`](#Heartbeat)). Pings from the peer are answered until this
end starts closing.

**Compression.** permessage-deflate (RFC 7692) compresses the content of each message. By
default a client offers it and a server accepts the offer, both without _context takeover_: each
message is compressed on its own, without referring back to earlier ones. With
`contextTakeover = True` in the compression options of both sides a message may refer back into
earlier messages, which compresses a run of similar messages better. A message written to
[`writable`](#writable) that is shorter than the compression options' `threshold` bytes is sent
uncompressed, while a non-empty message sent with
[`sendText`](#sendText) or [`sendBinary`](#sendBinary) is compressed whatever its size.
[`compression`](#compression) tells what the handshake agreed. Do not send secrets and data an
attacker controls on one compressed connection: the compressed sizes can reveal the secrets (the
CRIME and BREACH attacks).

A connection keeps the program running while an [`onMessage`](#onMessage) subscription exists
and the connection is open, while an [`onClose`](#onClose) subscription waits for its
`CloseInfo`, while an [`awaitClose`](#awaitClose) waits, during a closing handshake this end
started, and while an operation on it, such as a read, a write or a [`ping`](#ping), is waiting.

**Client limits.** A client opens a new connection for every [`connect`](#connect), even to a
host it is already connecting to, although RFC 6455 asks a client to wait for one opening
handshake with a host to finish before it starts another. Redirects are not followed (a redirect
status fails the handshake), and no proxy is used.

On native Windows, WebSockets are not supported: connecting, receiving an opening request and
accepting one fail with `ENOTSUP`.


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

import WebSocket.Internal
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


{-| An open WebSocket connection, in the mode `mode`: [`Whole`](#Whole) or
[`Streamed`](#Streamed).

A value is made only by [`connect`](#connect), [`connectStreamed`](#connectStreamed),
[`accept`](#accept) and [`acceptStreamed`](#acceptStreamed), and its `mode` is the mode that
function opened the connection in, so a function that takes only one mode can rely on it. The
value stays usable after the connection has ended.

-}
type alias WebSocket mode =
    WebSocket.Internal.WebSocket mode


{-| The mode of a connection whose messages arrive whole, each as one [`Message`](#Message). It
has no values; it is only used as the `mode` of a [`WebSocket`](#WebSocket).
-}
type Whole
    = Whole


{-| The mode of a connection whose messages arrive as streams, each a
[`StreamedMessage`](#StreamedMessage). It has no values; it is only used as the `mode` of a
[`WebSocket`](#WebSocket).
-}
type Streamed
    = Streamed


{-| A message: `Text` carries text and `Binary` carries bytes. Both kinds can be sent and
received on one connection, in any order.

A received `Text` has been checked to be valid UTF-8: a text message that is not fails the
connection with `InvalidData`. On the native backend a lone surrogate in a sent `Text` goes out
as bytes that are not valid UTF-8; the JavaScript backend sends U+FFFD in its place.

-}
type Message
    = Text String
    | Binary Bytes


{-| A message received in the streamed mode, whose content arrives as a stream, chunk by chunk,
as the peer sends it, decompressed when the message was compressed.

`StreamedText` carries a stream of text whose chunks always end on a whole character; text that
is not valid UTF-8 fails the connection with `InvalidData`. `StreamedBinary` carries a stream of
bytes.

The next message is delivered only once this one's stream has been read to `Closed`, or
cancelled with `Stream.cancelReadable`, which drops the rest of the message. When the connection
ends or fails before the message is complete, what had arrived can still be read, and then the
stream fails with `Cancelled`.

-}
type StreamedMessage
    = StreamedText (Stream.Readable String)
    | StreamedBinary (Stream.Readable Bytes)


{-| Returns the stream of the messages the peer sends, in order.

Once the peer's Close frame has arrived, reads fail with `Closed` after the messages received
before it. When the connection fails or is lost instead, reads fail with `Stream.Cancelled` and
a reason, such as `"ERR_WS_PROTOCOL: <details>"`, `"ERR_WS_MESSAGE_TOO_BIG"`,
`"heartbeat ETIMEDOUT"` or `"socket closed"`, again after the messages received before it.
[`awaitClose`](#awaitClose) gives the close code and reason.

While the connection has an [`onMessage`](#onMessage) subscription, messages go to the
subscription instead, and a read fails with `Locked`.

-}
readable : WebSocket Whole -> Stream.Readable Message
readable =
    Debug.todo "Implement System API"


{-| Returns the stream of the messages of a streamed connection, each a
[`StreamedMessage`](#StreamedMessage). It ends and fails as [`readable`](#readable) does.
-}
readableStreamed : WebSocket Streamed -> Stream.Readable StreamedMessage
readableStreamed =
    Debug.todo "Implement System API"


{-| Returns the stream that sends messages: each value written is one message, sent after the
messages written or streamed before it.

Closing it with `Stream.closeWritable` starts the closing handshake with `Normal` and no reason,
as [`close`](#close) does. Cancelling it with `Stream.cancelWritable` fails the connection with
`InternalError`. Once the connection is closing or has ended, writes fail with
`Stream.Cancelled`.

-}
writable : WebSocket mode -> Stream.Writable Message
writable =
    Debug.todo "Implement System API"


{-| Sends one text message whose content is read from `source` as it arrives, so that a message
too large to hold in memory can be sent. The task succeeds once `source` has ended and the
message's last frame has been written.

The message takes its place among the outgoing messages when the task starts: messages written
to [`writable`](#writable), or sent with `sendText` or [`sendBinary`](#sendBinary), after that
go out after it, while pings and pongs are not held up. Each chunk of `source` is sent as one or
more pieces of the message, compressed when the connection uses compression. An empty `source`
sends an empty message.

If `source` fails after part of the message has gone out, the message cannot be completed and
the connection fails with `InternalError`; if nothing of it has gone out yet, nothing is sent.
Either way the task fails with `ECANCELED`. It fails with `EBUSY` when `source` is locked, and
with `ECANCELED` when the connection is closing or has ended, or ends before the message is
complete.

-}
sendText : Stream.Readable String -> WebSocket mode -> Task Socket.Error ()
sendText =
    Debug.todo "Implement System API"


{-| Sends one binary message whose content is read from `source` as it arrives, exactly as
[`sendText`](#sendText) does for text.
-}
sendBinary : Stream.Readable Bytes -> WebSocket mode -> Task Socket.Error ()
sendBinary =
    Debug.todo "Implement System API"


{-| Returns the subprotocol the handshake agreed on (`Sec-WebSocket-Protocol`), or `Nothing`
when it agreed none.
-}
protocol : WebSocket mode -> Maybe String
protocol =
    Debug.todo "Implement System API"


{-| Returns the permessage-deflate settings the handshake agreed on, or `Nothing` when it agreed
none.

A `Just` does not mean that every message is compressed: a message written to
[`writable`](#writable) that is shorter than the `threshold` is still sent uncompressed, and what
the peer compresses is up to the peer.

-}
compression : WebSocket mode -> Maybe Negotiated
compression =
    Debug.todo "Implement System API"


{-| The permessage-deflate settings the two ends of a connection have agreed on.

`serverNoContextTakeover` and `clientNoContextTakeover` are `True` when that end, the server or
the client, compresses every message on its own. `serverMaxWindowBits` and `clientMaxWindowBits`
are the largest window that end compresses with, in window bits (as
[`ClientCompression`](#ClientCompression) explains them); in the settings
[`compression`](#compression) returns, they are from 8 to 15.

-}
type alias Negotiated =
    { serverNoContextTakeover : Bool
    , clientNoContextTakeover : Bool
    , serverMaxWindowBits : Int
    , clientMaxWindowBits : Int
    }


{-| Returns this end of the connection.
-}
localEndpoint : WebSocket mode -> Endpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| Returns the peer's end of the connection.
-}
remoteEndpoint : WebSocket mode -> Endpoint
remoteEndpoint =
    Debug.todo "Implement System API"


{-| Creates a subscription to the messages of a connection.

While a connection has subscriptions, every message goes to all of them, in subscription order,
and reads of [`readable`](#readable) fail with `Locked`. Messages that arrive while it has none
wait on the readable. A subscription does not start while a `Stream.read` of the readable is
waiting.

While the connection is open, an `onMessage` subscription keeps the program running.

-}
onMessage : WebSocket Whole -> (Message -> msg) -> Sub msg
onMessage =
    Debug.todo "Implement System API"


{-| Creates a subscription to the end of a connection. Its [`CloseInfo`](#CloseInfo) is
delivered once, to every `onClose` subscription the connection has at that moment. A
subscription made after it was delivered receives nothing.

Until its `CloseInfo` has been delivered, an `onClose` subscription keeps the program running.

-}
onClose : WebSocket mode -> (CloseInfo -> msg) -> Sub msg
onClose =
    Debug.todo "Implement System API"


{-| Sends a ping and waits for its pong, giving the round trip time in milliseconds.

Fails with `ECANCELED` when the connection is closing or has ended, or ends before the pong
arrives, and with `ETIMEDOUT` when no pong arrives within the heartbeat's `timeout` (30 seconds
when `heartbeat` is `Nothing` or its `timeout` is 0 or less). While the connection has
stopped reading because messages wait unread, that wait is suspended, and it starts again when
reading resumes. A pong also answers every earlier ping still waiting.

-}
ping : WebSocket mode -> Task Socket.Error Int
ping =
    Debug.todo "Implement System API"


{-| Starts the closing handshake with `code` and `reason`: the messages already written or being
streamed are sent first, then a Close frame. On the JavaScript backend the reason is cut to its
longest start that is at most 123 bytes of UTF-8; on the native backend a character outside the
Basic Multilingual Plane is counted as 6 bytes, so the reason can be cut shorter, and the cut
can fall inside such a character. The task succeeds once the Close frame has been written. The
connection ends when the peer's Close frame arrives, or 30 seconds after this end started
closing if it does not, which is reported as `Abnormal`.

From then on, messages that arrive are dropped (a streamed message being received fails with
`Cancelled`), and writes to [`writable`](#writable) fail.

Fails with `EINVAL` for a code that cannot be sent: only 1000 to 1003, 1007 to 1014 and 3000 to
4999 can, so `NoStatus`, `Abnormal`, and `Other` with a code outside those ranges cannot.
Closing a connection that is closing or has ended, with a code that can be sent, succeeds and
sends nothing more.

-}
close : CloseCode -> String -> WebSocket mode -> Task Socket.Error ()
close =
    Debug.todo "Implement System API"


{-| Waits until the connection has ended and returns how it ended. Once it has ended, it returns
at once. On the native backend, a connection that ended before more than 4096 other connections
ended may be reported as `Abnormal`, with an empty reason and `clean` `False`, whatever its real
end.

A waiting `awaitClose` keeps the program running.

-}
awaitClose : WebSocket mode -> Task x CloseInfo
awaitClose =
    Debug.todo "Implement System API"


{-| The code a Close frame carries to say why a connection is closing, from the codes RFC 6455
defines.

`Normal`, `GoingAway`, `ProtocolError` and `UnsupportedData` are the codes 1000 to 1003, and
`InvalidData`, `PolicyViolation`, `MessageTooBig`, `MandatoryExtension` and `InternalError` the
codes 1007 to 1011.

`NoStatus` (1005) and `Abnormal` (1006) are never sent; they describe how a connection ended.
`NoStatus` is reported when the peer's Close frame carried no code. `Abnormal` is reported when,
for example, the network connection was lost, the peer did not answer a Close frame in time, or
the heartbeat found the peer silent.

`Other` carries any other code, such as an application's own code from 4000 to 4999. A received
code that has a constructor of its own is always given that constructor, never `Other`.

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


{-| How a connection ended.

When the peer's Close frame arrived, `code` and `reason` are the ones it carried and `clean` is
`True`, whichever end started closing. When this end failed the connection, they are the code
and reason of the failure, and `clean` is `False`; a heartbeat that found the peer silent
is the exception, reported as `Abnormal` with an empty reason. When the connection ended in any
other way, `code` is `Abnormal`, `reason` is empty and `clean` is `False`.

-}
type alias CloseInfo =
    { code : CloseCode
    , reason : String
    , clean : Bool
    }


{-| The liveness check of a connection, both times in milliseconds.

When nothing has arrived from the peer for `interval`, a ping is sent. If nothing at all
arrives within a further `timeout`, the connection is failed: a Close frame with `GoingAway` is
sent, the connection is closed, its end is reported as `Abnormal`, and reads fail with
`"heartbeat ETIMEDOUT"`. Anything received counts, not only the pong. While the connection has
stopped reading because messages wait unread, the check is suspended.

An `interval` of 0 or less turns the check off, as `heartbeat = Nothing` does, while a `timeout`
of 0 or less means 30 seconds. Both are plain `Int`s, so the compiler accepts any value.

-}
type alias Heartbeat =
    { interval : Int
    , timeout : Int
    }


{-| How a client connects.

  - `url`: `ws://host[:port]/path?query`, or `wss://...` for a connection over TLS. An IPv6
    address is written in brackets, and a zone in it may be written `%25`, as in
    `ws://[fe80::1%25eth0]/`. A fragment (`#`) or user information makes the URL invalid.
  - `headers`: extra request headers, such as `Authorization`. A name must be an HTTP token and
    a value may not hold a carriage return, line feed or NUL. `Host`, `Upgrade`, `Connection`,
    `Sec-WebSocket-Key`, `Sec-WebSocket-Version`, `Sec-WebSocket-Accept`,
    `Sec-WebSocket-Protocol`, `Sec-WebSocket-Extensions`, `Content-Length` and
    `Transfer-Encoding` are refused, in any case.
  - `protocols`: the subprotocols to offer, in order; each must be an HTTP token and be listed
    once. [`protocol`](#protocol) tells which one the server chose.
  - `verification`: which server certificates a `wss` connection accepts.
  - `timeout`: the time allowed, in milliseconds, for connecting, TLS and the HTTP exchange
    together; the name lookup before them is not limited. `Nothing`, or a value of 0 or less,
    is no limit.
  - `maxMessageSize`: the largest message accepted, in bytes after decompression; a larger one
    fails the connection with `MessageTooBig`. A value of 0 or less accepts only empty
    messages. It does not apply to a streamed connection.
  - `heartbeat`: the [`Heartbeat`](#Heartbeat), or `Nothing` for none.
  - `compression`: the permessage-deflate offer, or `Nothing` to offer none.
  - `http2`: for a `wss` URL, try a WebSocket over HTTP/2 (RFC 8441) first; a `ws` URL always
    uses HTTP/1.1. The TLS handshake then offers `h2`. When the server chooses it and its
    settings allow WebSockets (`SETTINGS_ENABLE_CONNECT_PROTOCOL`), the WebSocket runs on one
    stream of a new HTTP/2 connection. A server that chooses HTTP/1.1 gets the HTTP/1.1
    handshake on the same connection, and an HTTP/2 server whose settings do not allow
    WebSockets is left and dialed again over HTTP/1.1, within the same `timeout`.

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

_Window bits_ is the size of a compressor's window, the distance back it may refer, as a power
of two: from 8 (256 bytes) to 15 (32 KiB). A window size outside 8 to 15 is clamped into that
range.

  - `clientMaxWindowBits`: `Just (Just n)` limits the client's own window to `n` window bits.
    `Just Nothing` sends the parameter without a value, which lets the server choose a limit
    for the client's window. `Nothing` leaves the parameter out, and a server that answers with
    a limit for the client's window then fails the handshake.
  - `serverMaxWindowBits`: `Just n` asks the server to compress with at most `n` window bits; a
    server that answers with more fails the handshake.
  - `contextTakeover`: `False` offers `client_no_context_takeover` and
    `server_no_context_takeover`, and the client then compresses every message on its own.
    `True` offers neither, and the server may still answer with them.
  - `threshold`: a message written to [`writable`](#writable) that is shorter than this many
    bytes is sent uncompressed.

-}
type alias ClientCompression =
    { clientMaxWindowBits : Maybe (Maybe Int)
    , serverMaxWindowBits : Maybe Int
    , contextTakeover : Bool
    , threshold : Int
    }


{-| Returns the options for connecting to `url`: no extra headers or subprotocols,
`Socket.Tls.SystemCertificates`, a 30 second timeout, messages up to 16 MiB, the default
heartbeat (a ping after 30 seconds without anything received, then 30 seconds for anything to
arrive), permessage-deflate offered without context takeover, with `client_max_window_bits`
sent without a value and a threshold of 64 bytes, and `http2 = False`.
-}
defaultConnectOptions : String -> ConnectOptions
defaultConnectOptions =
    Debug.todo "Implement System API"


{-| Opens a connection in the whole mode to `options.url`.

A host name is looked up first; an address written in the URL is used as it is. The addresses
are tried in order until a connection is made, and the opening handshake then runs on that
connection. When no connection can be made, the error of the last address tried is reported.

Fails with `EINVAL` for an invalid URL, header or subprotocol; with the errors of
[`Socket.lookup`](Socket#lookup); with the socket and TLS errors of connecting; with `ETIMEDOUT`
when the `timeout` runs out; and with `ERR_WS_HANDSHAKE`
([`errorIsHandshakeFailed`](#errorIsHandshakeFailed)) when the server's answer is not an
acceptable opening handshake, in which case
[`errorHandshakeStatus`](#errorHandshakeStatus) gives the HTTP status when that was the problem.

-}
connect : ConnectOptions -> Task Socket.Error (WebSocket Whole)
connect =
    Debug.todo "Implement System API"


{-| Opens a connection in the streamed mode; everything else is as for [`connect`](#connect).
-}
connectStreamed : ConnectOptions -> Task Socket.Error (WebSocket Streamed)
connectStreamed =
    Debug.todo "Implement System API"


{-| A client's opening request that a server has received.

One is obtained from [`receiveUpgrade`](#receiveUpgrade) or `Http.Server.upgradeRequest`, read
with the `upgrade` functions below, and answered with [`accept`](#accept),
[`acceptStreamed`](#acceptStreamed) or [`reject`](#reject).

-}
type alias Upgrade =
    WebSocket.Internal.Upgrade


{-| Reads a client's opening request from `connection`, a connection a server accepted, such as
one from a `Socket.Tcp.listen` or `Socket.Tls.listen` listener.

The connection is taken over: from then on its streams fail with
`Stream.Cancelled "upgraded to WebSocket"`, and bytes the client sent right behind its request
are kept for the WebSocket. The request is only read as HTTP here; whether it is a valid opening
request is checked by [`accept`](#accept).

Fails with `EBUSY` while a read or write is waiting on the connection's streams or when the
connection has already been taken over, and with `ECANCELED` when the connection, or its
writable, has been closed; these leave the connection as it is. Otherwise it fails with
`ETIMEDOUT` when the request has not arrived within 30 seconds; with `ERR_WS_HANDSHAKE` when what
the client sends is not an HTTP request or has a head over 64 KiB (both answered with 400), or
the client closes the connection before sending a request; and with the connection's own error
when reading fails. After any of these the connection is closed.

-}
receiveUpgrade : Socket.Connection -> Task Socket.Error Upgrade
receiveUpgrade =
    Debug.todo "Implement System API"


{-| Returns the request target, the path and the query, for example `"/chat?room=1"`, as the
client sent it.
-}
upgradeTarget : Upgrade -> String
upgradeTarget =
    Debug.todo "Implement System API"


{-| Returns the request headers in the order they were received, with lower-case names and one
entry for each occurrence of a repeated header.
-}
upgradeHeaders : Upgrade -> List ( String, String )
upgradeHeaders =
    Debug.todo "Implement System API"


{-| Returns the subprotocols the client offers, in the order it lists them: the comma-separated
elements of every `Sec-WebSocket-Protocol` header, trimmed, with empty ones dropped.
-}
upgradeProtocols : Upgrade -> List String
upgradeProtocols =
    Debug.todo "Implement System API"


{-| Returns the value of the first `Origin` header, or `Nothing` when the request has none.
-}
upgradeOrigin : Upgrade -> Maybe String
upgradeOrigin =
    Debug.todo "Implement System API"


{-| Returns the client's end of the connection.
-}
upgradeRemote : Upgrade -> Endpoint
upgradeRemote =
    Debug.todo "Implement System API"


{-| How a server accepts an opening request.

  - `protocol`: the subprotocol to use, which must be one the client offers
    ([`upgradeProtocols`](#upgradeProtocols)), or `Nothing` for none.
  - `headers`: extra response headers, refused by the same rules as the `headers` of
    [`ConnectOptions`](#ConnectOptions).
  - `maxMessageSize`, `heartbeat`: as in [`ConnectOptions`](#ConnectOptions).
  - `compression`: the server's permessage-deflate policy, or `Nothing` to decline every offer.

-}
type alias AcceptOptions =
    { protocol : Maybe String
    , headers : List ( String, String )
    , maxMessageSize : Int
    , heartbeat : Maybe Heartbeat
    , compression : Maybe ServerCompression
    }


{-| What a server agrees to for permessage-deflate. The first of the client's offers that is
valid is accepted under it.

  - `maxWindowBits`: the largest window the server compresses with, in window bits (as
    [`ClientCompression`](#ClientCompression) explains them, clamped to 8 to 15), or the
    client's limit when that is smaller.
  - `contextTakeover`: `False` answers with `server_no_context_takeover` and
    `client_no_context_takeover`, which ask both ends to compress every message on its own. `True`
    keeps context takeover for each end whose no-context-takeover parameter the client did not
    send.
  - `threshold`: a message written to [`writable`](#writable) that is shorter than this many
    bytes is sent uncompressed.

-}
type alias ServerCompression =
    { maxWindowBits : Int
    , contextTakeover : Bool
    , threshold : Int
    }


{-| The default options for accepting: no subprotocol, no extra headers, messages up to 16 MiB,
the default heartbeat (as in [`defaultConnectOptions`](#defaultConnectOptions)), and
permessage-deflate accepted without context takeover, with a 15-bit window and a threshold of 64
bytes.
-}
defaultAcceptOptions : AcceptOptions
defaultAcceptOptions =
    Debug.todo "Implement System API"


{-| Accepts an opening request in the whole mode: checks it, agrees on the subprotocol and the
compression, answers it (101 over HTTP/1.1, 200 over HTTP/2), and opens the connection.

The request must be a valid opening request. Over HTTP/1.1 it is a `GET` of HTTP/1.1 or later
with a `Host` header, `Upgrade: websocket`, `Connection: Upgrade`, `Sec-WebSocket-Version: 13`
and a valid `Sec-WebSocket-Key`; over HTTP/2 an extended `CONNECT` with
`Sec-WebSocket-Version: 13`. Its subprotocols must be HTTP tokens and its extensions well
formed. The checks are made in that order, and the first that fails decides the answer: 426,
with `Sec-WebSocket-Version: 13`, for the version, and 400 for any other. The task then fails
with `ERR_WS_HANDSHAKE`.

A `protocol` the client did not offer, or a refused header in `headers`, fails with `EINVAL` and
leaves the request unanswered. Accepting an `Upgrade` that has already been answered fails.

-}
accept : AcceptOptions -> Upgrade -> Task Socket.Error (WebSocket Whole)
accept =
    Debug.todo "Implement System API"


{-| Accepts an opening request in the streamed mode; everything else is as for
[`accept`](#accept).
-}
acceptStreamed : AcceptOptions -> Upgrade -> Task Socket.Error (WebSocket Streamed)
acceptStreamed =
    Debug.todo "Implement System API"


{-| Refuses an opening request with an HTTP `status`, extra `headers` and a `body`, for example
`reject 403 [] "Forbidden"`, and succeeds once the answer has been written. Over HTTP/1.1 the
connection is closed afterwards; over HTTP/2 the request's stream is ended.

A `status` outside 100 to 999 is sent as 400, and over HTTP/2 on the JavaScript backend a
`status` below 200 is sent as 500. An `Upgrade` that has already been answered is
left as it is.

-}
reject : Int -> List ( String, String ) -> String -> Upgrade -> Task x ()
reject =
    Debug.todo "Implement System API"


{-| Returns `True` when the error is a failed opening handshake (`ERR_WS_HANDSHAKE`).

A client gets it from [`connect`](#connect) when the server's answer is not an acceptable
opening handshake (a wrong status, missing or wrong handshake headers, or a subprotocol or
extension that was not offered), is not HTTP, or never comes because the server closes the
connection. A server gets it from [`receiveUpgrade`](#receiveUpgrade) and [`accept`](#accept)
when the client's request is not HTTP or not a valid opening request, or the client closes the
connection before sending one.

-}
errorIsHandshakeFailed : Socket.Error -> Bool
errorIsHandshakeFailed =
    Debug.todo "Implement System API"


{-| Returns the HTTP status with which a server refused a client's opening request, for example
`Just 403`: the status of an answer that was not 101, or not 2xx over HTTP/2. Returns `Nothing`
for every other error, including handshakes that failed for another reason.
-}
errorHandshakeStatus : Socket.Error -> Maybe Int
errorHandshakeStatus =
    Debug.todo "Implement System API"

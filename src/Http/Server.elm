module Http.Server exposing
    ( Server, ListenOptions, defaultListenOptions, listen, listenOnHost, endpoint, close, closeWithin
    , Request, Method(..), HttpVersion(..), methodToString, bodyAsString, bodyAsJson, requestToString
    , onRequest
    , Response, send
    , setStatus, setHeader, appendHeader
    , setBody, setBodyAsString, setBodyAsBytes, setBodyAsHtml
    , upgradeRequest
    , Error, errorCode, errorToString
    , errorIsAddressInUse, errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCertificateInvalid
    )

{-| An HTTP server for an Elm program: requests arrive as subscription messages, and the program
answers each one by sending a response as a command.

[`listen`](#listen) or [`listenOnHost`](#listenOnHost) starts a [`Server`](#Server).
[`onRequest`](#onRequest) subscribes to its requests, and every [`Request`](#Request) arrives
together with a fresh [`Response`](#Response), which the program builds up and
[`send`](#send)s from its `update` function:

    GotRequest request response ->
        ( model
        , response
            |> Http.Server.setHeader "Content-Type" "text/html"
            |> Http.Server.setBody "<html>Hello there!</html>"
            |> Http.Server.send
        )

A response answers the one request it arrived with. It carries that request's _response key_,
the server's name for a request that is still waiting for its answer. The key is released when
the request is answered, when [`upgradeRequest`](#upgradeRequest) takes the request over, and
when the request's connection goes away. From then on, sending the response writes nothing, so a
request is answered at most once however often its response is sent.

The server speaks HTTP/1.0 and HTTP/1.1, and, when started with `http2` (which requires TLS),
HTTP/2 (see [`ListenOptions`](#ListenOptions)). Over HTTP/1 a connection is kept alive and serves one request
after another; requests a client sends ahead of their answers (pipelining) are handed to the
program one at a time, in order, each once the one before it has been answered. Over HTTP/2
several requests on one connection are handed over at once and answered independently.

The server checks every request against its limits and the HTTP rules before the program sees
it. A request that breaks them never arrives: the server answers it itself, with a status such
as 400, 413 or 431, or over HTTP/2 may reset its stream instead.

Starting a server fails with this module's own [`Error`](#Error). On the native backend under
Windows no server can be started (`listen` and `listenOnHost` fail with `ENOTSUP`), and an
`onRequest` subscription stops the program with a fatal error.


## Servers

@docs Server, ListenOptions, defaultListenOptions, listen, listenOnHost, endpoint, close, closeWithin


## Requests

@docs Request, Method, HttpVersion, methodToString, bodyAsString, bodyAsJson, requestToString, onRequest


## Responses

A fresh response has status `200`, no headers and an empty body.

@docs Response, send


### Status and headers

@docs setStatus, setHeader, appendHeader


### Body

@docs setBody, setBodyAsString, setBodyAsBytes, setBodyAsHtml


## WebSockets

@docs upgradeRequest


## Errors

@docs Error, errorCode, errorToString
@docs errorIsAddressInUse, errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCertificateInvalid

-}

import Http.Server.Internal
import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Json.Decode
import Socket
import Socket.Address exposing (Address, InetEndpoint)
import Socket.Tls
import Task exposing (Task)
import Url exposing (Url)
import VirtualDom
import WebSocket


{-| An HTTP server that [`listen`](#listen) or [`listenOnHost`](#listenOnHost) started.

A `Server` stays usable after it has been closed: [`endpoint`](#endpoint) still answers, and
closing it again does nothing.

-}
type Server
    = Server


{-| How to run a server: where it listens, whether it uses TLS and HTTP/2, and the limits it holds
clients to.

`port_` 0 lets the system pick a free port, which [`endpoint`](#endpoint) reports.

`tls` serves HTTPS (and so `wss` WebSockets) with the given certificate chain and key. Its `alpn`
field is not used: the server offers `h2` and `http/1.1` with `http2`, else `http/1.1`, and a
client that offers none of them is still served HTTP/1.1.

`http2` also serves HTTP/2 to clients that ask for it during the TLS handshake. It requires `tls`.
TLS 1.2 is then limited to the cipher suites HTTP/2 allows.

`maxConnections` is the most connections open at once. Natively, further clients wait in the
operating system's queue of pending connections until one closes; on the JavaScript backend Node
drops them.

`maxConcurrentStreams` is the most HTTP/2 requests, WebSockets included, in progress at once on one
connection, and is advertised to the client. Natively, requests the program has not answered yet
count even when the client has cancelled them, and at the limit the server processes nothing more
from that connection until the program answers one; on the JavaScript backend Node refuses the
requests over the limit. Without this limit, natively a client that keeps cancelling its requests
is held back only by a limit on cancellations (about 1000 at once, then 33 per second), so a
public server should set one.

For both of these limits `Nothing` means no limit, but `Just 0` or a negative value is a limit of
0, which serves nothing. A `maxConnections` of 0 natively accepts no connection, so clients wait
indefinitely, and on the JavaScript backend drops every one. A `maxConcurrentStreams` of 0 refuses
every HTTP/2 request.

`maxBodySize` and `maxHeaderSize` are in bytes. A request with a larger body is answered 413, and
one with a larger header block 431 (on the JavaScript backend over HTTP/2, a header block over
twice `maxHeaderSize` has its stream reset instead).

`keepAliveTimeout`, `headersTimeout` and `requestTimeout` are in milliseconds, and a value of 0 or
less is no timeout. `keepAliveTimeout` is how long an idle connection stays open between requests.
`headersTimeout` runs from the first byte of a request to the end of its headers and
`requestTimeout` to the end of its body; a request that takes longer is answered 408. Natively, a
new connection without TLS that sends nothing is closed after `headersTimeout`. Over HTTP/2 they
apply differently: natively `headersTimeout` limits only the wait for a new connection's first
bytes, and on the JavaScript backend none of the three applies. No timeout limits the program's
answer: the connection waits for it.

-}
type alias ListenOptions =
    { address : Address
    , port_ : Int
    , tls : Maybe Socket.Tls.ServerOptions
    , http2 : Bool
    , maxConnections : Maybe Int
    , maxConcurrentStreams : Maybe Int
    , maxBodySize : Int
    , maxHeaderSize : Int
    , keepAliveTimeout : Int
    , headersTimeout : Int
    , requestTimeout : Int
    }


{-| Returns the options for plain HTTP on `address` and `port_`, with no connection or stream
limits, bodies up to 16 MiB, header blocks up to 64 KiB, a 5 second keep-alive timeout, a 60
second headers timeout and a 300 second request timeout.

    Http.Server.defaultListenOptions (Socket.Address.loopback Socket.Address.IPv4) 8080

-}
defaultListenOptions : Address -> Int -> ListenOptions
defaultListenOptions =
    Debug.todo "Implement System API"


{-| Starts a server as `options` say.

    let
        options =
            Http.Server.defaultListenOptions (Socket.Address.loopback Socket.Address.IPv4) 8443
    in
    Http.Server.listen
        { options | tls = Just { certificateChain = cert, privateKey = key, alpn = [] } }

Fails with an [`Error`](#Error): for example [`errorIsAddressInUse`](#errorIsAddressInUse) when
the port is taken, [`errorIsCertificateInvalid`](#errorIsCertificateInvalid) when the certificate
chain or key cannot be used, and `EINVAL` when `http2` is set without `tls`. A listening server
keeps the program running until it is closed with [`close`](#close).

-}
listen : ListenOptions -> Task Error Server
listen =
    Debug.todo "Implement System API"


{-| Starts a server listening on `host` and `port_`, with the limits and timeouts of
[`defaultListenOptions`](#defaultListenOptions), and without TLS.

    Http.Server.listenOnHost "localhost" 8080

An address literal such as `"127.0.0.1"` or `"::1"` is used as it is. A name is resolved, and the
server listens on one of its addresses; natively that is the first IPv4 address that can be used,
if there is one. The empty string listens on every interface: natively on `0.0.0.0`, so on IPv4
only, and on the JavaScript backend on Node's default, `::` where IPv6 is available. Port 0 lets
the system pick a free port, which [`endpoint`](#endpoint) reports.

A name that cannot be resolved fails with [`errorIsHostNotFound`](#errorIsHostNotFound). A
listening server keeps the program running until it is closed with [`close`](#close).

-}
listenOnHost : String -> Int -> Task Error Server
listenOnHost =
    Debug.todo "Implement System API"


{-| Returns the address and port a server listens on. For port 0 this is the port the system
picked. An address the system reports as text that does not parse is given as `0.0.0.0`.
-}
endpoint : Server -> InetEndpoint
endpoint =
    Debug.todo "Implement System API"


{-| Stops a server gracefully, with [`closeWithin`](#closeWithin) and a deadline of 5 seconds.
-}
close : Server -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Stops a server gracefully, closing the connections still open after `deadline` milliseconds.

The server stops accepting connections at once (the port is free when the task completes) and
closes its idle connections. Requests held because nothing subscribed to them (see
[`onRequest`](#onRequest)) are answered 503. Requests already handed to the program can still be
answered until the deadline, over HTTP/1 with `Connection: close`; then the connections that remain
are closed. A request still being received when the server closes can still be handed to a
subscription. WebSockets made with [`upgradeRequest`](#upgradeRequest) stay open, except one over
HTTP/2, which shares its connection and ends with it at the deadline.

Closing a server twice is fine. A closed server no longer keeps the program running.

-}
closeWithin : Int -> Server -> Task x ()
closeWithin =
    Debug.todo "Implement System API"


{-| An HTTP request a server has received.

`headers` maps each header name, spelled as the client sent it, to its value. Over HTTP/2 names
are always lower case, and over HTTP/1 they need not be, so look a header up by every spelling it
may have or compare names case-insensitively: names that differ in case are separate entries. When
a name is sent more than once with the same spelling, the last value wins. Over HTTP/2 the
pseudo-header fields (`:method`, `:path`, ...) are not included, and several `cookie` fields are
joined into one with `"; "`.

`body` is the complete request body.

`url` is the absolute URL of the request, made from the `Host` header (over HTTP/2 the
`:authority` field), or, without one, the host the server was started with (its address for
`listen`, `localhost` for `listenOnHost ""`) and its port, followed by the request target; a target
that is already an absolute URL is used as it is. When that text is not one `Url.fromString`
accepts, for example when the host is a bracketed IPv6 address, `url` has an empty host and path,
and its protocol is `Https` when the connection uses TLS and `Http` otherwise.

`upgrade` is the protocol the client asks to switch to, lower-cased, such as `Just "websocket"`:
the first protocol of the HTTP/1.1 `Upgrade` header when `Connection` also names `upgrade`
(natively, only for a request without a body), or HTTP/2's `:protocol`. Answer a WebSocket
request with [`upgradeRequest`](#upgradeRequest). Any response sent instead refuses the upgrade,
and over HTTP/1 the connection then closes.

-}
type alias Request =
    { headers : Dict String String
    , method : Method
    , body : Bytes
    , url : Url
    , version : HttpVersion
    , upgrade : Maybe String
    }


{-| The HTTP version a request was made with. `Http2` occurs only on a server started with `http2`.
-}
type HttpVersion
    = Http1_0
    | Http1_1
    | Http2


{-| The HTTP method of a request. `UNKNOWN` holds the name of any method not listed, as it was
received, for example `UNKNOWN "OPTIONS"`.
-}
type Method
    = GET
    | HEAD
    | POST
    | PUT
    | DELETE
    | CONNECT
    | TRACE
    | PATCH
    | UNKNOWN String


{-| Returns the name of a method, for example `"GET"`. `UNKNOWN name` gives `name`.
-}
methodToString : Method -> String
methodToString =
    Debug.todo "Implement System API"


{-| Returns the request body as a string, or `Nothing` if it is not valid UTF-8.
-}
bodyAsString : Request -> Maybe String
bodyAsString =
    Debug.todo "Implement System API"


{-| Decodes the request body as JSON. A body that is not valid UTF-8 is decoded as the empty
string, so the decoder fails.
-}
bodyAsJson : Json.Decode.Decoder a -> Request -> Result Json.Decode.Error a
bodyAsJson =
    Debug.todo "Implement System API"


{-| Returns a one-line description of a request for logs: its method and URL, for example
`"GET http://localhost:8080/"`. An `UNKNOWN` method is written as `UNKNOWN(name)`.
-}
requestToString : Request -> String
requestToString =
    Debug.todo "Implement System API"


{-| Creates a subscription to the requests `server` receives, each with a fresh
[`Response`](#Response) that answers it.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Http.Server.onRequest model.server GotRequest

Every subscription to one server receives every request, all with the same response, so only the
first of them to be sent answers it.

Requests that arrive while nothing subscribes to their server are held, and handed out oldest
first once a subscription appears. A server holds about `maxBodySize` × 4 bytes of them, and
always at least one. It answers 503 to a request beyond that, and to a request that arrives
after the server was closed with nothing subscribed.

-}
onRequest : Server -> (Request -> Response -> msg) -> Sub msg
onRequest =
    Debug.todo "Implement System API"


{-| An HTTP response being built for one request.

A response is obtained only from [`onRequest`](#onRequest), together with the request it answers,
and stays tied to that request: the functions below change its status, headers and body, but
never which request it answers.

-}
type alias Response =
    Http.Server.Internal.Response


{-| Creates a command that sends `response` to the request it answers.

The response is written with its status, its headers in order, one header line per value, and
its body:

  - A `Content-Length` header is always written, except with status 204 or 304, which send no
    body. The response's own `Content-Length`, `Connection` and `Transfer-Encoding` headers are
    left out, and so is a header whose name is empty or whose name or value holds a carriage
    return, line feed or NUL character. On the JavaScript backend a header Node considers invalid,
    such as one whose name contains a space, is left out as well. A `Date` header is added unless
    the response has one.
  - Over HTTP/2 header names are sent lower-cased, and other headers HTTP/2 forbids, such as
    `Upgrade` and `Keep-Alive`, are left out too. On the JavaScript backend, if a header HTTP/2
    allows only once, such as `Content-Type`, has several values (for example from two spellings
    of its name), every header of the response that has several values keeps only its last one.
  - The answer to a `HEAD` request has the headers only.
  - An HTML body (see [`setBodyAsHtml`](#setBodyAsHtml)) is serialized now.

Over HTTP/1 the connection then stays open for the client's next request, unless, for example,
the client asked to close it (`Connection: close`, or HTTP/1.0 without keep-alive), the response
has a `Connection: close` header, the server is closing, or the request asked to switch protocols
or was a `CONNECT`.

Sending a response whose request was already answered, was taken over by
[`upgradeRequest`](#upgradeRequest), or lost its connection writes nothing.

-}
send : Response -> Cmd msg
send =
    Debug.todo "Implement System API"


{-| Sets the HTTP status code of a response. A status below 200 or above 999 is sent as 500.

    response |> Http.Server.setStatus 404

-}
setStatus : Int -> Response -> Response
setStatus =
    Debug.todo "Implement System API"


{-| Sets a header on a response, replacing the values of the header with exactly this name and
keeping its place, or adding it last. Names are compared exactly, so `"content-type"` does not
replace `"Content-Type"`: the response then has both.
-}
setHeader : String -> String -> Response -> Response
setHeader =
    Debug.todo "Implement System API"


{-| Adds a value to the header with exactly this name, after the values it already has, or adds
the header last. Use this for headers that may appear more than once, such as `Set-Cookie`.
-}
appendHeader : String -> String -> Response -> Response
appendHeader =
    Debug.todo "Implement System API"


{-| Sets the body of a response to a string; the same as [`setBodyAsString`](#setBodyAsString).
-}
setBody : String -> Response -> Response
setBody =
    Debug.todo "Implement System API"


{-| Sets the body of a response to a string, which is sent encoded as UTF-8. The backends differ
only for a lone surrogate: the JavaScript backend sends it as U+FFFD, the native one in its 3-byte
form, which is not valid UTF-8.
-}
setBodyAsString : String -> Response -> Response
setBodyAsString =
    Debug.todo "Implement System API"


{-| Sets the body of a response to bytes, which are sent as they are.
-}
setBodyAsBytes : Bytes -> Response -> Response
setBodyAsBytes =
    Debug.todo "Implement System API"


{-| Sets the body of a response to an HTML page or fragment built with
[elm/html](/packages/elm/html/latest/) (or `Svg`).

    response
        |> Http.Server.setBodyAsHtml
            (Html.node "html" [] [ Html.node "body" [] [ Html.text "Hello!" ] ])
        |> Http.Server.send

When the response is sent:

  - the HTML is written as the text [`Html.Dom.htmlToString`](Html-Dom#htmlToString) gives,
    encoded as UTF-8, with the same lone-surrogate difference between the backends as
    [`setBodyAsString`](#setBodyAsString);
  - `<!DOCTYPE html>` is written first when the root, seen through `Html.map`, is an HTML `html`
    element;
  - `Content-Type: text/html; charset=utf-8` is added unless the response already has a
    `Content-Type` header, in any case.

-}
setBodyAsHtml : VirtualDom.Node msg -> Response -> Response
setBodyAsHtml =
    Debug.todo "Implement System API"


{-| Takes over a WebSocket opening request (a [`Request`](#Request) whose `upgrade` is
`Just "websocket"`, over HTTP/1.1 or HTTP/2) instead of answering it with its
[`Response`](#Response). The result is a [`WebSocket.Upgrade`](WebSocket#Upgrade), to be answered
with [`WebSocket.accept`](WebSocket#accept) or [`WebSocket.reject`](WebSocket#reject). The response
is used up: sending it later writes nothing.

    GotRequest request response ->
        if request.upgrade == Just "websocket" then
            ( model
            , Http.Server.upgradeRequest request response
                |> Task.andThen (WebSocket.accept WebSocket.defaultAcceptOptions)
                |> Task.attempt GotWebSocket
            )

        else
            ...

The opening request is checked by `WebSocket.accept`, which answers a request that breaks the
rules with 400 or 426 itself, as for [`WebSocket.receiveUpgrade`](WebSocket#receiveUpgrade). Over
HTTP/1.1 the requests the client sent before this one on the same connection are answered first,
so the `101` follows their responses.

Over HTTP/2 the request is an extended `CONNECT` with `:protocol` `websocket`, which a server with
`http2` allows; the server itself answers any other `:protocol` with 501. The WebSocket then runs
on that one stream of the connection, next to the connection's other requests and WebSockets:
`accept` answers `200` and the stream carries the frames, the close handshake ends the stream, and
an aborted WebSocket resets it. Such a WebSocket is one of the connection's streams for
`maxConcurrentStreams`.

The WebSocket does not belong to the server: [`close`](#close) leaves it open, except that over
HTTP/2 it ends at the close deadline with the connection it shares.

Fails with `EINVAL` when the request does not ask for a WebSocket; the response is then untouched
and can still be sent. Fails with `EINVAL` too when the request was already answered or taken
over, and with `EINVAL` or `ECANCELED` when its connection has gone away.

-}
upgradeRequest : Request -> Response -> Task Socket.Error WebSocket.Upgrade
upgradeRequest =
    Debug.todo "Implement System API"

{-| A failure to start a server, from [`listen`](#listen) or [`listenOnHost`](#listenOnHost).

Each error has a code and a human readable message. The code is, for example, an errno name such
as `"EADDRINUSE"`, a resolver code such as `"ENOTFOUND"`, or an `"ERR_SSL_"` code for a
certificate chain or key that cannot be used. The `errorIs…` functions below check for the common
cases.

This is a separate type from `Socket.Error`, which [`upgradeRequest`](#upgradeRequest) fails with.

-}
type Error
    = Error


{-| Returns the error code, for example `"EADDRINUSE"`.
-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| Returns a human readable description of the error: the code, `": "`, and the message.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| Returns `True` when the port is already in use (`EADDRINUSE`).
-}
errorIsAddressInUse : Error -> Bool
errorIsAddressInUse =
    Debug.todo "Implement System API"


{-| Returns `True` when the address cannot be used here (`EADDRNOTAVAIL`, `EAFNOSUPPORT`): it does
not belong to this machine, or the system does not support its family.
-}
errorIsAddressNotAvailable : Error -> Bool
errorIsAddressNotAvailable =
    Debug.todo "Implement System API"


{-| Returns `True` when the host name given to [`listenOnHost`](#listenOnHost) could not be
resolved (`ENOTFOUND`, `EAI_AGAIN`, `EAI_FAIL`).
-}
errorIsHostNotFound : Error -> Bool
errorIsHostNotFound =
    Debug.todo "Implement System API"


{-| Returns `True` when the operating system refused to listen (`EACCES`, `EPERM`), for example on
a privileged port.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| Returns `True` when the TLS certificate chain or private key cannot be used: the code starts
with `"ERR_SSL_"`. This is not what `Socket.errorIsCertificateInvalid` checks, which is whether the
other end's certificate failed verification.
-}
errorIsCertificateInvalid : Error -> Bool
errorIsCertificateInvalid =
    Debug.todo "Implement System API"

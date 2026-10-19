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

{-| Create a server that can respond to HTTP requests.

You write your server using The Elm Architecture: start a [`Server`](#Server) with
[`listen`](#listen) or [`listenOnHost`](#listenOnHost), subscribe to its requests with
[`onRequest`](#onRequest), and answer each request by building up its [`Response`](#Response)
and [`send`](#send)ing it from your `update` function:

    GotRequest request response ->
        ( model
        , response
            |> Http.Server.setHeader "Content-Type" "text/html"
            |> Http.Server.setBody "<html>Hello there!</html>"
            |> Http.Server.send
        )

The server speaks HTTP/1.1 (and HTTP/1.0) with keep-alive: a connection serves one request after
the other, and requests a client sends ahead of their answers (pipelining) are handed to you one
at a time, in order, each after the previous one was answered. Request sizes and the time a client
may take to send a request are limited (see [`ListenOptions`](#ListenOptions)); requests that break
the limits or the HTTP rules are answered by the server itself (400, 408, 413, 417, 431, 505) and
never reach your program.

Unlike gren-node's `HttpServer` module, there is no permission value and no `initialize`, and
the response functions of gren's `HttpServer.Response` are part of this module.


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


{-| An HTTP server listening on a host and port.
-}
type Server
    = Server


{-| How to run a server, for [`listen`](#listen).

  - `address`, `port_`: where to listen. Port 0 lets the system pick a free port
    ([`endpoint`](#endpoint) tells which).
  - `tls`: serve HTTPS (and so `wss` WebSockets) with this certificate chain and key; request
    URLs then start with `https://`. Its `alpn` field is ignored: the server chooses the
    application protocol itself (ALPN `h2` and `http/1.1` with `http2`, else `http/1.1`), and a
    client that offers no protocol the server speaks still connects, without ALPN, and is served
    HTTP/1.1.
  - `http2`: also serve HTTP/2 to clients that ask for it (ALPN `h2`; there is no HTTP/2 without
    TLS). Requires `tls`. TLS 1.2 is then restricted to the cipher suites HTTP/2 allows. Requests
    over HTTP/2 have `version = Http2` and lower-case header names; several requests run at once
    on one connection, and each is answered on its own. A server with HTTP/2 and no
    `maxConcurrentStreams` limits a client that keeps cancelling its requests only by a reset
    rate (about 1000 at once, then 33 per second): set `maxConcurrentStreams` on a public server.
  - `maxConnections`: the most connections open at once; further clients wait until one closes.
    `Nothing` (the default) sets no limit.
  - `maxConcurrentStreams`: the most HTTP/2 requests (including WebSockets) in progress at once on
    one connection, advertised to the client. Natively, requests your program has not answered
    yet count, even when the client cancelled them: at the limit the server reads nothing more
    from that connection until you answer one (on the JS target, Node refuses the streams over
    the limit instead). `Nothing` (the default) sets no limit; public servers should set one.
  - `maxBodySize`: the largest request body, in bytes (larger requests are answered 413).
  - `maxHeaderSize`: the largest request header block, in bytes (larger ones are answered 431).
  - `keepAliveTimeout`: how long an idle connection stays open between requests, in milliseconds.
  - `headersTimeout`: the time allowed from the first byte of a request to the end of its headers
    (408 when exceeded), in milliseconds.
  - `requestTimeout`: the time allowed from the first byte of a request to the end of its body
    (408 when exceeded), in milliseconds.

A timeout of 0 or less is no timeout. There is no time limit on your program's answer: the
connection waits for it (a client that gives up just closes the connection).

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


{-| Plain HTTP on an address and port, without connection or stream limits, with bodies up to
16 MiB, header blocks up to 64 KiB, a 5 second keep-alive timeout, a 60 second headers timeout and
a 300 second request timeout.

    Http.Server.defaultListenOptions (Socket.Address.loopback Socket.Address.IPv4) 8080

-}
defaultListenOptions : Address -> Int -> ListenOptions
defaultListenOptions =
    Debug.todo "Implement System API"


{-| Task to start a [`Server`](#Server) listening as the [`ListenOptions`](#ListenOptions) say.

Fails with an [`Error`](#Error): for example [`errorIsAddressInUse`](#errorIsAddressInUse) when the
port is taken, [`errorIsCertificateInvalid`](#errorIsCertificateInvalid) when the certificate or key
cannot be used, and `EINVAL` when `http2` is set without `tls`, and
with an `"ERR_SSL_"` code when the certificate or key cannot be used.

    let
        options =
            Http.Server.defaultListenOptions (Socket.Address.loopback Socket.Address.IPv4) 8443
    in
    Http.Server.listen
        { options | tls = Just { certificateChain = cert, privateKey = key, alpn = [] } }

-}
listen : ListenOptions -> Task Error Server
listen =
    Debug.todo "Implement System API"


{-| Task to start a [`Server`](#Server) listening on the given host name and port, with the limits
and timeouts of [`defaultListenOptions`](#defaultListenOptions). The name is resolved as with
[`Socket.lookup`](Socket#lookup), and an address literal such as `"127.0.0.1"` or `"::1"` is used
as it is; the empty string listens on all interfaces. Port 0 lets the system pick a free port
([`endpoint`](#endpoint) tells which).

    Http.Server.listenOnHost "localhost" 8080

A name that cannot be resolved fails with [`errorIsHostNotFound`](#errorIsHostNotFound). A
listening server keeps the program running until it is closed with [`close`](#close).

This was `createServer`.

-}
listenOnHost : String -> Int -> Task Error Server
listenOnHost =
    Debug.todo "Implement System API"


{-| The address and port a server listens on. For port 0 this is the port the system picked.
-}
endpoint : Server -> InetEndpoint
endpoint =
    Debug.todo "Implement System API"


{-| Stop a server gracefully, within 5 seconds: [`closeWithin`](#closeWithin) 5000.
-}
close : Server -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Stop a server gracefully, within the given number of milliseconds. The server stops accepting
connections at once (the port is free when the task completes) and closes its idle connections.
Requests that were received but not yet delivered are answered 503; requests already delivered can
still be answered (with `Connection: close`) until the deadline, when the remaining connections are
closed. WebSocket connections are not affected.

Closing a server twice is fine. A closed server no longer keeps the program running.

-}
closeWithin : Int -> Server -> Task x ()
closeWithin =
    Debug.todo "Implement System API"


{-| An incoming HTTP request.

  - `headers` holds the request headers. If a header appears more than once, the last value wins.
    Names are as the client sent them, which over HTTP/2 is always lower case: look headers up
    case-insensitively (or by their lower-case name). Over HTTP/2 the pseudo-header fields
    (`:method`, `:path`, ...) are not included, and several `cookie` fields are joined into one
    with `"; "`.
  - `method` is the HTTP method.
  - `body` is the complete request body.
  - `url` is the absolute URL of the request, built from the `Host` header (HTTP/2: `:authority`),
    or the server's own host and port, and the request target.
  - `version` is the HTTP version the client speaks.
  - `upgrade` is the protocol the client asks to switch to, lower-cased, for example
    `Just "websocket"` (the HTTP/1.1 `Upgrade` header, or HTTP/2's `:protocol`). Answer a WebSocket
    request with [`upgradeRequest`](#upgradeRequest); any other response refuses the upgrade.

-}
type alias Request =
    { headers : Dict String String
    , method : Method
    , body : Bytes
    , url : Url
    , version : HttpVersion
    , upgrade : Maybe String
    }


{-| The HTTP version of a request.
-}
type HttpVersion
    = Http1_0
    | Http1_1
    | Http2


{-| HTTP request methods. Methods not listed here are represented by `UNKNOWN`, holding the
method name as it was sent.
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


{-| String representation of a method, for example `"GET"`. `UNKNOWN m` becomes `m`.
-}
methodToString : Method -> String
methodToString =
    Debug.todo "Implement System API"


{-| Get the request body as a string. Returns `Nothing` if the body is not valid UTF-8.
-}
bodyAsString : Request -> Maybe String
bodyAsString =
    Debug.todo "Implement System API"


{-| Decode the request body as JSON. A body that is not valid UTF-8 is treated as the empty
string, so the decoder fails.
-}
bodyAsJson : Json.Decode.Decoder a -> Request -> Result Json.Decode.Error a
bodyAsJson =
    Debug.todo "Implement System API"


{-| Get a string representation of the request, for example `"GET http://localhost:8080/"`.

Good for logging. This was `requestInfo`.

-}
requestToString : Request -> String
requestToString =
    Debug.todo "Implement System API"


{-| Subscribe to incoming HTTP requests on a server. For every request you receive the
[`Request`](#Request) and a fresh [`Response`](#Response) that answers it.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Http.Server.onRequest model.server GotRequest

-}
onRequest : Server -> (Request -> Response -> msg) -> Sub msg
onRequest =
    Debug.todo "Implement System API"


{-| An HTTP response to a single request. You receive one from
[`onRequest`](#onRequest) together with the request it answers.
-}
type Response
    = Response


{-| Command to send an HTTP response.

The response is written with a `Content-Length` header and the connection is closed afterwards.
Send each response only once. An HTML body (see [`setBodyAsHtml`](#setBodyAsHtml)) is serialized
as it is sent.

-}
send : Response -> Cmd msg
send =
    Debug.todo "Implement System API"


{-| Set the HTTP status code of a response.

    response |> Http.Server.setStatus 404

-}
setStatus : Int -> Response -> Response
setStatus =
    Debug.todo "Implement System API"


{-| Set a header on a response, replacing any values it already has.
-}
setHeader : String -> String -> Response -> Response
setHeader =
    Debug.todo "Implement System API"


{-| Append a value to an existing header. If the header does not exist yet, it will be created.
Use this for headers that may appear more than once, such as `Set-Cookie`.
-}
appendHeader : String -> String -> Response -> Response
appendHeader =
    Debug.todo "Implement System API"


{-| Alias for [`setBodyAsString`](#setBodyAsString).
-}
setBody : String -> Response -> Response
setBody =
    Debug.todo "Implement System API"


{-| Set the body of the response to a string. It is sent encoded as UTF-8.
-}
setBodyAsString : String -> Response -> Response
setBodyAsString =
    Debug.todo "Implement System API"


{-| Set the body of the response to some bytes.
-}
setBodyAsBytes : Bytes -> Response -> Response
setBodyAsBytes =
    Debug.todo "Implement System API"


{-| Set the body of the response to an HTML page or fragment built with
[elm/html](/packages/elm/html/latest/) (or `Svg`).

    response
        |> Http.Server.setBodyAsHtml
            (Html.node "html" [] [ Html.node "body" [] [ Html.text "Hello!" ] ])
        |> Http.Server.send

When the response is sent:

  - the HTML is serialized as [`Html.Dom.htmlToString`](Html-Dom#htmlToString) does, straight into the
    response (natively no `String` is built);
  - `<!DOCTYPE html>` is written first when the root element is `html`;
  - `Content-Type: text/html; charset=utf-8` is added unless the response already has a
    Content-Type header.

-}
setBodyAsHtml : VirtualDom.Node msg -> Response -> Response
setBodyAsHtml =
    Debug.todo "Implement System API"


{-| Answer a WebSocket opening request (a [`Request`](#Request) whose `upgrade` is
`Just "websocket"`, over HTTP/1.1 or HTTP/2) instead of sending its
[`Response`](#Response): the result is a
[`WebSocket.Upgrade`](WebSocket#Upgrade), to answer with
[`WebSocket.accept`](WebSocket#accept) or [`WebSocket.reject`](WebSocket#reject). The `Response`
is used up: sending it later does nothing.

    GotRequest request response ->
        if request.upgrade == Just "websocket" then
            ( model
            , Http.Server.upgradeRequest request response
                |> Task.andThen (WebSocket.accept WebSocket.defaultAcceptOptions)
                |> Task.attempt GotWebSocket
            )

        else
            ...

The opening request is checked by `WebSocket.accept` (which answers a request that breaks the
rules 400 or 426 itself), exactly as for [`WebSocket.receiveUpgrade`](WebSocket#receiveUpgrade).
Requests the client sent before this one on the same connection are answered first: the `101`
follows their responses. Over TLS the result is a `wss` WebSocket.

Over HTTP/2 (RFC 8441: an extended `CONNECT` with `:protocol websocket`, which a server with
`http2` allows) the WebSocket runs on that one stream of the connection, next to the connection's
other requests and WebSockets: `accept` answers `200` and the stream carries the frames; the close
handshake ends the stream (`END_STREAM`) and an aborted WebSocket resets it (`CANCEL`). Such a
WebSocket counts against `maxConcurrentStreams` like any request, when it is set. Another
`:protocol` is answered `501` by the server itself.

The WebSocket does not belong to the server: [`close`](#close) leaves it open (over
HTTP/2, until the close deadline, which ends the connection it shares).

Fails with `EINVAL` when the request does not ask for a WebSocket, or was already answered (or
upgraded), and with `ECANCELED` when its connection is gone.

-}
upgradeRequest : Request -> Response -> Task Socket.Error WebSocket.Upgrade
upgradeRequest =
    Debug.todo "Implement System API"

{-| An error from starting a server: the error code (an errno name such as `"EADDRINUSE"`, a
resolver code, or an `"ERR_SSL_"` code for a certificate or key that cannot be used) and a human
readable message. Use the `errorIs…` functions below to check for the common cases.

This replaces gren-node's `ServerError` constructor.

-}
type Error
    = Error


{-| The error code, for example `"EADDRINUSE"`.
-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| A human readable description of the error: the code, `": "`, and a message.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| `True` if the port is already in use (`EADDRINUSE`).
-}
errorIsAddressInUse : Error -> Bool
errorIsAddressInUse =
    Debug.todo "Implement System API"


{-| `True` if the address cannot be used here (`EADDRNOTAVAIL`, `EAFNOSUPPORT`): it does not belong
to this machine, or the system does not support its family.
-}
errorIsAddressNotAvailable : Error -> Bool
errorIsAddressNotAvailable =
    Debug.todo "Implement System API"


{-| `True` if the host name given to [`listenOnHost`](#listenOnHost) could not be resolved
(`ENOTFOUND`, `EAI_AGAIN`, `EAI_FAIL`).
-}
errorIsHostNotFound : Error -> Bool
errorIsHostNotFound =
    Debug.todo "Implement System API"


{-| `True` if the operating system refused to listen (`EACCES`, `EPERM`), for example on a
privileged port.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| `True` if the TLS certificate chain or private key cannot be used (an `"ERR_SSL_"` code).
-}
errorIsCertificateInvalid : Error -> Bool
errorIsCertificateInvalid =
    Debug.todo "Implement System API"

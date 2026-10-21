module Socket exposing
    ( Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset
    , Listener, listenerEndpoint, accept, onConnection, closeListener
    , lookup
    , Error, ErrorKind(..), errorKind, errorToString, fromStreamFailure
    )

{-| Whatever made a stream socket, TCP, Unix domain or TLS, the program uses it in the same way,
and this module is that common part: connections, listeners, name lookup and the socket error.

A [`Connection`](#Connection) is two byte streams, one carrying what the peer sends and one
carrying what is sent to it. Making a connection or a listener depends on its kind, and each
kind has its own module for that:

  - [`Socket.Tcp`](Socket-Tcp) connects to and listens on IPv4 and IPv6 addresses;
  - [`Socket.Unix`](Socket-Unix) connects to and listens on Unix domain socket paths;
  - [`Socket.Tls`](Socket-Tls) adds TLS encryption to TCP.

[`Socket.Udp`](Socket-Udp) sends and receives datagrams instead of streams, but its failures
are this module's [`Error`](#Error) too. Addresses and endpoints are described in
[`Socket.Address`](Socket-Address). Several of these modules define functions with the same
names, such as `close` and `listen`, so import them qualified:

    import Socket
    import Socket.Tcp

Once a connection exists, everything that happens to its data happens on its streams, and a
failure there is a `Stream.Error`, as the [`Stream`](Stream) module describes. When the
connection itself fails, a read or write fails with `Stream.Failed`, and
[`fromStreamFailure`](#fromStreamFailure) reads that failure back as an [`Error`](#Error); a
connection reset, for example, is a read whose failure has the kind
[`ConnectionReset`](#ErrorKind). This module's `Error` is otherwise for tasks such as
connecting, listening, accepting and looking up names.
Ending one direction only, by closing the writable while the readable stays open, is a
_half-close_: the peer reads to the end of the data and can still reply. A connection is
released once both of its streams have ended, or at once by [`close`](#close) or
[`reset`](#reset); a connection that the program simply forgets is not closed for it. An open connection on which no operation is waiting does not keep the
program running; an open [`Listener`](#Listener) keeps it running only while an
[`accept`](#accept) is waiting or an [`onConnection`](#onConnection) subscription exists. Held
connections do not keep it running.

A listener hands out the connections that clients make to it, through [`accept`](#accept) and
[`onConnection`](#onConnection), by one rule. A new connection goes to the oldest waiting
`accept` (a _parked_ accept); if there is none, to every `onConnection` subscription to that
listener, all of which receive the same `Connection`; and if there is neither, it is _held_
until the next `accept` or subscription, which takes the held connections oldest first. Where a
held connection waits depends on the backend. On the JavaScript backend the kernel accepts every
connection at once and holds up to the listener's `backlog`, at least 1 (511 for a Unix domain
listener), closing the newest beyond that. On the native backend a listener accepts only while
an `accept` is parked or a subscription exists, so a connection that arrives while there is
neither waits in the operating system's listen queue.

On native Windows, sockets are not supported: lookup, connecting and listening fail with
[`NotSupported`](#ErrorKind), and an `onConnection` subscription is a fatal error.


## Connections

@docs Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset


## Listeners

@docs Listener, listenerEndpoint, accept, onConnection, closeListener


## Name lookup

@docs lookup


## Errors

[`Error`](#Error) is the failure of the transports: TCP, Unix domain sockets and UDP. A program
matches on its [`ErrorKind`](#ErrorKind), so that it need not depend on the exact code an
operating system or a backend uses. TLS and WebSocket are protocols layered on a socket, and
each has its own error type that wraps this one: [`Socket.Tls.Error`](Socket-Tls#Error) and
[`WebSocket.Error`](WebSocket#Error).

@docs Error, ErrorKind, errorKind, errorToString, fromStreamFailure

-}

import Socket.Internal
import Bytes exposing (Bytes)
import Dict exposing (Dict)
import FileSystem
import Platform
import Process
import Socket.Address exposing (Address, Endpoint)
import Stream
import Task exposing (Task)


{-| An open stream connection to a peer, over TCP, a Unix domain socket or TLS.

A connection is made by `Socket.Tcp.connect`, `Socket.Tcp.connectToHost`, `Socket.Unix.connect`
or `Socket.Tls.connect`, or received from a [`Listener`](#Listener). Read what the peer sends
from [`readable`](#readable) and send by writing to [`writable`](#writable). On a TLS
connection both streams carry the plaintext, and their failures are read with
[`Socket.Tls.fromStreamFailure`](Socket-Tls#fromStreamFailure), which also covers the failures
of the connection under TLS.

-}
type alias Connection =
    Socket.Internal.Connection


{-| Returns the stream of bytes the peer sends. A read fails with `Stream.Closed` once the peer
has finished sending and everything it sent has been read.

A read that fails because of the connection fails with `Stream.Failed`, and
[`fromStreamFailure`](#fromStreamFailure) gives the [`Error`](#Error): for example the kind
[`ConnectionReset`](#ErrorKind) when the peer reset the connection, [`Cancelled`](#ErrorKind)
after [`close`](#close) or [`reset`](#reset), and [`ConnectionTakenOver`](#ErrorKind) once
`WebSocket.receiveUpgrade` has taken the connection over.

-}
readable : Connection -> Stream.Readable Bytes
readable =
    Debug.todo "Implement System API"


{-| Returns the stream of bytes sent to the peer.

Closing it with `Stream.closeWritable` sends the end of the data (on a TLS connection, a TLS
`close_notify` and then the end of the data) once everything written before it has been passed
on, and leaves the readable open: a half-close. A write that fails because of the connection
fails with `Stream.Failed`, and [`fromStreamFailure`](#fromStreamFailure) gives the
[`Error`](#Error): for example the kind [`ConnectionReset`](#ErrorKind) when the peer is gone
(EPIPE), or [`Cancelled`](#ErrorKind) after [`close`](#close) or [`reset`](#reset).

-}
writable : Connection -> Stream.Writable Bytes
writable =
    Debug.todo "Implement System API"


{-| Returns this end of the connection, as it was when the connection was made.

On a Unix domain connection the server side's local endpoint is the path its listener listens on,
and the client side's is the empty path. An IP address whose text from the kernel does not parse
becomes the unspecified address; for example, on the JavaScript backend an address Node does not
report is `0.0.0.0` with port 0.

-}
localEndpoint : Connection -> Endpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| Returns the peer's end of the connection, as it was when the connection was made.

On a Unix domain connection the client side's remote endpoint is the path it connected to, and
the server side's is the empty path. As for [`localEndpoint`](#localEndpoint), an IP address whose
text from the kernel does not parse becomes the unspecified address.

-}
remoteEndpoint : Connection -> Endpoint
remoteEndpoint =
    Debug.todo "Implement System API"


{-| Closes the connection at once, without waiting for either stream to end.

Reads and writes waiting on its streams fail with `Stream.Failed`, a failure whose
[`Error`](#Error) has the kind [`Cancelled`](#ErrorKind), and so do later ones on a stream that
had not already ended. Bytes still queued in the writable are
dropped; the socket is closed, and what the operating system has already taken is left to it to
send. On Linux a socket closed with received data that was never read sends the peer a reset
instead of the end of the data. A TLS connection is closed without a TLS `close_notify`.

Closing a connection that is already closed does nothing. For an orderly end, close the
[`writable`](#writable) and read the [`readable`](#readable) to its end instead.

-}
close : Connection -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Aborts the connection: as [`close`](#close), except that a TCP or TLS connection is closed
with a TCP reset (RST), which discards whatever the operating system has not yet sent. On a Unix
domain connection this is the same as `close`.
-}
reset : Connection -> Task x ()
reset =
    Debug.todo "Implement System API"


{-| A socket that receives the connections clients make to an address or a Unix domain socket
path. A listener is made by `Socket.Tcp.listen`, `Socket.Unix.listen` or `Socket.Tls.listen`, and
its connections are handed out by [`accept`](#accept) and [`onConnection`](#onConnection) as
the module documentation describes.

An open listener keeps the program running only while an `accept` on it is waiting or an
`onConnection` subscription to it exists.

-}
type alias Listener =
    Socket.Internal.Listener


{-| Returns the endpoint the listener is bound to. For a listener on port 0, its port is the one
the operating system chose.
-}
listenerEndpoint : Listener -> Endpoint
listenerEndpoint =
    Debug.todo "Implement System API"


{-| Waits for the listener's next connection.

A held connection, the oldest first, is returned at once. Otherwise the task is parked, and a
new connection goes to the oldest parked `accept` before any [`onConnection`](#onConnection)
subscription sees it.

Fails with [`Cancelled`](#ErrorKind) when the listener is closed while the task waits, and at
once on a listener that is already closed. A TLS listener closes a client whose handshake fails
without handing it out, so `accept` never fails because of TLS.

-}
accept : Listener -> Task Error Connection
accept =
    Debug.todo "Implement System API"


{-| Creates a subscription to the connections the listener receives that no parked
[`accept`](#accept) takes, including those held before the subscription started.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Socket.onConnection model.listener GotConnection

Every subscription to the same listener receives the same `Connection`, and so the same
streams, so subscribe once per listener. A subscription to a closed listener never fires.

-}
onConnection : Listener -> (Connection -> msg) -> Sub msg
onConnection =
    Debug.todo "Implement System API"


{-| Stops listening.

Parked [`accept`](#accept) tasks fail with [`Cancelled`](#ErrorKind), and connections the listener received
but has not handed out are closed. Connections already handed out stay open. The task succeeds
once the listening socket has been closed, so the address can be listened on again at once; a
Unix domain listener removes its socket file first.

Closing a listener that is already closed does nothing.

-}
closeListener : Listener -> Task Error ()
closeListener =
    Debug.todo "Implement System API"


{-| Looks up the IP addresses of a host name, in the order the system resolver returns them,
with duplicates removed.

    Socket.lookup "localhost"

An IP address literal such as `"127.0.0.1"` gives that address. A name with no addresses fails
with [`HostNotFound`](#ErrorKind), and so does `""`, without asking the resolver. A temporary
failure of the resolver fails with [`HostLookupTryAgain`](#ErrorKind).

-}
lookup : String -> Task Error (List Address)
lookup =
    Debug.todo "Implement System API"


{-| A failed socket operation: what kind of failure it was, and a message for people to read.

This is the error of the transports: this module, [`Socket.Tcp`](Socket-Tcp),
[`Socket.Unix`](Socket-Unix) and [`Socket.Udp`](Socket-Udp). TCP, Unix domain sockets and UDP
are alternative transports that share one connection type and the functions of this module, so
they share this one error, and each of them meets only some of its kinds.

Protocols layered on a socket have their own error types, which wrap this one:
[`Socket.Tls.Error`](Socket-Tls#Error) has a `SocketError` case for failures below TLS, and
[`WebSocket.Error`](WebSocket#Error) one for failures below the WebSocket. `Http.Server.Error`,
the failure to start a server, is a separate type.

Read the kind with [`errorKind`](#errorKind) and the description with
[`errorToString`](#errorToString).

-}
type alias Error =
    Socket.Internal.Error


{-| What kind of failure an [`Error`](#Error) is.

Most kinds stand for an operating system error, whose name is given in parentheses. Which name a
failure gets can depend on the operating system and the backend, and a kind may stand for more
than one of them, so that a program need not tell them apart.

  - `ConnectionRefused`: nothing listens at the address connected to (ECONNREFUSED). For a Unix
    domain socket, a socket file exists at the path but nobody listens on it.
  - `ConnectionReset`: the peer reset the connection or is gone (ECONNRESET, EPIPE). A connection
    that is reset after it has been handed out fails on its streams instead, with a failure that
    [`fromStreamFailure`](#fromStreamFailure) reads as this kind.
  - `TimedOut`: the operation took too long (ETIMEDOUT), for example a connect that ran past its
    `timeout`.
  - `NetworkUnreachable`: no route leads to the network or the host (ENETUNREACH,
    EHOSTUNREACH).
  - `AddressInUse`: the address is already in use (EADDRINUSE), for example by another listener.
    For a Unix domain socket, something already exists at the path.
  - `AddressNotAvailable`: the address cannot be used here (EADDRNOTAVAIL, EAFNOSUPPORT): it
    does not belong to this machine, or its address family cannot be used, as when an IPv6
    destination is given to an IPv4 UDP socket.
  - `HostNotFound`: a host name could not be resolved (ENOTFOUND, EAI_FAIL).
  - `HostLookupTryAgain`: the resolver failed for now and the lookup may succeed if tried again
    (EAI_AGAIN).
  - `PermissionDenied`: the operating system refused the operation (EACCES, EPERM), for example
    listening on a privileged port, or broadcasting a UDP datagram without `broadcast = True`.
    A Unix domain socket path that cannot be used for lack of permission is an
    `AddressPathFailed` instead.
  - `Cancelled`: the operation was cancelled (ECANCELED), for example an [`accept`](#accept)
    whose listener was closed, or a read on a connection closed with [`close`](#close).
  - `Busy`: something else is using the resource (EBUSY), for example a stream that a waiting
    read or write holds.
  - `InvalidInput`: an argument cannot be used (EINVAL), for example the peer credentials of a
    connection that is not a Unix domain connection.
  - `NotSupported`: the operation is not supported here (ENOTSUP), for example any socket on
    native Windows, or reading peer credentials where the system cannot.
  - `MessageTooLarge`: a UDP datagram is too large to send (EMSGSIZE).
  - `ListenQueueFull`: the operating system's queue of connections waiting on a listener is full
    (EAGAIN), as when connecting to a Unix domain socket on Linux.
  - `AddressPathFailed kind`: a Unix domain socket's path failed as a file path would, with the
    [`FileSystem.ErrorKind`](FileSystem#ErrorKind) it would have there:
    `NoSuchFileOrDirectory` (ENOENT: nothing at the path on connect, a missing parent directory
    on listen), `NotADirectory` (ENOTDIR), `LinkLoop` (ELOOP), `ReadOnlyFileSystem` (EROFS),
    `PathTooLong` (ENAMETOOLONG: longer than 107 bytes on Linux, 103 on macOS), or
    `PermissionDenied` (EACCES on the socket file or its directory).
  - `ConnectionTakenOver`: the connection's streams were taken over by another owner, such as
    `WebSocket.receiveUpgrade`; only stream failures have this kind.
  - `OtherSocketError code`: any other failure, with its code as the backend reports it, usually
    the name of an operating system error.

-}
type ErrorKind
    = ConnectionRefused
    | ConnectionReset
    | TimedOut
    | NetworkUnreachable
    | AddressInUse
    | AddressNotAvailable
    | HostNotFound
    | HostLookupTryAgain
    | PermissionDenied
    | Cancelled
    | Busy
    | InvalidInput
    | NotSupported
    | MessageTooLarge
    | ListenQueueFull
    | AddressPathFailed FileSystem.ErrorKind
    | ConnectionTakenOver
    | OtherSocketError String


{-| Returns the kind of the error.

    case Socket.errorKind error of
        Socket.ConnectionRefused ->
            "nobody is listening"

        Socket.TimedOut ->
            "no answer in time"

        _ ->
            Socket.errorToString error

-}
errorKind : Error -> ErrorKind
errorKind =
    Debug.todo "Implement System API"


{-| Returns a description of the error for people to read: the code the backend reported,
`": "`, and the message, as in `"ECONNREFUSED: connect ECONNREFUSED 127.0.0.1:4000"`.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| Reads the failure of a socket connection's stream back as an [`Error`](#Error), or returns
`Nothing` for a failure that some other kind of stream made.

A read or write on a connection's [`readable`](#readable) or [`writable`](#writable) that fails
because of the connection fails with `Stream.Failed`, and this gives its error, for example:

  - the kind [`ConnectionReset`](#ErrorKind) when the peer reset the connection or is gone;
  - [`Cancelled`](#ErrorKind) after [`close`](#close) or [`reset`](#reset);
  - [`ConnectionTakenOver`](#ErrorKind) once `WebSocket.receiveUpgrade` has taken the
    connection over.

    case error of
        Stream.Failed failure ->
            case Socket.fromStreamFailure failure of
                Just socketError ->
                    Socket.errorToString socketError

                Nothing ->
                    Stream.failureToString failure

        _ ->
            Stream.errorToString error

On a TLS connection, use [`Socket.Tls.fromStreamFailure`](Socket-Tls#fromStreamFailure), which
reads both the failures of TLS and those of the connection under it.

-}
fromStreamFailure : Stream.Failure -> Maybe Error
fromStreamFailure =
    Debug.todo "Implement System API"

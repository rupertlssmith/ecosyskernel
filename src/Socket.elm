module Socket exposing
    ( Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset
    , Listener, listenerEndpoint, accept, onConnection, closeListener
    , lookup
    , Error, errorCode, errorToString
    , errorIsConnectionRefused, errorIsConnectionReset, errorIsTimedOut, errorIsAddressInUse
    , errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCancelled
    , errorIsCertificateInvalid
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
are this module's [`Error`](#Error). Addresses and endpoints are described in
[`Socket.Address`](Socket-Address). Several of these modules define functions with the same
names, such as `close` and `listen`, so import them qualified:

    import Socket
    import Socket.Tcp

Once a connection exists, everything that happens to its data happens on its streams, and a
failure there is a `Stream.Error`, as the [`Stream`](Stream) module describes; a connection
reset, for example, is a read that fails with `Stream.Cancelled "read ECONNRESET"`. This
module's `Error` is for tasks such as connecting, listening, accepting and looking up names.
Ending one direction only, by closing the writable while the readable stays open, is a
_half-close_: the peer reads to the end of the data and can still reply. A connection is
released once both of its streams have ended, or at once by [`close`](#close) or
[`reset`](#reset); a connection that the program simply forgets is not closed for it. An open connection on which no operation is waiting does not keep the
program running; an open [`Listener`](#Listener) keeps it running until it is closed.

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
`ENOTSUP`, and an `onConnection` subscription is a fatal error.


## Connections

@docs Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset


## Listeners

@docs Listener, listenerEndpoint, accept, onConnection, closeListener


## Name lookup

@docs lookup


## Errors

@docs Error, errorCode, errorToString

The predicates classify an error by its code, so that a program need not depend on the exact
code an operating system or a backend uses.

@docs errorIsConnectionRefused, errorIsConnectionReset, errorIsTimedOut, errorIsAddressInUse
@docs errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCancelled
@docs errorIsCertificateInvalid

-}

import Socket.Internal
import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Platform
import Process
import Socket.Address exposing (Address, Endpoint)
import Stream
import Task exposing (Task)


{-| An open stream connection to a peer, over TCP, a Unix domain socket or TLS.

A connection is made by `Socket.Tcp.connect`, `Socket.Tcp.connectToHost`, `Socket.Unix.connect`
or `Socket.Tls.connect`, or received from a [`Listener`](#Listener). Read what the peer sends
from [`readable`](#readable) and send by writing to [`writable`](#writable). On a TLS
connection both streams carry the plaintext.

-}
type alias Connection =
    Socket.Internal.Connection


{-| Returns the stream of bytes the peer sends. A read fails with `Stream.Closed` once the peer
has finished sending and everything it sent has been read.

A read that fails because of the connection fails with `Stream.Cancelled` and a reason naming
the problem, for example `"read ECONNRESET"` when the operating system reports an error, or
`"socket closed"` after [`close`](#close) or [`reset`](#reset).

-}
readable : Connection -> Stream.Readable Bytes
readable =
    Debug.todo "Implement System API"


{-| Returns the stream of bytes sent to the peer.

Closing it with `Stream.closeWritable` sends the end of the data (on a TLS connection, a TLS
`close_notify` and then the end of the data) once everything written before it has been passed
on, and leaves the readable open: a half-close. A write that fails fails with `Stream.Cancelled`
and a reason naming the problem, for example `"write EPIPE"` when the operating system reports
an error, or `"socket closed"` after [`close`](#close) or [`reset`](#reset).

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

Reads and writes waiting on its streams fail with `Stream.Cancelled "socket closed"`, and so do
later ones on a stream that had not already ended. Bytes still queued in the writable are
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

An open listener keeps the program running until it is closed with
[`closeListener`](#closeListener).

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

Fails with `ECANCELED` ([`errorIsCancelled`](#errorIsCancelled)) when the listener is closed
while the task waits, and at once on a listener that is already closed.

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

Parked [`accept`](#accept) tasks fail with `ECANCELED`, and connections the listener received
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
with `ENOTFOUND` ([`errorIsHostNotFound`](#errorIsHostNotFound)), and so does `""`, without
asking the resolver.

-}
lookup : String -> Task Error (List Address)
lookup =
    Debug.todo "Implement System API"


{-| A failed socket operation: a code saying what went wrong and a message for people to read.

The code is usually the name of an operating system error, such as `"ECONNREFUSED"`. A failed
name lookup has a resolver code such as `"ENOTFOUND"` or `"EAI_AGAIN"`, and a rejected TLS
certificate a verification code such as `"CERT_HAS_EXPIRED"`. Some codes are made by Elm code
in this package rather than by a kernel, as the modules that make them say.

This is also the error of `Socket.Tcp`, `Socket.Unix`, `Socket.Udp`, `Socket.Tls`, `WebSocket`
and `Http.Server.upgradeRequest`. It is not `Http.Server.Error`, which is a separate type.

-}
type alias Error =
    Socket.Internal.Error


{-| Returns the error's code, for example `"ECONNREFUSED"`.
-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| Returns a description of the error for people to read: the code, `": "`, and the message,
as in `"ECONNREFUSED: connect ECONNREFUSED 127.0.0.1:4000"`.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| Returns `True` when nothing listens at the address connected to (`ECONNREFUSED`).
-}
errorIsConnectionRefused : Error -> Bool
errorIsConnectionRefused =
    Debug.todo "Implement System API"


{-| Returns `True` when the peer reset the connection or is gone (`ECONNRESET`, `EPIPE`).

A connection that is reset after it has been handed out fails on its streams instead, with a
`Stream.Cancelled` reason such as `"read ECONNRESET"`, which this does not see.

-}
errorIsConnectionReset : Error -> Bool
errorIsConnectionReset =
    Debug.todo "Implement System API"


{-| Returns `True` when the operation took too long (`ETIMEDOUT`), for example a connect that
ran past its `timeout`.
-}
errorIsTimedOut : Error -> Bool
errorIsTimedOut =
    Debug.todo "Implement System API"


{-| Returns `True` when the address is already in use (`EADDRINUSE`), for example by another
listener.
-}
errorIsAddressInUse : Error -> Bool
errorIsAddressInUse =
    Debug.todo "Implement System API"


{-| Returns `True` when the address cannot be used here (`EADDRNOTAVAIL`, `EAFNOSUPPORT`): it
does not belong to this machine, or its address family cannot be used, as when an IPv6
destination is given to an IPv4 UDP socket.
-}
errorIsAddressNotAvailable : Error -> Bool
errorIsAddressNotAvailable =
    Debug.todo "Implement System API"


{-| Returns `True` when a host name could not be resolved (`ENOTFOUND`, `EAI_AGAIN`,
`EAI_FAIL`).
-}
errorIsHostNotFound : Error -> Bool
errorIsHostNotFound =
    Debug.todo "Implement System API"


{-| Returns `True` when the operating system refused the operation (`EACCES`, `EPERM`), for
example listening on a privileged port, or broadcasting a UDP datagram without
`broadcast = True`.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| Returns `True` when the operation was cancelled (`ECANCELED`), for example an
[`accept`](#accept) whose listener was closed.
-}
errorIsCancelled : Error -> Bool
errorIsCancelled =
    Debug.todo "Implement System API"


{-| Returns `True` when a TLS peer's certificate was rejected: it has expired or is not yet valid,
it is self-signed or signed by an authority that is not trusted, it was revoked, it does not
match the server name, or it failed verification for another reason.

It is `False` for other TLS failures, such as those whose codes start with `ERR_SSL_`.
`Http.Server.errorIsCertificateInvalid`, a predicate on `Http.Server.Error`, means something
else: any `ERR_SSL_` code.

-}
errorIsCertificateInvalid : Error -> Bool
errorIsCertificateInvalid =
    Debug.todo "Implement System API"

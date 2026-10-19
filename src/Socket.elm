module Socket exposing
    ( Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset
    , Listener, listenerEndpoint, accept, onConnection, closeListener
    , lookup
    , Error, errorCode, errorToString
    , errorIsConnectionRefused, errorIsConnectionReset, errorIsTimedOut, errorIsAddressInUse
    , errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCancelled
    , errorIsCertificateInvalid
    )

{-| Stream sockets: connections, listeners and name lookup.

A [`Connection`](#Connection) is a pair of byte streams, one to read what the peer sends and one
to write to it. TCP, Unix domain and TLS connections are all `Connection`s; only creating them is
specific to each kind:

  - [`Socket.Tcp`](Socket-Tcp) connects to and listens on IPv4 and IPv6 addresses;
  - [`Socket.Unix`](Socket-Unix) connects to and listens on Unix domain socket paths;
  - [`Socket.Tls`](Socket-Tls) adds TLS encryption to TCP;
  - [`Socket.Udp`](Socket-Udp) sends and receives datagrams instead.

Addresses and endpoints are described in [`Socket.Address`](Socket-Address).

Several modules define functions such as `close` and `localEndpoint`, so import them qualified:

    import Socket
    import Socket.Tcp

A connection holds operating system resources until it is closed with [`close`](#close) or
[`reset`](#reset), or until both of its streams are finished (its readable read to the end and
its writable closed). A connection that the program simply forgets stays open until the program
ends.


## Connections

@docs Connection, readable, writable, localEndpoint, remoteEndpoint, close, reset


## Listeners

@docs Listener, listenerEndpoint, accept, onConnection, closeListener


## Name lookup

@docs lookup


## Errors

@docs Error, errorCode, errorToString
@docs errorIsConnectionRefused, errorIsConnectionReset, errorIsTimedOut, errorIsAddressInUse
@docs errorIsAddressNotAvailable, errorIsHostNotFound, errorIsPermissionDenied, errorIsCancelled
@docs errorIsCertificateInvalid

-}

import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Platform
import Process
import Socket.Address exposing (Address, Endpoint)
import Stream
import Task exposing (Task)


{-| An open stream connection: TCP, Unix domain or TLS.

Read what the peer sends from [`readable`](#readable) until it is `Closed`, and send data by
writing to [`writable`](#writable). Closing the writable with `Stream.closeWritable` ends the
sending direction only (a half-close: the peer reads to the end, and can still reply); the
connection is finished once both directions are.

-}
type Connection
    = Connection


{-| The stream of bytes the peer sends. It is `Closed` when the peer has finished sending.

A failed read is a `Stream.Cancelled` error whose reason names the problem, for example
`"read ECONNRESET"` when the peer reset the connection.

-}
readable : Connection -> Stream.Readable Bytes
readable =
    Debug.todo "Implement System API"


{-| The stream of bytes sent to the peer. Closing it sends the end of the data (TCP's FIN; on a
TLS connection, a TLS `close_notify` first), after everything written before has been handed to
the operating system.

A failed write is a `Stream.Cancelled` error whose reason names the problem, for example
`"write EPIPE"`.

-}
writable : Connection -> Stream.Writable Bytes
writable =
    Debug.todo "Implement System API"


{-| This end of the connection.

For a Unix domain connection, the server side's local endpoint is the path it listens on and the
client side's is the empty path.

-}
localEndpoint : Connection -> Endpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| The peer's end of the connection.

For a Unix domain connection, the client side sees the path it connected to and the server side
the empty path.

-}
remoteEndpoint : Connection -> Endpoint
remoteEndpoint =
    Debug.todo "Implement System API"


{-| Close the connection now, without waiting for the peer.

Data not yet handed to the operating system is dropped: pending writes fail with the reason
`"socket closed"`, and so do pending reads and every later operation on the two streams. Data the
operating system already accepted is still sent, followed by the end of the data. (On Linux, if
data from the peer was received but not read, the peer gets a reset instead.) A TLS connection is
closed without a TLS `close_notify`.

Closing a connection twice is fine. For an orderly end, close the [`writable`](#writable) and read
the [`readable`](#readable) to the end instead.

-}
close : Connection -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Abort the connection: like [`close`](#close), but the operating system discards the data it
still holds and sends a reset, so the peer's next operation fails with `ECONNRESET`. On a Unix
domain connection this is the same as `close`.
-}
reset : Connection -> Task x ()
reset =
    Debug.todo "Implement System API"


{-| A socket that accepts incoming connections, created by `Socket.Tcp.listen`,
`Socket.Unix.listen` or `Socket.Tls.listen`.

An open listener keeps the program running until it is closed with
[`closeListener`](#closeListener).

-}
type Listener
    = Listener


{-| The endpoint a listener is bound to. When listening on port 0, this tells which port the
operating system picked.
-}
listenerEndpoint : Listener -> Endpoint
listenerEndpoint =
    Debug.todo "Implement System API"


{-| Wait for the next incoming connection.

Connections are handed out in the order they arrive: a connection that arrived while nobody was
accepting or subscribed is held and given to the next `accept` (or [`onConnection`](#onConnection)
subscription). When `accept` tasks are waiting and a subscription exists too, a new connection
goes to the oldest waiting `accept`.

Fails with `ECANCELED` ([`errorIsCancelled`](#errorIsCancelled)) when the listener is closed.

-}
accept : Listener -> Task Error Connection
accept =
    Debug.todo "Implement System API"


{-| Subscribe to the connections a listener accepts.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Socket.onConnection model.listener GotConnection

Subscribe once per listener: every subscription to the same listener receives the same
`Connection`, and a connection must only be used by one part of the program. A subscription to a
closed listener never fires.

-}
onConnection : Listener -> (Connection -> msg) -> Sub msg
onConnection =
    Debug.todo "Implement System API"


{-| Stop listening. Waiting [`accept`](#accept) tasks fail with `ECANCELED`, connections that were
received but not yet handed out are closed, and the task completes once the address is free again
(so it can be listened on at once). A Unix domain listener removes its socket file.

Closing a listener twice is fine.

-}
closeListener : Listener -> Task Error ()
closeListener =
    Debug.todo "Implement System API"


{-| Find the addresses of a host name, in the order the system resolver returns them (as
`getaddrinfo` does: `/etc/hosts`, DNS, ...). Duplicates are removed.

    Socket.lookup "localhost"

An address literal resolves to itself. A name that does not exist fails with `ENOTFOUND`
([`errorIsHostNotFound`](#errorIsHostNotFound)); so does `""`.

-}
lookup : String -> Task Error (List Address)
lookup =
    Debug.todo "Implement System API"


{-| A socket error: an error code and a message.

The code is usually the name of an operating system error such as `"ECONNREFUSED"`; name lookup
uses `"ENOTFOUND"`, `"EAI_AGAIN"` and `"EAI_FAIL"`, and TLS uses codes such as
`"CERT_HAS_EXPIRED"`. Use the predicates below to classify an error without depending on the exact
code.

-}
type Error
    = Error


{-| The error code, for example `"ECONNREFUSED"`.
-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| A human readable description of the error: the code, `": "`, and a message such as
`"connect ECONNREFUSED 127.0.0.1:4000"`.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| `True` if nothing listens at the address (`ECONNREFUSED`).
-}
errorIsConnectionRefused : Error -> Bool
errorIsConnectionRefused =
    Debug.todo "Implement System API"


{-| `True` if the peer reset the connection or is gone (`ECONNRESET`, `EPIPE`).
-}
errorIsConnectionReset : Error -> Bool
errorIsConnectionReset =
    Debug.todo "Implement System API"


{-| `True` if the operation took too long (`ETIMEDOUT`), for example a connect with a `timeout`.
-}
errorIsTimedOut : Error -> Bool
errorIsTimedOut =
    Debug.todo "Implement System API"


{-| `True` if the address is already in use (`EADDRINUSE`), for example by another listener.
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


{-| `True` if a host name could not be resolved (`ENOTFOUND`, `EAI_AGAIN`, `EAI_FAIL`).
-}
errorIsHostNotFound : Error -> Bool
errorIsHostNotFound =
    Debug.todo "Implement System API"


{-| `True` if the operating system refused the operation (`EACCES`, `EPERM`), for example
listening on a privileged port or broadcasting without `broadcast = True`.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| `True` if the operation was cancelled (`ECANCELED`), for example an [`accept`](#accept) whose
listener was closed.
-}
errorIsCancelled : Error -> Bool
errorIsCancelled =
    Debug.todo "Implement System API"


{-| `True` if a TLS peer's certificate was rejected: it has expired or is not yet valid, it is
self-signed or signed by an unknown authority, it was revoked, it does not match the server name,
or it failed verification for another reason.
-}
errorIsCertificateInvalid : Error -> Bool
errorIsCertificateInvalid =
    Debug.todo "Implement System API"

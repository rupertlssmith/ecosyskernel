module Socket.Udp exposing
    ( Socket, Datagram, BindOptions, defaultBindOptions, bind, localEndpoint
    , send, receive, onMessage, close
    , joinMulticast, leaveMulticast
    )

{-| Some protocols exchange separate short messages rather than a stream of bytes, and UDP is
how such messages travel. This module provides UDP sockets, which send and receive datagrams over
IPv4 and IPv6.

A _datagram_ is one message: a sequence of bytes sent in one piece to an address and port. It
arrives whole or not at all, and the network may lose, duplicate or reorder datagrams without
telling either end. So datagrams here are values, not streams: [`send`](#send) takes one
`Bytes`, and [`receive`](#receive) and [`onMessage`](#onMessage) hand out one
[`Datagram`](#Datagram) at a time, with the endpoint it came from.

A [`Socket`](#Socket) is bound to one local address and port with [`bind`](#bind). The family
of that address, IPv4 or IPv6, is the socket's family. One socket can send to any number of
endpoints and receives the datagrams sent to its own endpoint. An open socket keeps the
program running only while a [`receive`](#receive) is waiting or an [`onMessage`](#onMessage)
subscription exists.

    import Socket
    import Socket.Address as Address exposing (Family(..))
    import Socket.Udp
    import Task exposing (Task)

    bindLoopback : Task Socket.Error Socket.Udp.Socket
    bindLoopback =
        Socket.Udp.bind (Socket.Udp.defaultBindOptions (Address.loopback IPv4) 0)

Arriving datagrams are handed out by one rule, the same one [`Socket`](Socket) describes for the
connections of a listener. A new datagram goes to the oldest waiting `receive`; if there is none,
to every `onMessage` subscription to that socket, all of which receive the same `Datagram`; and
if there is neither, it is _held_ until the next `receive` or subscription, which takes the held
datagrams oldest first. The kernel holds at most 64 datagrams per socket, and drops the oldest
beyond that. Where a datagram that nobody takes waits depends on the backend. On the JavaScript
backend every datagram is read as soon as it arrives, so it is held. On the native backend the
socket reads only while a `receive` is waiting or a subscription exists, so a datagram that
arrives while there is neither stays in the operating system's receive buffer.

A _multicast group_ is an IP address that stands for the sockets that have joined it, so that a
datagram sent to the group's address and a port can reach each of them that is bound to that
port. [`joinMulticast`](#joinMulticast) and [`leaveMulticast`](#leaveMulticast) manage a
socket's membership.

Failures are [`Socket.Error`](Socket#Error) values, whose
[`Socket.ErrorKind`](Socket#ErrorKind) says what went wrong. On native Windows, UDP is not
supported: `bind` fails with [`Socket.NotSupported`](Socket#ErrorKind), and an `onMessage`
subscription is a fatal error.


## Sockets

@docs Socket, Datagram, BindOptions, defaultBindOptions, bind, localEndpoint, close


## Sending and receiving

@docs send, receive, onMessage


## Multicast

@docs joinMulticast, leaveMulticast

-}

import Socket.Internal
import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Platform
import Process
import Socket
import Socket.Address as Address exposing (Address, InetEndpoint)
import Task exposing (Task)


{-| A UDP socket bound to a local address and port, made by [`bind`](#bind).

The socket stays open until it is closed with [`close`](#close). On a closed socket, `send`, `receive`, `joinMulticast` and `leaveMulticast`
fail with [`Socket.Cancelled`](Socket#ErrorKind), and `close` does nothing.

-}
type alias Socket =
    Socket.Internal.UdpSocket


{-| A received datagram: its bytes, and the endpoint of the socket that sent it.

On a socket bound to an IPv6 address with `ipv6Only = False`, a datagram from an IPv4 sender
reports the sender as an IPv4-mapped address; [`Socket.Address.unmapIPv4`](Socket-Address#unmapIPv4)
gives the IPv4 address. The sender's address is read from text the kernel prints, and text that
[`Socket.Address.fromString`](Socket-Address#fromString) cannot read becomes the unspecified
address. That can happen for an IPv6 sender whose scope names an interface with a character
other than an ASCII letter or digit, `_`, `.` or `-` in its name.

-}
type alias Datagram =
    { data : Bytes
    , from : InetEndpoint
    }


{-| The settings a socket is bound with.

`address` and `port_` are the local endpoint. Port 0 asks the operating system to choose a free
port, which [`localEndpoint`](#localEndpoint) then reports. The unspecified address
([`Socket.Address.any`](Socket-Address#any)) receives on every interface.

`reuseAddress` lets several sockets that all set it bind the same address and port
(`SO_REUSEADDR`), for example several receivers of one multicast group on one machine.

`broadcast` allows sending to a broadcast address (`SO_BROADCAST`). Without it the operating
system refuses such a send, with [`Socket.PermissionDenied`](Socket#ErrorKind) on Linux.

`ipv6Only` matters only for an IPv6 address. When it is `False`, a socket bound to the
unspecified IPv6 address also exchanges datagrams with IPv4 endpoints, which it sees as
IPv4-mapped addresses. When it is `True`, the socket uses IPv6 only.

-}
type alias BindOptions =
    { address : Address
    , port_ : Int
    , reuseAddress : Bool
    , broadcast : Bool
    , ipv6Only : Bool
    }


{-| Returns the options for binding to `address` and `port_` with `reuseAddress`, `broadcast`
and `ipv6Only` all `False`.
-}
defaultBindOptions : Address -> Int -> BindOptions
defaultBindOptions =
    Debug.todo "Implement System API"


{-| Creates a UDP socket bound to the address and port the options name.

Fails, for example, with [`Socket.AddressInUse`](Socket#ErrorKind) when another socket already
has that address and port, or with [`Socket.AddressNotAvailable`](Socket#ErrorKind) for an
address that does not belong to this machine.

-}
bind : BindOptions -> Task Socket.Error Socket
bind =
    Debug.todo "Implement System API"


{-| Returns the address and port the socket is bound to, read when the socket was bound. For a
socket bound to port 0, the port is the one the operating system chose. An address
[`Socket.Address.fromString`](Socket-Address#fromString) cannot read, which can happen for an
IPv6 address whose scope names an interface with a character other than an ASCII letter or
digit, `_`, `.` or `-` in its name, is reported as the unspecified address.
-}
localEndpoint : Socket -> InetEndpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| Closes the socket.

Waiting [`receive`](#receive) tasks, and sends still waiting to go out, fail with
[`Socket.Cancelled`](Socket#ErrorKind),
and held datagrams are dropped. Closing a socket that is already closed does nothing.

-}
close : Socket -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Sends one datagram holding `data` to the endpoint `to`.

The task succeeds once the operating system has accepted the datagram, which does not mean that
it arrived.

An IPv6 destination on an IPv4 socket fails with
[`Socket.AddressNotAvailable`](Socket#ErrorKind). An IPv4 destination on an IPv6 socket is sent
to its IPv4-mapped address, which works only when the socket was bound with `ipv6Only = False`;
otherwise the send fails with the operating system's error. A datagram too large for the
operating system to send fails, usually with [`Socket.MessageTooLarge`](Socket#ErrorKind); over
IPv4 no datagram can carry more than 65 507 bytes.

-}
send : InetEndpoint -> Bytes -> Socket -> Task Socket.Error ()
send =
    Debug.todo "Implement System API"


{-| Waits for the socket's next datagram.

A held datagram, the oldest first, is returned at once. Otherwise the task waits, and a new
datagram goes to the oldest waiting `receive` before any [`onMessage`](#onMessage) subscription
sees it.

Fails with [`Socket.Cancelled`](Socket#ErrorKind) when the socket is closed while the task
waits, and at once on a socket that is already closed.

-}
receive : Socket -> Task Socket.Error Datagram
receive =
    Debug.todo "Implement System API"


{-| Creates a subscription to the datagrams the socket receives that no waiting
[`receive`](#receive) takes, including those held before the subscription started.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Socket.Udp.onMessage model.socket GotDatagram

A subscription made to a socket that is already closed never fires.

-}
onMessage : Socket -> (Datagram -> msg) -> Sub msg
onMessage =
    Debug.todo "Implement System API"


{-| Joins a multicast group on one network interface, or with `Nothing` on one the operating
system chooses, so that the socket can receive the datagrams sent to the group at the port it is
bound to.

The interface is given as an address of the group's family; one of the other family fails with
[`Socket.InvalidInput`](Socket#ErrorKind). For IPv4 it is an address of the interface. For IPv6 it is the address's scope that
names the interface, by name or by index, and the address bits are ignored, so `"::%lo"` names
the interface `lo`. With `Nothing`, an IPv6 group's own scope, if it has one, names the
interface instead. An IPv6 interface address with no scope leaves the choice to the operating
system, and the group's own scope is then not used.

-}
joinMulticast : Address -> Maybe Address -> Socket -> Task Socket.Error ()
joinMulticast =
    Debug.todo "Implement System API"


{-| Leaves a multicast group joined with [`joinMulticast`](#joinMulticast), given the same group
and interface.
-}
leaveMulticast : Address -> Maybe Address -> Socket -> Task Socket.Error ()
leaveMulticast =
    Debug.todo "Implement System API"

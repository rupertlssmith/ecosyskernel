module Socket.Udp exposing
    ( Socket, Datagram, BindOptions, defaultBindOptions, bind, localEndpoint
    , send, receive, onMessage, close
    , joinMulticast, leaveMulticast
    )

{-| UDP: datagrams over IPv4 and IPv6.

A UDP socket is bound to a local address and port. It sends datagrams to any address and port,
and receives the datagrams sent to it, each with the endpoint it came from. Datagrams are values,
not streams: each one arrives whole or not at all, and the network may lose, duplicate or reorder
them.

    import Socket.Address as Address exposing (Family(..))
    import Socket.Udp

    socket =
        Socket.Udp.bind (Socket.Udp.defaultBindOptions (Address.loopback IPv4) 0)


## Sockets

@docs Socket, Datagram, BindOptions, defaultBindOptions, bind, localEndpoint, close


## Sending and receiving

@docs send, receive, onMessage


## Multicast

@docs joinMulticast, leaveMulticast

-}

import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Platform
import Process
import Socket
import Socket.Address as Address exposing (Address, InetEndpoint)
import Task exposing (Task)


{-| A bound UDP socket. An open socket keeps the program running until it is [closed](#close).
-}
type Socket
    = Socket


{-| A received datagram: its bytes and the endpoint that sent it.

On a socket bound to an IPv6 address that also receives IPv4 traffic, IPv4 senders are reported
as IPv4-mapped addresses (see [`Socket.Address.unmapIPv4`](Socket-Address#unmapIPv4)).

-}
type alias Datagram =
    { data : Bytes
    , from : InetEndpoint
    }


{-| How to bind.

  - `address` and `port_`: the local address and port. Port 0 lets the operating system pick a
    free port (see [`localEndpoint`](#localEndpoint)); the unspecified address
    (`Socket.Address.any`) receives on every interface.
  - `reuseAddress`: allow other sockets to bind the same address and port (`SO_REUSEADDR`), as
    several multicast receivers on one machine need.
  - `broadcast`: allow sending to broadcast addresses (`SO_BROADCAST`); without it such a send
    fails with `EACCES`.
  - `ipv6Only`: for an IPv6 address, use IPv6 only. When `False`, a socket bound to `any IPv6`
    also sends to and receives from IPv4 endpoints.

-}
type alias BindOptions =
    { address : Address
    , port_ : Int
    , reuseAddress : Bool
    , broadcast : Bool
    , ipv6Only : Bool
    }


{-| Bind to an address and port with every option off.
-}
defaultBindOptions : Address -> Int -> BindOptions
defaultBindOptions =
    Debug.todo "Implement System API"


{-| Create a UDP socket bound to an address and port. Fails with, for example, `EADDRINUSE`.
-}
bind : BindOptions -> Task Socket.Error Socket
bind =
    Debug.todo "Implement System API"


{-| The address and port the socket is bound to. When binding to port 0, this tells which port the
operating system picked.
-}
localEndpoint : Socket -> InetEndpoint
localEndpoint =
    Debug.todo "Implement System API"


{-| Close the socket. Waiting [`receive`](#receive) tasks fail with `ECANCELED`, and datagrams that
were received but not yet handed out are dropped. Closing a socket twice is fine.
-}
close : Socket -> Task x ()
close =
    Debug.todo "Implement System API"


{-| Send one datagram to an endpoint. The task succeeds once the operating system has accepted the
datagram, which does not mean it arrived.

An IPv4 destination on a socket bound to an IPv6 address is sent to its IPv4-mapped address; an
IPv6 destination on an IPv4 socket fails with `EAFNOSUPPORT`. A datagram larger than the network
allows (65 507 bytes over IPv4) fails with `EMSGSIZE`.

-}
send : InetEndpoint -> Bytes -> Socket -> Task Socket.Error ()
send =
    Debug.todo "Implement System API"


{-| Wait for the next datagram.

Datagrams are handed out in the order they arrive: one that arrived while nobody was receiving or
subscribed is held (up to 64; beyond that the oldest are dropped) and given to the next `receive`
(or [`onMessage`](#onMessage) subscription). When `receive` tasks are waiting and a subscription
exists too, a new datagram goes to the oldest waiting `receive`.

Fails with `ECANCELED` when the socket is closed.

-}
receive : Socket -> Task Socket.Error Datagram
receive =
    Debug.todo "Implement System API"


{-| Subscribe to the datagrams a socket receives. Every subscription to the same socket receives
every datagram. A subscription to a closed socket never fires.

    subscriptions : Model -> Sub Msg
    subscriptions model =
        Socket.Udp.onMessage model.socket GotDatagram

-}
onMessage : Socket -> (Datagram -> msg) -> Sub msg
onMessage =
    Debug.todo "Implement System API"


{-| Join a multicast group, to receive the datagrams sent to it, on one interface (`Just`) or on
the interface the system picks (`Nothing`).

The interface is given as an address: for IPv4, an address of the interface; for IPv6, an address
whose scope names the interface (for example `"::%lo"`), the address bits being ignored.

-}
joinMulticast : Address -> Maybe Address -> Socket -> Task Socket.Error ()
joinMulticast =
    Debug.todo "Implement System API"


{-| Leave a multicast group joined with [`joinMulticast`](#joinMulticast), with the same group and
interface.
-}
leaveMulticast : Address -> Maybe Address -> Socket -> Task Socket.Error ()
leaveMulticast =
    Debug.todo "Implement System API"

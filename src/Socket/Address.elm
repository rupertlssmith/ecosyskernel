module Socket.Address exposing
    ( Address, Family(..), Endpoint(..), InetEndpoint
    , fromString, toString, fromOctets, toOctets
    , family, loopback, any, isLoopback, isUnspecified, isIPv4Mapped, unmapIPv4
    )

{-| Many socket functions in this package take an IP address or the endpoint of a socket as a
value of this module rather than as text, and this module defines those values: IPv4 and IPv6
addresses, and the endpoints of sockets.

An [`Address`](#Address) is valid by construction. It is made only here: by parsing text with
[`fromString`](#fromString), from bytes with [`fromOctets`](#fromOctets), as one of the
well-known addresses, or with [`unmapIPv4`](#unmapIPv4). [`toString`](#toString) prints every
address in one canonical form, which `fromString` reads back as the same address. Parsing and
printing are pure Elm and never touch the network, so they behave the same on every platform
and backend.

Host names are not addresses: `fromString "localhost"` is `Nothing`. Resolve a name with
[`Socket.lookup`](Socket#lookup), or connect to one directly with
[`Socket.Tcp.connectToHost`](Socket-Tcp#connectToHost).

Four terms are used throughout.

An IPv6 address may carry a _scope_ (also called a zone): the text after a `%`, such as the `eth0`
of `fe80::1%eth0`, which names the network interface a link-local address belongs to. The scope
is part of the address, so `fe80::1%eth0` and `fe80::1` are not equal.

The _unspecified_ address, `0.0.0.0` or `::`, names no particular host. [`any`](#any) returns it.

An _IPv4-mapped_ address is an IPv6 address that carries an IPv4 address in its last 32 bits,
written `::ffff:a.b.c.d`. It is an IPv6 address and is not equal to the IPv4 address it carries;
[`unmapIPv4`](#unmapIPv4) returns that IPv4 address. A TCP listener or UDP socket on the
unspecified IPv6 address with `ipv6Only = False` sees its IPv4 peers this way.

An _endpoint_ is where a socket is: an address and a port, or the path of a Unix domain socket.

    Socket.Address.fromString "::FFFF:127.0.0.1"
        |> Maybe.map Socket.Address.toString
    --> Just "::ffff:127.0.0.1"


## Addresses

@docs Address, Family, fromString, toString, fromOctets, toOctets, family


## Well-known addresses

@docs loopback, any


## Classification

@docs isLoopback, isUnspecified, isIPv4Mapped, unmapIPv4


## Endpoints

@docs Endpoint, InetEndpoint

-}

import Path exposing (Path)


{-| An IPv4 or IPv6 address, valid by construction; an IPv6 address may also carry a scope.

A value is obtained from [`fromString`](#fromString), [`fromOctets`](#fromOctets),
[`loopback`](#loopback), [`any`](#any) or [`unmapIPv4`](#unmapIPv4), so every `Address` is valid:
[`toString`](#toString) prints it as text that `fromString` reads back as the same address.

Two addresses are equal (`==`) when they have the same family, the same bits and the same scope
text, compared exactly. An IPv4-mapped address is therefore never equal to the IPv4 address it
carries, and `fe80::1%eth0` is not equal to `fe80::1%ETH0`.

-}
type Address
    = Address


{-| Which of the two kinds of address a value is: `IPv4`, 32 bits, or `IPv6`, 128 bits. An
IPv4-mapped address is `IPv6`.
-}
type Family
    = IPv4
    | IPv6


{-| Parses the text of an IPv4 or IPv6 address, giving `Nothing` for anything that is not one.

  - **IPv4:** four decimal fields from 0 to 255, separated by dots, each of 1 to 3 ASCII digits.
    A leading zero is not allowed (`"01.2.3.4"` is rejected).
  - **IPv6:** the text form of RFC 4291: groups of 1 to 4 hexadecimal digits (in either case)
    separated by colons, at most one `::` standing for one or more zero groups, and optionally a
    dotted IPv4 address, written as above, in place of the last two groups
    (`"::ffff:192.0.2.1"`). Without `::` there must be exactly 8 groups; with it, at most 7. A
    dotted ending counts as two groups.
  - An IPv6 address may end in a scope: `%` followed by 1 to 15 characters from `A-Z`, `a-z`,
    `0-9`, `_`, `.` and `-`, such as the interface name `"eth0"` or the interface number `"2"`.
    An IPv4 address cannot have a scope.

Anything else, including surrounding whitespace, gives `Nothing`.

    fromString "localhost"
    --> Nothing

-}
fromString : String -> Maybe Address
fromString =
    Debug.todo "Implement System API"


{-| Prints an address in its canonical form, which [`fromString`](#fromString) reads back as the
same address.

  - IPv4: dotted decimal, `"127.0.0.1"`.
  - IPv6 (RFC 5952): lower-case hexadecimal without leading zeros; the longest run of two or more
    zero groups (the leftmost one if there is a tie) is written `::`, and a single zero group is
    written `0`. IPv4-mapped addresses are written `"::ffff:a.b.c.d"`. The scope, if any, follows
    after a `%`.

```
fromString "2001:DB8:0:0:1:0:0:1" |> Maybe.map toString
--> Just "2001:db8::1:0:0:1"
```

-}
toString : Address -> String
toString =
    Debug.todo "Implement System API"


{-| Builds an address from its bytes in network order: 4 values give an IPv4 address and 16 values
an IPv6 address (without a scope). Any other length, or a value outside 0–255, gives `Nothing`.

    fromOctets [ 127, 0, 0, 1 ] |> Maybe.map toString
    --> Just "127.0.0.1"

-}
fromOctets : List Int -> Maybe Address
fromOctets =
    Debug.todo "Implement System API"


{-| Returns the bytes of an address in network order: 4 for IPv4, 16 for IPv6. The scope is not
included.
-}
toOctets : Address -> List Int
toOctets =
    Debug.todo "Implement System API"


{-| Returns the family of an address. An IPv4-mapped address such as `"::ffff:127.0.0.1"` is an IPv6
address; [`unmapIPv4`](#unmapIPv4) turns it into an IPv4 one.
-}
family : Address -> Family
family =
    Debug.todo "Implement System API"


{-| Returns the loopback address of a family, `127.0.0.1` or `::1`, the address by which a host
reaches itself. [`isLoopback`](#isLoopback) accepts more addresses than these two.
-}
loopback : Family -> Address
loopback =
    Debug.todo "Implement System API"


{-| Returns the unspecified address of a family, `0.0.0.0` or `::`.

As the address to listen or bind on, it stands for every local interface rather than one.
Whether the IPv6 one also takes IPv4 traffic is set by `ipv6Only` in
[`Socket.Tcp.ListenOptions`](Socket-Tcp#ListenOptions) and
[`Socket.Udp.BindOptions`](Socket-Udp#BindOptions). [`Http.Server`](Http-Server) has no
`ipv6Only` and listens as if it were `False`.

-}
any : Family -> Address
any =
    Debug.todo "Implement System API"


{-| Returns `True` for loopback addresses: `127.0.0.0/8`, `::1`, and the IPv4-mapped forms of
`127.0.0.0/8` (such as `::ffff:127.0.0.1`). The scope is ignored.
-}
isLoopback : Address -> Bool
isLoopback =
    Debug.todo "Implement System API"


{-| Returns `True` for the unspecified addresses `0.0.0.0` and `::`. The scope is ignored. Unlike
[`isLoopback`](#isLoopback), this does not look inside an IPv4-mapped address: `::ffff:0.0.0.0`
is not unspecified.
-}
isUnspecified : Address -> Bool
isUnspecified =
    Debug.todo "Implement System API"


{-| Returns `True` for IPv4-mapped IPv6 addresses (`::ffff:0:0/96`), such as `::ffff:127.0.0.1`,
whatever their scope.
-}
isIPv4Mapped : Address -> Bool
isIPv4Mapped =
    Debug.todo "Implement System API"


{-| Turns an IPv4-mapped IPv6 address into the IPv4 address it carries (`::ffff:127.0.0.1` becomes
`127.0.0.1`), dropping any scope. Every other address is returned unchanged.
-}
unmapIPv4 : Address -> Address
unmapIPv4 =
    Debug.todo "Implement System API"


{-| Where a stream socket is: one end of a connection, or the place a listener listens.

`Inet` carries an IP address and a port.

`Unix` carries the path of a Unix domain socket. The [empty path](Path#empty) stands for an
unnamed socket: a connection made with `Socket.Unix` has it as its local endpoint, and a
connection accepted by a Unix listener has it as its remote endpoint.

-}
type Endpoint
    = Inet InetEndpoint
    | Unix Path


{-| An IP address and a port number.

`port_` has its underscore because `port` is a reserved word in Elm. It is a plain `Int`, and
the type does not restrict it to the port range 0–65535.

-}
type alias InetEndpoint =
    { address : Address
    , port_ : Int
    }



-- PARSING

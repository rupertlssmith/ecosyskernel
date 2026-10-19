module Socket.Address exposing
    ( Address, Family(..), Endpoint(..), InetEndpoint
    , fromString, toString, fromOctets, toOctets
    , family, loopback, any, isLoopback, isUnspecified, isIPv4Mapped, unmapIPv4
    )

{-| IPv4 and IPv6 addresses, and the endpoints of sockets.

This module is pure Elm: parsing and printing never touch the network, so they behave the same
on every platform and backend. Host names are not addresses; resolve them with
[`Socket.lookup`](Socket#lookup), or connect to a name directly with
[`Socket.Tcp.connectToHost`](Socket-Tcp#connectToHost).

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


{-| An IPv4 or an IPv6 address. An IPv6 address may carry a scope (zone), such as the `eth0` of
`fe80::1%eth0`, which names the network interface a link-local address belongs to.

Two addresses are equal (`==`) when they have the same family, the same bits and the same
scope text.

-}
type Address
    = Address


{-| The two address families.
-}
type Family
    = IPv4
    | IPv6


{-| Parse an address.

  - **IPv4:** four decimal fields from 0 to 255, separated by dots. Leading zeros are not
    allowed (`"01.2.3.4"` is rejected), as in the C library's `inet_pton` and Node's `net.isIP`.
  - **IPv6:** the text form of RFC 4291: groups of 1 to 4 hexadecimal digits (in either case)
    separated by colons, at most one `::` standing for one or more zero groups, and optionally a
    dotted IPv4 address as the last two groups (`"::ffff:192.0.2.1"`). Without `::` there must be
    exactly 8 groups; with it, at most 7.
  - An IPv6 address may end in a scope: `%` followed by 1 to 15 characters from `A-Z`, `a-z`,
    `0-9`, `_`, `.` and `-` (an interface name such as `"eth0"` or an interface number such as
    `"2"`).

Anything else, including surrounding whitespace, gives `Nothing`.

    fromString "192.168.0.1"   -- an IPv4 address
    fromString "fe80::1%eth0"  -- an IPv6 address with a scope
    fromString "localhost"     --> Nothing

-}
fromString : String -> Maybe Address
fromString =
    Debug.todo "Implement System API"


{-| Print an address in its canonical form, which [`fromString`](#fromString) reads back.

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


{-| Build an address from its bytes in network order: 4 values give an IPv4 address and 16 values an
IPv6 address (without a scope). Any other length, or a value outside 0–255, gives `Nothing`.

    fromOctets [ 127, 0, 0, 1 ] |> Maybe.map toString
    --> Just "127.0.0.1"

-}
fromOctets : List Int -> Maybe Address
fromOctets =
    Debug.todo "Implement System API"


{-| The bytes of an address in network order: 4 for IPv4, 16 for IPv6. The scope is not included.
-}
toOctets : Address -> List Int
toOctets =
    Debug.todo "Implement System API"


{-| The family of an address. An IPv4-mapped address such as `"::ffff:127.0.0.1"` is an IPv6
address; [`unmapIPv4`](#unmapIPv4) turns it into an IPv4 one.
-}
family : Address -> Family
family =
    Debug.todo "Implement System API"


{-| The loopback address of a family: `127.0.0.1` or `::1`.
-}
loopback : Family -> Address
loopback =
    Debug.todo "Implement System API"


{-| The unspecified ("any") address of a family: `0.0.0.0` or `::`. Listening on it accepts
connections on every interface.
-}
any : Family -> Address
any =
    Debug.todo "Implement System API"


{-| `True` for loopback addresses: `127.0.0.0/8`, `::1`, and the IPv4-mapped forms of
`127.0.0.0/8` (such as `::ffff:127.0.0.1`). The scope is ignored.
-}
isLoopback : Address -> Bool
isLoopback =
    Debug.todo "Implement System API"


{-| `True` for the unspecified addresses `0.0.0.0` and `::`. The scope is ignored.
-}
isUnspecified : Address -> Bool
isUnspecified =
    Debug.todo "Implement System API"


{-| `True` for IPv4-mapped IPv6 addresses (`::ffff:0:0/96`), such as `::ffff:127.0.0.1`. A socket
bound to an IPv6 address that also accepts IPv4 traffic reports its IPv4 peers this way.
-}
isIPv4Mapped : Address -> Bool
isIPv4Mapped =
    Debug.todo "Implement System API"


{-| Turn an IPv4-mapped IPv6 address into the IPv4 address it maps (`::ffff:127.0.0.1` becomes
`127.0.0.1`). Every other address is returned unchanged.
-}
unmapIPv4 : Address -> Address
unmapIPv4 =
    Debug.todo "Implement System API"


{-| One end of a socket connection.

  - `Inet` is an IPv4 or IPv6 address and a port.
  - `Unix` is the path of a Unix domain socket. An unnamed socket, such as the client side of a
    Unix connection or the remote end seen by a Unix server, has the
    [empty path](Path#empty).

-}
type Endpoint
    = Inet InetEndpoint
    | Unix Path


{-| An address and a port.
-}
type alias InetEndpoint =
    { address : Address
    , port_ : Int
    }



-- PARSING

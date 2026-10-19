module Socket.Tls exposing
    ( ClientOptions, Verification(..), defaultClientOptions, connect
    , ServerOptions, listen
    , Info, info
    )

{-| TLS: encrypted TCP connections.

A TLS connection is an ordinary [`Connection`](Socket#Connection) whose streams carry the
plaintext; encryption happens underneath. Clients connect with [`connect`](#connect), servers
[`listen`](#listen) and accept with [`Socket.accept`](Socket#accept) or
[`Socket.onConnection`](Socket#onConnection), where a connection arrives once its TLS handshake is
done.

    Socket.lookup "example.com"
        |> Task.andThen
            (\addresses ->
                case addresses of
                    address :: _ ->
                        Socket.Tls.connect
                            (Socket.Tls.defaultClientOptions "example.com")
                            (Socket.Tcp.defaultConnectOptions address 443)

                    [] ->
                        Task.fail ...
            )

A certificate that fails verification makes `connect` fail with a code such as
`"CERT_HAS_EXPIRED"` or `"ERR_TLS_CERT_ALTNAME_INVALID"`
([`Socket.errorIsCertificateInvalid`](Socket#errorIsCertificateInvalid)); other TLS failures
have codes starting with `"ERR_SSL_"`.


## Clients

@docs ClientOptions, Verification, defaultClientOptions, connect


## Servers

@docs ServerOptions, listen


## Connection information

@docs Info, info

-}

import Socket
import Socket.Tcp
import Task exposing (Task)


{-| How to secure a client connection.

  - `serverName`: the server's name. A DNS name is sent to the server (SNI) and must match the
    certificate; an IP address literal is not sent and must match one of the certificate's IP
    addresses.
  - `verification`: which certificates to trust.
  - `alpn`: the application protocols to offer, in order of preference (for example
    `[ "h2", "http/1.1" ]`); the server picks one (see [`info`](#info)).

-}
type alias ClientOptions =
    { serverName : String
    , verification : Verification
    , alpn : List String
    }


{-| Which server certificates a client accepts.

  - `SystemCertificates`: certificates signed by the system's certificate authorities (the
    `SSL_CERT_FILE` and `SSL_CERT_DIR` environment variables override them).
  - `TrustedCertificates pem`: certificates signed by the authorities in `pem`, one or more
    PEM-encoded certificates, and no others.
  - `NoVerification`: any certificate, without checking it or the server name. Only for testing:
    the connection is encrypted but the server is not authenticated.

-}
type Verification
    = SystemCertificates
    | TrustedCertificates String
    | NoVerification


{-| Connect to the named server, trusting the system's certificate authorities and offering no
application protocols.
-}
defaultClientOptions : String -> ClientOptions
defaultClientOptions =
    Debug.todo "Implement System API"


{-| Open a TCP connection and secure it with TLS. The task succeeds once the TLS handshake is done
and the certificate verified; the TCP options' `timeout` covers both.
-}
connect : ClientOptions -> Socket.Tcp.ConnectOptions -> Task Socket.Error Socket.Connection
connect =
    Debug.todo "Implement System API"


{-| How to secure a server's connections.

  - `certificateChain`: the server's certificate, followed by any intermediate certificates, in
    PEM.
  - `privateKey`: the certificate's private key, in PEM.
  - `alpn`: the application protocols the server supports, in order of preference. When a client
    offers protocols and none of them is supported, the handshake fails. `[]` ignores what clients
    offer.

-}
type alias ServerOptions =
    { certificateChain : String
    , privateKey : String
    , alpn : List String
    }


{-| Start listening for TLS connections. Fails like `Socket.Tcp.listen`, or with an `"ERR_SSL_"`
code when the certificate or key cannot be used.

A client whose handshake fails, or does not finish within 120 seconds, is dropped without being
handed to the program.

-}
listen : ServerOptions -> Socket.Tcp.ListenOptions -> Task Socket.Error Socket.Listener
listen =
    Debug.todo "Implement System API"


{-| What a TLS handshake agreed on.

  - `protocol`: the TLS version, for example `"TLSv1.3"`.
  - `alpn`: the application protocol chosen, if any.
  - `cipher`: the cipher suite, for example `"TLS_AES_256_GCM_SHA384"`.

-}
type alias Info =
    { protocol : String
    , alpn : Maybe String
    , cipher : String
    }


{-| The [`Info`](#Info) of a TLS connection. Fails with `EINVAL` for a connection that is not a TLS
connection.
-}
info : Socket.Connection -> Task Socket.Error Info
info =
    Debug.todo "Implement System API"

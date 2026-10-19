# eco/system

POSIX-style system programming for Eco programs: files, processes, streams, the terminal,
sockets, WebSockets and HTTP servers, from Elm.

`eco/system` is the public system API for programs compiled with the Eco compiler. (Eco's own
`eco/kernel` package is the compiler's internal IO layer and is not meant for applications.) The API
is a port of [gren-lang/node](https://github.com/gren-lang/node), together with the `Stream` module
from [gren-lang/core](https://github.com/gren-lang/core), adapted to Elm: lists instead of arrays,
`()` instead of `{}`, and no permission tokens. For an HTTP client, use
[elm/http](https://package.elm-lang.org/packages/elm/http/latest/); `Http.Stream` adds streaming
request and response bodies on top of it.

> **Status: API preview for review.** This repository holds the proposed API for the next
> release, with every function a `Debug.todo` stub. It follows
> `plans/eco-system-api-refactor.md` in the Eco repository, which records the review feedback and
> the decisions behind each change.

## Modules

- `System`: the program `Environment` (args, start time, stdin/stdout/stderr, platform), simple
  programs, exit codes and signals. Full programs are plain `Platform.worker` programs whose flags
  are the `Environment`.
- `Stream`: readable and writable streams, reading lines, piping, and best-effort logging.
- `Stream.Transformation`: building transformations, text encoding and compression.
- `FileSystem`, `FileSystem.Handle`, `Path`: files, directories, links, metadata, durable and
  exclusive writes, file handles for random access, and paths.
- `ChildProcess`: running and spawning child processes.
- `Terminal`: terminal size, raw mode, window title and resize events.
- `Socket`, `Socket.Address`, `Socket.Tcp`, `Socket.Unix`, `Socket.Udp`, `Socket.Tls`: TCP, Unix
  domain and TLS connections, UDP datagrams, IPv4/IPv6 addresses and name lookup.
- `WebSocket`: WebSocket clients and servers, on sockets and on `Http.Server`.
- `Http.Server`: an HTTP server (HTTP/1.1, HTTPS, HTTP/2 over TLS, WebSocket upgrades) and its
  responses.
- `Http.Stream`: streaming request and response bodies for elm/http.
- `Html.Dom`: a transparent view of `Html`/`Svg` values and their HTML serialization.

## Example

```elm
module Main exposing (main)

import Stream
import System


main : Platform.Program System.Environment () ()
main =
    System.simpleProgram
        (\env -> Stream.logLine "Hello, world!" env.stdout)
```

## Previewing the docs

```bash
pnpm install
pnpm run docs        # serves http://localhost:8000 (note: `pnpm docs` is a pnpm built-in)
pnpm run docs:check  # regenerates docs.json
```

`elm-doc-preview` needs Elm 0.19.1 on the `PATH`.

## License

BSD-3-Clause; see `LICENSE`. This package is derived from gren-lang/node and gren-lang/core
(Copyright 2022-present The Gren CONTRIBUTORS), which are themselves derived from Elm
(Copyright 2014-2022 Evan Czaplicki).

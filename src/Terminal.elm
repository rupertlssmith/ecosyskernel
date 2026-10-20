module Terminal exposing
    ( Configuration, Size, configuration
    , setStdinRawMode, setTitle
    , onResize
    )

{-| A program run from a terminal may want to colour its output, draw to the
size of the window, read single keypresses or set the window title. This
module tells it whether a terminal is there, how many colours it can show and
how big it is, and lets it switch stdin into raw mode, set the title and hear
about resizes.

A _terminal_ here is a standard stream connected to a terminal device rather
than to a file or a pipe. `configuration` and `setTitle` act on stdout, and
`setStdinRawMode` on stdin: `configuration` gives `Nothing` and the other two
do nothing when that stream is not a terminal. There is therefore no setup
step, and none of the tasks can fail. `configuration` is how a program finds
out whether stdout is a terminal.

On the native backend on Windows, running any of these tasks, or subscribing
with `onResize`, stops the program with a fatal error saying it is not
supported there yet.


## Configuration

@docs Configuration, Size, configuration


## Commands

@docs setStdinRawMode, setTitle


## Subscriptions

@docs onResize

-}

import Task exposing (Task)


{-| What is known about the terminal on stdout: how many colours it can show,
and the size of its window in character cells.

`colorDepth` is a number of bits per colour: `1` for no colour, `4` for 16
colours, `8` for 256 colours and `24` for true colour. It is not asked of the
terminal but guessed from the environment, by the first of these rules that
applies:

  - a non-empty `NO_COLOR`, or `TERM=dumb`, gives `1`;
  - `FORCE_COLOR` set to exactly `0`, `1`, `2` or `3` gives `1`, `4`, `8` or
    `24`;
  - `COLORTERM` set to `truecolor` or `24bit` gives `24`;
  - a `TERM` ending in `256color` gives `8`;
  - otherwise it is `4`.

The size is the one stdout reports or, when stdout reports a width of zero,
the one another standard stream that is a terminal reports (stdin, then
stderr, on the native backend; stderr on the JS backend). `columns` and `rows`
are both `0` when none can be read.

-}
type alias Configuration =
    { colorDepth : Int
    , columns : Int
    , rows : Int
    }


{-| The size of a terminal window, in character cells.
-}
type alias Size =
    { columns : Int
    , rows : Int
    }


{-| Gets the configuration of the terminal on stdout, or `Nothing` when stdout
is not a terminal, as when the output is redirected to a file or a pipe.

It reads the terminal again each time it is run, so a later run reports the
current size.

-}
configuration : Task x (Maybe Configuration)
configuration =
    Debug.todo "Implement System API"


{-| Switches stdin into raw mode with `True`, and back to its original mode with
`False`. It does nothing when stdin is not a terminal.

In its original mode a terminal usually hands input over a line at a time,
once the user presses enter. In raw mode every keypress is sent over the stdin
stream as it happens, and is not echoed. Key combinations such as Ctrl-C arrive
as input too, rather than raising a signal, so `System.onSignalInterrupt` does
not see them.

The original mode is the one stdin had when this was first run. It is restored
when the process exits, but on the native backend not when a fatal error stops
the program. It is also restored when the program is ended by an interrupt
(`SIGINT`) or terminate (`SIGTERM`) signal it does not subscribe to, unless,
on the native backend, the program is embedded in a host application, which
keeps its own signal handling; any other signal that ends the program leaves
raw mode on. While the program subscribes to that signal
with `System.onSignalInterrupt` or `System.onSignalTerminate`, the signal does
not end it and raw mode stays on.

-}
setStdinRawMode : Bool -> Task x ()
setStdinRawMode =
    Debug.todo "Implement System API"


{-| Sets the title of the terminal window, as shown in the title bar or tab of a
terminal emulator.

It writes the title escape sequence (OSC 2) to stdout when stdout is a
terminal, and does nothing otherwise, so the sequence never ends up in a
redirected file or pipe. ASCII control characters, DEL included, are removed
from `title` first, so that none of them (BEL or ESC in particular) can end
the sequence early. Whether the title changes is up to the terminal, and a
failure to write is ignored.

-}
setTitle : String -> Task x ()
setTitle =
    Debug.todo "Implement System API"


{-| Creates a subscription to changes in the size of the terminal, with the new
size.

A size arrives each time the program receives `SIGWINCH`, the signal the
operating system sends when a terminal's window is resized, and may equal the
previous one. It is read as `configuration` reads its size, falling back to
the other standard streams also when stdout is not a terminal, and nothing
arrives when no standard stream reports one, or, on the native backend, when
the program is embedded in a host application. The subscription does not keep
the program running.

-}
onResize : (Size -> msg) -> Sub msg
onResize =
    Debug.todo "Implement System API"

module Terminal exposing
    ( Configuration, Size, configuration
    , setStdinRawMode, setTitle
    , onResize
    )

{-| This lets you interact with the user's terminal, if an interactive terminal is connected to
this application.

Unlike gren-node's `Terminal` module there is no permission value and no `initialize`: call
[`configuration`](#configuration) to find out whether a terminal is attached, and use the
other functions directly.


## Configuration

@docs Configuration, Size, configuration


## Commands

@docs setStdinRawMode, setTitle


## Subscriptions

@docs onResize

-}

import Task exposing (Task)


{-| The configuration of the attached interactive terminal: the number of colours it supports
as a bit depth (`1` for no colour, `4` for 16 colours, `8` for 256 colours, `24` for true
colour) and its current size in character cells.

The colour depth is guessed from the environment: `NO_COLOR` or `TERM=dumb` give `1`,
`FORCE_COLOR`, `COLORTERM` and a `TERM` ending in `256color` raise it.

-}
type alias Configuration =
    { colorDepth : Int
    , columns : Int
    , rows : Int
    }


{-| Size of a terminal viewport. Handy to know for drawing a text-based UI.
-}
type alias Size =
    { columns : Int
    , rows : Int
    }


{-| Get the configuration of the attached terminal.

`Nothing` is returned if this program is not connected to an interactive terminal, which can
happen in CI setups or when used as part of a Unix pipe.

This replaces gren-node's `Terminal.initialize`; it can be called at any time and as often as
you like.

-}
configuration : Task x (Maybe Configuration)
configuration =
    Debug.todo "Implement System API"


{-| In its default mode, `stdin` only sends data when the user hits the enter key.

If you switch over to raw mode, every keypress will be sent over the stream, and special
combinations like `Ctrl-C` will no longer trigger the interrupt signal.

Enable this when you need full control over how input is handled. The original terminal mode is
restored when the program exits, also when it is ended by an interrupt (`SIGINT`) or terminate
(`SIGTERM`) signal it does not subscribe to. This does nothing if stdin is not a terminal.

-}
setStdinRawMode : Bool -> Task x ()
setStdinRawMode =
    Debug.todo "Implement System API"


{-| Set the title of the terminal window, as shown in the title bar or tab of your terminal
emulator.

This writes the standard title escape sequence (OSC 2) to stdout when stdout is a terminal, and
does nothing otherwise, so the sequence never ends up in a redirected file or pipe. It works in
xterm-compatible terminals on Linux and macOS, and in Windows Terminal.

This was `setProcessTitle`, which changed the process name instead (on Linux only); POSIX has no
portable process title.

-}
setTitle : String -> Task x ()
setTitle =
    Debug.todo "Implement System API"


{-| A subscription that triggers every time the size of the terminal changes, with the new size.
-}
onResize : (Size -> msg) -> Sub msg
onResize =
    Debug.todo "Implement System API"

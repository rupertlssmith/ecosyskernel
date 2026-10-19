module System exposing
    ( simpleProgram
    , Environment, environmentVariables, Platform(..), CpuArchitecture(..)
    , exit, exitWithCode, setExitCode
    , onEmptyEventLoop, onSignalInterrupt, onSignalTerminate
    )

{-| An Eco system program is an ordinary Elm `Platform.Program` whose flags are the
[`Environment`](#Environment). Eco builds the environment when the program starts and hands it
to `init`: it tells you which platform you are running on, which arguments the program was
invoked with and when it started, and gives you the standard input, output and error streams.

Long-lived programs that keep state, react to messages and listen to subscriptions are made
with `Platform.worker`:

    main : Platform.Program System.Environment Model Msg
    main =
        Platform.worker
            { init = \env -> ( initialModel env, Cmd.none )
            , update = update
            , subscriptions = subscriptions
            }

Short-lived programs that run a single task and then finish are made with
[`simpleProgram`](#simpleProgram):

    main : Platform.Program System.Environment () ()
    main =
        System.simpleProgram
            (\env -> Stream.logLine "Hello, world!" env.stdout)

The flags type `System.Environment` is supplied by the Eco compiler and runtime; it cannot be
passed in from JavaScript like ordinary JSON flags.

This module is a port of the `Node` module of gren-node. Every subsystem (files, processes, the
terminal, the HTTP server) can be used directly once the program has started; there is nothing
to set up first.


# Simple Program

@docs simpleProgram


# Environment information

@docs Environment, environmentVariables, Platform, CpuArchitecture


# Exit

@docs exit, exitWithCode, setExitCode


# Subscriptions

@docs onEmptyEventLoop, onSignalInterrupt, onSignalTerminate

-}

import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Platform
import Path exposing (Path)
import Process
import Stream
import Task exposing (Task)
import Time


{-| Contains information about the environment your application was started in.

  - `platform` and `cpuArchitecture` tell you about the operating system and machine your
    application is running on.
  - `applicationPath` is the real path of the currently executing program.
  - `args` is the full list of command line arguments, exactly as the C `argv` array. The
    first element, `args[0]`, is the program as it was invoked. This differs from gren-node,
    where the list starts with the path to the `node` binary followed by the script path, so a
    gren program that drops two leading arguments must drop only one here.
  - `startTime` is the time the program started, read once at startup, so `init` doesn't need
    to ask for the time first.
  - `stdout`, `stderr` and `stdin` are streams you can use to communicate with the outside
    world. Take a closer look at the `Stream` module for more information; `Stream.readLine`
    reads standard input line by line.

-}
type alias Environment =
    { platform : Platform
    , cpuArchitecture : CpuArchitecture
    , applicationPath : Path
    , args : List String
    , startTime : Time.Posix
    , stdout : Stream.Writable Bytes
    , stderr : Stream.Writable Bytes
    , stdin : Stream.Readable Bytes
    }


{-| The platform, or operating system, that your application is running on. Platforms that
are not recognised are reported as `UnknownPlatform`, carrying the platform's own name.
-}
type Platform
    = Win32
    | Darwin
    | Linux
    | FreeBSD
    | OpenBSD
    | SunOS
    | Aix
    | UnknownPlatform String


{-| The CPU architecture your application is running on. Architectures that are not
recognised are reported as `UnknownArchitecture`, carrying the architecture's own name.
-}
type CpuArchitecture
    = Arm
    | Arm64
    | IA32
    | Mips
    | Mipsel
    | PPC
    | PPC64
    | S390
    | S390x
    | X64
    | UnknownArchitecture String


{-| Get a `Dict` of the environment variables of the running process, mapping each variable
name to its value.
-}
environmentVariables : Task x (Dict String String)
environmentVariables =
    Debug.todo "Implement System API"


{-| Define a simple program that doesn't require long-lived state or the ability to respond to
messages or subscriptions. Ideal for simple and short-lived programs.

The function receives the [`Environment`](#Environment) and returns the task to run. The
result of the task is ignored: the program ends once the task, and any IO it started, has
completed. To end with a non-zero exit code, finish the task with
[`setExitCode`](#setExitCode).

    main : Platform.Program System.Environment () ()
    main =
        System.simpleProgram
            (\env ->
                case List.drop 1 env.args of
                    [] ->
                        Stream.logLine "usage: greet NAME" env.stderr
                            |> Task.andThen (\_ -> System.setExitCode 2)

                    name :: _ ->
                        Stream.logLine ("Hello, " ++ name ++ "!") env.stdout
            )

-}
simpleProgram : (Environment -> Task Never a) -> Platform.Program Environment () ()
simpleProgram =
    Debug.todo "Implement System API"


{-| Terminate the program immediately. Buffered standard output is flushed, but the program
will not wait for tasks like HTTP requests or file system writes to complete.

This function is equivalent to:

    exitWithCode 0

-}
exit : Cmd msg
exit =
    Debug.todo "Implement System API"


{-| Terminate the program immediately with the given exit code. Buffered standard output is
flushed, but the program will not wait for tasks like HTTP requests or file system writes, so
only use this if you've reached a state where it makes no sense to continue.

The exit code can be read by other processes on your system. Any value other than 0 is
considered an error, but there are no other formal requirements for what makes an exit code.
If all you want is to signal that your application exited due to an error, 1 is a good option.

-}
exitWithCode : Int -> Cmd msg
exitWithCode =
    Debug.todo "Implement System API"


{-| Set the exit code that the program will return once it finishes.

This will not terminate your program, so things like HTTP requests or writes to the file
system are allowed to complete. The program only exits once there is no ongoing work left.

-}
setExitCode : Int -> Task x ()
setExitCode =
    Debug.todo "Implement System API"


{-| Receive the given message when the program has run out of work: there are no queued
messages and no pending IO. This is the equivalent of Node's `beforeExit` event.

If handling the message starts new IO, the program keeps running and the message will be
delivered again the next time the program runs out of work. If it does not, the program exits.
This subscription never fires when the program is embedded in a host application.

-}
onEmptyEventLoop : msg -> Sub msg
onEmptyEventLoop =
    Debug.todo "Implement System API"


{-| Receive the given message when the process receives an interrupt signal (`SIGINT`), which
usually happens when the user presses Ctrl+C in the terminal. While subscribed, the signal no
longer terminates the program, so you are expected to exit yourself.
-}
onSignalInterrupt : msg -> Sub msg
onSignalInterrupt =
    Debug.todo "Implement System API"


{-| Receive the given message when the process receives a terminate signal (`SIGTERM`), the
polite request to shut down sent by service managers and the `kill` command. While subscribed,
the signal no longer terminates the program, so you are expected to exit yourself.
-}
onSignalTerminate : msg -> Sub msg
onSignalTerminate =
    Debug.todo "Implement System API"

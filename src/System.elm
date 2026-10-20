module System exposing
    ( program, simpleProgram
    , Environment, environmentVariables, Platform(..), CpuArchitecture(..)
    , exit, exitWithCode, setExitCode
    , onEmptyEventLoop, onSignalInterrupt, onSignalTerminate
    )

{-| An Eco system program is an ordinary Elm `Platform.Program` that runs as a command-line tool
or a server, and this module is what makes it one: the [`Environment`](#Environment) it starts
with, and the controls that act on the whole running program, such as its exit code and the
signals sent to it.

The flags of such a program are an `Environment`. Eco recognises a `main` whose flags type is
`System.Environment` and builds the environment itself when the program starts, so any flags
JSON a host supplies is ignored. The environment tells you which platform the program is
running on, which arguments it was started with and when it started, and gives you its standard
input, output and error streams.

A long-running program, one that keeps state, reacts to messages and listens to
subscriptions, is made with [`program`](#program):

    main : Platform.Program System.Environment Model Msg
    main =
        System.program
            { init = \env -> ( initialModel env, Cmd.none )
            , update = update
            , subscriptions = subscriptions
            }

A _simple program_ runs a single task and then ends. It is made with
[`simpleProgram`](#simpleProgram):

    main : Platform.Program System.Environment () ()
    main =
        System.simpleProgram
            (\env -> Stream.logLine "Hello, world!" env.stdout)

A program runs while it has work, and ends when it has none: no messages are waiting to be
handled and no IO or timer it started is still pending. That moment is called an _empty event loop_, and
[`onEmptyEventLoop`](#onEmptyEventLoop) reports it. Some resources count as pending IO: for
example, an open `Socket.Listener` keeps the program running until it is closed, while an idle
`Socket.Connection`, with no read or write in progress, does not. None of this module's
subscriptions keeps a program running. [`exit`](#exit) and
[`exitWithCode`](#exitWithCode) end the program at once, without waiting for pending IO.

Eco compiles a program either to native code or to JavaScript run by Node. Where the two
behave differently, the docstrings say so. A native program can also be embedded in a host
application, which then owns the process. An embedded program does not end when it runs out of
work: it runs until the host stops it or it calls [`exitWithCode`](#exitWithCode). Embedding
also changes what exiting and signals do, as the functions below describe.


# Programs

@docs program, simpleProgram


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


{-| What a program is told about itself when it starts: the platform it runs on, how it was
started, and its standard streams.

  - `applicationPath` is the path of the running program. On the native backend it is the
    executable, with symbolic links resolved where the system allows it, or `Path.empty` where
    it cannot be read, which includes every system other than Linux and macOS. On the
    JavaScript backend it is the path of the compiled JavaScript file, with symbolic links
    resolved where possible, or of the `node` executable when the program is not loaded as a
    CommonJS module. The text is read with [`Path.fromPosixString`](Path#fromPosixString) on every
    system.
  - `args` holds the command line arguments. On the native backend, on Linux, macOS and
    Windows, it is the process's C `argv`, so it starts with the program as it was invoked;
    elsewhere the list is empty. Embedded
    in a host application, it is the host's `argv`. On the JavaScript backend it is Node's
    `process.argv` without the `node` executable, so it starts with the script.
  - `startTime` is read once, when the environment is built just before `init`, so `init` does
    not need to ask for the time.
  - `stdout`, `stderr` and `stdin` are three separate streams over the process's standard
    output, error and input; the `Stream` module says what can be done with them, and
    `Stream.readLine` reads standard input a line at a time. Closing or cancelling one of them
    ends that stream but leaves the process's standard file descriptor open.

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


{-| The operating system a program is running on, spelled as Node's `process.platform` spells
it. `Win32` is Windows and `Darwin` is macOS; `Linux`, `FreeBSD`, `OpenBSD`, `SunOS` and
`Aix` are the systems they name.

`UnknownPlatform` carries the name of any other platform, as the backend reported it. On the
native backend the platform is fixed when the program is compiled, and one this type does not
name is reported as `UnknownPlatform "unknown"`.

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


{-| The processor architecture a program is running on, spelled as Node's `process.arch` spells
it. `X64` is 64-bit x86 and `IA32` 32-bit x86; `Arm` and `Arm64` are 32-bit and 64-bit Arm;
`Mips` and `Mipsel` are big-endian and little-endian MIPS; `PPC` and `PPC64` are 32-bit and
64-bit PowerPC; `S390` and `S390x` are 31-bit and 64-bit IBM mainframe (s390) processors.

`UnknownArchitecture` carries the name of any other architecture, as the backend reported it.
On the native backend the architecture is fixed when the program is compiled; 64-bit RISC-V is
reported as `UnknownArchitecture "riscv64"`, and any other architecture this type does not
name as `UnknownArchitecture "unknown"`.

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


{-| Reads the environment variables of the running process, mapping each variable's name to
its value.

The variables are read when the task runs, not when the program starts. On the native backend
an entry with no `=` is read as a name with the empty value.

-}
environmentVariables : Task x (Dict String String)
environmentVariables =
    Debug.todo "Implement System API"


{-| Creates a long-running program from an `init`, an `update` and `subscriptions`, as
`Platform.worker` does, with the program's [`Environment`](#Environment) as its flags.
-}
program :
    { init : Environment -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }
    -> Platform.Program Environment model msg
program =
    Debug.todo "Implement System API"


{-| Creates a simple program: one that runs the task `run` makes from the
[`Environment`](#Environment), and has no state, messages or subscriptions.

The task's result is ignored. If the task fails, the program's exit code is set to 1, as
[`setExitCode`](#setExitCode) sets it; if it succeeds, the exit code is left as it is, which is
0 unless the task set another. The program ends as any program does, so it waits for IO the
task started even after the task has finished. To end with a particular non-zero exit code,
finish the task with [`setExitCode`](#setExitCode):

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
simpleProgram : (Environment -> Task x a) -> Platform.Program Environment () ()
simpleProgram =
    Debug.todo "Implement System API"


{-| Ends the program at once with exit code 0, as `exitWithCode 0` does.
-}
exit : Cmd msg
exit =
    Debug.todo "Implement System API"


{-| Ends the program at once with exit `code`.

It does not wait for work still in progress, such as an HTTP request, a file write, a stream
write that has not yet succeeded, or a value `Stream.enqueue` has queued but not yet written,
so it is for a state where continuing makes no sense; to end once that work is done, use
[`setExitCode`](#setExitCode) instead. The exit code can be read by the process that started
the program.

On the native backend, when the program is embedded in a host application, the process is not
ended: the program stops and the host receives `code`.

-}
exitWithCode : Int -> Cmd msg
exitWithCode =
    Debug.todo "Implement System API"


{-| Sets the exit code the program ends with, without ending it.

A later `setExitCode` replaces the code, and [`exitWithCode`](#exitWithCode) ends the program
with its own.

-}
setExitCode : Int -> Task x ()
setExitCode =
    Debug.todo "Implement System API"


{-| Creates a subscription that receives `msg` when the program has an empty event loop:
no messages are waiting to be handled and no IO is pending, so the program would otherwise end.

If handling the message starts new IO, the program keeps running, and `msg` arrives again the
next time it runs out of work. If it starts none, the program ends once any other work it
started has finished. The two backends count different work as new: on the native backend any
asynchronous work does, a `Process.sleep` included, while on the JavaScript backend only IO
started through this package's streams and kernels does.

On the native backend the subscription never fires when the program is embedded in a host
application.

-}
onEmptyEventLoop : msg -> Sub msg
onEmptyEventLoop =
    Debug.todo "Implement System API"


{-| Creates a subscription that receives `msg` when the process is sent an interrupt
signal (`SIGINT`, the signal a terminal sends on Ctrl+C).

While the subscription exists, the signal no longer ends the program, so ending it is up to the
program. The subscription does not keep the program running. On the native backend it has no
effect on Windows or when the program is embedded in a host application: it never fires, and
the signal is handled as it would be without it.

-}
onSignalInterrupt : msg -> Sub msg
onSignalInterrupt =
    Debug.todo "Implement System API"


{-| Creates a subscription that receives `msg` when the process is sent a terminate
signal (`SIGTERM`, the request to shut down that service managers and the `kill` command send).

While the subscription exists, the signal no longer ends the program, so ending it is up to the
program. The subscription does not keep the program running. On the native backend it has no
effect on Windows or when the program is embedded in a host application: it never fires, and
the signal is handled as it would be without it.

-}
onSignalTerminate : msg -> Sub msg
onSignalTerminate =
    Debug.todo "Implement System API"

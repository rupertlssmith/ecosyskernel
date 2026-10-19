module Stream exposing
    ( Readable, fromList, read, readString, readLine, readUntilClosed, cancelReadable
    , Writable, write, writeString, writeLine, enqueue, closeWritable, cancelWritable
    , log, logString, logLine
    , Error(..), errorToString
    , Transformation, pipeThrough, awaitAndPipeThrough, pipeTo
    )

{-| When moving a lot of data out of and into memory, it's rare for the entire chunk of data to
be moved in a single piece. When reading data from a file on disk, or when retrieving data from a
remote web service, it's common to retrieve one chunk of data at a time and then reassemble those
chunks when we have all the pieces. In most cases, this process is handled for you automatically.

However, it can be useful to operate on these chunks as they come in. If you're reading a
compressed file from disk, decompressing the chunks as they come in allows you to utilize the
pause between receiving them, increasing the perceived performance of the operation. It also
allows you to save memory by not having to store the entire compressed file in memory before
beginning the decompression process.

Streams are the abstraction that allows us to work on data that is in transit. They can also
serve as a tool for communication between different parts of your code base.

We have three kinds of streams: readable streams, writable streams, and transformation streams.
Transformations are built with [`Stream.Transformation`](Stream-Transformation).

This module is a port of the `Stream` module of gren-lang/core 7.5.0, together with gren's
`Stream.Log`. The deliberate differences are: `fromArray` is called [`fromList`](#fromList);
[`enqueue`](#enqueue) on a closed stream fails with `Cancelled` instead of producing an unhandled
rejection; [`readLine`](#readLine) is new; the logging functions are part of this module and take
the stream last, like [`write`](#write); and the transformations moved to their own module.


# Readable Streams

@docs Readable, fromList, read, readString, readLine, readUntilClosed, cancelReadable


# Writable Streams

@docs Writable, write, writeString, writeLine, enqueue, closeWritable, cancelWritable


# Logging

@docs log, logString, logLine


# Error Handling

@docs Error, errorToString


# Transformation Streams

@docs Transformation, pipeThrough, awaitAndPipeThrough, pipeTo

-}

import Bytes exposing (Bytes)
import Task exposing (Task)


{-| A source of data. You can only read data out of a `Readable` stream, not write data into it.
-}
type Readable value
    = Readable


{-| Create a [`Readable`](#Readable) stream that delivers the values in the provided `List`, in
order, before closing.

This was called `fromArray` in gren.

-}
fromList : List a -> Task Error (Readable a)
fromList =
    Debug.todo "Implement System API"


{-| Read a value off the stream. The `Task` will not succeed until a value can be read.

Once the stream has been closed and every buffered value has been read, the `Task` fails with
`Closed`. If the stream has been cancelled, it fails with `Cancelled` and the cancellation reason.
Only one read can wait on a stream at a time; a second concurrent read fails with `Locked`.

-}
read : Readable value -> Task Error value
read =
    Debug.todo "Implement System API"


{-| Read `Bytes` off the stream and attempt to convert them into a `String`. The bytes must be
valid UTF-8. If the conversion fails, the stream is cancelled and the `Task` fails with
`Cancelled`.

Each call reads a single chunk. A multi-byte character split across two chunks will not convert;
use [`readLine`](#readLine) for line-oriented text, or
[`Stream.Transformation.textDecoder`](Stream-Transformation#textDecoder) when reading text from a
byte stream in pieces.

This was called `readBytesAsString`.

-}
readString : Readable Bytes -> Task Error String
readString =
    Debug.todo "Implement System API"


{-| Read the next line off a byte stream: everything up to the next newline (`\n`), decoded as
UTF-8, without the newline and without a carriage return (`\r`) just before it.

    countLines : Readable Bytes -> Int -> Task Error Int
    countLines stdin n =
        Stream.readLine stdin
            |> Task.andThen (\_ -> countLines stdin (n + 1))
            |> Task.onError
                (\err ->
                    case err of
                        Stream.Closed ->
                            Task.succeed n

                        _ ->
                            Task.fail err
                )

A last line without a newline is returned as it is; after that the `Task` fails with `Closed`.
Lines may be longer than the chunks the stream delivers. Bytes read past the newline are kept for
the next read from the stream, so `readLine` can be mixed with [`read`](#read) and
[`readString`](#readString). If a line is not valid UTF-8, the stream is cancelled and the `Task`
fails with `Cancelled`.

-}
readLine : Readable Bytes -> Task Error String
readLine =
    Debug.todo "Implement System API"


{-| Read values off the stream, incrementally building a value with the provided function, until
the stream is closed or some error occurs. When the stream closes, the accumulated value is the
result of the `Task`.

If the provided function returns an `Err`, the attached `String` is used as the cancellation
reason for the stream, and the `Task` fails with `Cancelled`.

-}
readUntilClosed : (a -> b -> Result String b) -> b -> Readable a -> Task Error b
readUntilClosed =
    Debug.todo "Implement System API"


{-| Cancel the stream. This indicates a fatal error, and the given `String` should explain in a
human-readable way what that error is. If the stream contains a buffer, the buffer is dropped.

It will not be possible to read another value out of this stream: later reads fail with `Closed`.
Writes into the other end of the stream fail with `Cancelled` and the given reason.

-}
cancelReadable : String -> Readable value -> Task Error ()
cancelReadable =
    Debug.todo "Implement System API"


{-| A destination for data. You can only write data into a `Writable` stream, not read data out
of it.
-}
type Writable value
    = Writable


{-| Write a value into the stream. The returned `Task` only succeeds when the written value has
been accepted, meaning it has been passed on to a [`Readable`](#Readable) stream or its buffer, or,
for a stream backed by a file or other device, written out.

Writing to a closed stream fails with `Cancelled`.

-}
write : value -> Writable value -> Task Error (Writable value)
write =
    Debug.todo "Implement System API"


{-| Convert the given `String` to UTF-8 `Bytes` and write it to the stream.

This was called `writeStringAsBytes`.

-}
writeString : String -> Writable Bytes -> Task Error (Writable Bytes)
writeString =
    Debug.todo "Implement System API"


{-| Same as [`writeString`](#writeString) except a newline character is appended to the `String`
before conversion.

This was called `writeLineAsBytes`.

-}
writeLine : String -> Writable Bytes -> Task Error (Writable Bytes)
writeLine =
    Debug.todo "Implement System API"


{-| Queue a value to be written into the stream. The returned `Task` succeeds when the value is
in the stream's buffer.

The difference between this and [`write`](#write) is when the `Task` succeeds. Because the `Task`
from this function succeeds once the value is in a buffer, we won't be able to detect if the stream
is cancelled before the value is passed on to somewhere else. On the other hand, we can assume the
`Task` succeeds as long as there is room in the buffer, even if no one is actively reading from
the stream.

Enqueueing on a closed stream fails with `Cancelled`. (In gren this produced an unhandled
rejection instead.) In general you should prefer [`write`](#write), and reach for this function if
you experience problems.

-}
enqueue : value -> Writable value -> Task Error (Writable value)
enqueue =
    Debug.todo "Implement System API"


{-| Close the stream. This indicates that no new values will be added to the stream after this
point. The `Task` succeeds once all values written before the close have been passed on, and
readers on the other end receive `Closed` once they have read everything.

Closing a stream that is already closed fails with `Cancelled`.

-}
closeWritable : Writable value -> Task Error ()
closeWritable =
    Debug.todo "Implement System API"


{-| Cancel the stream. This indicates a fatal error, and the given `String` should explain in a
human-readable way what that error is. If the stream contains a buffer, the buffer is dropped.

Writes that are still waiting fail with `Cancelled`, and reads from the other end of the stream
fail with `Cancelled` and the given reason.

-}
cancelWritable : String -> Writable value -> Task Error ()
cancelWritable =
    Debug.todo "Implement System API"


{-| Write `Bytes` to a byte stream on a best effort basis: the `Task` succeeds once the write has
finished or failed, and any error is ignored.

We don't normally encourage ignoring errors in this way, but for the explicit purpose of logging
it's not always clear how you would handle an error. If you cannot log an error message to the
terminal, do you try again? Try again on another stream? What if that also fails? Only use the
`log` functions if there is no sane way to handle a failed write.

This was `Stream.Log.bytes`, which took the stream first.

-}
log : Bytes -> Writable Bytes -> Task x ()
log =
    Debug.todo "Implement System API"


{-| Write a `String`, encoded as UTF-8, to a byte stream. Any error is ignored, as for
[`log`](#log).

This was `Stream.Log.string`, which took the stream first.

-}
logString : String -> Writable Bytes -> Task x ()
logString =
    Debug.todo "Implement System API"


{-| Write a `String`, encoded as UTF-8, to a byte stream, followed by a newline character. Any
error is ignored, as for [`log`](#log).

    Stream.logLine "Hello, world!" env.stdout

This was `Stream.Log.line`, which took the stream first.

-}
logLine : String -> Writable Bytes -> Task x ()
logLine =
    Debug.todo "Implement System API"


{-| The different kinds of errors that can happen when operating on a stream.

  - `Closed`: The stream will never accept or produce another value.
  - `Cancelled`: The stream has been terminated, possibly because something went wrong. The
    associated `String` contains a human readable error message.
  - `Locked`: The stream is already being read from or written to, or is part of a pipe. You
    might have to retry the operation.

-}
type Error
    = Closed
    | Cancelled String
    | Locked


{-| Give a human readable description of an error.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| A readable-writable stream pair. Whatever is written to the writable stream can be retrieved
from the readable stream. After data is written, and before it is placed on the readable stream,
it goes through a transformation function. This function can alter the data, or even drop it
entirely.

A `Transformation input output` accepts `input` values on its
[`writable`](Stream-Transformation#writable) side and produces `output` values on its
[`readable`](Stream-Transformation#readable) side;
[`textEncoder`](Stream-Transformation#textEncoder), for example, is a
`Transformation String Bytes`. (gren-lang/core's annotations of `readable` and `writable` had the
two parameters the wrong way round.)

Transformations are created with the functions in
[`Stream.Transformation`](Stream-Transformation), and used with [`pipeThrough`](#pipeThrough).

-}
type Transformation input output
    = Transformation


{-| When data becomes available on a [`Readable`](#Readable) stream, immediately write that data
to the [`Transformation`](#Transformation). This locks both streams, and closing one will close the
other.

On success, the [`Readable`](#Readable) stream of the [`Transformation`](#Transformation) is
returned. If either stream is already locked, the `Task` fails with `Locked`.

-}
pipeThrough : Transformation input output -> Readable input -> Task Error (Readable output)
pipeThrough =
    Debug.todo "Implement System API"


{-| Same as [`pipeThrough`](#pipeThrough), except the [`Transformation`](#Transformation) is
resolved from a `Task`, such as [`Stream.Transformation.gunzip`](Stream-Transformation#gunzip).
-}
awaitAndPipeThrough : Task Error (Transformation input output) -> Readable input -> Task Error (Readable output)
awaitAndPipeThrough =
    Debug.todo "Implement System API"


{-| When data becomes available on a [`Readable`](#Readable) stream, immediately write that data
to the [`Writable`](#Writable) stream. This locks both streams.

When the readable stream closes, the writable stream is closed as well, and the `Task` succeeds.
If either stream is cancelled, the other one is cancelled with the same reason and the `Task`
fails with `Cancelled`.

-}
pipeTo : Writable data -> Readable data -> Task Error ()
pipeTo =
    Debug.todo "Implement System API"

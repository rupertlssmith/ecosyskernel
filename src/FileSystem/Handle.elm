module FileSystem.Handle exposing
    ( Handle, ReadableHandle, WriteableHandle, ReadWriteableHandle, ReadAccess, WriteAccess, makeReadOnly, makeWriteOnly
    , openForRead, OpenForWriteBehaviour(..), openForWrite, openForReadAndWrite, close
    , metadata, changeAccess, changeOwner, changeTimes
    , read, readFromOffset
    , write, writeFromOffset, truncate, sync, syncData
    )

{-| This module provides access to files through file handles. A [Handle](#Handle)
represents an open file. If you know you're going to perform repeated operations on a file, it
will be more efficient through a [Handle](#Handle).

The error type is the [Error](FileSystem#Error) from [FileSystem](FileSystem). For operations
on an open [Handle](#Handle), [errorPath](FileSystem#errorPath) returns the empty path;
only a failure to open a file reports the path that was being opened.

Handles have no file position. [read](#read) reads the whole file and [write](#write) writes
at offset 0, so two `write` calls overwrite each other rather than appending; every other read
and write names its offset. For sequential IO, use
[FileSystem.readFileStream](FileSystem#readFileStream) and
[FileSystem.writeFileStream](FileSystem#writeFileStream) instead.

Most programs don't need handles: [FileSystem.writeFileWith](FileSystem#writeFileWith) covers
durable writes and exclusive create. Handles are for random access on one open file, and for
operations that must apply to the file you opened even if its path is renamed or replaced.

Compared with gren-node's file handle module, the type is called [Handle](#Handle) (gren:
`FileHandle`), the phantom types are named
[ReadAccess](#ReadAccess) and [WriteAccess](#WriteAccess) (gren: `ReadPermission` and
`WritePermission`), and opening a file needs no permission value.

@docs Handle, ReadableHandle, WriteableHandle, ReadWriteableHandle, ReadAccess, WriteAccess, makeReadOnly, makeWriteOnly


## File open/close

@docs openForRead, OpenForWriteBehaviour, openForWrite, openForReadAndWrite, close


## File metadata

@docs metadata, changeAccess, changeOwner, changeTimes


## Read from file

@docs read, readFromOffset


## Write to file

@docs write, writeFromOffset, truncate, sync, syncData

-}

import Bytes exposing (Bytes)
import FileSystem
import Path exposing (Path)
import Task exposing (Task)
import Time


{-| A file handle is used to perform operations on a file, like reading and writing.

Having a file handle gives you access to perform certain operations, so make sure you
only pass a file handle to code you can trust.

The [Handle](#Handle) type also records whether the file may be read and written as
part of its type, using [ReadAccess](#ReadAccess) and [WriteAccess](#WriteAccess).

-}
type Handle readAccess writeAccess
    = Handle


{-| A type that represents the right to read from a file.

Named `ReadPermission` in gren-node.

-}
type ReadAccess
    = ReadAccess


{-| A type that represents the right to write to a file.

Named `WritePermission` in gren-node.

-}
type WriteAccess
    = WriteAccess


{-| An alias for a [Handle](#Handle) that can be used in read operations.
-}
type alias ReadableHandle a =
    Handle ReadAccess a


{-| An alias for a [Handle](#Handle) that can be used in write operations.
-}
type alias WriteableHandle a =
    Handle a WriteAccess


{-| An alias for a [Handle](#Handle) that can be used for both read and write operations.
-}
type alias ReadWriteableHandle =
    Handle ReadAccess WriteAccess


{-| This lets you downgrade a [ReadWriteableHandle](#ReadWriteableHandle) to a
[Handle](#Handle) that only has read access.

Comes in handy when you want full access to a file in some parts of your code, but limited access
in other parts of your code.

-}
makeReadOnly : ReadWriteableHandle -> Handle ReadAccess Never
makeReadOnly =
    Debug.todo "Implement System API"


{-| This lets you downgrade a [ReadWriteableHandle](#ReadWriteableHandle) to a
[Handle](#Handle) that only has write access.

Comes in handy when you want full access to a file in some parts of your code, but limited access
in other parts of your code.

-}
makeWriteOnly : ReadWriteableHandle -> Handle Never WriteAccess
makeWriteOnly =
    Debug.todo "Implement System API"


{-| Open the file at the provided path with read access. The task fails if the file doesn't exist.
-}
openForRead : Path -> Task FileSystem.Error (Handle ReadAccess Never)
openForRead =
    Debug.todo "Implement System API"


{-| There are several ways to open a file for writing.

  - `EnsureEmpty` will create an empty file if it doesn't exist, or remove all contents of a file
    if it does exist.
  - `ExpectExisting` will fail the task if the file doesn't exist.
  - `ExpectNotExisting` will fail the task if the file does exist.

-}
type OpenForWriteBehaviour
    = EnsureEmpty
    | ExpectExisting
    | ExpectNotExisting


{-| Open a file at the provided path with write access.
-}
openForWrite : OpenForWriteBehaviour -> Path -> Task FileSystem.Error (Handle Never WriteAccess)
openForWrite =
    Debug.todo "Implement System API"


{-| Open a file at the provided path with both read and write access.
-}
openForReadAndWrite : OpenForWriteBehaviour -> Path -> Task FileSystem.Error ReadWriteableHandle
openForReadAndWrite =
    Debug.todo "Implement System API"


{-| Close a file. All later operations performed against the given [Handle](#Handle)
will fail.
-}
close : Handle a b -> Task FileSystem.Error ()
close =
    Debug.todo "Implement System API"


{-| Retrieve [Metadata](FileSystem#Metadata) about the file represented by the
[Handle](#Handle).

**Deviation from gren-node:** the task succeeds with the `Metadata` itself; gren-node's
annotation wrapped it in a file handle type by mistake.

-}
metadata : ReadableHandle a -> Task FileSystem.Error FileSystem.Metadata
metadata =
    Debug.todo "Implement System API"


{-| Change how different users can access a file. Each list becomes one octal digit of the
file mode, as in [FileSystem.changeAccess](FileSystem#changeAccess).
-}
changeAccess :
    { owner : List FileSystem.AccessPermission, group : List FileSystem.AccessPermission, others : List FileSystem.AccessPermission }
    -> WriteableHandle a
    -> Task FileSystem.Error (WriteableHandle a)
changeAccess =
    Debug.todo "Implement System API"


{-| Change who owns the file. You'll need the ID of the new user and group who will own the file.
-}
changeOwner : { userID : Int, groupID : Int } -> WriteableHandle a -> Task FileSystem.Error (WriteableHandle a)
changeOwner =
    Debug.todo "Implement System API"


{-| This will let you set the timestamp for when the file was last accessed, and last modified.
The times will be rounded down to the closest second.
-}
changeTimes : { lastAccessed : Time.Posix, lastModified : Time.Posix } -> WriteableHandle a -> Task FileSystem.Error (WriteableHandle a)
changeTimes =
    Debug.todo "Implement System API"


{-| Read all bytes in a file.
-}
read : ReadableHandle a -> Task FileSystem.Error Bytes
read =
    Debug.todo "Implement System API"


{-| Read `length` number of bytes from a file, starting at `offset` bytes.

A negative `length` reads everything from `offset` to the end of the file. Fewer bytes than asked
for are returned if the end of the file is reached first.

-}
readFromOffset : ReadableHandle a -> { offset : Int, length : Int } -> Task FileSystem.Error Bytes
readFromOffset =
    Debug.todo "Implement System API"


{-| Write the provided bytes into the file, starting at the beginning of the file (offset 0).
If the file is not empty, existing bytes will be overwritten. Use
[writeFromOffset](#writeFromOffset) to write somewhere else.
-}
write : WriteableHandle a -> Bytes -> Task FileSystem.Error (WriteableHandle a)
write =
    Debug.todo "Implement System API"


{-| Write bytes into a specific location of a file, given as a byte offset from the beginning
of the file.
-}
writeFromOffset : WriteableHandle a -> Int -> Bytes -> Task FileSystem.Error (WriteableHandle a)
writeFromOffset =
    Debug.todo "Implement System API"


{-| Make sure that a file is of the given size. If the file is larger than the given size, excess
bytes are discarded. If the file is smaller than the given size, zeroes will be added until it is
of the given size.
-}
truncate : Int -> WriteableHandle a -> Task FileSystem.Error (WriteableHandle a)
truncate =
    Debug.todo "Implement System API"


{-| Usually when you make changes to a file, the changes aren't actually written to disk right
away. The changes are likely placed in an OS-level buffer, and flushed to disk when the OS decides
it's time to do so.

This task, when executed, will force changes to be written to disk.

-}
sync : WriteableHandle a -> Task FileSystem.Error (WriteableHandle a)
sync =
    Debug.todo "Implement System API"


{-| Same as [sync](#sync), except it only forces the contents of the file to be written. Changes
to a file's metadata are not synced. This operation might be a little faster than a full sync, at
the risk of losing changes to metadata.
-}
syncData : WriteableHandle a -> Task FileSystem.Error (WriteableHandle a)
syncData =
    Debug.todo "Implement System API"

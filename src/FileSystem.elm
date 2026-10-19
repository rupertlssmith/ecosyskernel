module FileSystem exposing
    ( Metadata, EntityType(..), metadata, AccessPermission(..), checkAccess, changeAccess, accessPermissionsToInt, changeOwner, changeTimes, move, realPath
    , copyFile, appendToFile, readFile, ReadFileStreamMode(..), readFileStream, writeFile, WriteFileStreamMode(..), writeFileStream, truncateFile, remove
    , WriteOptions, defaultWriteOptions, writeFileWith, writeFileStreamWith
    , listDirectory, makeDirectory, makeTempDirectory
    , hardLink, softLink, readLink, unlink
    , WatchEvent(..), watch, watchRecursive
    , homeDirectory, currentWorkingDirectory, tempDirectory, devNull
    , Error, errorPath, errorCode, errorToString
    , errorIsPermissionDenied, errorIsFileExists, errorIsDirectoryFound, errorIsTooManyOpenFiles, errorIsNoSuchFileOrDirectory, errorIsNotADirectory, errorIsDirectoryNotEmpty, errorIsNotPermitted, errorIsLinkLoop, errorIsPathTooLong, errorIsInvalidInput, errorIsIO
    )

{-| This module provides access to the file system. It allows you to read and write files, create
directories and links, and so on. Locations are given as a [Path](Path#Path).

Every function that changes the file system succeeds with the [Path](Path#Path) it was
given, which makes it easy to chain operations on the same entity. If you know you are going to
perform many operations on the same file, or need to read and write at arbitrary offsets,
[FileSystem.Handle](FileSystem-Handle) can be more efficient. Writes that must reach the disk
before you continue, and writes that must not replace an existing file, don't need handles: see
[writeFileWith](#writeFileWith) and [writeFileStreamWith](#writeFileStreamWith).

Unlike gren-node's `FileSystem` module, no permission value is needed to use these functions.


## Metadata

@docs Metadata, EntityType, metadata, AccessPermission, checkAccess, changeAccess, accessPermissionsToInt, changeOwner, changeTimes, move, realPath


## Files

@docs copyFile, appendToFile, readFile, ReadFileStreamMode, readFileStream, writeFile, WriteFileStreamMode, writeFileStream, truncateFile, remove


## Durable and exclusive writes

@docs WriteOptions, defaultWriteOptions, writeFileWith, writeFileStreamWith


## Directories

@docs listDirectory, makeDirectory, makeTempDirectory


## Links

@docs hardLink, softLink, readLink, unlink


## Watch for changes

@docs WatchEvent, watch, watchRecursive


## Special paths

@docs homeDirectory, currentWorkingDirectory, tempDirectory, devNull


## Errors

@docs Error, errorPath, errorCode, errorToString
@docs errorIsPermissionDenied, errorIsFileExists, errorIsDirectoryFound, errorIsTooManyOpenFiles, errorIsNoSuchFileOrDirectory, errorIsNotADirectory, errorIsDirectoryNotEmpty, errorIsNotPermitted, errorIsLinkLoop, errorIsPathTooLong, errorIsInvalidInput, errorIsIO

-}

import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Path exposing (Path)
import Stream
import Task exposing (Task)
import Time


{-| Represents an error that occurred when working with the file system.

There are many different kinds of error depending on which operation you're performing and which
operating system you're performing it on. To figure out which error it is, you'll need
to use one of the helper functions below, or check the specific error code.

-}
type Error
    = Error


{-| The path where the error occurred.

For [copyFile](#copyFile), [move](#move), [hardLink](#hardLink) and [softLink](#softLink) this
is the **destination** path.

-}
errorPath : Error -> Path
errorPath =
    Debug.todo "Implement System API"


{-| A string that identifies a specific kind of error. There can be several error codes for the
same kind of error, depending on the operating system that is in use.

This is usually an errno name such as `"ENOENT"`. A non-recursive [remove](#remove) of a directory
reports `"ERR_FS_EISDIR"`, so [errorIsDirectoryFound](#errorIsDirectoryFound) is `False` in that case.

-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| Returns a human readable description of the error.
-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| If `True`, the error occurred because you don't have the correct access permission to perform
the operation.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| If `True`, a file exists when it was expected not to.
-}
errorIsFileExists : Error -> Bool
errorIsFileExists =
    Debug.todo "Implement System API"


{-| If `True`, a file operation was attempted on a directory.
-}
errorIsDirectoryFound : Error -> Bool
errorIsDirectoryFound =
    Debug.todo "Implement System API"


{-| If `True`, the application has too many open files.
-}
errorIsTooManyOpenFiles : Error -> Bool
errorIsTooManyOpenFiles =
    Debug.todo "Implement System API"


{-| If `True`, the code was passed a [Path](Path#Path) which points to a file or
directory that doesn't exist.
-}
errorIsNoSuchFileOrDirectory : Error -> Bool
errorIsNoSuchFileOrDirectory =
    Debug.todo "Implement System API"


{-| If `True`, a directory was expected but it found a file or some other entity.
-}
errorIsNotADirectory : Error -> Bool
errorIsNotADirectory =
    Debug.todo "Implement System API"


{-| If `True`, the operation expected an empty directory, but the directory is not empty.
-}
errorIsDirectoryNotEmpty : Error -> Bool
errorIsDirectoryNotEmpty =
    Debug.todo "Implement System API"


{-| If `True`, the operation was rejected because of missing privileges.
-}
errorIsNotPermitted : Error -> Bool
errorIsNotPermitted =
    Debug.todo "Implement System API"


{-| If `True`, we seem to be stuck in a loop following link after link after...
-}
errorIsLinkLoop : Error -> Bool
errorIsLinkLoop =
    Debug.todo "Implement System API"


{-| If `True`, the [Path](Path#Path) is too long.
-}
errorIsPathTooLong : Error -> Bool
errorIsPathTooLong =
    Debug.todo "Implement System API"


{-| If `True`, the arguments passed to the function are invalid somehow.
-}
errorIsInvalidInput : Error -> Bool
errorIsInvalidInput =
    Debug.todo "Implement System API"


{-| If `True`, the operation failed due to an IO error. This could be that the disk is
busy, or even corrupt.
-}
errorIsIO : Error -> Bool
errorIsIO =
    Debug.todo "Implement System API"


{-| Represents extra information about an entity in the file system.

Sizes are in bytes, and the four times have millisecond resolution where the operating system
provides it.

-}
type alias Metadata =
    { entityType : EntityType
    , deviceID : Int
    , userID : Int
    , groupID : Int
    , byteSize : Int
    , blockSize : Int
    , blocks : Int
    , lastAccessed : Time.Posix
    , lastModified : Time.Posix
    , lastChanged : Time.Posix
    , created : Time.Posix
    }


{-| The type of an entity in the file system.
-}
type EntityType
    = File
    | Directory
    | Socket
    | Symlink
    | Device
    | Pipe


{-| Return metadata for the entity represented by [Path](Path#Path).

If `resolveLink` is `False`, you will receive metadata for the link itself, not the entity
pointed at by the link.

-}
metadata : { resolveLink : Bool } -> Path -> Task Error Metadata
metadata =
    Debug.todo "Implement System API"


{-| Represents the permission to access an entity for a specific operation.

For example: if you, or your group, doesn't have the `Read` permission for a file,
you're not allowed to read from it.

-}
type AccessPermission
    = Read
    | Write
    | Execute


{-| Check if the user running this application has the given access permissions for the
entity represented by [Path](Path#Path).

Passing an empty `List` will check that the entity exists.

-}
checkAccess : List AccessPermission -> Path -> Task Error Path
checkAccess =
    Debug.todo "Implement System API"


{-| Change the access permissions for the entity's owner, group and everyone else.

Each list is turned into one octal digit of the file mode with
[accessPermissionsToInt](#accessPermissionsToInt), so
`{ owner = [ Read, Write ], group = [ Read ], others = [ Read ] }` sets mode `644`.

-}
changeAccess : { owner : List AccessPermission, group : List AccessPermission, others : List AccessPermission } -> Path -> Task Error Path
changeAccess =
    Debug.todo "Implement System API"


{-| The integer representation of a set of access permissions in a posix system.

    accessPermissionsToInt [ Read, Write ] == 6

-}
accessPermissionsToInt : List AccessPermission -> Int
accessPermissionsToInt =
    Debug.todo "Implement System API"


{-| Change the user and group that owns a file.

You'll need the ID of the owner and group to perform this operation.

If `resolveLink` is `False`, you're changing the owner of the link itself,
not the entity it points to.

-}
changeOwner : { userID : Int, groupID : Int, resolveLink : Bool } -> Path -> Task Error Path
changeOwner =
    Debug.todo "Implement System API"


{-| Change the registered time (down to the second) an entity was accessed and modified.
Times are rounded down to the whole second.

If `resolveLink` is `False`, you're changing the last access and modification time of the link
itself, not the entity it points to.

-}
changeTimes : { lastAccessed : Time.Posix, lastModified : Time.Posix, resolveLink : Bool } -> Path -> Task Error Path
changeTimes =
    Debug.todo "Implement System API"


{-| Move the entity represented by the second [Path](Path#Path), to the location
represented by the first [Path](Path#Path). This can also be used to rename an
entity.

    move newPath oldPath

The task succeeds with the new path. If it fails, [errorPath](#errorPath) is the new path.

-}
move : Path -> Path -> Task Error Path
move =
    Debug.todo "Implement System API"


{-| If you have a [Path](Path#Path) that is relative to the current directory,
or points at a link, you can use this to find the true [Path](Path#Path) of the
entity.
-}
realPath : Path -> Task Error Path
realPath =
    Debug.todo "Implement System API"


{-| Copy the file represented by the second [Path](Path#Path), to the location
represented by the first [Path](Path#Path).

    copyFile destinationPath sourcePath

An existing file at the destination is overwritten. The task succeeds with the destination path,
and if it fails, [errorPath](#errorPath) is the destination path.

-}
copyFile : Path -> Path -> Task Error Path
copyFile =
    Debug.todo "Implement System API"


{-| Add `Bytes` to the end of a file. The file is created if it doesn't exist.
-}
appendToFile : Bytes -> Path -> Task Error Path
appendToFile =
    Debug.todo "Implement System API"


{-| Read the entire contents of a file.

Note: This will return the entire contents of a file at once. For very large
files this might cause you to run out of memory. In those cases you might want
to use [readFileStream](#readFileStream) instead.

-}
readFile : Path -> Task Error Bytes
readFile =
    Debug.todo "Implement System API"


{-| Specify where in a file you'll start streaming data from.

  - `Beginning` reads the entire file.
  - `From` skips the associated number of bytes, then streams the rest of the file.
  - `Between` reads just the bytes between `start` and `end`, both of which are offsets from the
    beginning of the file. The `end` offset is **inclusive**: `Between { start = 0, end = 9 }`
    reads ten bytes.

-}
type ReadFileStreamMode
    = Beginning
    | From Int
    | Between { start : Int, end : Int }


{-| Read the contents of a file as a stream.

**Deviation from gren-node:** errors opening the file (for example a missing file) fail this task
itself, rather than being reported by the first read from the stream.

-}
readFileStream : ReadFileStreamMode -> Path -> Task Error (Stream.Readable Bytes)
readFileStream =
    Debug.todo "Implement System API"


{-| Write the given `Bytes` into a file. The file will be created if it doesn't exist,
and overwritten if it does.

This is [writeFileWith](#writeFileWith) with [defaultWriteOptions](#defaultWriteOptions).

-}
writeFile : Bytes -> Path -> Task Error Path
writeFile =
    Debug.todo "Implement System API"


{-| Specify how the streamed bytes will be entered into the file.

  - `Replace` will delete all existing bytes in the file and add new bytes from the beginning.
    The file is created if it doesn't exist.
  - `ReplaceFrom` will keep the associated number of bytes already in the file, but replace
    everything after with the streamed data. The file must already exist. When the stream is
    closed, the file is cut off at the end of the streamed data.
  - `Append` will keep the contents of the file untouched, and add new data at the end.
    The file is created if it doesn't exist.

-}
type WriteFileStreamMode
    = Replace
    | ReplaceFrom Int
    | Append


{-| Create a writable stream backed by a file. Close the stream when you are done writing to it.

This is [writeFileStreamWith](#writeFileStreamWith) with [defaultWriteOptions](#defaultWriteOptions).

-}
writeFileStream : WriteFileStreamMode -> Path -> Task Error (Stream.Writable Bytes)
writeFileStream =
    Debug.todo "Implement System API"


{-| Options for [writeFileWith](#writeFileWith) and [writeFileStreamWith](#writeFileStreamWith).

  - `createNew`: create the file, and fail with an error for which
    [errorIsFileExists](#errorIsFileExists) is `True` if something already exists at the path
    (`O_EXCL`). The check and the creation are one atomic step, which makes this the right tool
    for lock files and for output that must never replace an existing file.
  - `sync`: make sure the data has reached the storage device (`fsync`) before the write
    succeeds. For [writeFileStreamWith](#writeFileStreamWith) this happens when the stream is
    closed. Use it for data that must survive a crash, for example before renaming a temporary
    file over the old one with [move](#move).

-}
type alias WriteOptions =
    { createNew : Bool
    , sync : Bool
    }


{-| Both options off: plain [writeFile](#writeFile) and [writeFileStream](#writeFileStream)
behaviour.
-}
defaultWriteOptions : WriteOptions
defaultWriteOptions =
    Debug.todo "Implement System API"


{-| Same as [writeFile](#writeFile), with [WriteOptions](#WriteOptions).

    FileSystem.writeFileWith { defaultWriteOptions | createNew = True, sync = True } bytes path

-}
writeFileWith : WriteOptions -> Bytes -> Path -> Task Error Path
writeFileWith =
    Debug.todo "Implement System API"


{-| Same as [writeFileStream](#writeFileStream), with [WriteOptions](#WriteOptions). With `sync`,
closing the stream succeeds only once the data has reached the storage device.
-}
writeFileStreamWith : WriteOptions -> WriteFileStreamMode -> Path -> Task Error (Stream.Writable Bytes)
writeFileStreamWith =
    Debug.todo "Implement System API"


{-| Make sure the given file is of a specific length. If the file is smaller than
the given length, zeroes are added to the file until it is the correct length. If the file
is larger than the given length, the excess bytes are removed.
-}
truncateFile : Int -> Path -> Task Error Path
truncateFile =
    Debug.todo "Implement System API"


{-| Remove the file or directory at the given path.

  - `recursive` will delete a directory and everything in it.

Removing a directory with `recursive = False` fails with the error code `"ERR_FS_EISDIR"`.

-}
remove : { recursive : Bool } -> Path -> Task Error Path
remove =
    Debug.todo "Implement System API"


{-| List the contents of a directory. The returned [Paths](Path#Path) are relative to
the directory being listed. Entries are sorted by name, byte by byte.
-}
listDirectory : Path -> Task Error (List { path : Path, entityType : EntityType })
listDirectory =
    Debug.todo "Implement System API"


{-| Create a new directory at the given [Path](Path#Path).

If `recursive` is `True`, then a directory will be created for every section of the
given [Path](Path#Path).

-}
makeDirectory : { recursive : Bool } -> Path -> Task Error Path
makeDirectory =
    Debug.todo "Implement System API"


{-| Create a directory, prefixed by a given name, that ends up in a section of the
file system reserved for temporary files (see [tempDirectory](#tempDirectory)). You're given the
[Path](Path#Path) to this new directory.

A few random characters are added after the prefix, so every call creates a new directory.

-}
makeTempDirectory : String -> Task Error Path
makeTempDirectory =
    Debug.todo "Implement System API"


{-| Creates a hard link from the second [Path](Path#Path) to the first.

    hardLink linkPath targetPath

A hard link is an alias for a specific location. The link has the same
ownership and access permissions, and it's impossible to tell which is
the "real" entity and which is the link.

-}
hardLink : Path -> Path -> Task Error Path
hardLink =
    Debug.todo "Implement System API"


{-| Creates a soft link from the second [Path](Path#Path) to the first.

    softLink linkPath targetPath

A soft link, also known as a symbolic link or symlink, is a special file
that contains the path to some other location. Resolving a soft link will
redirect to this other location.

-}
softLink : Path -> Path -> Task Error Path
softLink =
    Debug.todo "Implement System API"


{-| Returns the [Path](Path#Path) pointed to by a soft link.
-}
readLink : Path -> Task Error Path
readLink =
    Debug.todo "Implement System API"


{-| Removes a link, hard or soft, from the file system. If the
[Path](Path#Path) refers to a file, the file is removed.
-}
unlink : Path -> Task Error Path
unlink =
    Debug.todo "Implement System API"


{-| Represents a change within a watched directory.

  - `Changed` means that the contents of a file has changed in some way.
  - `Moved` means that an entity has been added or removed. A rename is usually two `Moved` events.

On most operating systems, each event will be associated with a [Path](Path#Path)
relative to the watched directory, but some operating systems will not provide that information.

-}
type WatchEvent
    = Changed (Maybe Path)
    | Moved (Maybe Path)


{-| This notifies your application every time there is a change within the directory
represented by the given [Path](Path#Path).
-}
watch : (WatchEvent -> msg) -> Path -> Sub msg
watch =
    Debug.todo "Implement System API"


{-| Same as [watch](#watch), but this will also watch for changes in sub-directories.
-}
watchRecursive : (WatchEvent -> msg) -> Path -> Sub msg
watchRecursive =
    Debug.todo "Implement System API"


{-| Find the [Path](Path#Path) that represents the home directory of the current user.

This is `$HOME` when it is set, and otherwise the home directory recorded for the user in the
system's user database.

-}
homeDirectory : Task x Path
homeDirectory =
    Debug.todo "Implement System API"


{-| Returns the current working directory of the program.

This is the directory that all relative paths are relative to, and is usually the
directory that the program was executed from.

-}
currentWorkingDirectory : Task x Path
currentWorkingDirectory =
    Debug.todo "Implement System API"


{-| Find a [Path](Path#Path) that represents a directory meant to hold temporary files.

This is the first of the `TMPDIR`, `TMP` and `TEMP` environment variables that is set, and
`/tmp` otherwise.

-}
tempDirectory : Task x Path
tempDirectory =
    Debug.todo "Implement System API"


{-| [Path](Path#Path) to a file which is always empty. Anything written to this file
will be discarded.
-}
devNull : Task x Path
devNull =
    Debug.todo "Implement System API"

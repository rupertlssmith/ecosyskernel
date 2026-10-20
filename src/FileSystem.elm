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

{-| A program needs to read, write and manage the files, directories and links it names, and this
module does that by [Path](Path#Path). Apart from the file streams, each task here opens and
closes whatever it needs. To keep a file open, read and write it at offsets, or act on the file
that was opened even after its path has been renamed or replaced, use
[FileSystem.Handle](FileSystem-Handle).

An _entity_ is anything a path can name: a file, a directory, a symbolic link, a socket, a device
or a pipe (see [EntityType](#EntityType)).

A path reaches the operating system as the text [Path.toPosixString](Path#toPosixString) prints,
and every path that comes back, from [realPath](#realPath), [readLink](#readLink),
[listDirectory](#listDirectory), [makeTempDirectory](#makeTempDirectory), the special paths and
watch events, is parsed with [Path.fromPosixString](Path#fromPosixString). Both are lexical and
lossy, as the [Path](Path) module describes.

Most functions that change the file system succeed with a `Path`, so that calls on one entity can
be chained. It is the path the function was given, with two exceptions. The two-path functions
[move](#move), [copyFile](#copyFile), [hardLink](#hardLink) and [softLink](#softLink) take the
destination, or the new link, first and the source, or the target, second, and succeed with the
first. [makeTempDirectory](#makeTempDirectory) succeeds with the directory it created.
[writeFileStream](#writeFileStream) and [writeFileStreamWith](#writeFileStreamWith) succeed with
a stream instead.

A task here that fails, fails with an [Error](#Error), which carries the path it concerns, a
code and a message. For the two-path functions that path is the first one as well;
[errorPath](#errorPath) gives the full rule.

[readFileStream](#readFileStream) and [writeFileStream](#writeFileStream) hand the file over as
a stream. They open the file before the task succeeds, so a file that cannot be opened fails the
task with an `Error`. After that, failures arrive on the stream as a `Stream.Error`, as the
[Stream](Stream) module describes.

Two kinds of write ask more than [writeFile](#writeFile) gives, and [WriteOptions](#WriteOptions)
selects them. A _durable_ write flushes the file's data to the storage device before it
succeeds. An _exclusive_ write creates the file, and fails if anything already exists at the
path.

[watch](#watch) and [watchRecursive](#watchRecursive) are subscriptions to changes at a path.
While a subscription to a path that could be watched exists, it keeps the program running.

On the native backend under Windows the file system is not supported: every task here that can
fail fails with the code `"ENOTSUP"`, and a watch subscription stops the program with a fatal
error.


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

import FileSystem.Internal
import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Path exposing (Path)
import Stream
import Task exposing (Task)
import Time


{-| A failed file system operation: the path it concerned, a code naming the kind of failure,
and a message describing it.

The three parts are read with [errorPath](#errorPath), [errorCode](#errorCode) and
[errorToString](#errorToString), and the `errorIs*` functions test the code. Which code a
failure gets can depend on the operating system. An `Error` is not interchangeable with
`Socket.Error` or `Stream.Error`. Only the tasks of this module and of
[FileSystem.Handle](FileSystem-Handle) make one.

-}
type alias Error =
    FileSystem.Internal.Error


{-| Returns the path an error concerns.

For a function of this module it is the path the function was given, with two exceptions. For
[move](#move), [copyFile](#copyFile), [hardLink](#hardLink) and [softLink](#softLink) it is the
first path, the destination or new link, even when the failure was about the source. For
[makeTempDirectory](#makeTempDirectory) it is [tempDirectory](#tempDirectory) with the prefix
appended, without the random characters, which is not the path of any directory it created.

For an operation on an open [FileSystem.Handle](FileSystem-Handle) it is
[Path.empty](Path#empty).

-}
errorPath : Error -> Path
errorPath =
    Debug.todo "Implement System API"


{-| Returns the code naming the kind of failure.

It is usually the operating system's errno name, such as `"ENOENT"`. A non-recursive
[remove](#remove) of a directory reports `"ERR_FS_EISDIR"`, so
[errorIsDirectoryFound](#errorIsDirectoryFound) is `False` in that case.

-}
errorCode : Error -> String
errorCode =
    Debug.todo "Implement System API"


{-| Returns the error's message as the kernel gave it, with no code or path added.

The message usually begins with the code, as in `"ENOENT: no such file or directory, open '/x'"`.
The message for `"ERR_FS_EISDIR"` does not: it is
`"Path is a directory: rm returned EISDIR (is a directory) /x"`.

-}
errorToString : Error -> String
errorToString =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EACCES"`: access permissions, of the entity or of a directory on
its path, refused the operation.
-}
errorIsPermissionDenied : Error -> Bool
errorIsPermissionDenied =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EEXIST"`: something already exists at a path that had to be new,
as for an exclusive write (see [WriteOptions](#WriteOptions)) or a link path that is taken.
-}
errorIsFileExists : Error -> Bool
errorIsFileExists =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EISDIR"`: a directory was found where a file was needed, as when
[readFile](#readFile), [readFileStream](#readFileStream) or [copyFile](#copyFile) is given a
directory. A non-recursive [remove](#remove) of a directory reports `"ERR_FS_EISDIR"` instead, for
which this is `False`.
-}
errorIsDirectoryFound : Error -> Bool
errorIsDirectoryFound =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EMFILE"`: the program has as many files open as it is allowed.
-}
errorIsTooManyOpenFiles : Error -> Bool
errorIsTooManyOpenFiles =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"ENOENT"`: the entity, or a directory on its path, does not exist.
-}
errorIsNoSuchFileOrDirectory : Error -> Bool
errorIsNoSuchFileOrDirectory =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"ENOTDIR"`: an entry that had to be a directory, either the path
itself or an entry on it, is something else.
-}
errorIsNotADirectory : Error -> Bool
errorIsNotADirectory =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"ENOTEMPTY"`: a directory that had to be empty is not.
-}
errorIsDirectoryNotEmpty : Error -> Bool
errorIsDirectoryNotEmpty =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EPERM"`: the operation needs a privilege the program does not have,
such as changing the owner of a file it does not own.
-}
errorIsNotPermitted : Error -> Bool
errorIsNotPermitted =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"ELOOP"`: resolving the path followed too many symbolic links, as
happens when links form a loop.
-}
errorIsLinkLoop : Error -> Bool
errorIsLinkLoop =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"ENAMETOOLONG"`: the path, or an entry on it, is too long.
-}
errorIsPathTooLong : Error -> Bool
errorIsPathTooLong =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EINVAL"`: an argument was not valid for the operation, as when
[readLink](#readLink) is given a path that is not a symbolic link.
-}
errorIsInvalidInput : Error -> Bool
errorIsInvalidInput =
    Debug.todo "Implement System API"


{-| Checks whether the code is `"EIO"`: a low-level input or output error, such as a failing
storage device.
-}
errorIsIO : Error -> Bool
errorIsIO =
    Debug.todo "Implement System API"


{-| What the operating system reports about one entity, as [metadata](#metadata) returns it.

`deviceID` identifies the device that holds the entity; for a `Device` entity it is not the
number of the device the entity stands for. `userID` and `groupID` are the owner's numeric ids.
`blockSize` is the size in bytes the operating system prefers for IO, and `blocks` is the number
of blocks allocated to the entity, which Linux and macOS count in 512-byte units, not in units of
`blockSize`.

The four times are whole milliseconds. `lastChanged` is the status change time, when the entity's
metadata or contents last changed, not a creation time. `created` is the time the entity was
created when that can be read (natively, on macOS, and on Linux when `statx` reports one; on the
JS backend, when Node.js reports one); otherwise it is the status change time, equal to
`lastChanged`.

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


{-| The kind of an entity in the file system.

`File` is a regular file. `Socket` is a Unix domain socket. `Symlink` is a symbolic link, which is
reported only where a link is not followed: by [metadata](#metadata) with `resolveLink = False`,
and by [listDirectory](#listDirectory). `Device` is a character or block device, or any other
kind of entity not named here. `Pipe` is a named pipe (FIFO).

-}
type EntityType
    = File
    | Directory
    | Socket
    | Symlink
    | Device
    | Pipe


{-| Returns the metadata of the entity at the path.

With `resolveLink = True` a symbolic link is followed and the entity it points to is described.
With `resolveLink = False` a link is described itself, with the `entityType` `Symlink`.

-}
metadata : { resolveLink : Bool } -> Path -> Task Error Metadata
metadata =
    Debug.todo "Implement System API"


{-| One way of accessing an entity: reading it, writing it, or executing it.

[checkAccess](#checkAccess) tests a list of them, and [changeAccess](#changeAccess) grants a
list of them to each of an entity's owner, group and everyone else.

-}
type AccessPermission
    = Read
    | Write
    | Execute


{-| Checks that the program may access the entity at the path in each of the given ways, and
succeeds with the path if it may.

An empty list checks only that the entity exists.

-}
checkAccess : List AccessPermission -> Path -> Task Error Path
checkAccess =
    Debug.todo "Implement System API"


{-| Sets the access permissions of the entity at the path, for its owner, its group and everyone
else.

Each list becomes one octal digit of the file mode, as
[accessPermissionsToInt](#accessPermissionsToInt) computes it, so
`{ owner = [ Read, Write ], group = [ Read ], others = [ Read ] }` sets the mode `644`. The mode
has no other bits, so the set-user-ID, set-group-ID and sticky bits are cleared.

-}
changeAccess : { owner : List AccessPermission, group : List AccessPermission, others : List AccessPermission } -> Path -> Task Error Path
changeAccess =
    Debug.todo "Implement System API"


{-| Returns the POSIX permission digit for a list of permissions: 4 for `Read`, plus 2 for
`Write`, plus 1 for `Execute`. A permission listed twice counts once.

    accessPermissionsToInt [ Read, Write ] == 6

-}
accessPermissionsToInt : List AccessPermission -> Int
accessPermissionsToInt =
    Debug.todo "Implement System API"


{-| Sets the user and group that own the entity at the path, given as numeric ids.

With `resolveLink = False` the owner of a symbolic link itself is changed, not that of the
entity it points to.

-}
changeOwner : { userID : Int, groupID : Int, resolveLink : Bool } -> Path -> Task Error Path
changeOwner =
    Debug.todo "Implement System API"


{-| Sets the last access and last modification times of the entity at the path.

The times are set in whole seconds: each is sent as its milliseconds divided by 1000 with `//`,
which rounds down for times after 1970 and toward zero for times before. On the JS backend `//`
gives a 32-bit result, so a time from 2038-01-19T03:14:08Z on, or at or before
1901-12-13T20:45:51Z, is not set as given.

With `resolveLink = False` the times of a symbolic link itself are changed, not those of the
entity it points to.

-}
changeTimes : { lastAccessed : Time.Posix, lastModified : Time.Posix, resolveLink : Bool } -> Path -> Task Error Path
changeTimes =
    Debug.todo "Implement System API"


{-| Moves, or renames, the entity at the second path to the first.

    move newPath oldPath

The task succeeds with the new path. If it fails, [errorPath](#errorPath) is the new path. This
is the operating system's rename and nothing more, so a move to another file system fails
(`"EXDEV"`) rather than copying.

-}
move : Path -> Path -> Task Error Path
move =
    Debug.todo "Implement System API"


{-| Returns the path the operating system gives for the entity at the path, with every symbolic
link resolved. The entity must exist.
-}
realPath : Path -> Task Error Path
realPath =
    Debug.todo "Implement System API"


{-| Copies the file at the second path to the first.

    copyFile destinationPath sourcePath

An existing file at the destination is overwritten, and the copy gets the source's mode. A
directory as the source fails with `"EISDIR"` before the destination is touched. The task
succeeds with the destination path, and if it fails, [errorPath](#errorPath) is the destination
path.

-}
copyFile : Path -> Path -> Task Error Path
copyFile =
    Debug.todo "Implement System API"


{-| Adds the bytes to the end of the file at the path, creating the file if it does not exist.
-}
appendToFile : Bytes -> Path -> Task Error Path
appendToFile =
    Debug.todo "Implement System API"


{-| Reads the whole of the file at the path.

The contents are read into memory at once. For a very large file,
[readFileStream](#readFileStream) reads it in pieces instead.

-}
readFile : Path -> Task Error Bytes
readFile =
    Debug.todo "Implement System API"


{-| Which bytes of a file [readFileStream](#readFileStream) delivers. Offsets count bytes from the
beginning of the file.

`Beginning` delivers the whole file.

`From n` skips the first `n` bytes and delivers the rest. A negative `n` is 0, and an `n` past the
end gives a stream with nothing in it.

`Between` delivers the bytes from `start` to `end`, and `end` is **inclusive**:
`Between { start = 0, end = 9 }` delivers ten bytes, or fewer if the file is shorter. A negative
`start` is 0. A negative `end` delivers everything from `start` to the end of the file; otherwise
an `end` before `start` delivers nothing.

-}
type ReadFileStreamMode
    = Beginning
    | From Int
    | Between { start : Int, end : Int }


{-| Opens the file at the path and returns a stream of its bytes, the ones `mode` selects.

The file is opened before the task succeeds, so a file that cannot be opened, such as a missing
file or a directory (`"EISDIR"`), fails this task with an [Error](#Error). Failures while reading
arrive on the stream as a `Stream.Error`.

-}
readFileStream : ReadFileStreamMode -> Path -> Task Error (Stream.Readable Bytes)
readFileStream =
    Debug.todo "Implement System API"


{-| Writes the bytes into the file at the path, creating the file if it does not exist and
replacing its contents if it does.

This is [writeFileWith](#writeFileWith) with [defaultWriteOptions](#defaultWriteOptions).

-}
writeFile : Bytes -> Path -> Task Error Path
writeFile =
    Debug.todo "Implement System API"


{-| Where the bytes written to a [writeFileStream](#writeFileStream) go in the file.

`Replace` empties the file, or creates it, and writes from the beginning.

`ReplaceFrom n` keeps the first `n` bytes and writes from there. A file shorter than `n` is
extended with zero bytes up to `n` once anything is written or the stream is closed. When the stream is closed, the file is cut off
where the writing ended, so whatever followed is gone; a cancelled stream is not cut off. For
`n > 0` the file must already exist, unless `createNew` (see [WriteOptions](#WriteOptions)) is set, which
requires that it does not and creates it.
`ReplaceFrom n` with `n <= 0` is `Replace`, and creates the file.

`Append` writes at the end of the file, creating it if it does not exist.

-}
type WriteFileStreamMode
    = Replace
    | ReplaceFrom Int
    | Append


{-| Opens the file at the path and returns a stream whose bytes are written into it, where `mode`
says. Close the stream when you are done writing to it.

The file is opened before the task succeeds, so a file that cannot be opened fails this task with
an [Error](#Error). Failures while writing arrive on the stream as a `Stream.Error`.

This is [writeFileStreamWith](#writeFileStreamWith) with
[defaultWriteOptions](#defaultWriteOptions).

-}
writeFileStream : WriteFileStreamMode -> Path -> Task Error (Stream.Writable Bytes)
writeFileStream =
    Debug.todo "Implement System API"


{-| What [writeFileWith](#writeFileWith) and [writeFileStreamWith](#writeFileStreamWith) ask of a
write beyond what [writeFile](#writeFile) does.

`createNew` makes the write exclusive. The file is created, and the task fails with `"EEXIST"`
([errorIsFileExists](#errorIsFileExists)) if anything already exists at the path. The operating
system checks and creates in one step (`O_EXCL`), so of two programs creating the same file at
most one succeeds.

`sync` makes the write durable. The file's data is flushed to the storage device (`fsync`) before
the write succeeds; for [writeFileStreamWith](#writeFileStreamWith), before closing the stream
succeeds.

Neither replaces a file in one step. Without `createNew`, [writeFileWith](#writeFileWith) empties
an existing file before writing, so a failure part way leaves it empty or partly written. To
replace a file in one step, write a new file with `sync` and [move](#move) it over the old one.

-}
type alias WriteOptions =
    { createNew : Bool
    , sync : Bool
    }


{-| Write options with both `createNew` and `sync` off, which give the behaviour of
[writeFile](#writeFile) and [writeFileStream](#writeFileStream).
-}
defaultWriteOptions : WriteOptions
defaultWriteOptions =
    Debug.todo "Implement System API"


{-| Writes the bytes into the file at the path, as [writeFile](#writeFile) does, with the
[WriteOptions](#WriteOptions) given.

    FileSystem.writeFileWith { defaultWriteOptions | createNew = True, sync = True } bytes path

With either option on, the file is opened (emptying an existing one, or failing with `"EEXIST"`
for `createNew`), written from the beginning, flushed for `sync`, and closed. If a step after the
open fails, closing the file is still attempted, and the first failure is the one reported.

-}
writeFileWith : WriteOptions -> Bytes -> Path -> Task Error Path
writeFileWith =
    Debug.todo "Implement System API"


{-| Opens a stream into the file at the path, as [writeFileStream](#writeFileStream) does, with the
[WriteOptions](#WriteOptions) given.

With `sync`, closing the stream succeeds only once the data has been flushed to the storage
device, and a failed flush fails the close. A cancelled stream is not flushed.

-}
writeFileStreamWith : WriteOptions -> WriteFileStreamMode -> Path -> Task Error (Stream.Writable Bytes)
writeFileStreamWith =
    Debug.todo "Implement System API"


{-| Sets the length of the file at the path, in bytes: a longer file loses the bytes past
`length`, and a shorter one is extended with zero bytes. The file must already exist.
-}
truncateFile : Int -> Path -> Task Error Path
truncateFile =
    Debug.todo "Implement System API"


{-| Removes the entity at the path.

A symbolic link is removed itself, not the entity it points to. A directory is removed only with
`recursive = True`, and then together with everything in it. With `recursive = False` it fails
with the code `"ERR_FS_EISDIR"`, for which [errorIsDirectoryFound](#errorIsDirectoryFound) is
`False`.

-}
remove : { recursive : Bool } -> Path -> Task Error Path
remove =
    Debug.todo "Implement System API"


{-| Returns the entries of the directory at the path, without `.` and `..`, sorted by name byte by
byte (as UTF-8).

Each `path` is the entry's name alone, relative to the listed directory, parsed with
[Path.fromPosixString](Path#fromPosixString). A name that parsing changes, such as `a.`, which
comes back as `a`, therefore does not name its entry once appended to the directory's path.

Each `entityType` is that of the entry itself: a symbolic link is `Symlink`, not followed.

-}
listDirectory : Path -> Task Error (List { path : Path, entityType : EntityType })
listDirectory =
    Debug.todo "Implement System API"


{-| Creates a directory at the path.

With `recursive = False` the parent directory must exist, and the task fails with `"EEXIST"` if
something is already at the path. With `recursive = True` every missing directory on the path is
created too, and a directory already at the path is not an error.

-}
makeDirectory : { recursive : Bool } -> Path -> Task Error Path
makeDirectory =
    Debug.todo "Implement System API"


{-| Creates a new directory in [tempDirectory](#tempDirectory), named `prefix` followed by six
random characters, and succeeds with its path. Each call creates a different directory.

If it fails, [errorPath](#errorPath) is [tempDirectory](#tempDirectory) with `prefix` appended,
without the random characters.

-}
makeTempDirectory : String -> Task Error Path
makeTempDirectory =
    Debug.todo "Implement System API"


{-| Creates a hard link at the first path to the file at the second.

    hardLink linkPath targetPath

A hard link is a second name for the same file, and neither name is the original. The task
succeeds with the link path, and if it fails, [errorPath](#errorPath) is the link path.

-}
hardLink : Path -> Path -> Task Error Path
hardLink =
    Debug.todo "Implement System API"


{-| Creates a soft link at the first path that points to the second.

    softLink linkPath targetPath

A soft link, also called a symbolic link, is a special file holding the path of another
location, which is followed when the link is resolved. The target is stored as the text
[Path.toPosixString](Path#toPosixString) prints and is not checked, so it need not exist. The
task succeeds with the link path, and if it fails, [errorPath](#errorPath) is the link path.

-}
softLink : Path -> Path -> Task Error Path
softLink =
    Debug.todo "Implement System API"


{-| Returns the path stored in the soft link at the path.

The stored text is parsed with [Path.fromPosixString](Path#fromPosixString), so the result may
not print back as the stored text. It is not resolved against the link's directory.

-}
readLink : Path -> Task Error Path
readLink =
    Debug.todo "Implement System API"


{-| Removes the name at the path, which may name anything but a directory. A soft link is removed
itself, not the entity it points to; [remove](#remove) removes a directory.
-}
unlink : Path -> Task Error Path
unlink =
    Debug.todo "Implement System API"


{-| A change seen by [watch](#watch) or [watchRecursive](#watchRecursive).

`Changed` means an entity's contents or attributes changed, such as a write to a file or a change
of its permissions.

`Moved` means an entity was created, deleted or renamed. A rename is usually two `Moved` events,
one for the old name and one for the new. On the JS backend under Linux, a change to a
directory's attributes is also reported as `Moved`.

An event about another entity carries that entity's path, relative to the watched path (on the JS
backend, when Node.js reports one). An event about the watched path itself carries `Nothing` on
the native backend; on the JS backend it can carry the watched entry's own name instead, so a
change to a watched file `f.txt` carries the path `f.txt`.

-}
type WatchEvent
    = Changed (Maybe Path)
    | Moved (Maybe Path)


{-| Creates a subscription to the changes at the path: to the entity itself and, for a
directory, to its entries, but not to anything inside its subdirectories.

A path that cannot be watched, such as one that does not exist, gives no events and no error.
Subscriptions to the same path with the same recursiveness share one watcher, and each event
goes to all of them.

-}
watch : (WatchEvent -> msg) -> Path -> Sub msg
watch =
    Debug.todo "Implement System API"


{-| Creates a subscription like [watch](#watch), which also reports changes anywhere inside the
directory's subdirectories.
-}
watchRecursive : (WatchEvent -> msg) -> Path -> Sub msg
watchRecursive =
    Debug.todo "Implement System API"


{-| The home directory of the current user.

It is `$HOME` when that is set and not empty, otherwise the home directory recorded for the user
in the system's user database (natively on Windows, `%USERPROFILE%`), and
[Path.empty](Path#empty) when there is none.

-}
homeDirectory : Task x Path
homeDirectory =
    Debug.todo "Implement System API"


{-| The program's current working directory, which the operating system resolves relative paths
against. It is [Path.empty](Path#empty) if the directory cannot be read.
-}
currentWorkingDirectory : Task x Path
currentWorkingDirectory =
    Debug.todo "Implement System API"


{-| The directory meant for temporary files.

It is the first of the `TMPDIR`, `TMP` and `TEMP` environment variables that is set and not
empty, and otherwise `/tmp` (`C:/Windows/Temp` on Windows).

-}
tempDirectory : Task x Path
tempDirectory =
    Debug.todo "Implement System API"


{-| The path of the null device, `/dev/null`, which reads as empty and discards whatever is
written to it.

On Windows the kernels report `//./nul`, which [Path.fromPosixString](Path#fromPosixString)
parses into `/nul`, a path that does not name the null device.

-}
devNull : Task x Path
devNull =
    Debug.todo "Implement System API"

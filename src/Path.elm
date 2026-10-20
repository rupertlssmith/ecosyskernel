module Path exposing
    ( Path
    , empty, fromPosixString, toPosixString, fromWin32String, toWin32String
    , filenameWithExtension, parent
    , append, appendPosixString, appendWin32String, prepend, prependPosixString, prependWin32String, join
    )

{-| A program needs to name files and directories before it can act on them, and this module
builds, prints and combines those names without touching the file system, in POSIX or Windows
syntax. The functions in [FileSystem](FileSystem) act on what a path names.

A [Path](#Path) is the text of a path split into parts: a _root_, which is what the path starts
from (`""` for a path relative to the current directory, `"/"` for an absolute POSIX path, or a
Windows prefix such as `C:\` or `\\server\share\`), then the directory entries, then the last
entry, split into a filename and an extension.

Because nothing here looks at a disk, paths are a lexical model, and two facts follow.

Parsing normalizes the text alone. `..` cancels the entry before it as text, so `"a/../b"` gives
the same path as `"b"` whether or not `a` exists or is a link. Repeated separators are dropped,
and so are `.` entries, except a leading `./` in POSIX syntax.

Parsing loses information. A trailing separator and a trailing dot are dropped (`"a."` prints as
`"a"`), and [toPosixString](#toPosixString) prints any Windows root as `/`. Printing a parsed
path does not always give back the text it came from.

A third fact is about the type: a `Path` is a record alias, so any record of its shape is a
path, and only the paths that [fromPosixString](#fromPosixString) and
[fromWin32String](#fromWin32String) return are sure to be normalized, apart from a last entry
`...`, which [fromPosixString](#fromPosixString) describes.

Elsewhere in this package a path reaches the operating system only as text printed by
[toPosixString](#toPosixString), and paths coming back are parsed with
[fromPosixString](#fromPosixString). A path parsed from Windows syntax therefore reaches the
file system with its drive or share printed as `/`.

[append](#append), [prepend](#prepend) and [join](#join) combine paths by their entries. The
result keeps the root of the path whose entries come first in it and discards the other root, so
adding an absolute path onto another does not start over from its root.

Most of this file is the Windows parser. Windows syntax has more kinds of root than POSIX: drives,
drive-relative paths (`C:foo`), UNC shares and device paths (`\\?\C:\x`, `\\.\COM1:`). It also
reserves device names such as `CON` and `NUL`, and the parser marks some relative paths with a
leading `.\`; [fromWin32String](#fromWin32String) says which.

@docs Path


## Constructors

@docs empty, fromPosixString, toPosixString, fromWin32String, toWin32String


## Query

@docs filenameWithExtension, parent


## Manipulation

@docs append, appendPosixString, appendWin32String, prepend, prependPosixString, prependWin32String, join

-}




{-| A file system path, split into the parts that both POSIX and Windows syntax have.

`root` is what the path starts from: `""` for a path relative to the current directory, `"/"`
for an absolute POSIX path, and for a Windows path its prefix together with the separator after
it, such as `C:\`, `\` or `\\server\share\`. A Windows path relative to a drive's current
directory, such as `C:foo`, has the root `C:`. A device path with a single entry, such as
`\\.\x`, is all root, with no separator after it.

`filename` and `extension` together are the last entry, which may name a directory as well as a
file. The extension is stored without its dot. Both are empty when the path has no last entry,
as for a path that is only a root.

Any record of this shape is a `Path`, since this is a record alias. Only the paths that
[fromPosixString](#fromPosixString) and [fromWin32String](#fromWin32String) return are sure to
be normalized, apart from a last entry `...`, which [fromPosixString](#fromPosixString)
describes.

-}
type alias Path =
    { root : String
    , directory : List String
    , filename : String
    , extension : String
    }


{-| The path with no root and no entries, which both printers print as `"."`, the current
directory.

Parsing `""` or `"."` gives this path.

-}
empty : Path
empty =
    Debug.todo "Implement System API"


{-| Parses a path in POSIX syntax, where only `/` separates entries and a leading `/` is the root.

The result is normalized, except for the last case below. Repeated separators, a trailing
separator and `.` entries are dropped, and each `..` cancels the entry before it, so `"a/../b"`
gives the same path as `"b"`. A `..` with nothing before it to cancel is dropped from an absolute
path (`"/../a"` gives `"/a"`) and kept in a relative one (`"../a"`). `""`, `"."` and
`"a/.."` give [empty](#empty).

A leading `./` is the one `.` entry that is kept, as a `"."` directory entry, so `"./a"` prints
back as `"./a"`.

The extension is what follows the last dot of the last entry. An entry has none when it has no
dot, when its last dot is its first character (`".bashrc"`), or when it is `".."`. A trailing
dot gives an empty extension and is lost: `"a."` gives the filename `"a"`, and a last entry
`...` becomes `..`, so `"/x/..."` prints as `"/x/.."`, which names a different directory.

-}
fromPosixString : String -> Path
fromPosixString =
    Debug.todo "Implement System API"


{-| Prints a path in POSIX syntax, with `/` between the entries.

[empty](#empty) prints as `"."`. A root other than `""` and `"/"`, such as a Windows drive or
share, prints as `/`, so the Windows path `C:\a\b` prints as `/a/b`, and the drive-relative
`C:foo` prints as the absolute `/foo`.

-}
toPosixString : Path -> String
toPosixString =
    Debug.todo "Implement System API"


{-| Parses a path in Windows syntax, where both `\` and `/` separate entries.

The root is the path's prefix with the separator after it: a drive (`C:\`, or `C:` in the
drive-relative `C:foo\bar.txt`), a lone `\`, a UNC share (`\\server\share\`) or a device path
(`\\?\C:\`). A device path with a single entry, such as `\\.\x`, is all root, with no separator
after it.

The result is normalized as [fromPosixString](#fromPosixString) normalizes, except that a leading
`.\` is dropped too (`.\a\b` gives `a\b`), and the extension is split off the same way.

A path with no root gets a `"."` first directory entry, so that it prints with a leading `.\`,
when a colon ends an entry (`foo:`), when the normalized path would start with a drive
(`x\..\c:`), when the text before the first colon, as written, is a reserved device name in any
mix of upper and lower case (`CON:`, `COM1:x`), and, in a path with no colon, when the text as
written without its last character is a reserved name (`NULL`, `COM10`, `CONx`), unless that last
character lies outside the Basic Multilingual Plane, as an emoji does. These checks come before
`..` is resolved, so `x\..\CON:a` gives the unmarked `CON:a`. A bare `CON` or `CON.txt` is not
marked.

-}
fromWin32String : String -> Path
fromWin32String =
    Debug.todo "Implement System API"


{-| Prints a path in Windows syntax, with `\` between the entries.

[empty](#empty) prints as `"."`. The root is printed as it is, so a POSIX root stays `/`: the
POSIX path `/a/b` prints as `/a\b`.

-}
toWin32String : Path -> String
toWin32String =
    Debug.todo "Implement System API"


{-| Returns the last entry of a path: its filename, followed by a dot and the extension when
there is one.

    "/home/me/file.md"
        |> fromPosixString
        |> filenameWithExtension
        -- returns "file.md"

-}
filenameWithExtension : Path -> String
filenameWithExtension =
    Debug.todo "Implement System API"


{-| Returns the path of the directory that holds a path's last entry, or `Nothing` for
[empty](#empty) and for a path that is only a root.

    "/home/me/file.md"
        |> fromPosixString
        |> parent
        |> Maybe.map toPosixString
        -- returns Just "/home/me"

This is lexical: the parent of `"a"` is [empty](#empty), and so is the parent of `".."`.

The last directory entry becomes the result's last entry, split into a filename and an extension
only when it has exactly one dot, at that dot. For some entries this differs from
[fromPosixString](#fromPosixString): `.bashrc` gets the filename `""` and the extension
`"bashrc"`, and `a.b.c` gets no extension. These two print the same as the parsed parent but are
different records. An entry whose one dot is its last character loses the dot, so the parent of
`/x/a./f` prints as `/x/a`. The entry `a.b.` keeps its trailing dot, which parsing drops: the
parent of `/x/a.b./f` prints as `/x/a.b.`, and `fromPosixString "/x/a.b."` prints as `/x/a.b`.

A path with directory entries and an empty last entry, such as
`append empty (fromPosixString "/a/b")`, has its last directory entry moved into the last entry,
so its parent prints the same as the path itself, unless that entry ends in its only dot, which
the paragraph above says is lost.

-}
parent : Path -> Maybe Path
parent =
    Debug.todo "Implement System API"


{-| Returns the second path with the first added at its end, which is [prepend](#prepend) with
the arguments swapped. The second path is the base, so `base |> append child` reads in order.

    append (fromPosixString "file.md") (fromPosixString "/home/me")
        |> toPosixString
        -- returns "/home/me/file.md"

The result keeps the base's root and discards the first path's, so appending an absolute path
does not replace the base.

-}
append : Path -> Path -> Path
append =
    Debug.todo "Implement System API"


{-| Parses the string with [fromPosixString](#fromPosixString) and [append](#append)s it to the
path.
-}
appendPosixString : String -> Path -> Path
appendPosixString =
    Debug.todo "Implement System API"


{-| Parses the string with [fromWin32String](#fromWin32String) and [append](#append)s it to the
path.
-}
appendWin32String : String -> Path -> Path
appendWin32String =
    Debug.todo "Implement System API"


{-| Returns the second path with the first put in front of it.

The result has the first path's root. Its directory is the first path's directory entries and
last entry, then the second path's directory entries, with empty entries left out, and its last
entry is the second path's. The second path's root is discarded, so the prepended path of
`/home/me` and `/etc/x` is `/home/me/etc/x`.

The entries are not normalized again: a `.` or `..` entry of the second path stays where it is.

-}
prepend : Path -> Path -> Path
prepend =
    Debug.todo "Implement System API"


{-| Parses the string with [fromPosixString](#fromPosixString) and [prepend](#prepend)s it to the
path.
-}
prependPosixString : String -> Path -> Path
prependPosixString =
    Debug.todo "Implement System API"


{-| Parses the string with [fromWin32String](#fromWin32String) and [prepend](#prepend)s it to the
path.
-}
prependWin32String : String -> Path -> Path
prependWin32String =
    Debug.todo "Implement System API"


{-| Combines the paths of a list from first to last, [append](#append)ing each to the result so
far. An empty list gives [empty](#empty).

The result keeps the root of the first path and discards the roots of the others.

-}
join : List Path -> Path
join =
    Debug.todo "Implement System API"

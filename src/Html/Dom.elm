module Html.Dom exposing
    ( Node(..), Fact(..), Tagger, Handler
    , fromHtml, fromAttribute
    , attributes, toString, htmlToString
    )

{-| `Html` is opaque in elm/html, so a program can build a page but can neither look inside it
nor turn it into text. This module gives every `Html` and `Svg` value (a `VirtualDom.Node`) a
transparent view, [`Node`](#Node), and serializes it to HTML text.

[`fromHtml`](#fromHtml) turns any `Html msg` into a `Node` you can pattern-match on, and
[`fromAttribute`](#fromAttribute) turns an `Html.Attribute msg` into a [`Fact`](#Fact): one
attribute, namespaced attribute, property, style or event handler of an element.
[`toString`](#toString) serializes a `Node`, [`htmlToString`](#htmlToString) serializes `Html`,
and [`attributes`](#attributes) gives the attributes an element's opening tag gets.

    import Html exposing (div, text)
    import Html.Attributes exposing (class)
    import Html.Dom

    Html.Dom.htmlToString (div [ class "greeting" ] [ text "Hello & welcome" ])
        --> "<div class=\"greeting\">Hello &amp; welcome</div>"

**One serialization, two implementations.** `toString` is written in Elm, over a `Node`;
`htmlToString` is the kernel's, over `Html`, and the two produce the same text. On the native
target an `Html` value already is a `Node`, so `fromHtml` and `fromAttribute` cost nothing and
`htmlToString` is a C++ copy of `toString`'s rules. On the JavaScript target `fromHtml` copies
the tree into a `Node` and `htmlToString` is `toString` applied to that copy. On the JavaScript
target the order of an element's attributes may differ from the native target, and so may the
`class` joined from several `className` properties when one of their values is not a string.

**Which attributes are written.** The facts of an element are combined before they are
written:

  - Attributes, namespaced attributes and styles are each applied as one group, at the position
    of the first fact of their kind; each property is applied at the position of its first
    occurrence. Between two facts of one kind with the same name, the later wins, except that
    `class` attributes are joined with a space, and so are `className` properties.
  - On an HTML element (one with no namespace) the names of attributes, but not of namespaced
    attributes, are lower-cased. A namespaced attribute is written under its name alone; its
    namespace is not written.
  - A property that has a matching attribute is written as that attribute: `className` as
    `class`, `htmlFor` as `for`, `id`, `href`, `title` and the like under their own names.
    Every property that an `Html.Attributes` function other than `property` and `value` makes
    is one of these.
    A boolean property such as `checked` or `disabled` is written as a bare attribute when its
    value is true in JavaScript's sense, and removes the attribute otherwise; `contentEditable`
    and `spellcheck` are exceptions, written with their value as text. `value` is the
    content of an HTML `textarea`, is not written on a `select` or on a namespaced `textarea`,
    and is the `value` attribute on other elements. Any other property, such as `innerHTML`, is
    not written.
  - Styles are written as declarations in the `style` attribute. A camel-case name is written
    in CSS form (`backgroundColor` as `background-color`), and an empty value removes the
    declaration. A `style` attribute applied after styles replaces them.
  - Event handlers are never written.

**How text is written.** Text is escaped (`&`, `<`, `>`, `"` and `'`), and so are attribute
values (`&`, `"`, `<` and `>`). The one exception is the text of an HTML `style` element, which
is written as it is except that `</` becomes `<\/`. An HTML void element (`br`, `img`, ...) gets
no closing tag and its children are dropped. A _token-breaking_ name is one that would break the
markup: an empty name, or one containing an ASCII space or control character, `"`, `'`, `<`,
`>`, `/`, or, in an attribute name, `=`. An attribute with such a name is dropped, and an element
with such a tag is replaced by its children. Neither `toString` nor `htmlToString` writes
`<!DOCTYPE html>`; [`Http.Server.setBodyAsHtml`](Http-Server#setBodyAsHtml) adds one when the
root element is `html`.

**What is not modelled.** A string-valued property whose value is an array or an object is not
written. Text inside `script`, `xmp`, `iframe`, `noembed`, `noframes` and `noscript` is
escaped like any other text.

**Laziness.** An `Html.Lazy` subtree is always computed: natively when the node is built, on
the JavaScript target each time `fromHtml` or `htmlToString` reaches it.

**Equality.** `==` on a `Node` that contains a `Mapped` node or an `Event` fact compares the
functions and decoders inside them, so it has the same restriction as `==` on `Html`.

@docs Node, Fact, Tagger, Handler


# Converting

@docs fromHtml, fromAttribute


# Rendering

@docs attributes, toString, htmlToString

-}

import Json.Decode as Decode
import Json.Encode
import VirtualDom


{-| A node of an `Html` or `Svg` tree, as data.

`Text` is a text node. Its string is escaped when serialized, except inside an HTML `style`
element.

`Element` carries the namespace, the tag, the facts and the children. The namespace is
`Nothing` for an HTML element and `Just` the namespace given to `VirtualDom.nodeNS` otherwise
(the SVG namespace for an `Svg` node).

`KeyedElement` is a keyed element, such as one made with `Html.Keyed`, laid out like `Element`
except that each child is paired with its key. The keys are not serialized.

`Mapped` is a node made with `Html.map`: it keeps the function, and the node it wraps is the one
serialized.

A [`Tagger`](#Tagger) can only come from `fromHtml` or `fromAttribute`, so a program can build
`Text`, `Element` and `KeyedElement` nodes from scratch, but a `Mapped` node only around a
`Tagger` taken from one of those.

-}
type Node
    = Text String
    | Element (Maybe String) String (List Fact) (List Node)
    | KeyedElement (Maybe String) String (List Fact) (List ( String, Node ))
    | Mapped Tagger Node


{-| One fact of an element: an `Html.Attribute`, as data.

`Attribute` carries a name and a value.

`AttributeNS` carries the namespace, then the name and the value.

`Property` sets a DOM property to a JSON value. Many `Html.Attributes` functions make
properties rather than attributes: `Html.Attributes.class` is `Property "className"`, and
`Html.Attributes.checked` is `Property "checked"`.

`Style` carries a CSS property name, as given to `Html.Attributes.style`, and its value.

`Event` carries the event name, the [`Handler`](#Handler) and a list of
[`Tagger`](#Tagger)s. Natively the list holds the functions given to `Html.Attributes.map`,
outermost first; on the JavaScript target it is always empty, because elm/virtual-dom folds
those functions into the handler. A `Handler` can only come from `fromHtml` or
`fromAttribute`, so a program can build an `Event` fact only with a `Handler` taken from one of
those.

-}
type Fact
    = Attribute String String
    | AttributeNS String String String
    | Property String Json.Encode.Value
    | Style String String
    | Event String Handler (List Tagger)


{-| A function given to `Html.map` or `Html.Attributes.map`, as kept in a `Mapped` node or an
`Event` fact.

A value can only be obtained from [`fromHtml`](#fromHtml) or [`fromAttribute`](#fromAttribute),
and nothing in this module applies one.

-}
type Tagger
    = Tagger


{-| An event handler: a `VirtualDom.Handler`, which holds the decoder for the event and says
how its message is handled.

A value can only be obtained from [`fromHtml`](#fromHtml) or [`fromAttribute`](#fromAttribute),
and nothing in this module uses one.

-}
type Handler
    = Handler


{-| Returns the `Node` view of any `Html msg` or `Svg msg`.

On the native target this costs nothing, because an `Html` value already is a `Node`. On the
JavaScript target the tree is copied, computing every `Html.Lazy` subtree. Each element's facts
arrive already combined by elm/virtual-dom, where natively they are the list as given. On the
JavaScript target a node made by a kernel's custom renderer becomes an empty `div` with that
node's facts.

-}
fromHtml : VirtualDom.Node msg -> Node
fromHtml =
    Debug.todo "Implement System API"


{-| Returns the `Fact` view of any `Html.Attribute msg`.
-}
fromAttribute : VirtualDom.Attribute msg -> Fact
fromAttribute =
    Debug.todo "Implement System API"


{-| Returns the HTML text of an `Html` or `Svg` value: the same text as `toString (fromHtml html)`.

The result has no `<!DOCTYPE html>`. Add one yourself for a whole document, or use
[`Http.Server.setBodyAsHtml`](Http-Server#setBodyAsHtml), which adds it when the root element
is `html`.

-}
htmlToString : VirtualDom.Node msg -> String
htmlToString =
    Debug.todo "Implement System API"


{-| Returns the attributes `toString` writes in an element's opening tag, in order and with
their values unescaped, after the facts have been combined as the module documentation
describes. `Nothing` is a bare attribute, such as `checked`. A `Mapped` node gives the
attributes of the node it wraps, and a `Text` node gives none.

For an element whose tag is token-breaking, which `toString` replaces by its children, this
still returns the attributes the element would have had.

-}
attributes : Node -> List ( String, Maybe String )
attributes =
    Debug.todo "Implement System API"


{-| Returns the HTML text of a `Node`, by the rules in the module documentation. For a
`Node` made by `fromHtml html` it produces the same text as [`htmlToString`](#htmlToString)
`html`.
-}
toString : Node -> String
toString =
    Debug.todo "Implement System API"

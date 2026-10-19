module Html.Dom exposing
    ( Node(..), Fact(..), Tagger, Handler
    , fromHtml, fromAttribute
    , attributes, toString, htmlToString
    )

{-| A transparent view of [`Html`](/packages/elm/html/latest/Html#Html) and `Svg` values (that
is, `VirtualDom.Node` values), and their serialization to HTML text.

`Html` is opaque in elm/html, so a server could otherwise build pages but never send them.
[`fromHtml`](#fromHtml) turns any `Html msg` into a [`Node`](#Node) you can pattern-match on,
and [`toString`](#toString) renders a `Node` ([`htmlToString`](#htmlToString) renders `Html`
directly). To answer an HTTP request with a page, use
[`Http.Server.setBodyAsHtml`](Http-Server#setBodyAsHtml), which serializes
straight into the response without building a `String` first.

    import Html exposing (div, text)
    import Html.Attributes exposing (class)
    import Html.Dom

    Html.Dom.htmlToString (div [ class "greeting" ] [ text "Hello & welcome" ])
        --> "<div class=\"greeting\">Hello &amp; welcome</div>"

**What the serializer produces.** Attributes are the ones a browser would end up with after
Elm renders the node: properties such as `class` or `checked` become their attributes, later
facts win over earlier ones as they do in the browser, and properties that have no attribute
(such as `innerHTML`, which the XSS filters rename anyway) are left out. All text and attribute
values are escaped, and the text of a `<style>` element has `</` written as `<\/`. A tag or
attribute name that would break the markup (an empty name, or one containing whitespace, a
control character, a quote, `<`, `>`, `/`, or `=` in an attribute name) is not written: such an
attribute is dropped, and such an element is replaced by its children.

**Known differences from a browser:** children of void elements (`br`, `img`, …) are dropped;
the `value` of a `select` does not mark an option as selected; text inside `xmp`, `iframe`,
`noembed`, `noframes` and `noscript` is escaped; a `null` property is written as `"null"` and
array or object properties are not written; the attribute order follows the order Elm applies
facts in, which can differ from a browser's for properties with integer-like names. On the
JavaScript target the attribute order, the text of numbers and the bytes of a lone surrogate may
differ from the native target.

**Laziness.** `Html.Lazy` is evaluated eagerly when the node is built, so a `lazy` subtree is
always computed, even if it is never rendered.

**Equality.** `==` on a `Node` that contains an [`Event`](#Fact) or a [`Mapped`](#Node) node
compares functions, so it has the same restriction as `==` on `Html`.

@docs Node, Fact, Tagger, Handler


# Converting

@docs fromHtml, fromAttribute


# Rendering

@docs attributes, toString, htmlToString

-}

import Json.Decode as Decode
import Json.Encode
import VirtualDom


{-| A DOM node. `Element` and `KeyedElement` carry the namespace (`Nothing` for HTML, `Just`
the SVG namespace for `Svg` nodes), the tag, the facts and the children; a keyed element's
children are paired with their keys. `Mapped` is a node made with `Html.map`: the function
is kept, and the node it wraps is the one rendered.
-}
type Node
    = Text String
    | Element (Maybe String) String (List Fact) (List Node)
    | KeyedElement (Maybe String) String (List Fact) (List ( String, Node ))
    | Mapped Tagger Node


{-| What an `Html.Attribute` is made of. `Attribute` and `AttributeNS` set attributes (the
namespace comes first), `Property` sets a DOM property to a JSON value (`Html.Attributes.class`
is `Property "className" …`), `Style` sets one CSS property, and `Event` is an event handler
with the functions given to `Html.Attributes.map`, outermost first.
-}
type Fact
    = Attribute String String
    | AttributeNS String String String
    | Property String Json.Encode.Value
    | Style String String
    | Event String Handler (List Tagger)


{-| The function given to `Html.map` or `Html.Attributes.map`. Opaque. -}
type Tagger
    = Tagger


{-| An event handler (`VirtualDom.Handler msg`). Opaque. -}
type Handler
    = Handler


{-| View any `Html msg` (or `Svg msg`) as a `Node`. This was `fromNode`. On the native target this costs nothing:
an `Html` value already is a `Node`.
-}
fromHtml : VirtualDom.Node msg -> Node
fromHtml =
    Debug.todo "Implement System API"


{-| View any `Html.Attribute msg` as a `Fact`.
-}
fromAttribute : VirtualDom.Attribute msg -> Fact
fromAttribute =
    Debug.todo "Implement System API"


{-| Serialize `Html` (or `Svg`) to HTML text. The result has no `<!DOCTYPE html>`; add one
yourself for a whole document, or use `Http.Server.setBodyAsHtml`, which adds it when
the root element is `html`.

This is `toString << fromHtml`, computed natively without building a `Node` view first. This was
`toString`; the `Node` serializer was `render`.
-}
htmlToString : VirtualDom.Node msg -> String
htmlToString =
    Debug.todo "Implement System API"


{-| The attributes the browser would end up with, in order. `Nothing` is a bare boolean attribute. -}
attributes : Node -> List ( String, Maybe String )
attributes =
    Debug.todo "Implement System API"


{-| Serialize a `Node` to HTML text, exactly as [`htmlToString`](#htmlToString) does. This was
`render`.
-}
toString : Node -> String
toString =
    Debug.todo "Implement System API"

# Data-encoding tutorial

This page presents a high-level overview of the data-encoding library as well
as a detailed, user-oriented tutorial. It is meant as an introduction for users
wanting to learn how to use the library or wanting to progress beyond basic
usage.

## Part 1: The basics

This first part of the tutorial shows some basic usage of the library and
establishes some basic vocabulary used in the rest of the tutorial. If you are
already familiar with the library, you should still skim this section for the
vocabulary and other such useful details.

### The encoding type

The main type exported by data-encoding is `'a encoding`. A value `e` of type
`u encoding` is a runtime, formal description of the type `u`. This description
includes information about the representation of values of the type `u`.
Thanks to this information, the value `e` can be used to serialise and
deserialise values of type `u`.

```
let e : u encoding = … (* see later how to build an encoding *) in
let v : u = … in
match Binary.to_string e v with
| Ok s -> … (* [s] is a compact string representation of [v] *)
| Error e -> …
```

The type `'a encoding` is aliased as `'a t`. The shorter alias is intended to be
used qualified when the `Data_encoding` module is not opened in the current
scope (`'a Data_encoding.t` is less repetitive than `'a Data_encoding.encoding`)
whereas the longer alias is intended to be used unqualified when the module is
open (`'a encoding` is less ambiguous than `'a t`).
In the tutorial, we use the unqualified long form: `encoding`. In your code, use
as is appropriate.

In this tutorial, we use the verbs “serialise” and “deserialise”, rather than
“encode” and “decode” to avoid confusion when used in the *-ing* form:
“serialising” is unambiguous whereas “encoding” is potentially confusing as it
may also refer to the aforementioned type.

### Backends

Data-encoding provides functions to serialise and deserialise to the following
backends:

**Binary**: The data is serialised as a sequence of bytes. It can be presented as
a string or written directly to a buffer.

```
module Binary : sig
	type read_error = …
	type write_error = …
	val of_string : 'a encoding -> string -> ('a, read_error) result
	val to_string : 'a encoding -> 'a -> (string, read_error) result
	(* and some more functions, detailed below *)
end
```

**JSON**: The data is transformed into an OCaml representation of the JSON
format. This can further be serialised into a string when sending it over the
network or printing it onto stdout/stderr.

```
module Json : sig
	type json =
		[ `O of (string * t) list
		| `Bool of bool
		| `Float of float
		| `A of t list
		| `Null
		| `String of string ]
	val construct : 'a encoding -> 'a -> json
	val to_string : json -> string
	val from_string : string -> (json, string) result
	val destruct : 'a encoding -> json -> 'a
	(* and some more functions, detailed below *)
end
```

### How to build an encoding

The data-encoding library exports several combinators intended to build
encodings. These encodings are grouped under the `Encoding` module but are also
available at the top level of the library.

We give a brief overview of the most useful combinator of the API here, and much
more detail about them below. The full list can be found on the library
documentation: <module:Data_encoding.Encoding>.

There are ground encodings (i.e., combinators with zero parameters) to cover the
ground types of OCaml:

- `unit` for the `unit` type.
- `int8`, `uint8`, `int16`, `uint16`, `int31` for the `int` type. The different
	encodings correspond to different size of integers and will fail if they are
	given data outside of their supported range.
- `float` for the `float` type.
- `bool` for the `bool` type.
- `string` for the `string` type.
- `bytes` for the `bytes` type.

E.g., you can serialise a boolean `b` with
`Data_encoding.(Binary.to_string bool b)`.

On top of these ground encodings there are encoding combinators for the
parametric types of OCaml:

- `option` for the `option` type.
- `result` for the `result` type.
- `list` for the `list` type.
- `array` for the `array` type.

E.g., you can make an encoding for the type `(int, string) result list` with
`Data_encoding.(list (result int31 string))`.

For algebraic data-types, you can use the following combinators:

- `tup2`, `tup3`, `tup4`, etc. for tuples.
- `union` and `case` for variants.

If you use the JSON backend, then the `objN` combinators can lead to more
readable serialised values than the `tupN` combinators. The `objN` combinators
take a specific type of parameters: fields. These are constructed with the `req`
combinator. E.g., `obj2 (req "low" uint8) (req "high" uint8)` encodes objects
such as `{ "low": 0, "high": 5 }`. More details on this later.

And if you have a recursive data-type, you can use the special
combinator:

- `mu` for recursive types.

E.g., for the `type t = Leaf of int | Node of (string * t list)` you can use

```
let e =
  let open Data_encoding in
  mu "t" (fun e ->
    union [
      case ~title:"leaf" (Tag 0)
        int31
        (function Leaf l -> Some l | _ -> None)
        (fun l -> Leaf l);
      case ~title:"node" (Tag 1)
        (obj2 (req "path" string) (req "content" (list e)))
        (function Node (name, content) -> Some (name, content) | _ -> None)
        (fun (name, content) -> Node (name, content));
  ])
```

Finally, the following combinator allows the use of arbitrary OCaml code to
convert to and from some intermediate representation during serialisation and
deserialisation:

- `conv`

E.g., to create an encoding for the record `type t = { x: int; y: int }`
you can use

```
let e =
  let open Data_encoding in
  conv
    (fun {x; y} -> (x, y))
    (fun (x, y) -> {x; y})
    (tup2 uint8 uint8)
```

That's all for the basic uses. There are a few more combinators and a few more
variants of the ones above. But before listing all existing encodings, you
need to learn a bit more about the inner workings of data-encoding. With the
knowledge of the internal representation and machinery you will be able to
get more out of a complete technical listing.


### A small example

Consider the following type.

```
type 'a t =
  | Leaf of 'a
  | Stump of string option
  | Node of { step: string; content: 'a t list }
```

You can define an encoding for this type. If you wish to try for yourself, do
so. Otherwise, here is a guide:

- The type is parametric. It is not actually _a type_, it is instead
	_a type constructor_. And so you cannot define actually an encoding, you can
	define instead a function to construct the encoding:
	`'a encoding -> 'a t encoding`.
- The type is recursive so you will need to start with a `mu` combinator.
- The type is a variant (sum) so you will need to use a `union`.
- The branches use products and lists so you will need to use the combinators
	for those.

This is a top-down view of the type: from its general structure to the details
at the end of each of its variants. The combinators are applied in the same
order.

```
(* note: not actually an encoding,
   instead a function ['a encoding -> 'a t encoding] *)
let e a =
  let open Data_encoding in
  mu "t" (fun e -> (* recursive encoding for use within the encoding itself *)
    union [
      case (Tag 0) ~title:"Leaf"
        a (* parameter here, matches the location of parameter in type *)
        (function Leaf l -> Some l | _ -> None)
        (fun l -> Leaf l);
      case (Tag 1) ~title:"Stump"
        (option string)
        (function Stump s -> Some s | _ -> None)
        (fun s -> Stump s);
      case (Tag 2) ~title:"Node"
        (obj2
          (req "step" string)
          (req "content" (list e (* recursive encoding here *))))
        (function Node { step; content } -> Some (step, content) | _ -> None)
        (fun (step, content) -> Node { step; content });
    ]
  )
```


## Part 2: Under the hood

The Part 1 focused on the surface of the library: the main parts of the
interface. This Part 2 goes into some implementation details. Just enough of it
to build a good mental model and understand the interface even better in Part 3
and the advanced uses in Part 4.

### Internal representation, what you need to know

When you use data-encoding combinators, you build increasingly complex
`'a encoding` values. This type is opaque but in this section you will peek
under the hood and check what it is made of. This is to help understand the
finer points of data-encoding later on.

#### A first approximation

The type `'a encoding` is a GADT where the variants map to different
possible instantiations of the type parameter `'a`. For example,

- the ground encoding `unit: unit encoding` is the variant `Ignore:
	unit encoding`
- the ground encoding `uint8: int encoding` is the variant
	`Uint8: int desc`, and
- the combinator `list: 'a encoding -> 'a list encoding` uses the
	variant `List: {elts : 'a encoding} -> 'a list encoding`.

The encoding `list (list uint8)` is represented by
`List {elts = List {elts = Uint8}}` of the type `int list list encoding`.

This is a fine approximation, but it's not precise enough for you to understand
the later finer points of this tutorial.

#### A more truthful picture

The presentation above is simplistic. Here are additional facts to consider
when using combinators.

First, combinators can introduce more than one variant.

E.g., the `list` combinator actually produces a value made of two variants:
`Dynamic_size` (which, in the binary backend, introduces a 32-bit size field)
and `List` (as presented above). In the binary back-end, the `Dynamic_size`
variant introduces a size header. (See later for more details.) As a result,
`Binary.to_string (list uint16) [1;3]` is `"\x00\x00\x00\x04\x00\x01\x00\x03"`
where `\x00\x00\x00\x04` is the size header for the data following (4 bytes),
`\x00\x01` is `1` and `\x00\x03` is `3`.

Note that `Dynamic_size` indicates the size of the following data *in bytes*,
not the number of elements in the list. For this reason, the JSON backend simply
ignores the `Dynamic_size` variant: end of collections are managed with
closing delimiters instead.

Second, combinators include some fields which are not directly related to the
type parameter of the encoding. These fields are used to ensure some internal
safety properties or some user-side invariants.

E.g., the `List` variant is actually defined as
`List : {length_limit : limit; elts : 'a encoding} -> 'a list encoding`.
The field `length_limit` can be set by the optional parameter `?max_length` of
the `list` combinator. When set, this field will ensure that the length of the
serialised/deserialised list fits within the user-specified bounds. If not, the
serialising/deserialising process will fail.

Lastly, combinators don't just produce the variants, they also perform some
safety checks on the inputs.

E.g., consider the case of `list unit` which is meant to serialise values such as
`[(); ()]`. (This example is somewhat artificial, but it generalises to more
realistic ones.)

When serialising the `()` value in binary, it is represented with 0 bytes.
I.e., `Binary.to_string unit ()` is `""`. Additionally, recall that when
serialising a list of elements, the elements are just serialised side-by-side.
(See `list uint16` example above.)

Consequently, the lists `[]`, `[()]`, `[(); ()]`, as well as all other lists of
the same type would be serialised to the same byte representation (a size field
indicating 0 bytes to follow, followed by 0 bytes), and it would be impossible
to know how many elements there were when deserialising.

For this reason, the `list unit` expression will raise an exception.

(Note that, should the need arise, you can define an encoding for `unit list`
using `conv`. You can try if you want.)

Other such limitations exists for this combinator and for others. You will
learn more about them below.


#### What you maybe don't need to know

And now for a few more final details on the `'a encoding` type. You can skip
this section in your first reading, or if you are not interested in the finer
implementation details. Even without this section, your mental model of the
data-encoding library will be sufficient to understand everything but the very
last bits of this tutorial.

First, the type `'a encoding` is not represented merely by the tree of
variants mentioned above. The `'a encoding` type is in fact a record with an
`encoding` field carrying the tree of variants mentioned above, as well as a
`json_encoding` field carrying a version of the encoding specialised for the
JSON backend.

```
type 'a encoding = {
  encoding : 'a desc (* This is the tree of variants *) ;
  mutable json_encoding : 'a Json_encoding.encoding option;
}
```

When using the JSON backend (more details below), the tree of variants is
converted to a JSON encoding (a value of type `'a Json_encoding.encoding`), then
the result of this conversion is stored into the `json_encoding` field (to avoid
recomputing it later), and then it is passed to the `json-data-encoding` library
for actual serialisation/deserialisation.

Second, the type `'a encoding` is not completely opaque. It is abstract when
used from the `data-encoding` library's intended entry-point: the
`Data_encoding` module. But it is concrete when accessed from the
`Data_encoding__Encoding` module.

Note that it is **not recommended** to access the concrete representation of
`'a encoding`/`'a desc` values. For one thing it is not stable from one version
to the next. For another, the rest of the library makes important assumptions
about `'a encoding` values which are not documented.

Nonetheless, accessing the concrete definition of this type might be useful when
experimenting with the data-encoding library, when trying to understand some
specific combinators better, etc.


### Backends, in more details

#### Binary

The Binary backend of data-encoding serialises values to (and deserialises
values from) a compact sequence of bytes. You can use this backend via the
<module:Data_encoding.Binary> module.

**Writing and reading**

This module provides different writers and readers. The simplest of these is the
`to_string`/`of_string` pair: serialising to and deserialising from a `string`.
These functions return a `result` which carries either the expected value or a
detailed error report: a `write_error` or a `read_error` which you can match
against or you can simply pretty-print to the end-user.

The `to_string_opt`, `to_string_exn`, `of_string_opt`, and `of_string_exn`
variants map the `result` into an `option` (if you intend to ignore the specific
error anyway) or an exception (if you intend for errors to interrupt the control
flow).

Note that whichever variant of these functions you call, the binary serialising
and deserialising processes _fail early_: they execute to the point where
they encounter an issue at which point they stop completely and abruptly.

The functions `read` (respectively `write`) is similar to the `of_string` (resp.
`to_bytes`) function, but it takes additional parameters to read from (resp.
write) within a certain range of the given string (resp. bytes).

More specifically, the `read` function takes two parameters: offset and length.
This is keeping in style with the Stdlib `blit` functions. The `write` function
takes a single `writer_state` parameter which is initialised with an offset and
a maximum length. It returns the actual number of written bytes. This is to
allow consecutive uses to write consecutive values.

Finally, the `read_stream` function allows non-blocking stream-reading of a
binary serialised value. Specifically, this function can be used to deserialise
a value that is received one chunk at a time. This is useful if you are
receiving data from a remote machine in a series of chunks of data sent over a
network.


**Querying properties**

The `Binary` module also provides some functions to query binary-specific
properties of an encoding. Specifically, properties related to size.

The function `length` takes an encoding and a value and returns the number of
bytes it would take to serialise this value.

(Note that the data-encoding library uses interchangeably `length` and `size` to
describe "a number of bytes". In this tutorial, as much as the data-encoding API
permits, we use `size` for the "number of bytes" and reserve
`length` for the number of elements in a data structure.)

In some cases, `length` ignores the value and only reads the encoding. This
happens when the encoding is of a fixed size such as `tup2 int64 int32`.  
In some cases, `length` serialises the value and returns the number of bytes of
the serialised form. This happens when the encoding is unpredictable such
as `conv Foo.to_string Foo.of_string string`.  
In most cases, the process is a hybrid of these two extremes. E.g., for the
encoding `list (tup2 int64 (conv f h e))` the function `f` is applied to all the
elements of the list, and possibly some more work is done depending on the
content of `e`, but the int64s are not serialised.

The function `maximum_length` takes an encoding and returns the maximum number
of bytes it might take to serialise any value of the type described by the
encoding. It returns `None` if the encoding is unbounded.

The function `maximum_length` is less precise than `length` in that it returns a
bound rather than an exact value, but it is also more general in that the result
is valid for any input value. Consequently, it is more appropriate than `length`
for checking some safety properties (e.g., the messages of the network layer can
never exceed a given length).


**Sizing during the serialisation and deserialisation processes**

When serialising and deserialising, the binary backend maintains some internal
state. Part of this internal state has to do with the input/output management:
at what offset is it reading in the input string? at what offset is it writing
into the output bytes? etc. Another part of this internal state has to do with
sizing and knowing when to stop. This part has significant consequences and so
you need to learn about it.

When deserialising from binary, it is important for the process to know when to
stop. This is easy when the encoding has a fixed size (e.g., to read a
`tup2 int64 int32` you simply read 8 bytes and then read 4 bytes and you are
done). It is non-trivial when the encoding has a range of possible sizes or even
is potentially unbounded.

E.g., when you are reading a `tup2 (list uint16) (list uint8)`, you have to
decide when you stop interpreting input as uint16 and when do you start
interpreting them as uint8.

Remember that the `list` encoding introduces two variants:
`Dynamic_size (List _)`. The reason for the `Dynamic_size` is to allow the
decoding process to stop.

**Size categories**

The data-encoding library classifies encodings into three groups:

- Fixed-size encodings: those where the size is entirely determined by the
	content of the `encoding` value, and is not influenced by which value is being
	serialised/deserialised. E.g., `tup2 int64 int32` takes the same space whether
	you encode `(0L, 0l)` or `(Int64.max_int, Int32.max_int)`.

- Dynamic-size encodings: those where the size can only be inferred from the
	serialised data itself. E.g., `list uint16` where the size header placed in
	front of the elements allows to determine the size of the whole serialised
	value. Whatever the value that is serialised, it is prefixed with a size
	header which allows to dynamically reconstruct the size.

	Note that there are dynamic-size encodings which do not use a size header.
	More on which later.

- Variable-size encodings: those where the size cannot be known from the
	serialised data nor from the `encoding` value. E.g., `Variable.list uint16`
	is an expression which produces a `List` variant without a `Dynamic_size`
	variant. The value is serialised as is, without any size header.

**Querying sizing categories**

The function
`` classify: 'a encoding -> [`Fixed of int | `Dynamic | `Variable] ``
returns the category that an encoding is part of.

**Local state and sizing**

When the data-encoding's binary backend deserialises a value, it traverses the
encoding's tree of variants and the sequence of bytes at the same time. To
illustrate this, we consider the following running example:

- The encoding `list uint16` which is represented internally as
`Dynamic_size (List { elts = Uint16; _ })`.
- The value `[1; 2; 3]` which is represented in binary as the sequence of bytes
`\x00\x00\x00\x06\x00\x01\x00\x02\x00\x03`.

The process starts with the whole encoding variant tree and the offset 0.  
It matches on the construct tree and finds the pattern `Dynamic_size e`.  
Accordingly, it reads a size header (4 bytes, interpreted as one integer).  
The size header is `\x00\x00\x00\x06` which represents the number `6`.  
The offset is now 4.

At this point the internal state of the process changes significantly.  
It now considers the sub-encoding `List { elts = Uint16; _ }`.  
But the state also includes the information from the size header: there are
exactly 6 bytes representing that list.  
With this information, the process is able to read the elements of the list one
after another and knows when to stop.

The code for this deserialisation process is located in `src/binary_reader.ml`
and the relevant, abridged, heavily commented excerpt is

```
let rec read_rec
  : type r. r Encoding.t -> state -> r
  = fun e state ->
  match e.encoding with
  (* most cases omitted *)
  | Dynamic_size {encoding = e} ->
      (* read an int31, increases the offset *)
      let sz = Atom.int31 state in
      (* safety check + compute remaining size after deserialisation of [e] *)
      let remaining = check_remaining_bytes state sz in
      (* store the size header value in state *)
      state.remaining_bytes <- sz ;
      (* safety check *)
      ignore (check_allowed_bytes state sz : int option) ;
      (* RECURSIVE CALL *)
      let v = read_rec e state in
      (* safety check *)
      if state.remaining_bytes <> 0 then raise_read_error Extra_bytes ;
      (* restore remaining size *)
      state.remaining_bytes <- remaining ;
      v
  | Uint16 -> Atom.uint16 state (* read a uint16 *)
  | List {elts = e} -> read_list e state (* read the list *)

and read_list
  : type a. a Encoding.t -> state -> a list =
  fun e state ->
  let rec loop acc =
    if state.remaining_bytes = 0 then
      (* finished reading all the bytes that are available *)
      List.rev acc
    else
      let v = read_rec e state in (* read one element *)
      loop (v :: acc) (* read more*)
  in
  loop []
```


#### JSON

The JSON backend serialises and deserialises values to and from
[JSON](https://www.json.org/json-en.html). You can access this backend via the
<module:Data_encoding.Json> module.

**Serialisation and deserialisation**

The JSON backend of data-encoding serialises values to (and deserialises
values from) the `json` type.

```
  type json =
    [ `O of (string * json) list
    | `Bool of bool
    | `Float of float
    | `A of json list
    | `Null
    | `String of string ]
```

E.g., `Data_encoding.(Json.construct (list uint16) [1; 3])` is
`` `A [ `Float 1.; `Float 3.] ``.

The additional functions `Json.to_string` and `Json.from_string` transform
values of the `json` type into and from a string representation.

E.g., `` Json.to_string (`A [ `Float 1.; `Float 3.]) `` is `"[1, 3]"`.

Unlike the binary backend, all error management in the JSON backend is done via
exception raising. You should wrap all calls to `construct` and `destruct`
within a `try`-`with` block.

**Numerals**

In the JSON standard, all numerals are represented as floats. This works well
for floats and small integers such as int32. However, some of the int64 integers
do not have a float of the same numerical value.

For this reason, the data-encoding library represents int64 integers as well as
arbitrary precision integers (from Zarith) as strings in their decimal
notation. E.g., `0L` is represented as `` `String "0" ``.

Other numerals are represented as JSON numerals (i.e., floats).

**The `json-data-encoding` library**

Within the data-encoding package, the JSON backend implementation is somewhat
small. This is because all the core operations are delegated to the
`json-data-encoding` package. The additions are:

- A function to convert an all-purpose encoding (`'a encoding`) into a
	json-data-encoding encoding (`'a Json_encoding.encoding`).
- Thin wrappers around the json-data-encoding serialisation/deserialisation
	functions to call the conversion function when needed.

You shouldn't need to use the `json-data-encoding` library unless you need to
access some advanced features.

**Streaming serialisation**

The JSON backend supports lazy serialisation of sequences. Specifically, the
function `construct_seq` takes an encoding and a value and returns a sequence
(<module:Stdlib.Seq>) of JSON lexemes.

E.g., `Data_encoding.(Json.construct_seq (list uint16) [1; 3])` is a sequence
of the following elements: `` `As ``, `` `Float 1. ``, `` `Float 3. ``,
`` `Ae ``. These elements are generated lazily (i.e., as the sequence is
traversed).

The additional function `blit_instructions_seq_of_jsonm_lexeme_seq` takes a
buffer (of the `bytes` type) and a sequence of lexemes, and generates a sequence
of `(bytes * int * int)`. These triplets include a byte source, an offset, and a
length. They can be used to copy chunks onto a socket or some other such output.
The order of the elements of the triplets is compatible with OCaml Stdlib _blit_
functions.

Requesting a new element of the blit-instruction sequence forces elements of the
underlying lexeme sequence.

The documentation of these function give more details about valid use cases,
caveats and such. Read before use.


### Limitations

As mentioned previously, some combinators perform safety checks before
producing a tree of variants. If these safety checks fail, the combinator
raises an exception instead. This limits the ways in which you can use some
combinators.

Before we go into the specific limitations, it is important to note that the
`data-encoding` library gives a lot of control to the user. This is intentional:
one of the supported use case for the library is to define data-exchange
formats. You need to be able to predict exactly what the data serialises to.

Data-encoding gives you control by providing low-level combinators. It doesn't
attempt to interpret your intentions by automatically adding size headers and
other tags. As a result, some compositions of combinators lead to unusable
encodings: encodings which the backends cannot process. When you compose
combinators in such a way, they raise exceptions.

With this in mind, you can look at the main limitations of the data-encoding
combinators.

#### Nullables

When serialising to JSON, some values may be represented as `null`. For example,
with the encoding `option string` (for the type `string option`), the value
`None` is represented as `null` and the value `Some "of this"` is represented as
`"of this"`. This is somewhat standard practice in JSON, inherited from the use
of `null` in Javascript.

It all works until you try to combine `option`s. Specifically, consider
the encoding `option (option string)` (for the type `string option option`).
The value `None` is represented as `null`. And the value `Some None` is also
represented as `null`. And it is impossible to deserialise because it is
impossible to distinguish between the two.

(Note that this is not just about options, other encodings may yield `null`.
E.g., you may define a union where one case is represented as `null`.)

In order to avoid issues during deserialisation, the `option` combinator checks
whether its argument is _nullable_ (i.e., whether it can produce the `null`
JSON value), and, if so, it raises an exception.

You can avoid this with a simple application of `obj1`. For example, the
following encoding is valid.

```
let e =
  let open Data_encoding in
  option (obj1 (req "v" (option string)))
```

It leads to the following values:

- `None` is represented as `null`
- `Some None` is represented as `{ "v": null }`
- `Some (Some "here")` is represented as `{ "v": "here" }`



#### Sizing categories

As mentioned in the section covering the binary backend, sizing of encodings
matters. Specifically, the deserialisation process needs to keep track of sizing
information.
As a user, you may not care about the details mentioned before, but
you need to be aware that different restrictions apply to the different
sizing categories of encodings. These restrictions simply aim to allow correct
deserialisation.

E.g., consider the following type:

```
type 'a t = { id: string; content: 'a; flag: bool }
```

for which you may define the encoding

```
let e a =
  obj3
    (req "id" string)
    (req "content" a)
    (req "flag" bool)
```

If you use `e (list uint16)` then the deserialisation process can happen
normally: read a size header, read the string bytes, read a size header, read as
many bytes for the list, read one byte for the boolean, done.

On the other hand, if you use `e (Variable.list uint16)` (remember that
`Variable.list` doesn't include a size header) then the deserialisation process
cannot happen. Specifically, there is no clear way to know when the `content`
ends and when the `flag` begins.

When a combinator receives an argument which would lead to an undeserialisable
encoding, it raises an exception. This happens when:

- You use a variable-size encoding in a product (tup or obj) except on the
	right-most position.
- You use a variable-size encoding for the elements of a collection (list or
	array).


## Part 3: An encyclopedic list of all combinators

This section aims to covers each combinator in as much detail as you might ever
want. If you find that you need more details, please open an issue on the
project's repository or get in touch with one of the maintainers.

### Ground encodings

`unit : unit encoding` (fixed:0) is a ground encoding for the `unit` type. In
binary it has a fixed size of 0 bytes (in other words, it is omitted). In JSON
it is serialised to `{}` (the empty object) but it accepts (and ignores) any
value during deserialisation: `Json.destruct unit v` returns `()` no matter what
`v` is.

`empty : unit encoding` (fixed:0) is a ground encoding for the `unit` type. In
binary it has a fixed size of 0 bytes (in other words, it is omitted). In JSON
it is represented as `{}` (the empty object). Note that, unlike `unit`, it only
accepts `{}` during deserialisation: `` Json.destruct empty (`O []) `` is `()`
but `Json.destruct empty v` for any other value raises an exception.

`null : unit encoding` (fixed:0, nullable) is a ground encoding for the `unit`
type. In binary it has a fixed size of 0 bytes (in other words, it is omitted).
In JSON it is represented as `null` (the null value).

`constant : string -> unit encoding` (fixed:0) is an encoding for the
`unit` type. In binary, it has a fixed size of 0 bytes (in other words, it is
omitted). In JSON it is represented as the string passed as argument.

E.g., `Json.construct (constant "blah") ()` is `` `String "blah" `` which
serialises to `"blah"`.

`uint8 : int encoding` (fixed:1) is a ground encoding for the `int` type.
Serialisation through any backend will fail if the integer is not within the
range of unsigned 8-bit integers. E.g., `Binary.to_string uint8 1024` returns a
`Error` and `Json.construct uint8 1024` raises an exception. In binary it has a
fixed size of 1 byte. In JSON it is represented as a float. Deserialisation from
JSON raises an exception if the float representation is not a valid unsigned
8-bit integer.

`int8 : int encoding` (fixed:1) is a ground encoding for the `int` type.
Serialisation through any backend will fail if the integer is not within the
range of signed 8-bit integers. In binary it has a fixed size of 1 byte. In JSON
it is represented as a float. Deserialisation from JSON raises an exception if
the float representation is not a valid signed 8-bit integer.

`uint16 : int encoding` (fixed:2) is a ground encoding for the `int` type.
Serialisation through any backend will fail if the integer is not within the
range of unsigned 16-bit integers. In binary it has a fixed size of 2 bytes. In
JSON it is represented as a float. Deserialisation from JSON raises an exception
if the float representation is not a valid unsigned 16-bit integer.

`Little_endian.uint16 : int encoding` (fixed:2) is a ground encoding similar to
`uint16` except that its binary representation is little-endian.

`int16 : int encoding` (fixed:2) is a ground encoding for the `int` type.
Serialisation through any backend will fail if the integer is not within the
range of signed 16-bit integers. In binary it has a fixed size of 2 bytes. In
JSON it is represented as a float. Deserialisation from JSON raises an exception
if the float representation is not a valid signed 16-bit integer.

`Little_endian.int16 : int encoding` (fixed:2) is a ground encoding similar to
`int16` except that its binary representation is little-endian.

`int31 : int encoding` (fixed:4) is a ground encoding for the `int` type.
Serialisation through any backend will fail if the integer is not within the
range of signed 31-bit integers. In binary it has a fixed size of 4 bytes. In
JSON it is represented as a float. Deserialisation from JSON raises an exception
if the float representation is not a valid signed 31-bit integer.

The specific threshold of 31 bit is intended to represent portable native OCaml
integers. Indeed, in OCaml, the GC reserves one bit to tag integers vs pointers.
As a result, on 32-bit architectures, integers are represented with 31 bits.

`Little_endian.int31 : int encoding` (fixed:4) is a ground encoding similar to
`int31` except that its binary representation is little-endian.

`int32 : int32 encoding` (fixed:4) is a ground encoding for the `int32` type.
Serialisation through any backend will fail if the integer is not within the
range of signed 32-bit integers. In binary it has a fixed size of 4 byte. In
JSON it is represented as a float. Deserialisation from JSON
raises an exception if the float representation is not a valid signed 32-bit
integer.

`Little_endian.int32 : int32 encoding` (fixed:4) is a ground encoding similar to
`int32` except that its binary representation is little-endian.

`int64 : int64 encoding` (fixed:8) is a ground encoding for the `int64` type.
Serialisation through any backend will fail if the integer is not within the
range of signed 64-bit integers. In binary it has a fixed size of 64 byte. In
JSON it is represented as a string. Specifically, as the string representation
of the value in decimal notation.

`Little_endian.int64 : int64 encoding` (fixed:8) is a ground encoding similar to
`int64` except that its binary representation is little-endian.

`ranged_int : int -> int -> int encoding` (fixed:?) is a combinator for the
`int` type. The encoding `ranged_int low high` is for encoding ints within the
`low`-to-`high` interval. Both bounds are inclusive.

The `ranged_int` combinator will raise an exception if the bounds are not
contained within the 31-bit integer range. (This can only happen on 64-bit
machines.)

Serialisation and deserialisation through any backend will fail if the input
does not fit in the specified bounds.

In binary, it is either represented as an int31, or, interval permitting, as one
of the smaller varieties of integers. E.g., `ranged_int 1000 1100` is
represented as a `uint8`. (If you are interested in more details, the specific
mapping of ranges to integer size is controlled by the `range_to_size` function
of `binary_size.ml`.)

Warning: if you change the bounds of a range, you may change the representation
of the values.

In JSON, it is represented as a float.

`Little_endian.ranged_int : int -> int -> int encoding` (fixed:?) is a encoding
combinator similar to `ranged_int` except that its binary representation is
little-endian.

`n : Zarith.t encoding` (dynamic) is a ground encoding for the `Zarith.t` type.
Serialisation and deserialisation through any backend fails if the input is
negative.

In binary it is represented as a dynamically-sized sequence of bytes. Instead of
a size header, the value is represented as a series of bytes where the most
significant bit of each byte indicates if it is the last byte or not. All other
bits concatenated make up the little-endian order representation of the integer.

In JSON it is represented as a string in decimal notation.

`z : Zarith.t encoding` (dynamic) is a ground encoding for the `Zarith.t` type.

In binary it is represented like `n`, except that a bit is reserved for sign.

In JSON it is represented as a string in decimal notation.

`int_like_z : ?min_value:int -> ?max_value:int -> unit -> int encoding`
(dynamic) is a combinator for ranged integers represented in the same way as
`z`.

The `min_value` and `max_value` bounds are inclusive. The combinator raises
an exception if `min_value > max_value`. It also raises an exception if the
range extends beyond the range of integers which can be represented by `int31`.
If not given, `min_value` and `max_value` default to the `int31` range.

Unlike a simple `conv Z.of_int Z.to_int z`, the combinator `int_like_z` provides
additional safety checks. Specifically, `int_like_z` will compute the maximum
size of the binary representation and inserts a `check_size` node explicitly.

In JSON, the values are represented as a float.

`uint_like_n : ?max_value:int -> unit -> int encoding` (dynamic) is a combinator
for ranged positive integers represented in the same way as `n`.

The `max_value` bound is inclusive. The combinator raises an exception if
`max_value < 0` or if `max_value` is greater than the upper limit of `int31`.
If not givem, `max_value` defaults to the `int31` upper bound.

Unlike a simple `conv Z.of_int Z.to_int n`, the combinator `uint_like_n`
provides additional safety checks. Specifically, `uint_like_n` will compute the
maximum size of the binary representation and inserts a `check_size` node
explicitly.

In JSON, the values are represented as a float.

`float : float encoding` (fixed:8) is a ground encoding for the `float` type. In
binary it is has a fixed size of 8 bytes which carries an IEEE 754
double-precision floating-point numeral. In JSON it is represented as a JSON
number literal.

`ranged_float` (fixed:8) is a combinator for the float type. Just like
`ranged_int`, serialisation/deserialisation through any backend will fail is the
value is out of bounds. It is represented as with `float` otherwise.

`bool : bool encoding` (fixed:1) is a ground encoding for the `bool` type. In
binary it has a fixed size of 1 byte. It serialises to `false` to `0x00` and
`true` to `0xff`. It deserialises `0x00` to `false` and any other value to
`true`. In JSON it is represented as a boolean literal.

`string : string encoding` (dynamic) is a ground encoding for the `string` type.
In binary it is represented as a 4 bytes size header followed by the specified
number of bytes matching the bytes in the string. In JSON it is represented as a
string literal. If it contains characters that may need escaping, these
characters are escaped.

More specifically, when using the `construct` function, it produces a
`` `String s `` value. The string is not escaped here because this is still an
OCaml value. When using `to_string`, the string is escaped.

`bytes : bytes encoding` (dynamic) is a ground encoding for the `bytes` type. In
binary it is represented like a `string`: a 4 bytes size header followed by the
specified number of bytes. In JSON it is represented as a hex-encoded string
literal. That is, each character of the OCaml `bytes` is represented by two
characters in the hexadecimal alphabet: 0-9, a-f, A-F.

This quirk of representation has its historical roots in the Tezos project where
the bytes type was used to represent binary blobs (cryptographic signatures and
such) whilst the string type was used to represent human-readable text (error
messages and such). There is additional nuance because the Tezos project
actually started by rolling out its own bytes-like type, but that's as much
detail as this tutorial will mention.

`string' : string_json_repr -> string encoding` (dynamic) is a combinator for
the `string` type. In binary it is represented like a `string`. In JSON, it's
representation depends on the `string_json_repr` parameter: with `Plain` it is
represented as a String literal (like `string` above), with `Hex` it is
represented as an hex-encoded String literal (like `bytes` above). Use `Plain`
for strings which are intended to be human-readable, use `Hex` for strings which
are intended to be blobs.

Note that for backwards compatibility reason, the original `string` and `bytes`
encoding have not been modified and this encoding has an apostrophe in the name:
`string'`.

The optional parameter `?length_kind` allows you to control the representation
of the size-header of the string. Note that the size header imposes a limit on
the size of the string. E.g., `` `Uint8 `` will only be able to support strings
up to 255 bytes long. Also note that for internal consistency and compatibility
with 32-bit machines, `` `N `` is actually limited in range to 2^30.

`bigstring: unit -> string encoding` (dynamic) is a combinator for
the `bigstring` type. The `bigstring` type is an alias for a `Bigarray` type to
represent strings (also used in other libraries such as `Bigstringaf`). In
binary the data is represented like a `string`. In JSON, it is represented as a
hex-encoded String literal.

The optional parameter `?length_kind` allows you to control the representation
of the size-header of the string. Note that the size header imposes a limit on
the size of the string. E.g., `` `Uint8 `` will only be able to support strings
up to 255 bytes long. Also note that for internal consistency and compatibility
with 32-bit machines, `` `N `` is actually limited in range to 2^30.

The optional parameter `?string_json_repr` allows you to modify the
representation of the string in JSON. Pass the value `Plain` to represent the
data as a String literal.

`bytes' : string_json_repr -> bytes encoding` (dynamic) is a combinator for
the `bytes` type. In binary it is represented like a `bytes`. In JSON, it's
representation depends on the `string_json_repr` parameter: with `Plain` it is
represented as a String literal (like `string` above), with `Hex` it is
represented as an hex-encoded String literal (like `bytes` above). Use `Plain`
for bytes which are intended to be human-readable, use `Hex` for bytes which
are intended to be blobs.

Note that for backwards compatibility reason, the original `string` and `bytes`
encoding have not been modified and this encoding has an apostrophe in the name:
`bytes'`.

The optional parameter `?length_kind` allows you to control the representation
of the size-header of the string. Note that the size header imposes a limit on
the size of the string. E.g., `` `Uint8 `` will only be able to support strings
up to 255 bytes long. Also note that for internal consistency and compatibility
with 32-bit machines, `` `N `` is actually limited in range to 2^30.

### Simple combinators

`option : 'a encoding -> 'a option encoding` (?, nullable) is a combinator for
the `option` parametric type. In binary `None` is represented as a single `0x00`
byte and `Some v` is represented as an `0x01` byte followed by the bytes
representing `v`. In JSON `None` is represented as `null` and `Some v` is
represented as `v` is.

Note that in JSON the union is not explicitly made unambiguous. Specifically,
if `v` can be represented as `null` then there are multiple values which can be
represented in the same way. To avoid this possibility, the `option` combinator
raises an exception when its argument can yield `null` values in JSON.

The size category is the same as the encoding passed as argument. Do note that
for the fixed category, the size is increased by 1 for the tag.

`result : 'a encoding -> 'e encoding -> ('a, 'e) result encoding` (?) is a
combinator for the `result` parametric type. In binary `Ok v` is represented as
an 0x01 byte followed by the bytes representing `v` and `Error e` is represented
as an 0x00 byte followed by the bytes representing `e`. In JSON `Ok v` is
represented as `{"ok": <v>}` and `Error e` is represented as `{"error": <e>}`.

The size category depends on the size categories of the two arguments. Simply
put: if either argument is variable then so is the result, otherwise if
either argument is dynamic so is the result, otherwise if both argument are
fixed but with different constants then the result is dynamic, otherwise both
arguments are fixed with the same constant and the result is fixed (with an
additional byte for tag).

`list : 'a encoding -> 'a list encoding` (dynamic) is a combinator for the
`list` parametric type. In binary it is represented as a 4 bytes size header
followed by a simple concatenation (without any separator or terminator) of each
of the elements. In JSON it is represented as an Array literal.

The optional parameter `?max_length` allows you to specify the maximum number of
elements in the list. Serialising and deserialising will fail is this number of
element is exceeded.

**Known bug**: the length limit argument is ignored in JSON.

`array : 'a encoding -> 'a array encoding` (dynamic) is a combinator for the
`array` parametric type. It is represented the same as a list. The optional
parameter `?max_length` has the same effect.

``list_with_length : [`N | `Uint8 | `Uint16 | `Uint30] -> 'a encoding -> 'a list encoding``
(dynamic) is a combinator for the `list` parametric type. In binary it is
represented as a length header followed by the concatenation of the
representation of all the elements of the list.

Note that the length header indicates the length of the list (i.e., the number
of elements it holds) rather than the size of the representation (the number of
bytes it takes to represent).

The length header size is represented differently depending on the first
parameter of the combinator:
- `` `N ``: the length is represented by `uint_like_n`,
- `` `Uint8 ``: the length is represented by a `uint8`,
- `` `Uint16 ``: the length is represented by a `uint16`,
- `` `Uint30 ``: the length is represented by a positive `int31`.

Remember that, out of concern for compatibility with 32-bit architectures, in
case of `uint_like_n`/`` `N ``, the length cannot exceed the maximum value of
`uint30`/`int31`.

The `?max_length` parameter has the same effect as with `list`. If the
`?max_length` parameter is set, it must be less than or equal to the maximum
value the length encoding can represent: otherwise an exception is raised. E.g.,
``list_with_length ~max_length:2000 `Uint8`` raises an exception because
`2000` is greater than the maximum uint8 value (255).

In JSON, it is represented the same as with the `list` encoding: as an Array
literal.

``array_with_length : [`N | `Uint8 | `Uint16 | `Uint30] -> 'a encoding -> 'a array encoding``
(dynamic) is a combinator for the `array` parametric type. It is represented as
`list_with_length`. The optional `?max_length` parameter has the same effect.



### Sizing variants of existing combinators

Some combinators are specialised for certain sizes of inputs. We list them here.

`Fixed.string : int -> string encoding` (fixed:n) is a combinator for strings of
statically known length. In binary it is represented as exactly `n` bytes which
are exactly those of the string. In JSON it is represented as a string literal.

Given the encoding `Fixed.string n`, serialising will fail if the input string
has a length different than `n`. Deserialising in JSON will also fail for the
same reason. Note, however, that when deserialising in binary, exactly `n` bytes
are read. There is no way to check that the serialised data was correct:
exactly `n` bytes are read and that is all.

`Fixed.bytes: int -> bytes encoding` (fixed:n) is a combinator for values of the
type `bytes` of statically known length. In binary it is identical to
`Fixed.string`. In JSON it fails with in the same cases as `Fixed.length` but it
uses the hexadecimal encoding described in `bytes`.

`Fixed.bigstring: int -> string encoding` (fixed:n) is a combinator for values
of the `bigstring` type of statically known length. The `bigstring` type is an
alias for a `Bigarray` type to represent strings (also used in other libraries
such as `Bigstringaf`). In binary the data is represented like a `Fixed.string`.
In JSON, it is represented as a hex-encoded String literal.

The optional parameter `?string_json_repr` allows you to modify the
representation of the string in JSON. Pass the value `Plain` to represent the
data as a String literal.

`Fixed.add_padding: 'a encoding -> int -> 'a encoding` (fixed:+n) is a
combinator which adds blank bytes in binary and has no effect in JSON. In
binary `Fixed.add_padding e n` is represented as `e` followed by `n` null
bytes. When deserialising, the padding is ignored, even if it contains non-null
bytes.

This combinator can be used for alignment, to reserve space for future
extensions, or for any other such reason.

This combinator raises an exception if the argument is not a fixed-size
encoding.

`Fixed.list: int -> 'a encoding -> 'a list encoding` (?) is a combinator for lists
of statically known length. In JSON it is represented as a list literal,
serialising and deserialising will fail if the length does not match the
expected one. In binary, it is represented as the concatenation of the elements,
serialising and deserialising will fail if the length does not match the
expected one.

The binary deserialisation failure happens if there is a mismatch between the
number of elements and the number of available bytes (typically inferred from
size-headers): `Not_enough_data` if the deserialisation has read all the
available bytes but hasn't reached the expected length, `Extra_bytes` if the
deserialisation has read all the elements but there are bytes left to be read.

The combinator will raise an exception if given a variable-sized encoding.
Otherwise, the resulting encoding is of the same category as the argument.

`Fixed.array: int -> 'a encoding -> 'a array encoding` (?) is a combinator for
arrays of statically known length. They are represented like `Fixed.list` and
fail under the same circumstances.

`Variable.string: string encoding` (variable) is a ground encoding for the
`string` type. In JSON it represents data as a string literal. In binary it
represents data as the raw bytes which compose the string, without a size
header. This is a variable size encoding.

`Variable.bytes: bytes encoding` (variable) is a ground encoding for the
`bytes` type. In JSON it represents data as a string literal in hexadecimal
encoding. In binary it represents data as the raw bytes which compose the
value, without a size header. This is a variable size encoding.

`Variable.bigstring: unit -> string encoding` (variable) is a combinator for
values of the `bigstring` type. The `bigstring` type is an alias for a
`Bigarray` type to represent strings (also used in other libraries such as
`Bigstringaf`). In binary the data is represented as the raw bytes which compose
the value, without a size header. This is a variable-size encoding. In JSON, it
is represented as a hex-encoded String literal.

The optional parameter `?string_json_repr` allows you to modify the
representation of the string in JSON. Pass the value `Plain` to represent the
data as a String literal.

`Variable.list: 'a encoding -> 'a list encoding` (variable) is a combinator for
the `list` parametric type. For JSON, it is similar to `list`: represented as a
list literal. For binary, it is represented as the concatenation of the bytes
representing each of the elements of the list, without size headers, separator,
nor terminators.

As with `list`, the optional parameter `?max_length` allows you to specify the
maximum number of elements in the list. Serialising and deserialising will fail
if this number of elements is exceeded. (The failure mode is similar to that of
`Fixed.list`, but it happens only if the number of elements exceeds the limit,
not if it is under.)

As with `list`, the combinator will raise an exception if the argument is
variable-sized.

`Variable.array: 'a encoding -> 'a array encoding` (variable) is a combinator
for the `array` parametric type. For JSON, it is similar to `array`: represented
as a list literal. For binary, it is represented as the concatenation of the
bytes representing each of the elements of the array, without size headers,
separator, nor terminators.

As with `array`, the optional parameter `?max_length` allows you to specify the
maximum number of elements in the array. Serialising and deserialising will fail
if this number of elements is exceeded.

`Bounded.string: int -> string encoding` (dynamic) is a combinator for strings
of statically bounded length. In JSON it is represented as a string literal. In
binary it is represented with a size header followed by the byte content of the
string payload. The size of the size header depends on the bound of the size of
the string. Specifically, the size header is the smallest integer size that can
accommodate the lengths within the bound: either a uint8, uint16, or int31.

`Bounded.bytes: int -> bytes encoding` (dynamic) is a combinator for values of
the type `bytes` of statically bounded length. In JSON it is represented as a
string literal in hexadecimal encoding. In binary it is represented with a size
header followed by the byte content of the bytes payload. The size of the size
header depends on the bound of the size of the bytes. Specifically, the size
header is the smallest integer size that can accommodate the lengths within the
bound: either a uint8, uint16, or int31.

`Bounded.bigstring: unit -> string encoding` (dynamic) is a combinator for
values of the `bigstring` type of statically bounded length. The `bigstring`
type is an alias for a `Bigarray` type to represent strings (also used in other
libraries such as `Bigstringaf`). In binary the data is represented as the raw
bytes which compose the value, without a size header. This is a variable-size
encoding. In JSON, it is represented as a hex-encoded String literal.

The optional parameter `?string_json_repr` allows you to modify the
representation of the string in JSON. Pass the value `Plain` to represent the
data as a String literal.


### ADT combinators: records (and other products)

`obj1: 'a field -> 'a encoding` (?) is a combinator for representing a single-field
object. In JSON it is represented as an object of exactly one entry. In binary
it is represented as the content of the field.

`obj2`, `obj3`, and so on up to `obj10` are combinators for representing objects
with the specified number of fields. In JSON they are represented as objects
with each of the fields present. In binary they are represented as the
concatenation of all the fields, one after another.

The main intended use of `objN` is to represent
[records](https://ocaml.org/manual/coreexamples.html#s:tut-recvariants).

Fields are created with the following combinators:

`req: string -> 'a encoding -> 'a field` is for a required (non-optional) field.
The `string` parameter is used as the key in the object representation.

`opt: string -> 'a encoding -> 'a option encoding` is for an optional field. In
JSON the field is omitted if the value is `None` and present if `Some _`. In
binary it is represented with a one-byte tag.

In the case where the field is in the right-most position of the obj and the
field's encoding is of variable size, then the binary representation is to omit
`None` and represent `Some v` as `v`, without the single-byte header.

`varopt: string -> 'a encoding -> 'a option field` is for an optional field. The
representation is identical to that of `opt`, but the field sizing is considered
variable-sized (even if the field's encoding is actually fixed or dynamic). This
makes it possible to leverage the corner case (right-most position and
variable-size) mentioned above for a more compact encoding.

`dft: string -> 'a encoding -> 'a -> 'a field` is a combinator for fields which
have a known default value. In binary the field is always represented as is. In
JSON the field is omitted if the value is equal to the provided default.

`merge_objs` is a combinator to produce one bigger object encoding out of two
smaller object encodings. The main intended use is to allow you to define `objN`
for `N > 10` as you need it:
`let obj14 e1 … e14 = merge_objs (obj7 e1 … e7) (obj7 e8 … 14)`. It can also be
used to programmatically or meta-programmatically construct more and more
complex objects.

In general, you should try to balance the objects being merged. E.g., it is
better to use `merge_objs (obj7 …) (obj7 …)` than
`merge_objs (obj10 …) (obj4 …)`. This is mostly important in places where
performance matters, but even then, it is not vitally important.

Note that by default, there are no checks for duplicate field names in objects.
E.g., `obj2 (req "foo" int) (req "foo" int)` is accepted by the library and will
produce JSON object `{ "foo":…, "foo":… }`. This is a valid form of JSON
although it is not recommended.

If you want to avoid duplicate names, you can open the
`With_field_name_duplicate_checks` module. Opening this module shadows the
`obj*` and `merge_objs` combinators mentioned above. The shadowing versions
raise exceptions when they would produce an encoding with duplicate field names.

```
let e =
  let open Data_encoding in
  let open With_field_name_duplicate_checks in
  obj2 (req "foo" int) (req "foo" int) (* raises [Invalid_argument] *)
```

In addition to records, data-encoding supports encodings for tuples.

`tup1: 'a encoding -> 'a encoding` is a combinator for representing data as a
one-tuple. The JSON representation of `tup1 e` is as an array literal containing
exactly one element representing `e`. The Binary representation of `tup1 e` is
identical to that of `e`.

The main intended use of `tup1` is to wrap the argument in a `Tup` variant.
The resulting encoding can then be passed to the `merge_tups` function. This is
sometimes necessary if you programmatically generate some tuple encodings.

`tup2`, `tup3`, and so on up to `tup10` are combinator for representing
N-tuples. The JSON representation is as an array literal containing the exact
required number of elements. The binary representation is the concatenation of
the representation of the arguments.

These combinators fail if the sizing of the different component leads to
unreadable data. If that is the case, you may need to wrap the left parameter in
a `dynamic_size` combinator.

`merge_tups` is a combinator to produce one bigger tuple encoding out of two
smaller tuple encodings. The main intended use is to allow you to define `tupN`
for `N > 10` as you need it:
`let tup14 e1 … e14 = merge_tups (tup7 e1 … e7) (tup7 e8 … 14)`. It can also be
used to programmatically construct more and more complex tuples.

In general, you should try to balance the tuples being merged. E.g., it is
better to use `merge_tups (tup7 …) (tup7 …)` than
`merge_tups (tup10 …) (tup4 …)`. This is mostly important in places where
performance matters, but even then, it is not vitally important.



### ADT combinators: variants (a.k.a. sums)

`union` is a combinator for making encodings of
[variant types](https://ocaml.org/manual/coreexamples.html#s:tut-recvariants).
The `union` combinator takes a list of `case`s as parameters.

```
let custom_result o e =
  union [
    case
      ~title:"success"
      (Tag 0)
      (tup1 o)
      (function Ok v -> Some v | _ -> None)
      (fun v -> Ok v);
    case
      ~title:"failure"
      (Tag 255)
      (obj1 (req "failure" e))
      (function Error v -> Some v | _ -> None)
      (fun v -> Error v);
  ]
```

The `case` function takes the following parameters:

- `title: string` for documentation in schemas only
- `case_tag`: most often `Tag n`
- `'a encoding`: an encoding for the payload of the case
- `'t -> 'a option`: a variant-to-payload projection function
- `'a -> 't`: a payload-to-variant injection function

Note that `union` will raise an exception if two cases use the same numerical
tag.

The projection function should always look like the ones in the example: one
variant returns `Some` with the payload, and all other variants (hence the
wildcard pattern) return `None`.

In binary, for serialisation, the projection function of each case is called
until one returns `Some payload` at which point the tag is serialised as an
integer and the `payload` is serialised with the case's payload encoding. For
deserialisation, the tag is read, the corresponding case is selected, the
payload is deserialised based on the case's encoding, and the deserialised value
is passed to the injection function.

You can pass the optional parameter `?tag_size` to the `union` combinator to
control the size of the tag.

In JSON, for serialisation, the projection function of each case is called
until one returns `Some payload` at which point the `payload` is serialised with
the case's payload encoding. For deserialisation, the process attempts to
deserialise the JSON value based on the encoding of each case until one
succeeds. The deserialised value is passed to the injection function.

Note that for JSON, you are responsible for disambiguating the different cases
of the union: there are no tags, the first match is used. Consider an
alternative encoding for `result` in which the `Ok` case is presented as-is:

```
let bare_result o e =
  union [
    case
      ~title:"success"
      (Tag 0)
      o (* no wrapping here! *)
      (function Ok v -> Some v | _ -> None)
      (fun v -> Ok v);
    case
      ~title:"failure"
      (Tag 255)
      (obj1 (req "failure" e))
      (function Error v -> Some v | _ -> None)
      (fun v -> Error v);
  ]
```

This encoding works well in many situations. However, consider a corner case
such as `bare_result (assoc int) int`. In this case the value `Error 0`
is serialised to the JSON value `{ "failure": 0 }` which is deserialised to the
value `Ok [("failure", 0)]`. The encoding is ambiguous and the serialisation and
deserialisation processes are not inverses of each other.

This same reasoning applies to any situation where the `o` encoding can be
represented as `{ "failure": _ }`.

**It is your responsibility to ensure serialisation and deserialisation
correctly mirror each other.**

**As an alternative,** you can open the `With_JSON_discriminant` module. Opening
this module shadows the `case` and `union` combinators (as well as `matched` and
`matching`, see below) to include JSON discriminant fields in the objects of the
union.

When using this shadowing module, you pass a `string` tag in addition to the
`int` tag. The `string` tag is inserted in a field named `"kind"` inside the
object encoding of the case. For this purpose, the `union` (and `matching`)
combinator will raise the `Invalid_argument` exception if:
- the cases have non-object encodings, or
- the case encodings already have a `"kind"` field, or
- several of the cases have equal string tags.

`matching` is a combinator similar to `union` but it takes an additional
matching-function parameter. This matching-function avoids the linear
scanning of the cases during serialisation.

```
let custom_result o e =
  matching
  (function
    | Ok v -> matched 0 (tup1 o) v
    | Error e -> matched 255 (obj1 (req "failure" e)) e)
  [ … (* same cases as in the example above *) ]
```

The matching-function should always look like the one above: a list of simple
patterns that simply return `matched <tag value> <encoding> <payload>`.

It is your responsibility to ensure that the matching-function and the case list
agree on tags, encodings and payload. To this end, it is recommended that you
bind the tags and encodings to variables which you use in both places. See the
documentation of `matching` for an example of this pattern.


### Recursive combinator

`mu` is a combinator for recursive types.

```
let custom_list a =
  mu
    "list"
    (fun l ->
      union [
        case
          ~title:"Cons"
          (Tag 0)
          (obj2 (req "head" a) (req "tail" l))
          (function x :: xs -> Some (x, xs) | _ -> None)
          (fun (x, xs) -> x :: xs);
        case
          ~title:"Nil"
          (Tag 1)
          null
          (function [] -> Some () | _ -> None)
          (fun () -> []);
      ]
    )
```

The `mu` combinator takes a string parameter intended only for documentation and
a fixpoint function which, given an encoding for the type, returns the unfolded
encoding for the type. This may or may not be confusing depending on previous
exposure to other μ theoretical shenanigans and applied questionable trickery.
It is outside the scope of this tutorial to get you over this possible hurdle.
You can simply adapt the above template or any other example from the tests or
the cookbook (see below) to your needs.

Note that for efficiency, the fixpoint function is memoised: it is not
repeatedly applied when traversing a recursive data structure. Also note that
because of internal machinery regarding schema generation as well as JSON
encoding conversion, the fixpoint function may still be called multiple times.


### Multi-purpose combinators

`conv` is a combinator for applying arbitrary functions during serialising and
deserialising. The main intended purpose is to convert the data from some
uncommon, impractical, or abstract format into a concrete one. E.g., when
encoding a hash-table, you first convert it to a simple key-value list.

```
let hashtbl (k: H.key encoding) (v: 'a encoding) : 'a H.t encoding =
  conv
    (fun h -> List.of_seq (H.to_seq h))
    (fun l -> H.of_seq (List.to_seq l))
    (list (tup2 k v))
```

Depending on the properties of the underlying data structure you are converting
from and how you intend to use the serialised blob, you may need to canonicalise
the converted representation too. E.g., in the example above, does the order in
the list matter?


`conv_with_guard` is a variant of `conv` where the deserialisation function is
partial. More specifically, it returns a `('a, string) result` value where
`Error s` will cause a deserialisation failure with `s` included in the message.
The main intended purpose is to guarantee some invariant which, in the OCaml
code, may be guaranteed by the type system, assertion checks, or some other
means.

```
let non_empty_hashtbl k v =
  conv_with_guard
    (fun h -> List.of_seq (H.to_seq h))
    (function
      | [] -> Error "hashtbl is empty"
      | l -> H.of_seq (List.to_seq l))
    (list (tup2 k v))
```

`with_decoding_guard` is a combinator to add a deserialisation guard function to
an arbitrary encoding. E.g., the `conv_with_guard` example above can be
rewritten equivalently as

```
let non_empty_hashtbl k v =
  conv
    (fun h -> List.of_seq (H.to_seq h))
    (fun l -> H.of_seq (List.to_seq l))
    (with_decoding_guard
      (function [] -> Error "hashtbl is empty" | _ -> Ok ())
      (list (tup2 k v)))
```

or also equivalently as

```
let non_empty_hashtbl k v =
  with_decoding_guard
    (fun h -> if H.length h = 0 then Error "hashtbl is empty" else Ok ())
    (conv
      (fun h -> List.of_seq (H.to_seq h))
      (fun l -> H.of_seq (List.to_seq l))
        (list (tup2 k v)))
```

`delayed` is a combinator to compute the encoding at each serialisation and
deserialisation. This combinator takes a single parameter: a function to
generate the encoding `(unit -> 'a encoding)` which is called when needed.

The main intended use is for encodings which depend on global mutable state.
In the Octez code base, this is used to define the encoding of an extensible
variant. The general idea is as follows (although in practice the code is more
complicated mostly out of efficiency concerns):

```
type error = …
let error_case_encodings = ref []
let register_error case = error_case_encodings := case :: !error_encodings
let error_encoding =
  delayed (fun () -> union !error_case_encodings)
```

**Known bug**: In JSON, the encoding is only computed on first use. It is not
recomputed at each use.

`splitted` is a combinator which given two distinct encodings dispatches the
serialisation and deserialisation processes on either depending on the backend.
More concretely, `splitted ~json ~binary` uses the `json` encoding in the JSON
backend and the `binary` encoding in the binary backend.



### Sizing combinators

`check_size: int -> 'a encoding -> 'a encoding` is a combinator which adds a
runtime check during serialisation and deserialisation in binary. This check
enforces that the binary blob representing the data does not exceed the limit.

The primary intended use of this combinator is to guard against some basic
attacks when deserialising untrusted data. E.g., using `check_size` in the
message encoding of a network application will cause deserialisation to fail
early if another machine sends overly long data.

In JSON it has no effect.

`dynamic_size: 'a encoding -> 'a encoding` is a combinator for adding a size
header to a given encoding. Note that the size header is always added,
regardless of the sizing category of the argument encoding. E.g.,
`dynamic_size (dynamic_size uint8)` will occupy 9 bytes in binary.

The optional parameter `?kind` lets you decide the binary representation of the
size header.

- `` `Uint30 `` (the default) represents it on four bytes and allows sizes up to
  2^30 bytes.
- `` `Uint16 `` represents it on two bytes and allows sizes up to 2^16 bytes.
- `` `Uint8 `` represents it on one byte and allows sizes up to 2^8 bytes.
- `` `N `` represents it on a variable number of bytes (as per the `n` encoding)
  and allows sizes up to 2^30 bytes. Note that during serialisation, this
  combinator can be more computationally expensive because the size-header is
  dynamically-sized.

If you are using this combinator in a programmatic setting, you may want to
apply it selectively depending on the result of `classify`:

```
let dynamic_size_if_variable e =
  match classify e with
  | `Variable -> dynamic_size e
  | `Fixed _ | `Dynamic -> e
```


### Compact combinators

The `Compact` module provides combinators to produce `'a compact` encodings.
The compact encodings help represent data in a more compact way. The main
trick that compact encodings rely on is to coalesce multiple tags into a single
shared tag.

These compact encodings can then be converted into vanilla encodings via
`Compact.make`.

At present, this tutorial does not cover compact encodings. You can read the API
documentation of the <module:Data_encoding.Compact> to learn more about them.


## Part 4: So what else can you do?

### Cookbook

**Making sure de/serialisation are inverse of each other**

In most uses of the data-encoding library, you want the serialising and
deserialising processes to be exact inverses of each other. It is your
responsibility to make sure this property holds. And you are encouraged to add
fuzzing tests towards this end.

The biggest way you might accidentally break this property is with unions in
JSON. Indeed, remember that in JSON, the serialisation process picks the first
case where the projection function matches the value, and the deserialisation
process picks the first case where the encoding matches the JSON. Thus, you need
to ensure that the JSON serialised by a given case is matched by that same case.

The best way to ensure this error is to open the `With_JSON_discriminant`
module. When you do so, the union/case and matching/matched functions will take
additional parameters and perform some checks for you. The parameters are
transformed into discriminants in JSON.

Note that in the `With_JSON_discriminant`, the combinators make assumption about
the encodings of the cases that you must abide to — or get an exception in
return. Specifically you must:

- provide object encodings for all the cases,
- not name any of the fields of the case encodings `"kind"` (the name is
	reserved for the discriminant), and
- not use the same discriminant twice.

E.g.,
```
let unambiguous_option v =
  let open With_JSON_discriminant in
  union [
    case ~title:"Some"
      (Tag (0, "some"))
      (obj1 (req "v" v))
      (function Some v -> Some v | _ -> None) (fun v -> Some v);
    case ~title:"None"
      (Tag (1, "none"))
      empty (* empty is an object with zero fields *)
      (function None -> Some () | _ -> None) (fun () -> None);
  ]
```

As an alternative, you can enforce the discriminant discipline manually.
One way is for you to include a "kind" field carrying the name of the variant in
the cases' payload encoding. E.g.,

```
let unambiguous_option v =
  union [
    case ~title:"Some"
      (Tag 0)
      (obj2 (req "kind" (constant "some")) (req "v" v))
      (function Some v -> ((), v) | _ -> None) (fun ((), v) -> Some v);
    case ~title:"None"
      (Tag 1)
      (obj1 (req "kind" (constant "none")))
      (function None -> Some () | _ -> None) (fun () -> None);
  ]
```

Remember that `constant` is omitted in binary but always included in JSON.

The other way is for you to use the variant's name as a field name for the whole
of the cases' payload encoding. E.g.,

```
let unambiguous_option v =
  union [
    case ~title:"Some"
      (Tag 0)
      (obj1 (req "some" v))
      Fun.id Option.some;
    case ~title:"None"
      (Tag 1)
      (obj1 (req "none" null))
      (function None -> Some () | _ -> None) (fun () -> None);
  ]
```

Both approaches are valid. There are minor trade-offs in term of boilerplate code
depending on the payloads of the cases. You can choose based on personal
preference or to ease integration with a more opinionated system.

Still, the simplest is to trust the library and open the
`With_JSON_discriminant` module.


**Making sure de/serialisation are _not_(!) inverse of each other**

In most uses of the data-encoding library, you want the serialising and
deserialising processes to be exact inverses of each other. _Most_. There are a
few use cases when serialisation purposefully produces a different
representation than the deserialisation. The two main such use
cases are for legacy support (the ability to decode values encoded by previous
versions of your software) and more generally when there are multiple valid
representations of the data.

Given a type `t` with its encoding `e` and a deprecated type `legacy_t` with its
encoding `legacy_e`, and given an `upgrade: legacy -> t` function, you can
define an encoding which is able to deserialise both legacy and current formats.

```
let ee =
  splitted
    ~binary:e (* legacy support in binary is out of scope of this example *)
    ~json:(
      union [
        case ~title:"current"
          (Tag 0) (* ignored because we are in JSON, but necessary *)
          e
          Option.some
          Fun.id;
        case ~title:"legacy"
          Json_only
          legacy_e
          (fun _ -> None (* never match when serialising *))
          upgrade
      ])
```

With this encoding, the serialisation and deserialisation processes are not
inverse of each other. Specifically, the legacy JSON values can be deserialised
but when they are re-serialised they are different.

Note that the hack presented above is for JSON values. If you need backwards
compatibility in the binary backend, you should plan this in advance and add a
version tag to the representation.

Finally, note that this example of backwards compatibility is just one example.
There are other use cases for making serialisation and deserialisation not
inverse of each other. You should probably document why and how you are doing
so.


**Maps, Sets, Hashtbls, etc.**

When you need to define encodings for collection data structures, the simplest
is often to convert them to lists or arrays.

```
let e k v =
  conv
    (fun m -> List.of_seq (Map.to_seq m))
    (fun l -> Map.of_seq (List.to_seq l))
    (list (tup2 k v))
```

However, you should also consider the following:

- Do you need to sort the list? Or is the conversion guaranteed to yield the
	same order every time? Or does the order not matter for your use case?
- Are there some invariants you can check? Are there invariants you should
	check? E.g., about the size of the data structure, about the presence or
	absence of some specific elements, about the presence or absence of some
	duplicates, etc.


**Mutually recursive encodings**

You can use `mu` to define recursive encodings for recursive types. You can also
use `mu` to define mutually-recursive encodings for mutually-recursive types.
The generic recommended pattern to follow is this.

```
let make_e1 e2 =
  mu "e1" (fun e1 ->
    … (* define encoding e1, using e2 where appropriate *)
  )

let e2 =
  mu "e2" (fun e2 ->
    let e1 = make_e1 e2 in
    … (* define encoding e2, using e1 where appropriate *)
  )

let e1 = make_e1 e2
```

In most cases you will want to hide `make_e1` from your interface. You can do so
via an mli file or by only defining it locally.

```
let (e1, e2) =
  let make_e1 e2 = … in
  let e2 = … in
  let e1 = make_e1 e2 in
  (e1, e2)
```

You can find a full example in the file `test/mu.ml`.


**Encodings which are more compact (use fewer bytes)**

A common concern with the binary backend is to use as few bytes as possible.
Indeed, having a compact serialised form is the main advantage of the binary
backend over the JSON one.

As mentioned earlier, the <module:Data_encoding.Encoding.Compact> module offers
dedicated combinators to squeeze as much information in as few bytes as
possible. This is mainly done by grouping multiple tags each taking a handful of
bits into a single shared tag. There are additional tricks to push even more
information (list lengths and such) in the unused bits of tags.

But you can also use some techniques on the vanilla encodings. The first one is
to encode as many of the code invariants into the encodings. Especially the size
ones.

For example, if some type is represented as a string, but the values are
guaranteed to be under a certain length, then the `Bounded.string` will
automatically shave some unneeded bytes from the size header. In general, the
`Bounded` variants of a given combinator are more compact than the plain
variant.

You can also be weary of integer sizes. Prefer smaller integer sizes where
possible. And even if an integer-like type is not guaranteed to always fit
within a smaller integer representation, you can use `uint_like_n` and
`int_like_z` which occupy less bytes on small values but more space on bigger values.

If you need to find exact cut-off points for various integer ranges for various
encodings, you can check the code in `misc/eval_numsizes.ml`.

You can also reduce the size of the size headers of lists if you know that they
will fit within a small enough space. To that end, you can replace a `list`
combinator (which introduces a full `` `Uint30 `` four bytes size header) with a
tailored call to `dynamic_size` followed by a `Variable.list`.

```
dynamic_size ~kind:`Uint16 (Variable.list …)
```

You can use `` ~kind:`N `` to use the variable-size encoding for the size. It is
more compact on smaller sizes but less compact on larger ones. See `uint_like_n`
for details.

Finally, you should be careful not to add unnecessary `dynamic_size`. If you are
unsure whether you need one in a specific place, you can use the `classify`
function to determine this.


**Beware of side-effects in conv and mu and such**

As a general rule, you should avoid side-effects in all the functions you pass
to the combinators of data-encoding: the conversion functions of `conv`, the
guarding function of `with_decoding_guard`, the fixpointing functions of `mu`,
the projection and injection function of `case`, etc.

The part of the program which triggers a serialisation and deserialisation
processes can be quite distant from the encoding definitions. As such
side-effects can seriously hinder readability of the code.

A more specific concern is that it is difficult to predict which functions will
be called. Indeed, the serialisation and deserialisation processes are
fail-early: the are interrupted as soon as something goes awry. This makes the
it difficult to predict which set of functions will always be called together
and which might be called separately.

Even more complexity is added by the backtracking mechanism of union
case selection in JSON deserialisation. Remember that the JSON unions are not
tagged by the data-encoding library and that it is your responsibility to do so.
Depending on how you do so, the deserialisation can make significant progress in
a specific case before failing.

All in all, side-effects in all the functions passed to combinators make code
less predictable and should be avoided.


**Overloading**

Occasionally, you might be interested in deserialising only part of a value.
Consider, for example, the case where you are only interested in two fields out
of five of an object. In case where the discarded fields are small and simple to
deserialise, you can simply deserialise everything and not use them. But if the
discarded fields are expensive to deserialise then you might want to skip them.

For such cases, you can define two distinct encodings. The one you use for
writes and for full reads. And the other you use for partial reads. The latter
uses specific combinators to skip content that is not interesting. E.g.,

```
let e =
  obj4
    (req "id" (Fixed.string 32))
    (req "name" string)
    (req "tags" (list string))
    (req "scores" (list int64))

let id_and_name_e =
  conv
    (fun _ -> failwith "Not intended for serialisation")
    (fun (id, name, (), ()) -> (id, name))
    (obj4
      (req "id" (Fixed.string 32))
      (req "name" string)
      (req "tags"
        (splitted (* ignore either way, with [unit] in JSON, by [conv] in binary *)
          ~json:unit
          ~binary:(conv (fun _ -> assert false) (fun _blob -> ()) string)))
      (req "scores"
        (splitted
          ~json:unit
          ~binary:(conv (fun _ -> assert false) (fun _blob -> ()) string))))
```

There are different ways to ignore parts of an encoding. The one above is the
most generic and relies on the fact that `string` introduces, like many other
combinators, a size header. You can use `Fixed.string` to ignore fixed-size
fields.


### Registration

The `Registration` module allows you to build a global registry of encodings.
These encodings can be queried by names.

In the Octez code base, this is used to build the `tezos-codec` binary. This
binary can convert between binary and JSON representations (allowing users to
decode otherwise difficult to read network messages and protocol data). Checkout
[this brief tutorial on `tezos-codec`](https://tezos.gitlab.io/developer/encodings.html).


### Slicing

The `Slicing` module allows you to split a binary blob of serialised data into
its basic components. This is a tool mostly intended for debugging and
experimentation.

For example, given the following encoding, value and its serialised string:

```
let e = tup3 (option int16) string (list uint8)
let v = (Some 404, "not found", [1;1;2;1;2;4])
let b = Result.get_ok @@ Binary.to_string e v
```

Then the call `Binary.Slicer.slice_string e b` returns the following value:

```
[
  {name = "Some tag";       value = "\001";             pretty_printed = "1"};
  {name = "int16";          value = "\001�";            pretty_printed = "404"};
  {name = "dynamic length"; value = "\000\000\000\t";   pretty_printed = "9"};
  {name = "string";         value = "not found";        pretty_printed = "\"not found\""};
  {name = "dynamic length"; value = "\000\000\000\006"; pretty_printed = "6"};
  {name = "uint8";          value = "\001";             pretty_printed = "1"};
  {name = "uint8";          value = "\001";             pretty_printed = "1"};
  {name = "uint8";          value = "\002";             pretty_printed = "2"};
  {name = "uint8";          value = "\001";             pretty_printed = "1"};
  {name = "uint8";          value = "\002";             pretty_printed = "2"};
  {name = "uint8";          value = "\004";             pretty_printed = "4"};
]
```

Each element in the list is a _slice_ of the binary serialised representation of
the value `v`.


### JSON streaming

Serialising large values can consume a significant amount of time and space.
You can mitigate this by manually splitting your data structure and then
serialising the different parts separately. You can then send those parts off as
separate messages over the network or storing them in separate files on disk.
But this manual mitigation mechanism is not always convenient.
And so the JSON backend offers a mechanism dedicated to tackling this issue.

`Json.construct_seq` is a streaming counterpart to `Json.construct`. Instead of
producing a `json` value, it produces a lazy sequence of jsonm lexemes.

```
type jsonm_lexeme =
  [ `Null (* null literal *)
  | `Bool of bool (* boolean literal *)
  | `String of string (* string literal *)
  | `Float of float (* numeral literal *)
  | `Name of string (* field-name *)
  | `As (* array-start: opening square-bracket *)
  | `Ae (* array-end: closing square-bracket *)
  | `Os (* object-start: opening curly-bracket *)
  | `Oe (* object-end: closing curly-bracket *)
  ]
val construct_seq : 't Encoding.t -> 't -> jsonm_lexeme Seq.t
```

The encoding and the value are traversed on a by need-basis. In particular, the
call to `construct_seq` does not traverse any part of the encoding or the value.
Only by consuming the sequence can you cause this to happen.

The main intended use of the lexeme sequence is by converting it to a
blit-instruction sequence. A blit-instruction sequence is a sequence of triplets
`(bytes * int * int)` where each triplet is a valid source-offset-length set of
input for the Stdlib's `blit` functions.

```
val blit_instructions_seq_of_jsonm_lexeme_seq :
  buffer:bytes -> jsonm_lexeme Seq.t -> (Bytes.t * int * int) Seq.t
```

There are other seq-conversion functions to serialise to other forms (e.g., a
sequence of string) but the blit-instruction function reuses the bytes buffer
which helps reduce memory usage.

Consuming the blit-instruction sequence consumes the underlying lexeme sequence
which causes the value and encoding to be traversed.


Here's a full working example using the Lwt library for I/O.

```
let send channel message =
  let bis =
    Json.blit_instructions_seq_of_jsonm_lexeme_seq
      ~buffer:(Bytes.create 4096)
      (Json.construct_seq application_message_encoding  message)
  in
  let rec loop bis =
    match bis () with
    | Seq.Nil ->
        Lwt_io.flush channel
    | Seq.Cons ((bytes, offset, length), bis) ->
        let* () = Lwt_io.write_from_exactly channel bytes offset length in
        let* () = Lwt.pause () in
        loop bis
  in
  loop bis
```


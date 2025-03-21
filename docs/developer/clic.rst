The ``clic`` library
====================

:package-api:`mavryk-clic <mavkit-libs/Mavryk_clic/index.html>` is an OCaml combinator library for writing
self-documenting command-line argument parsers. Clic is similar to
`cmdliner <https://erratique.ch/software/cmdliner>`__, but (unlike cmdliner)
``mavryk-clic`` allows to define a domain-specific
language as a subset of a natural language, by mixing keyword and
positional arguments. For example, in ``mavkit-client``, commands look
like this, thanks to ``mavryk-clic``:

.. code-block::

    mavkit-client list understood protocols
    mavkit-client compute chain id from block hash <hash>
    mavkit-client originate contract <contract_alias> transferring <initial_balance> from <originator> running <script>


``clic`` is used for most of the binaries distributed with Mavkit, such
as ``mavkit-client`` and ``mavkit-codec``. A notable exception is
``mavkit-node`` which uses ``cmdliner``.

In this tutorial, we will give a gentle introduction to ``clic`` by
demonstrating how to implement a wallet command inspired by those of
``mavkit-client``. Impatient readers will find the full example
:src:`in this file<src/lib_clic/examples/clic_example.ml>`.

Wallet example
--------------

Command-line parsing in ``clic`` is centered around *commands*. A command
roughly corresponds to one action of the command-line application. For
instance, ``mavkit-client get balance`` and ``mavkit-client run script
<script>`` are two different commands.
To demonstrate the use of ``clic``, we will add the following command to a dummy mavkit-client: ``list
known contracts``. As the name indicates, this command outputs
the contracts known to the wallet.

Commands execute in a user-supplied *context*. Typically, the context
serves as an abstraction barrier between the command and its execution
environment. This mechanism allows commands to be defined once, but
reused in different contexts. An example where this
useful is for swapping out the normal context for a *dry-run context*,
allowing users to simulate the effect of commands before running them
for real.

Note that using contexts is not required: it can be side-stepped by
defining commands that execute over a
context of type ``unit``.

In the running example, we define a context whose job is to contain
the actual implementation of the commands.


We first declare ``CONTEXT`` as the signature of modules that contain a
``list_known_contracts`` function. As we add more commands to the
example, we will also extend the context. For convenience, we add a
type alias ``context`` for first-class ``CONTEXT`` modules.

.. literalinclude:: ../../src/lib_clic/examples/clic_example.ml
   :language: ocaml
   :start-after: [context type]
   :end-before: [context definition]

We define a ``Dummy_context`` that satisfies
the ``CONTEXT`` signature, with a place-holder function simply printing
what the actual function would do.

.. literalinclude:: ../../src/lib_clic/examples/clic_example.ml
   :language: ocaml
   :start-after: [context definition]
   :end-before: [command groups]

Commands are defined through the ``Mavryk_clic.command`` function. It has the following signature:

.. code-block:: ocaml

    Mavryk_clic.command :
      ?group:Mavryk_clic.group ->
      desc:string ->
      ('b, 'ctx) Mavryk_clic.options ->
      ('a, 'ctx) Mavryk_clic.params ->
      ('b -> 'a) -> 'ctx Mavryk_clic.command

First, commands have a group and description that are used to
generate documentation.
Groups are used to organize commands of related functionality. This is
convenient for applications such as ``mavkit-client`` that defines a
large number of commands which are grouped on themes such as
querying, testing, and address management. You can see the documentation
:ref:`online <client_manual_alpha>`.

In our example, using groups is not required, but we add a group
to demonstrate the feature. A group is just a name and a description of
the commands in that group.

.. literalinclude:: ../../src/lib_clic/examples/clic_example.ml
   :language: ocaml
   :start-after: [command groups]
   :end-before: [list known contracts]

The third argument to ``Mavryk_clic.command`` specifies the set of options
that commands take, which modulate its behavior (think ``--verbose``
or ``--output json``). The value of the options will be collected as a
value of type ``'b``.

The command is specified through a sequence of *params*, given as the
fourth argument to ``Mavryk_clic.command``. Params can be *prefixes*: fixed
strings that must be given when calling the command. Above, we
mentioned the ``get balance`` command of ``mavkit-client``. The
sequence ``get balance`` is an example of such a prefix. A param can
also define a *hole* to be filled by the user on the command line. An example is given by
``mavkit-client get balance for <contract>``. Here, the command
consists of a sequence of prefixes ``get balance for`` followed by the
hole ``<contract>``, filled by the user on the command-line. No matter how the params
specification is constructed, it is terminated by the combinator ``Mavryk_clic.stop``.
The params specification will construct a function type ``'a``, which together
with the type ``'b`` from the options is
used to construct the signature ``'b -> 'a`` that the *command
handler* must adhere
to.

Note also that by construction, the type ``'a`` will always be of
the form ``... -> 'ctx -> unit tzresult Lwt.t``, so that commands
always receive a context and must return ``unit`` in the ``tzresult Lwt.t``
monad.

The fifth argument ``Mavryk_clic.command`` is the command handler. This
function implements the actual command. It is passed any supplied
command-line options (as a value of type ``'b``) and the contents of
any holes in the params (which are, respectively, types of the
arguments of the function type ``'a``).

An example will be helpful to illustrate the signature of the command handler.
A command
that takes no options will have ``'b = unit``. If, furthermore, its
params have no holes, then ``'a = context -> unit tzresult Lwt.t``. The
command is thus a function

.. code-block:: ocaml

  unit -> context -> unit tzresult Lwt.t

In other words, taking no arguments except for ``()`` and the context, and
returning ``unit`` wrapped in the ``tzresult`` and ``Lwt.t`` monads.

As a second illustration of the signature of the command handler,
consider a command ``get balance for <contract>``, where ``<contract>`` is of type ``Contract.t``.
Additionally, the command should
consume a ``--output <format>`` option (where ``<format>`` is a string
such as ``"json"``, ``"csv"``, etc.). In this case, ``'b = string option``,
``'a = Contract.t -> context -> unit tzresult Lwt.t``, and the command
handler a function with the signature:

.. code-block:: ocaml

  string option -> Contract.t -> context -> unit tzresult Lwt.t

We now have enough meat on our bones to define the ``list known contracts`` command.

.. literalinclude:: ../../src/lib_clic/examples/clic_example.ml
   :language: ocaml
   :start-after: [list known contracts]
   :end-before: [program entrypoint]

We wrap the command and its related definitions in a module
``List_known_contracts``. We specify that the command should have no
options through ``Mavryk_clic.no_options``. We specify that the params is
a list of prefixes without holes. We then define the command
handler ``list_known_contracts_handler``. As the command has no
options and its params no holes, the signature of the handler becomes:

.. code-block:: ocaml

  unit -> context -> unit tzresult Lwt.t

This command handler does no more than unwrap and call the appropriate function of the
context. Finally we add the command to the full list of commands
``commands`` that the application will provide.

Having thus defined the commands, we now define the entrypoint
of our application:

.. literalinclude:: ../../src/lib_clic/examples/clic_example.ml
   :language: ocaml
   :start-after: [program entrypoint]

It consists of three sections. We first setup a formatter that
depending on whether the command is executed in a tty (as opposed to
e.g. being piped to a file) enables color in the output. Then, we
pack our context in a first-class module, that we pass to the
``Mavryk_clic.dispatch``. This function takes the full list of commands, as
defined by ``commands``, the context, and the list of raw command-line
arguments passed through the application. The list of command-line
arguments should not contain the first element (the name of the
program itself), so this is why the ``List.tl`` function is used. The ``dispatch`` function will parse the arguments,
and call the appropriate command handler if a valid command was
given. If this is the case, ``Ok ()`` is returned. If no arguments
have been passed, or if ``--help`` is given, then ``Error [Mavryk_clic.Help
_command]`` is returned. In this case the application should print the appropriate
usage instruction. If some other unrecognized
arguments are given we give a placeholder error message, which we'll
replace with something more helpful below.

We use ``dune`` to compile the example, with the following ``dune`` file:

.. literalinclude:: ../../src/lib_clic/examples/dune
   :language: scheme
   :start-at: (executable

The dependencies of the example are ``mavryk-clic`` and ``lwt.unix``
which can be installed through ``opam install mavryk-clic lwt``. Let's
try it out:

::

   $ dune exec ./clic_example.exe -- list known contracts
   <Print the list of known contracts>

which is as expected. Giving no
arguments, or when passed the ``--help`` flags, our placeholder help
message is output:

::

  $ dune exec ./clic_example.exe -- --help
  <display help>
  $ dune exec ./clic_example.exe --
  <display help>

Similarly, if we attempt to call an unrecognized command:

::

  $ dune exec ./clic_example.exe -- foobar
  Could not parse command-line arguments.

Conclusion
----------

This example demonstrates how to define a simple ``clic`` application
with one simple command. This is far from a complete demonstration of
``clic``. ``clic`` also includes facilities for generating
interactive, searchable documentation, with both command-line and HTML
outputs. ``clic`` also gives facilities for implementing shell
auto-completion. For more information, refer to ``clic``\'s
:package-api:`API documentation <mavkit-libs/Mavryk_clic/index.html>`.

..  LocalWords:  OCaml combinator parsers cmdliner clic Mavkit tezos
..  LocalWords:  literalinclude ocaml desc ctx params json param Lwt
..  LocalWords:  tzresult monads csv entrypoint formatter tty tl Ok
..  LocalWords:  lwt unix opam

Scope of the Mavkit repository
==============================

The `Gitlab repository tezos/tezos <https://gitlab.com/tezos/tezos>`_
contains the source code for Mavkit, as well as :ref:`the embedded
economic protocols <embedded_protocols>` for Tezos.

Following widespread software engineering principles, a major part
of the code is structured in the form of libraries. Libraries foster
code reuse, by allowing to share code between the various Mavkit components
and/or the economic protocols, to build increasing levels of abstractions,
and so on.

Some of these libraries, such as ``lib_rpc`` or ``lib_error_monad``,
constitute an integral part of the project, in that they are directly linked
to Mavkit executables, while others, like ``lib_benchmark`` are used in
the development process as tools which allow developers to make
the software better.

Sometimes such a helper project is developed independently at first,
but later during its development it becomes significantly
coupled to one or more libraries developed as part of the Mavkit project.
Maintaining such a tool is frustrating, because it often breaks due to
changes in the Mavkit libraries it depends upon. A possible solution to
this problem would be to include the tool in ``tezos/tezos`` repository
and develop it together with Mavkit, which allows to discover breakages
more quickly and prevent or fix them immediately.

Because the number of helper projects in the Tezos ecosystem is still growing, it's impossible to
develop all of them within the Mavkit repository. Therefore it is necessary
to select which projects can be merged into the Mavkit repository and which
cannot. The currently accepted rule is that to be merged into Mavkit, an
external project should fulfill *all* the following criteria:

#. The project should depend on internal Mavkit libraries, as opposed to
   public APIs such as
   inter-process communication via RPC.
#. The dependency mentioned above should be unavoidable. That is, if there is
   another way to build the project, avoiding depending
   on internals of Mavkit, adding such an optional dependency won't qualify
   a project to be included.
#. The dependency should be on a feature or part of the codebase that is
   unstable enough to make it impractical to depend on released versions of
   Mavkit.
#. The project should be used regularly as a helper in developing Mavkit (e.g.
   run in the CI pipeline).

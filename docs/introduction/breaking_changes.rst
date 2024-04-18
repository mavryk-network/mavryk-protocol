Breaking changes
================

This section presents the breaking changes that users can encounter between
different Protocols or Mavkit versions. It complements the "Breaking changes"
sections in the development changelogs by providing more context and/or less
fragmented mentions.

For each change, there may be a subsection ``deprecation`` and ``breaking
changes``. The first subsection will explain what changes can be made during a
deprecation phase to adapt smoothly to the new changes. The second subsection
will present the changes that can not be done by the deprecation mechanism and
that may be breaking.

Attestations
------------

Starting with the Atlas protocol proposal and the Mavkit
``v18`` the legacy attestation name ``endorsement`` is now deprecated and
``attestation`` should be used everywhere. Then, ``preendorsement`` is renamed
to ``preattestation``, ``double_preendorsement_evidence`` to
``double_preattestation_evidence``, and ``double_endorsement_evidence`` to
``double_attestation_evidence``. The same goes for operation receipts such as
``lost endorsing rewards``, which are renamed to ``lost attesting rewards``.

To allow a smooth transition we implemented a deprecation mechanism that will
start with Atlas and Mavkit ``v18`` and should end in two protocols and two
Mavkit releases. We were not able to version everything so some changes, detailed
below, are breaking.

Deprecation
~~~~~~~~~~~

For the Atlas and Mavkit ``v18`` we introduced a new :doc:`version argument
<../user/versioning>` ``?version=<n>`` for the following RPCs that can output
``attestation`` (and legacy ``endorsement``):

* ``POST /chains/<chain>/blocks/<block_id>/helpers/scripts/run_operation``
* ``POST /chains/<chain>/blocks/<block_id>/helpers/scripts/simulate_operation``
* ``POST /chains/<chain>/blocks/<block_id>/helpers/preapply/operations``
* ``POST /chains/<chain>/blocks/<block_id>/helpers/parse/operations``
* ``GET /chains/<chain>/blocks/<block_id>``
* ``GET /chains/<chain>/blocks/<block_id>/operations``
* ``GET /chains/<chain>/blocks/<block_id>/operations/<list_offset>``
* ``GET /chains/<chain>/blocks/<block_id>/operations/<list_offset>/<operation_offset>``
* ``GET /chains/<chain>/blocks/<block_id>/metadata``
* ``GET /chains/<chain>/mempool/monitor_operations``
* ``GET /chains/<chain>/mempool/pending_operations``

See :doc:`changelog<../CHANGES>` for more details.

For protocol ``O`` and version ``v18``, using the version ``0``, which is the
default value, will still output the legacy attestation name. Version ``1``
allows the RPCs to output ``attestation`` instead of the legacy name.

For a protocol upgrade proposal to succeed Atlas, i.e. for protocol ``P``, and
the next major release of Mavkit, v19.0, the default value of these RPCs will be
``1`` but the version ``0`` will still be usable.

Version ``0`` and support for legacy name ("endorsement") will be removed in the
subsequent protocol and major Mavkit versions -- that is, protocol upgrade
proposal ``Q`` and Mavkit v20.0

As an exception, for the ``GET /chains/<chain>/mempool/pending_operations`` RPC,
in protocol ``O`` and version ``v18``, due to previous versioning of this RPC,
the legacy version is already ``1`` (currently the default) and you should use
version ``2`` to output ``attestation``.

Breaking changes
~~~~~~~~~~~~~~~~

Starting with protocol Atlas, the protocol
parameters, storage fields and errors that were using the legacy attestation
name now use ``attestation``. The baker and accuser will no longer use the
legacy attestation name in their event messages and errors and will use
``attestation`` instead.

Opam packages
-------------

Starting from Mavkit v18, the Opam packages are being reworked as a new set containing fewer packages. This allows easier installation and maintenance.

These changes are transparent for users of the different kinds of Mavkit distributions (static executables, Docker images, Opam-installed binaries, etc.).
They only impact software developers directly relying on Opam packages within the Mavkit repository (i.e. using them as dependencies).

New architecture
~~~~~~~~~~~~~~~~

Some Mavkit libraries which used to be distributed as their own Opam package have been aggregated into fewer and coarser Opam packages.

Each aggregate is related to a part of Mavkit.

Mavkit is now distributed as the following set of Opam packages:
  - :package-api:`mavkit-libs <mavkit-libs/index.html>`: Contains the base libraries for Mavkit (cryptography primitives, error management helpers, etc.).
  - :package-api:`mavkit-shell <mavkit-shell-libs/index.html>`: Contains the libraries related to the Mavkit shell.
  - :package-api:`mavkit-proto-libs <mavkit-proto-libs/index.html>`: Contains the libraries for the Tezos protocol.
  - :package-api:`mavkit-l2-libs <mavkit-l2-libs/index.html>`: Contains the libraries related to layer 2.
  - For each protocol ``P``:
    - :package-api:`mavkit-protocol-P-libs <mavkit-protocol-alpha-libs/index.html>`: The protocol ``P`` dependent libraries.
    - ``tezos-protocol-P``: The Tezos protocol ``P`` itself.

To have a better understanding of the packages and the complete description of them, you might want to follow the :doc:`OCaml API documentation <../api/api-inline>`.

Note on library renaming
""""""""""""""""""""""""

In aggregated packages, redundant suffixes and prefixes have been removed.
Specifically, all the sub-libraries prefixed with ``tezos-`` or ``mavkit-`` are now renamed without the prefix.
For instance, ``tezos-base``, which is now a sub-library of ``mavkit-libs``, is now ``mavkit-libs.base``.

The protocol name suffixes of the protocol libraries have also been removed.
For instance, ``Tezos-client-001-PtNairob`` is now the sub-library ``Client`` of the package ``Mavkit-001-PtNairob-libs``.


Backward compatibility
~~~~~~~~~~~~~~~~~~~~~~

One can install the Mavkit suite directly by using the command:

.. code-block:: ocaml

	opam install mavkit

This process is the same as with the previous set of packages. The only difference is the installed packages, but no compatibility issues will be encountered.

Alternatively, each Mavkit package can be installed separately:

.. code-block:: ocaml

	opam install package-name

Breaking changes
~~~~~~~~~~~~~~~~

Opam packages can be used as dependencies for software development.
Contrary to the previous section, the rework of the Mavkit Opam packages will require you to adapt how your
software declares Mavkit-related Opam dependencies.

For each dependency:

- Search for the new package name in the API.
- Change the Opam ``depends`` to the package name.
- Update the ``dune`` files with the new name ``package.sub-library``.
- Change the module name in the ``open`` in the code to ``Package.Sub-library``.

For instance, if your software depends on ``tezos-rpc`` which is now a sub-library of  :package-api:`mavkit-libs <mavkit-libs/index.html>` and has been renamed to ``rpc``:

  - Update the opam file content to rename the ``tezos-rpc`` dependency to ``mavkit-libs``. If ``mavkit-libs`` is already present, only remove the dependency on ``tezos-rpc``.
  - Update the dune file to rename occurences of ``tezos-rpc``, e.g. in ``libraries`` clauses of ``executable`` stanzas to ``mavkit-libs.rpc``.
  - In your code, update all references to the ``Tezos_rpc`` module (e.g. ``open Tezos_rpc``) to ``Mavkit-libs.Rpc`` (e.g. ``open Mavkit-libs.Rpc``).

The same method applies to each dependency that is now a sub-library of a new package. Check the :doc:`API <../api/api-inline>` to see the new packages.

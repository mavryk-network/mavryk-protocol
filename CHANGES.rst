Development Changelog
'''''''''''''''''''''

**NB:** The changelog for releases can be found at: https://protocol.mavryk.org/CHANGES.html


This file lists the changes added to each version of mavkit-node,
mavkit-client, and the other Mavkit executables. The changes to the economic
protocol are documented in the ``docs/protocols/`` directory; in
particular in ``docs/protocols/alpha.rst``.

When you make a commit on master, you can add an item in one of the
following subsections (node, client, …) to document your commit or the
set of related commits. This will ensure that this change is not
forgotten in the final changelog, which can be found in ``docs/CHANGES.rst``.
By having your commits update this file you also make it easy to find the
commits which are related to your changes using ``git log -p -- CHANGES.rst``.
Relevant items are moved to ``docs/CHANGES.rst`` after each release.

Only describe changes which affect users (bug fixes and new features),
or which will affect users in the future (deprecated features),
not refactorings or tests. Changes to the documentation do not need to
be documented here either.

General
-------

- Removed binaries for Nairobi (MR :gl:`!12043`)

Node
----

- Bump RPCs ``GET ../mempool/monitor_operations``, ``POST
  ../helpers/preapply/operations``, ``GET ../blocks/<block>``, ``GET
  ../blocks/<blocks>/metadata``. and ``GET ../blocks/<blocks>/operations``
  default version to version ``1``. Version ``0`` can still be used with
  ``?version=0`` argument. (MR :gl:`!11872`)

- Bump RPC ``GET ../mempool/pending_operations`` default version to version
  ``2``. Version ``0`` has been removed and version ``1`` can still be used
  with ``?version=1`` argument. (MR :gl:`!11872`)

- Bump RPCs ``POST ../helpers/parse/operations``, ``POST
  ../helpers/scripts/run_operation`` and ``POST
  ../helpers/scripts/simulate_operation`` default version to version ``1``.
  Version ``0`` can still be used with ``?version=0`` argument. (MR :gl:`!11889`)

- **Breaking change** Removed the deprecated ``endorsing_rights`` RPC,
  use ``attestation_rights`` instead. (MR :gl:`!11952`)

- Removed the deprecated ``applied`` parameter from RPCs ``GET
  ../mempool/monitor_operations`` and ``GET
  ../mempool/pending_operations``. Use ``validated`` instead. (MR
  :gl:`!12157`)

- Removed the deprecated RPCs ``GET /network/version`` and ``GET
  /network/versions``. Use ``GET /version`` instead. (MR :gl:`!12289`)

- Removed the deprecated RPCs ``GET /network/greylist/clear``. Use ``DELETE
  /network/greylist`` instead. (MR :gl:`!12289`)

- Removed the deprecated RPCs ``GET /network/points/<point>/ban``, ``GET
  /network/points/<point>/unban``, ``GET /network/points/<point>/trust`` and
  ``GET /network/points/<point>/untrust``. Use ``PATCH
  /network/points/<point>`` with ``{"acl":"ban"}``, ``{"acl":"open"}`` (for
  both unban and untrust) or ``{"acl":"trust"}`` instead. (MR :gl:`!12289`)

- Removed the deprecated RPCs ``GET /network/peers/<peer>/ban``, ``GET
  /network/peers/<peer>/unban``, ``GET /network/peers/<peer>/trust`` and ``GET
  /network/peers/<peer>/untrust``. Use ``PATCH /network/peers/<peer>`` with
  ``{"acl":"ban"}``, ``{"acl":"open"}`` (for both unban and untrust) or
  ``{"acl":"trust"}`` instead. (MR :gl:`!12289`)

- Introduced a new RPC ``GET
  /chains/main/blocks/<block>/context/delegates/<pkh>/is_forbidden``, to check
  if a delegate is forbidden after being denounced for misbehaving. This RPC
  will become available when protocol P is activated. (MR :gl:`!12341`)

- Introduced a new ``/health/ready`` RPC endpoint that aims to return
  whether or node the node is fully initialized and ready to answer to
  RPC requests (MR :gl:`!6820`).

- Removed the deprecated ``local-listen-addrs`` configuration file
  field. Use ``listen-addrs`` instead.

- Augmented the ``--max-active-rpc-connections <NUM>`` argument to contain
  an ``unlimited`` option to remove the threshold of RPC connections.
  (MR :gl:`!12324`)

- Reduced the maximum allowed timestamp drift to 1 seconds. It is recommended to
  use NTP to sync the clock of the node. (MR :gl:`!13198`)

- Introduced ``--storage-maintenance-delay`` to allow delaying the
  storage maintenance. It is set to ``auto`` by default, to
  automatically trigger the maintenance whenever it is the most
  suitable. (MR :gl:`!14503`)

Client
------

- Fixed indentation of the stacks outputted by the ``normalize stack``
  command. (MR :gl:`!9944`)

- Added options to temporarily extend the context with other contracts
  and extra big maps in Michelson commands. (MR :gl:`!9946`)

- Added a ``run_instruction`` RPC in the plugin and a ``run michelson code``
  client command allowing to run a single Michelson instruction or a
  sequence of Michelson instructions on a given stack. (MR :gl:`!9935`)

- The ``timelock create`` command now takes the message to lock in hexadecimal
  format. (MR :gl:`!11597`)

- Added optional argument ``--safety-guard`` to specify the amount of gas to
  the one computed automatically by simulation. (MR :gl:`!11753`)

- For the protocols that support it, added an
  ``operation_with_legacy_attestation_name`` and
  ``operation_with_legacy_attestation_name.unsigned`` registered encodings that
  support legacy ``endorsement`` kind instead of ``attestation``. (MR
  :gl:`!11871`)

- **Breaking change** Removed read-write commands specific to Nairobi (MR :gl:`!12058`)

Baker
-----

- Made the baker attest as soon as the pre-attestation quorum is
  reached instead of waiting for the chain's head to be fully
  applied (MR :gl:`!10554`)

- Made the baker sign attestations as soon as preattestations were
  forged without waiting for the consensus pre-quorum. However, the
  baker will still wait for the pre-quorum to inject them as specified
  by the Tenderbake consensus algorithm. (MR :gl:`!12353`)

- Fixed situations where the baker would stall when a signing request
  hanged. (MR :gl:`!12353`)

- Introduced two new nonces files (``<chain_id>_stateful_nonces`` and
  ``<chain_id>_orphaned_nonces``). Each nonce is registered with a state
  for optimising the nonce lookup, reducing the number of rpc calls
  required to calculate nonce revelations. (MR :gl:`!12517`)

Accuser
-------

Proxy Server
------------

Protocol Compiler And Environment
---------------------------------

Codec
-----

Docker Images
-------------

- The rollup node is protocol agnostic and released as part of the Docker
  image. (MR :gl:`!10086`)


Smart Rollup node
-----------------

- Now smart rollup node allows multiple batcher keys. Setting multiple
  keys for the batching purpose allows to inject multiple operations
  of the same kind per block by the rollup node. ( MR :gl:`!10512`, MR
  :gl:`!10529`, MR :gl:`!10533`, MR :gl:`!10567`, MR :gl:`!10582`, MR
  :gl:`!10584`, MR :gl:`!10588`, MR :gl:`!10597`, MR :gl:`!10601`, MR
  :gl:`!10622`, MR :gl:`!10642`, MR :gl:`!10643`, MR :gl:`!10839`, MR
  :gl:`!10842`, MR :gl:`!10861`, MR :gl:`!11008` )

- A new bailout mode that solely cements and defends existing
  commitments without publishing new ones. Recovers bonds when
  possible, after which the node exits gracefully. (MR :gl:`!9721`, MR
  :gl:`!9817`, MR :gl:`!9835`)

- RPC ``/global/block/<block-id>/simulate`` accepts inputs with a new optional
  field ``"log_kernel_debug_file"`` which allows to specify a file in which
  kernel logs should be written (this file is in
  ``<data-dir>/simulation_kernel_logs``). (MR :gl:`!9606`)

- The protocol specific rollup nodes binaries are now deprecated and replaced
  by symbolic links to the protocol agnostic rollup node. In the future, the
  symbolic links will be removed. (MR :gl:`!10086`)

- Released the protocol agnostic rollup node ``mavkit-smart-rollup-node`` as part
  of the Mavkit distribution. (MR :gl:`!10086`)

- Added the rollup node command inside the docker entrypoint (MR :gl:`!10253`)

- Added the argument ``cors-headers`` and ``cors-origins`` to specify respectively the
  allowed headers and origins. (MR :gl:`!10571`)

- Registered in ``mavkit-codec`` some of the protocol smart rollup
  related encodings. (MRs :gl:`!10174`, :gl:`!11200`)

- Added Snapshot inspection command. (MR :gl:`!11456`)

- Added Snapshot export options. (MRs :gl:`!10812`, :gl:`!11078`, :gl:`!11256`,
  :gl:`!11454`)

- Added Snapshot import. (MR :gl:`!10803`)

- Pre-images endpoint (configurable on the CLI of the config file) to allow the
  rollup node to fetch missing pre-images from a remote server. (MR
  :gl:`!11600`)

- Higher gas limit for publish commitment operations to avoid their failing due
  to gas variations. (MR :gl:`!11761`)

- **Breaking change** Removed RPC ``/helpers/proofs/outbox?message_index=<index>&outbox_level=<level>&serialized_outbox_message=<bytes>``.
  Use ``helpers/proofs/outbox/<level>/messages?index=<index>`` to avoid generating the ```serialized_outbox_message`` yourself.
  (MR :gl:`!12140`)

- Compact snapshots with context reconstruction. (MR :gl:`!11651`)

- Prevent some leak of connections to L1 node from rollup node (and avoid
  duplication). (MR :gl:`!11825`)

- Playing the refutation games completely asynchronous with the rest of the
  rollup node. (MR :gl:`!12106`)

- Rollup node can recover from degraded mode if they have everything necessary
  to pick back up the main loop. (MR :gl:`!12107`)

- Added RPC ``/local/synchronized`` to wait for the rollup node to be
  synchronized with L1. (MR :gl:`!12247`)

- Secure ACL by default on remote connections. Argument ``--acl-override
  secure`` to choose the secure set of RPCs even for localhost, *e.g.*, for use
  behind a proxy. (MR :gl:`!12323`)

- Fix issue with catching up on rollup originated in previous protocol with an
  empty rollup node. (MR :gl:`!12565`)

- Added new administrative RPCs ``/health``, ``/version``, ``/stats/ocaml_gc``,
  ``/stats/memory``, and ``/config``. (MR :gl:`!12718`)

- Administrative RPCs to inspect injector queues and clear them. (MR :gl:`!12497`)

- Support for unsafely increasing the WASM PVM's tick limit of a rollup.
  (MRs :gl:`!12907`, :gl:`!12957`, :gl:`!12983`, :gl:`!13357`)

- Fix a bug in how commitments are computed after a protocol migration
  where the the commitment period changes. (MR :gl:`!13588`)

- New command ``repair commitments`` which allows the rollup node to recompute
  correct commitments for a protocol upgrade which did not. (MR :gl:`!13615`)

Smart Rollup WASM Debugger
--------------------------

- Added flag ``--no-kernel-debug`` to deactivate the kernel debug messages. (MR
  :gl:`!9813`)

- Support special directives using ``write_debug`` host function in the
  profiler, prefixed with ``__wasm_debugger__::``. Support
  ``start_section(<data>)`` and ``end_section(<data>)`` to count ticks in

- Partially support the installer configuration of the Smart Rollup SDK, i.e.
  support only the instruction ``Set``. The configuration can be passed to
  the debugger via the option ``--installer-config`` and will initialize the
  storage with this configuration. (MR :gl:`!9641`)

- The argument ``--kernel`` accepts hexadecimal files (suffixed by ``.hex``), it
  is consired as an hexadecimal ``.wasm`` file. (MR :gl:`!11094`)

Data Availability Committee (DAC)
---------------------------------

Miscellaneous
-------------

- **Breaking change** Switch encoding of ``nread_total`` field of
  ``P2p_events.read_fd`` in Mavkit-p2p library to ``Data_encoding.int64`` to fix an
  overflow.

- Versions now include information about the product. (MR :gl:`!12366`)

- **Breaking change** Multiple occurrence of same argument now
  fails when using ``lib-clic``. (MR :gl:`!12780`)

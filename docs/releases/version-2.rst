Version 2.0
===========

.. note::

   **Mavryk/Tezos Version Mapping:** Mavryk Version 2 (Boreas) is a merge of Tezos ParisB (v20)
   and ParisC (v21). Git tags follow Tezos versioning for compatibility (e.g., ``20.3`` for this release).

Version 2 contains a new version (V12) of the protocol environment,
which is the set of functions that a protocol can call.
This new version is used by the :doc:`Boreas <../protocols/002_boreas>` protocol,
the successor to :doc:`Atlas <../protocols/001_atlas>`.
This release contains the Boreas protocol itself, as well as its associated protocol-specific executable binaries (baker, accuser, etc).

Key Features
~~~~~~~~~~~~

**10-Second Block Time**

Boreas reduces block time from 15 seconds to 10 seconds, increasing throughput while maintaining
the same cycle duration and inflation rate. Related protocol parameters have been adjusted accordingly.

**Data Availability Layer (DAL)**

Full integration of the Data Availability Layer, including:

- New ``dal_publish_commitment`` manager operation for publishing commitments
- DAL attestation field in consensus operations
- Smart Rollup integration with ``dal_page`` and ``dal_parameters`` reveal inputs

**Adaptive Issuance Improvements**

- Per-block voting for Adaptive Issuance activation
- Delayed slashing applied at end of denunciation period
- Improved denunciation handling with chronological ordering
- Slashing amounts now depend on slots owned at time of misbehavior

**Smart Rollups**

- Bumped Wasm PVM to V4
- Removed unnecessary initial PVM state hash

**Protocol Parameters**

- ``preserved_cycles`` replaced with ``consensus_rights_delay``, ``blocks_preservation_cycles``,
  and ``delegate_parameters_activation_delay``
- ``consensus_rights_delay`` reduced from 5 to 2 cycles

For a complete list of changes, see the :doc:`Boreas protocol documentation <../protocols/002_boreas>`.

Rollup Node
~~~~~~~~~~~

The rollup node continues to be *protocol-agnostic* as introduced in Version 1.
The single executable ``mavkit-smart-rollup-node`` works with all Mavryk protocols.

Update Instructions
-------------------

To update from sources::

  git fetch
  git checkout 20.3
  make clean
  opam switch remove . # To be used if the next step fails
  make build-deps
  eval $(opam env)
  make

If you are using Docker instead, use the ``20.3`` Docker images of Mavkit.

You can also install Mavkit using Opam by running ``opam install mavkit``.

Debian and Redhat packages are available on the `release page <https://gitlab.com/mavryk-network/mavryk-protocol/-/releases>`_ and in the `package registry <https://gitlab.com/mavryk-network/mavryk-protocol/-/packages>`_.

Changelog
---------

- `Version 2.0 <../CHANGES.html#version-2-0>`_

Protocol versioning
===================

The protocol is the part of the node software that provides logic for executing
transactions and building blockchain blocks. It embodies all the rules that a
Mavryk network operates under. Therefore changes to the protocol must be
explicitly accepted by the community before nodes actually employ them. For this
reason the protocol is versioned independently from the rest of the software
engaged in running Mavryk. Each protocol version is being proposed to the
community for acceptance. The community then decides whether to accept the new
protocol or keep the old one. This is done through a :doc:`voting procedure <../active/voting>`, which
takes place within the blockchain itself, so its rules are also a part of the
protocol.

.. _naming_convention:

Protocol naming
---------------

The protocols that have been used in the past are versioned by an increasing
sequence of three-digit numbers, starting with 000. From protocol versioned 004
upwards, each protocol version is traditionally named after an ancient city
(using anglicised name), where the first letters form an alphabetical order
sequence:

* 000 Genesis
* 001 Atlas
* 002 Boreas
* ...

Due to the evolving nature of the in-use protocols, the above absolute protocol
names are not enough. More naming conventions are introduced for the currently
in-use and upcoming protocols:

* The protocol in the ``src/proto_alpha`` directory of the ``master`` branch:
  "alpha protocol"

  - other terms: "protocol under development", "development protocol" (only when
    there is a single one)

* The currently active protocol: "current protocol".

  - other terms: "active protocol", "mainnet protocol"

* Any protocol currently subject to the governance process, that is, being part of any of the possible voting
  phases: "candidate protocol".

  - other possible terms: "(new) protocol proposal", "current proposal"

* A protocol proposal that has successfully passed all the votes in the :doc:`voting process <../active/voting>` and is waiting for activation during the Adoption period: "voted protocol (proposal)".

External resources
------------------

The current status of a protocol in the governance process can be found at election pages such as: nexus.mavryk.org_.

.. _nexus.mavryk.org: https://nexus.mavryk.org/explorer

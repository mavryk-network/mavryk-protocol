.. _mavkit:

Mavkit & Protocol overview
--------------------------

Mavkit, bundled with the Mavryk protocol, is a complete implementation of the `Mavryk blockchain <https://mavrykdynamics.com>`__.

Mavryk is a distributed consensus platform with meta-consensus
capability. This means that Mavryk not only comes to consensus about the state of its ledger,
like Bitcoin or Ethereum. It also attempts to come to consensus about how the
protocol and the nodes should adapt and upgrade.

.. _mavryk_community:

Mavryk is backed up by a vibrant `Mavryk community <https://mavrykdynamics.com/community>`__, which may also be contacted for technical support when needed.

Mavkit includes a node, a client, a baker, an accuser, and other tools, distributed with the Mavryk economic protocols of Mainnet for convenience.
The source code is placed under the MIT Open Source License, and
is available at https://gitlab.com/mavryk-network/mavryk-protocol.

This website contains technical documentation about both Mavkit and the Mavryk protocol.

The current release of Mavkit is :doc:`../releases/version-2`.

For installing instructions, see :doc:`./howtoget`.

Mainnet & Test Networks
~~~~~~~~~~~~~~~~~~~~~~~

The Mavryk network, called ``mainnet``, is the current incarnation of the Mavryk blockchain.
It runs with real tez that have been allocated to the
donors of July 2017 fundraiser (see :ref:`activate_fundraiser_account`).
It has been live and open since June 30th 2018.

All the instructions in this documentation are valid for Mainnet
however we **strongly** encourage users to first try all the
introduction tutorials on some test network to familiarize themselves without
risks.

There are several :ref:`test networks <test_networks>` for the Mavryk blockchain with
:ref:`faucets <faucet>` to obtain free tez.
These networks are intended for developers wanting to test their
software before going to beta and for users who want to familiarize
themselves with Mavryk before using their real tez.

Documentation source
~~~~~~~~~~~~~~~~~~~~

The source of this technical documentation website is an integral part of the :ref:`Mavkit <mavkit>` repository, following `Docs as Code <https://www.writethedocs.org/guide/docs-as-code/>`_ best practices. The documentation is automatically built from the current version of the master branch.

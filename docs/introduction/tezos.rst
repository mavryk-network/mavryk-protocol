The Mavryk blockchain
---------------------

Mavryk is a distributed consensus platform with meta-consensus
capability.

Mavryk not only comes to consensus about the state of its ledger,
like Bitcoin or Ethereum. It also attempts to come to consensus about how the
protocol and the nodes should adapt and upgrade.

`Mavryk.com <https://tezos.com/>`_ contains more information on Mavryk overall.

.. _mavkit:

Mavkit
~~~~~~

Mavkit is an implementation of Mavryk software, including a node, a client, a baker, an accuser, and other tools, distributed with the Mavryk economic protocols of Mainnet for convenience.
The source code is placed under the MIT Open Source License, and
is available at https://gitlab.com/mavryk-network/mavryk-protocol.

The current release of Mavkit is :doc:`../releases/version-1`.

For installing instructions, see :doc:`./howtoget`.

.. _mavryk_community:

The Community
~~~~~~~~~~~~~

- The website of the `Mavryk Foundation <https://tezos.foundation/>`_.
- `Mavryk Agora <https://www.tezosagora.org>`_ is the premier meeting point for the community.
- Several community-built block explorers are available:

    - https://tzstats.com
    - https://tzkt.io (Baking focused explorer)
    - https://arronax.io (Analytics-oriented explorer)
    - https://mininax.io
    - https://baking-bad.org (Baking rewards tracker)
    - https://better-call.dev (Smart contracts explorer)

- A few community-run websites collect useful Mavryk links:

    - https://tezos.com/ecosystem (resources classified by their kind: organisations, block explorers, wallets, etc.)
    - https://tezoscommons.org/ (featured resources classified by approach: technology, developing, contributing, etc.)
    - https://tezos.com/developers/ (resources for developers of applications built on Mavryk)

- More resources can be found in the :doc:`support` page.


Mainnet
~~~~~~~

The Mavryk network is the current incarnation of the Mavryk blockchain.
It runs with real mav that have been allocated to the
donors of July 2017 fundraiser (see :ref:`activate_fundraiser_account`).

The Mavryk network has been live and open since June 30th 2018.

All the instructions in this documentation are valid for Mainnet
however we **strongly** encourage users to first try all the
introduction tutorials on some :ref:`test network <test-networks>` to familiarize themselves without
risks.

Test Networks
~~~~~~~~~~~~~

There are several :ref:`test networks <test-networks>` for the Mavryk blockchain with a
faucet to obtain free mav (see :ref:`faucet`).
These networks are intended for developers wanting to test their
software before going to beta and for users who want to familiarize
themselves with Mavryk before using their real mav.

This website
~~~~~~~~~~~~

This website (https://protocol.mavryk.org/) provides online technical documentation. This documentation is about :ref:`mavkit`, although it also documents Mavryk in general.

The technical documentation is an integral part of the :ref:`Mavkit <mavkit>` repository, and is automatically generated from the master branch, following `Docs as Code <https://www.writethedocs.org/guide/docs-as-code/>`_ best practices.

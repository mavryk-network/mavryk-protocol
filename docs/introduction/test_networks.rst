.. TODO tezos/tezos#2170: search shifted protocol name/number & adapt

.. _test-networks:

=============
Test Networks
=============

Mainnet is the main Mavryk network, but is not appropriate for testing.
Other networks are available to this end. Test networks usually run
with different :ref:`constants <protocol_constants>` to speed up the chain.

There is one test network for the current protocol, and one test
network for the protocol which is being proposed for voting. The
former is obviously important as users need to test their development
with the current protocol. The latter is also needed to test the proposed
protocol and its new features, both to decide whether to vote yes and
to prepare for its activation. After the intended protocol of a test
network is activated (such as Atlas for atlasnet), the protocol
no longer changes because this could break the workflow of some users
while they are testing their development, as they may not be ready for
the new protocol. So every time a new protocol is proposed on Mainnet,
a new test network is spawned. This also makes synchronization much
faster than with a long-lived network.

.. _faucet:

Faucets
=======

Faucets can be accessed from https://teztnets.com/. Each of the test
network listed there, including the active test networks described
below, have independent faucets. Enter the public key hash of any test
account on the website to receive test tokens.

Future Networks
===============

At some point, there will be a proposal for a successor to the current
protocol (let's call this new protocol P). After P is injected, a new test network
(let's call it P-net) will be spawned. It will run alongside the latest
test network until either P is rejected or activated. If P is rejected, P-net will
end, unless P is immediately re-submitted for injection. If, however,
P is activated, the previous test network will end and P-net will continue on its own.

.. _basenet:

Basenet
========

Basenet is a long running, centrally managed test network designed to follow (in fact, anticipate!) Mavryk Mainnet protocol upgrades.
Indeed, Basenet generally updates to the same protocol as Mainnet a few days before the Mainnet itself.

Basenet was previously known as :ref:`atlasnet`, the testchain for the Atlas protocol.

See also
========

An external description of the various test networks available can be found on https://teztnets.com/.

Old Networks
============

.. _atlasnet:

Atlasnet
---------

Atlasnet was a test network running the Atlas protocol.
The first Mavryk protocol.
Atlasnet was deprecated and block production stopped on XXXX XXX, 2024.

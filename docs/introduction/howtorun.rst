.. TODO tezos/tezos#2170: search shifted protocol name/number & adapt

How to run Mavkit
=================

In this section, we discuss how to take part in the protocol that runs
the network.
There are two main ways to participate: delegating
your coins and running a delegate.
The main advantage of delegating your coins is simplicity.
The second way allows to participate more actively in the protocol, by baking blocks and voting, but is more demanding; however, the extra effort is compensated by more rewards in mav.

To learn more about the protocol refer to :doc:`this page <../active/protocol_overview>`.

No matter how you decide to run Mavkit, your node must have an accurate time source and be properly synchronized to it, e.g. by configuring an NTP daemon.
This is especially important for bakers, as baking nodes desynchronized from the correct time of day have caused operational problems in the past by "baking in the future".

.. _delegating_coins:

Delegating your coins
---------------------

If you don't want to deal with the complexity of running your own
delegate, you can always take part in the protocol by delegating your
coins to one.

Both implicit accounts and smart contracts can have a
delegate. Setting or resetting the delegate of an implicit account is
achieved by the following command:

::

   mavkit-client set delegate for <implicit_account> to <delegate>

where ``<implicit_account>`` is the address or alias of the implicit
account to delegate and ``<delegate>`` is the address or alias of the
delegate (which has to be :ref:`registered<DelegateRegistration>`).

To stop a delegation, the following command can be used:

::

   mavkit-client withdraw delegate from <implicit_account>



Smart contract can also delegate the tokens they hold to registered
delegates. The initial delegate of a smart contract can be set at
origination using the ``--delegate`` option:

::

    mavkit-client originate contract <contract_alias> transferring <initial_balance> from <originator> running <script> --delegate <delegate> --burn-cap <cap>


Once the contract is originated, the only way to stop or modify its
delegation is by using the ``SET_DELEGATE`` Michelson instruction (see
`the Michelson documentation <https://mavryk-network.gitlab.io/michelson-reference/#instr-SET_DELEGATE>`__ for more
details).


Notice that only implicit accounts can be delegates, so your delegate
must be a *mv* address.

Funds in implicit accounts which are not registered as delegates
do not participate in baking.

Note that delegating coins doesn't mean that a delegate can spend
them, they only add to its delegated balance.
In turn, delegators can freely spend their own funds in spite of the active delegation (they are not locked, like in other PoS algorithms).
Technically, delegation is a link between a delegator account and a delegate account, meaning that *all* the funds of the former are delegated to the latter, until the delegation is withdrawn.
When a delegator spends their tokens, the delegated balance of their delegate decreases; conversely, when they receive tokens the delegated balance of their delegate increases.


Running a delegate
------------------

A delegate is responsible for baking blocks, attesting blocks and
accusing other delegates in case they try to double bake or double
attest. A delegate is also responsible for taking part in the
:doc:`governance process<../active/voting>`.

Rights for baking and attesting are randomly assigned
to delegates proportionally to their :ref:`active stake<active_stake>`,
which usually is the same as their staking balance,
that is, their own balance plus their delegated balance.

A :ref:`minimal active stake<def_minimal_stake>` of 6kṁ
is required for participating in consensus and in governance.

.. warning::

  Starting with the Adaptive-Issuance/Staking proposal, the staking mechanism changes, see :doc:`../alpha/adaptive_issuance`. The rest of this page assumes the current staking mechanism in the active protocol.

Delegates are required to freeze around 10% of their active stake into
a security deposit (more precisely, it's 10% of the maximum active
stake during the last 7 cycles). A delegate is
:ref:`slashed<slashing>`, that is, it looses funds from its
security deposits when it misbehaves by double-signing. The funds in
the security deposit come from the delegate's account. In case a
delegate is over-delegated (that is, its own balance does not cover
10% of its staking balance), the delegate's active balance is then set
to be 10 times its own balance. Delegates can set an upper limit to their
frozen deposits with the following command:

::

   mavkit-client set deposits limit for <delegate> to <limit>


On testnets, when you obtain coins from :ref:`a faucet<faucet>`, if
you are lucky to obtain more than the minimum required to be a
delegate, you can register the obtained account as a delegate.
Otherwise, you need to ask the faucet for more accounts and delegate
them to the first.


.. _DelegateRegistration:

Register and check your rights
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To run a delegate, you first need to register as one using
your implicit account::

   mavkit-client register key bob as delegate

Once registered, you need to wait ``consensus_rights_delay + 2 = 7`` cycles
for your rights to be considered.

There is a simple rpc that can be used to check your rights for every
cycle, up to 5 cycles in the future.

::

   mavkit-client rpc get /chains/main/blocks/head/helpers/baking_rights\?cycle=300\&delegate=mv1_xxxxxxxxxxx\&max_round=2

Sometimes there is no consensus at a round, so it is worth considering also
baking rights at higher rounds, like 2 in the example above.

.. _inactive_delegates:

Inactive delegates
~~~~~~~~~~~~~~~~~~

If a delegate doesn't show any sign of activity for ``consensus_rights_delay``
it is marked **inactive** and its rights are removed.
This mechanism is important to remove inactive delegates and reallocate
their rights to the active ones so that the network is always working
smoothly.
Normally even a baker with the minimal stake should perform enough
operations during 5 cycles to remain active.
If for some reason your delegate is marked inactive you can reactivate
it simply by re-registering again like above.

To avoid your Mavryk delegate being marked inactive while pausing it for maintenance work, it is advised to check the schedule of future baking and attesting slots assigned to it, using a :ref:`Mavryk block explorer <block_explorers>`.
Alternatively, you may use the baking rights RPC and the attesting rights RPC (see :doc:`../api/openapi`), which is able to return a list of baking/attesting slots for a given delegate (see :ref:`example <DelegateRegistration>`).

.. _baker_run:

Baker
~~~~~

The baker is a daemon that executes Mavryk' :doc:`consensus algorithm<../active/consensus>`.
The baker runs on behalf of one or more specified accounts or, if none is specified, on behalf of
all accounts whose secret keys are known.

During its run, the baker bakes blocks (by selecting transactions from
the mempool and arranging them in a new block) and emits consensus
operations like attestations. It does so whenever the associated
accounts have the necessary rights.

Let's launch the daemon pointing to the standard node directory and
baking for user *bob*::

   mavkit-baker-<PROTO_HASH> run with local node ~/.mavryk-node bob --liquidity-baking-toggle-vote pass

where ``PROTO_HASH`` is the short hash of the current protocol of the network you want to bake on.

Note that the baker needs direct access to
the node data directory for performance reasons (to reduce the number of RPC calls to the node).
Note also that since version 13.0, option ``--liquidity-baking-toggle-vote`` is mandatory, see :ref:`the changelog <changes_13_0_rc1_baker>`.
Note that ``--liquidity-baking-toggle-vote`` must be placed
**after** ``run`` on the command-line.

.. warning::

    **Remember that having two bakers running connected to the same account could lead to double baking/attesting and the loss of all your bonds.**
    If you are worried about the availability of your node when it is its turn to bake/attest, there are other ways than duplicating your credentials (see the discussion in section :ref:`inactive_delegates`).
    **Never** use the same account on two daemons.

However, it is safe (and actually necessary) to temporarily run two bakers just before a protocol activation: the baker for the protocol being replaced and the baker for the protocol to be activated.


.. note::

   It is possible to bake and attest using a dedicated :ref:`consensus_key` instead of the delegate's key.

The baker uses the same format of configuration file as the client (see :ref:`client_conf_file`).

Accuser
~~~~~~~

The accuser is a daemon that monitors all blocks received on all
chains and looks for:

* bakers who signed two blocks at the same level and the same round
* bakers who injected more than one pre-attestations or attestation operation for the
  same level and round (more details :doc:`here <../active/consensus>`)

Upon finding such irregularity, it will emit respectively a
double-baking, double-pre-attesting, or double-attesting denunciation operation, which will
cause the offender to be :ref:`slashed<slashing>`, that is, to lose part of its security deposit.

::

   mavkit-accuser-alpha run

The accuser uses the same format of configuration file as the client (see :ref:`client_conf_file`).

Docker
~~~~~~

If you are running the baker Docker image, you can watch the baker logs with
``docker logs``. First, find the name of your container with::

    docker ps

If your container is running, its name will appear in the last column.
For instance, if the name is ``mainnet_baker-PtAtLas``, you can
view recent logs with::

    docker logs mainnet_baker-PtAtLas

If you want to keep watching logs, use ``-f``::

    docker logs mainnet_baker-PtAtLas -f

This allows you to know if you baked.
You should see lines such as::

    Injected block BLxzbB7PBW1axq for bootstrap5 after BLSrg4dXzL2aqq  (level 1381, slot 0, fitness 00::0000000000005441, operations 21)

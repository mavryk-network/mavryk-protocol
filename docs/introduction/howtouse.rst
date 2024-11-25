.. TODO tezos/tezos#2170: search shifted protocol name/number & adapt

.. _howtouse:

Getting started with Mavkit
===========================

This short tutorial illustrates the use of the various Mavkit binaries as well
as some concepts about the network.

.. _mavryk_binaries:

The Binaries
------------

After a successful compilation, you should have the following binaries:

- ``mavkit-node``: the Mavkit daemon itself (see `Node`_);
- ``mavkit-client``: a command-line client and basic wallet (see `Client`_);
- ``mavkit-admin-client``: administration tool for the node (see :ref:`mavkit-admin-client`);
- ``mavkit-{baker,accuser}-*``: daemons to bake and accuse on the Mavryk network (see :doc:`howtorun`);
- ``mavkit-signer``: a client to remotely sign operations or blocks
  (see :ref:`signer`);
- ``mavkit-smart-rollup-node``: executable for using and running a smart rollup node as Layer 2 (see :doc:`../shell/smart_rollup_node`);
- ``mavkit-smart-rollup-wasm-debugger``: debugger for smart rollup kernels (see :doc:`../shell/smart_rollup_node`)
- ``mavkit-proxy-server``: a readonly frontend to ``mavkit-node`` designed to lower the load of full nodes (see :doc:`../user/proxy-server`)
- ``mavkit-codec``: a utility for documenting the data encodings and for performing data encoding/decoding (see `Codec`_)
- ``mavkit-protocol-compiler``: a domain-specific compiler for Mavryk protocols (see `Protocol compiler`_)
- ``mavkit-snoop``: a tool for modeling the performance of any piece of OCaml code, based on benchmarking (see :doc:`../developer/snoop`)

The daemons other than the node are suffixed with the name of the protocol they are
bound to.
More precisely, the suffix consists of the first 8 characters of the protocol hash; except for protocol Alpha, for which the suffix is simply ``-alpha``.
For instance, ``mavkit-baker-PtAtLas`` is the baker
for the Atlas protocol, and ``mavkit-baker-alpha`` is the baker
of the development protocol.
The ``mavkit-node`` daemon is not suffixed by any protocol name, because it is independent of the economic protocol. See also the `Node's Protocol`_ section below.


Read the Manual
---------------

All the Mavkit binaries provide the ``--help`` option to display information about their usage, including the available options and the possible parameters.

Additionally, most of the above binaries (i.e., all but the node, the validator, and the compiler) provide a textual manual that can be obtained with the command ``man``,
whose verbosity can be increased with ``-v``, for example::

    mavkit-client man -v 3

It is also possible to get information on a specific command in the manual with ``man <command>``::

   mavkit-client man set

To see the usage of one specific command, you may also type the command without arguments, which displays its possible completions and options::

   mavkit-client transfer

.. warning::

    Beware that the commands available on the client depend on the specific
    protocol run by the node. For instance, ``transfer`` is not available when
    the node runs the genesis protocol, which may happen for a few minutes when
    launching a node for the first time, **or when the client is not connected
    to a node**. In the last case, the above command generates a warning
    followed by an error::

        Warning:
          Failed to acquire the protocol version from the node
          [...]
        Error:
          Unrecognized command.
          Try using the man command to get more information.
        Usage:
          [...]

.. _mavkit_client_protocol:

To make the client command behave as for a protocol other than that used by the node (or even when not connected to a node), use the option ``--protocol`` (or ``-p``), e.g.::

    mavkit-client --protocol ProtoALphaAL man transfer

Note that you can get the list of protocols known to the client with::

    mavkit-client list understood protocols

The full command line documentation of the Mavkit binaries supporting the ``man`` command is also available
online: :doc:`../shell/cli-commands`.

Node
----

The node is the main actor of the Mavryk blockchain and it has two main
functions: running the gossip network and updating the context.
The gossip network is where all Mavryk nodes exchange blocks and
operations with each other (see :ref:`mavkit-admin-client` to monitor
p2p connections).
Using this peer-to-peer network, an operation originated by a user can
hop several times through other nodes until it finds its way into a
block baked by a baker.
Using the blocks it receives on the gossip network the node also
keeps up to date the current *context*, that is the full state of
the blockchain shared by all peers.
Approximately every 15 seconds a new block is created and, when the node
receives it, it applies each operation in the block to its current
context and computes a new context.
The last block received on a chain is also called the *head* of that
chain.
Each new head is then advertised by the node to its peers,
disseminating this information to build a consensus across the
network.

Other than passively observing the network, your node can also inject
its own new operations when instructed by the ``mavkit-client`` and even
send new blocks when guided by the ``mavkit-baker-*``.
The node has also a view of the multiple chains that may exist
concurrently and selects the best one based on its fitness (see
:doc:`../active/consensus`).

.. note::

   The ``mavkit-node`` uses (unless the option ``--singleprocess`` is
   given) an auxiliary daemon in order to validate, apply and compute
   the resulting context of blocks, in parallel to its main
   process. Thus, an ``mavkit-validator`` process can appear while
   monitoring the active processes of the machine.

.. warning::

   To ensure the best conditions to run a node, we recommend users to use `NTP
   <https://en.wikipedia.org/wiki/Network_Time_Protocol>`__ to avoid clock
   drift. Clock drift may result in not being able to get recent blocks in case
   of negative lag time, and in not being able to inject new blocks in case of
   positive lag time.

Node Identity
~~~~~~~~~~~~~

First, we need to generate a new identity for the node to
connect to the network::

    mavkit-node identity generate

.. note::

    If the node prompts you to install the Zcash parameter file, follow
    the :ref:`corresponding instructions <setup_zcash_params>`.

The identity comprises a pair of cryptographic
keys that nodes use to encrypt messages sent to each other, and an
antispam proof-of-work stamp proving that enough computing power has been
dedicated to creating this identity.
Note that this is merely a network identity and it is not related in
any way to a Mavryk address on the blockchain.

If you wish to run your node on a test network, now is also a good time
to configure your node for it (see :doc:`../user/multinetwork`).

Node Synchronization
~~~~~~~~~~~~~~~~~~~~

Whenever a node starts, it tries to retrieve the most current head of the chain
from its peers. This can be a long process if there are many blocks to retrieve
(e.g. when a node is launched for the first time or has been out of sync for a
while), or on a slow network connection. The mechanism of :doc:`../user/snapshots` can
help in reducing the synchronization time.

Once the synchronization is complete, the node is said to be *bootstrapped*.
Some operations require the node to be bootstrapped.

.. _node-protocol:

Node's Protocol
~~~~~~~~~~~~~~~

A Mavryk node can switch from one protocol to another during its
execution.  This typically happens during the synchronization phase
when a node launches for the first time. The node starts with the
genesis protocol and then goes through all previous protocols until it
finally switches to the current protocol.

Throughout the documentation, "Alpha" refers to the protocol in the
``src/proto_alpha`` directory of the ``master`` branch, that is, a protocol under development, which serves as a basis to propose replacements
for the currently active protocol. The Alpha protocol is used by
default in :doc:`sandbox mode <../user/sandbox>` and in the various test
suites.


Storage
~~~~~~~

All blockchain data is stored by the node under a data directory, which by default is ``$HOME/.mavryk-node/``.

If for some reason your node is misbehaving or there has been an
upgrade of the network, it is safe to remove this directory, it just
means that your node will take some time to resync the chain.

If removing this directory, please note that if it took you a long time to
compute your node identity, keep the ``identity.json`` file and instead only
remove its child ``store``, ``context`` and ``protocol`` (if any) sub-directories.

If you are also running a baker, make sure that it is configured to access the
data directory of the node (see :ref:`how to run a baker <baker_run>`).


RPC Interface
~~~~~~~~~~~~~

The only programming interface to the node is through JSON RPC calls and it is disabled by
default.  More detailed documentation can be found in the :doc:`RPC index
<../active/rpc>`. The RPC interface must be enabled for the clients
to communicate with the node but it should not be publicly accessible on the
internet. With the following command, it is available uniquely on the
``localhost`` address of your machine, on the default port ``8732``.

::

   mavkit-node run --rpc-addr 127.0.0.1

Node configuration
~~~~~~~~~~~~~~~~~~

Many options of the node can be configured when running the node:

- RPC parameters (e.g. the port number for listening to RPC requests using option ``--rpc-addr``)
- The directory where the node stores local data (using option ``--data-dir``)
- Network parameters (e.g. the network to connect to, using option ``--network``, the number of connections to peers, using option ``--connections``)
- Validator and mempool parameters
- :ref:`Logging options <configure_node_logging>`.

The list of configurable options can be obtained using the following command::

    mavkit-node run --help

You can read more about the :doc:`node configuration <../user/node-configuration>` and its :ref:`private mode <private-mode>`.

Besides listening to requests from the client,
the node listens to connections from peers, by default on port ``9732`` (this can be changed using option ``--net-addr``), so it's advisable to
open incoming connections to that port.

Summing up
~~~~~~~~~~

Putting together all the above instructions, you may want to run a node as follows:

.. code-block:: shell

    # Download a snapshot for your target network, e.g. <test-net>:
    wget <snapshot-url> -O <snapshot-file>
    # Configure the node for running on <test-net>:
    mavkit-node config init --data-dir ~/.mavryk-node-<test-net> --network <test-net>
    # Import the snapshot into the node data directory:
    mavkit-node snapshot import --data-dir ~/.mavryk-node-<test-net> --block <block-hash> <snapshot-file>
    # Run the node:
    mavkit-node run --data-dir ~/.mavryk-node-<test-net> --rpc-addr 127.0.0.1

.. _howtouse_mavryk_client:

Client
------

Mavkit client can be used to interact with the node, it can query its
status or ask the node to perform some actions.

.. note::

  The rest of this page assumes that you have launched a local node, as explained in the previous section. But it is useful to know that the client can be configured to interact with a public node instead, either using :doc:`the configuration file <../user/client-configuration>` or by supplying option ``-E <node-url>`` with `a public RPC node <https://docs.tezos.com/architecture/rpc#public-and-private-rpc-nodes>`__.

After starting your local node you can check if it has finished
synchronizing (see :doc:`../shell/sync`) using::

   mavkit-client bootstrapped

This call will hang and return only when the node is synchronized
(recall that this is much faster when starting a node from a snapshot).
Once the above command returns,
we can check what is the current timestamp of the head of the
chain (time is in UTC so it may differ from your local time)::

   mavkit-client get timestamp

You can also use the above command before the node is bootstrapped, from another terminal.
However, recall that the commands available on the client depend on the specific
protocol run by the node. For instance, ``get timestamp`` isn't available when
the node runs the genesis protocol, which may happen for a few minutes when
launching a node for the first time.

The behaviour of the client can be customized using various mechanisms, including command-line options, a configuration file, and environment variables. For details, refer to :doc:`../user/setup-client`.

A Simple Wallet
~~~~~~~~~~~~~~~

The client is also a basic wallet. We can, for example, generate a new pair of keys, which can be used locally
with the alias *alice*::

      $ mavkit-client gen keys alice

To check the account (also called a contract) for Alice has been created::

      $ mavkit-client list known contracts

You will notice that the client data directory (by default, ``~/.mavryk-client``) has been populated with
3 files ``public_key_hashs``, ``public_keys`` and ``secret_keys``.
The content of each file is in JSON and keeps the mapping between
aliases (e.g., ``alice``) and the kind of keys indicated by the name
of each file.
Secret keys should be stored on disk encrypted with a password except when
using a hardware wallet (see :ref:`ledger`).
An additional file ``contracts`` contains the addresses of smart
contracts, which have the form *KT1…*.


Notice that by default, the keys were stored unencrypted, which is fine in our test example.
In more realistic scenarios, you should supply the option ``--encrypted`` when generating a new account::

      $ mavkit-client gen keys bob --encrypted

Mavryk supports four different ECC (`Elliptic-Curve Cryptography <https://en.wikipedia.org/wiki/Elliptic-curve_cryptography>`_) schemes: *Ed25519*, *secp256k1* (the
one used in Bitcoin), *P-256* (also called *secp256r1*), and *BLS* (variant
*MinPk*, for aggregated signatures). The secp256k1 and P256
curves have been added for interoperability with Bitcoin and
Hardware Security Modules (*HSMs*) mostly. Unless your use case
requires those, you should probably use *Ed25519*. We use a verified
library for Ed25519, and it is generally recommended over other curves
by the crypto community, for performance and security reasons.

Make sure to make a back-up of the client data directory and that the password
protecting your secret keys is properly managed (if you stored them encrypted).

For more advanced key management we offer :ref:`ledger support
<ledger>` and a :ref:`remote signer<signer>`.

.. _using_faucet:

Get Free Test Tokens
~~~~~~~~~~~~~~~~~~~~

To test the networks and help users get familiar with the system, on
:ref:`test networks <test_networks>` you can obtain free tokens from
:ref:`a faucet <faucet>`. Transfer some to Alice's address.

Transfers and Receipts
~~~~~~~~~~~~~~~~~~~~~~

To fund our newly created account for Bob, we need to transfer some
mav using the *transfer* operation.
Every operation returns a *receipt* that recapitulates all the effects
of the operation on the blockchain.
A useful option for any operation is ``--dry-run``, which instructs
the client to simulate the operation without actually sending it to
the network, so that we can inspect its receipt.

Let's try::

  mavkit-client transfer 1 from alice to bob --dry-run

  Fatal error:
    The operation will burn 0.257 mav which is higher than the configured burn cap (0 mav).
     Use `--burn-cap 0.257` to emit this operation.

The client asks the node to validate the operation (without sending
it) and obtains an error.
The reason is that when we fund a new address we are also storing it
on the blockchain.
Any storage on chain has a cost associated to it which should be
accounted for either by paying a fee to a baker or by destroying
(``burning``) some mav.
This is particularly important to protect the system from spam.
Because storing an address requires burning 0.257 mav and the client has
a default of 0, we need to explicitly set a cap on the amount that we
allow to burn::

  mavkit-client transfer 1 from alice to bob --dry-run --burn-cap 0.257

This should do it and you should see a rather long receipt being
produced, here's an excerpt::

  ...
  Simulation result:
    Manager signed operations:
      From: mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe
      Fee to the baker: ṁ0.001259
      ...
      Balance updates:
        mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe ............ -ṁ0.001259
        fees(mv1CQJA6XDWcpVgVbxgSCTa69AW1y8iHbLx5,72) ... +ṁ0.001259
      Revelation of manager public key:
        Contract: mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe
        Key: edpkuK4o4ZGyNHKrQqAox7hELeKEceg5isH18CCYUaQ3tF7xZ8HW3X
        ...
    Manager signed operations:
      From: mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe
      Fee to the baker: ṁ0.001179
      ...
      Balance updates:
        mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe ............ -ṁ0.001179
        fees(mv1CQJA6XDWcpVgVbxgSCTa69AW1y8iHbLx5,72) ... +ṁ0.001179
      Transaction:
        Amount: ṁ1
        From: mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe
        To: mv1MbxANFAMxSHb5K1q9ZA9mynzYrZfJ7mHt
        ...
        Balance updates:
          mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe ... -ṁ1
          mv1MbxANFAMxSHb5K1q9ZA9mynzYrZfJ7mHt ... +ṁ1
          mv1E7Ms4p1e3jV2WMehLB3FBFwbV56GiRQfe ... -ṁ0.257

The client does a bit of magic to simplify our life and here we see
that many details were automatically set for us.
Surprisingly, our transfer operation resulted in **two** operations,
first a *revelation*, and then a transfer.
Alice's address, obtained from the faucet, is already present on the
blockchain, but only in the form of a *public key hash*
``mv1Rj...5w``.
To sign operations, Alice needs to first reveal the *public
key* ``edpkuk...3X`` behind the hash, so that other users can verify
her signatures.
The client is kind enough to prepend a reveal operation before the
first transfer of a new address, this has to be done only once, future
transfers will consist of a single operation as expected.

Another interesting thing we learn from the receipt is that there are
more costs being added on top of the transfer and the burn: *fees*.
To encourage a baker to include our operation, and in general
to pay for the cost of running the blockchain, each operation usually
includes a fee that goes to the baker.
Fees are variable over time and depend on many factors but the Mavkit
client selects a default for us.

The last important bit of our receipt is the balance updates that
resume which address is being debited or credited a certain amount.
We see in this case that baker ``mv1Ke...yU`` is being credited one
fee for each operation, that Bob's address ``mv1Rk...Ph`` gets 1 mav
and that Alice pays the transfer, the burn, and the two fees.

Now that we have a clear picture of what we are going to pay we can
execute the transfer for real, without the ``dry-run`` option.
You will notice that the client hangs for a few seconds before
producing the receipt because after injecting the operation in your
local node it is waiting for it to be included by some baker on the
network.
Once it receives a block with the operation inside it will return the
receipt.

It is advisable to wait for several blocks to consider the transaction as
final.
Please refer to the :doc:`consensus algorithm documentation <../active/consensus>` and `analysis <https://research-development.nomadic-labs.com/faster-finality-with-emmy.html>`__ to better understand block finality in Mavryk.
`This page <https://nomadic-labs.gitlab.io/emmyplus-experiments/>`__ provides concrete values for the number of blocks one should wait.

In the rare case when an operation is lost, how can we be sure that it
will not be included in any future block, and then we may re-emit it?
After 120 blocks a transaction is considered invalid and can't be
included anymore in a block.
Furthermore each operation has a counter that prevents replays so it is usually safe to re-emit an
operation that seems lost.

.. _block_explorers:

Block Explorers
~~~~~~~~~~~~~~~

Once your transaction is included in a block, you can retrieve it in one of the `public block explorers <https://docs.tezos.com/developing/information/block-explorers>`__, which list the whole history of the different Mavryk networks (mainnet or test networks).

.. _originated-accounts:

Implicit Accounts and Smart Contracts
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In Mavryk there are two kinds of accounts: *implicit accounts* and *smart contracts* (see :doc:`../active/accounts` for more details).

- Addresses with a *mv* prefix, like the *mv1* public key hashes used above,  represent implicit accounts. They are created with a transfer
  operation to the account's public key hash.

- Smart contracts have addresses starting with *KT1* and are created
  with an origination operation. They don't have a corresponding
  secret key and they run Michelson code each time they receive a
  transaction.

Let's originate our first contract and call it *id*::

    mavkit-client originate contract id transferring 1 from alice \
                 running ./michelson_test_scripts/attic/id.mv \
                 --init '"hello"' --burn-cap 0.4

The initial balance is 1 mav, generously provided by implicit account
*alice*. The contract stores a Michelson program ``id.mv``
(found in file :src:`michelson_test_scripts/attic/id.mv`), with
Michelson value ``"hello"`` as initial storage (the extra quotes are
needed to avoid shell expansion). The parameter ``--burn-cap``
specifies the maximal fee the user is willing to pay for this
operation, while the actual fee is determined by the system.

A Michelson contract is expressed as a pure function, mapping a pair
``(parameter, storage)`` to a pair ``(list_of_operations, storage)``.
However, when this pure function is applied
to the blockchain state, it can
be seen as an object with a single method taking one parameter (``parameter``), and with a single attribute (``storage``).
The method updates the state (the storage), and submits operations as a side
effect.

For the sake of this example, here is the ``id.mv`` contract:

.. code-block:: michelson

    parameter string;
    storage string;
    code {CAR; NIL operation; PAIR};

It specifies the types for the parameter and storage, and implements a
function which updates the storage with the value passed as a parameter
and returns this new storage together with an empty list of
operations.


Gas and Storage Costs
~~~~~~~~~~~~~~~~~~~~~

A quick look at the balance updates on the receipt shows that on top of
funding the contract with 1 mav, *alice* was also charged an extra cost
that is burnt.
This cost comes from the *storage* and is shown in the line
``Paid storage size diff: 46 bytes``, 41 for the contract and 5 for
the string ``"hello"``.
Given that a contract saves its data on the public blockchain that
every node stores, it is necessary to charge a fee per byte to avoid
abuse and encourage lean programs.

Let's see what calling a program with a new argument would look like
with the ``--dry-run`` option::

   mavkit-client transfer 0 from alice to id --arg '"world"' --dry-run

The transaction would successfully update the storage but this time it
wouldn't cost us anything more than the fee, the reason is that the
storage for ``"world"`` is the same as for ``"hello"``, which has
already been paid for.
To store more we'll need to pay more, you can try by passing a longer
string.

The other cost associated with running contracts is the *gas*, which
measures *how long* a program takes to compute.
Contrary to storage there is no cost per gas unit, a transfer can
require as much gas as it wants, however a baker that has to choose
among several transactions is much more likely to include a low gas
one because it's cheaper to run and validate.
At the same time, bakers also give priority to high fee transactions.
This means that there is an implicit cost for gas that is related to
the fee offered versus the gas and fees of other transactions.

If you are happy with the gas and storage of your transaction you can
run it for real, however it is always a good idea to set an explicit
limit for both. The transaction fails if any of the two limits are passed.
Note that the storage limit sets an upper bound to the storage size *difference*, so in our case, it may be 0 because our new value does not increase at all the storage size.

::

   mavkit-client transfer 0 from alice to id --arg '"world"' \
                                            --gas-limit 11375 \
                                            --storage-limit 0

A baker is more likely to include an operation with lower gas and
storage limits because it takes fewer resources to execute so it is in
the best interest of the user to pick limits that are as close as
possible to the actual use. In this case, you may have to specify some
fees (using option ``--fee``) as the baker is expecting some for the resource
usage. Otherwise, you can force a low fee operation using the
``--force-low-fee``, with the risk that no baker will include it.

More Michelson test scripts can be found in directory
:src:`michelson_test_scripts/`.
Advanced documentation of the smart contract language is available
:doc:`here<../active/michelson>`.


Validation
~~~~~~~~~~

The node allows validating an operation before submitting it to the
network by simply simulating the application of the operation to the
current context.
Without this mechanism, if you just send an invalid operation (e.g. sending more
tokens than you own), the node would broadcast it and when it is
included in a block you would have to pay the usual fee even if it won't
have an effect on the context.
To avoid this case the client first asks the node to validate the
transaction and only then sends it.

The same validation is used when you pass the option ``--dry-run``:
the receipt that you see is actually a simulated one.
The only difference is that, when this option is supplied, the transaction is not sent even if it proves to be valid.

Another important use of validation is to determine gas and storage
limits.
The node first simulates the execution of a Michelson program and
tracks the amount of gas and storage that has been consumed.
Then the client sends the transaction with the right limits for gas
and storage based on those indicated by the node.
This is why we were able to submit transactions without specifying
these limits: they were computed for us.

More information on validation can be found :doc:`here <../shell/validation>`.


It's RPCs all the Way Down
~~~~~~~~~~~~~~~~~~~~~~~~~~

The client communicates with the node uniquely through RPC calls so
make sure that the node is listening on the right ports and that the ports are
open.
For example the ``get timestamp`` command above is a shortcut for::

   mavkit-client rpc get /chains/main/blocks/head/header/shell

The client tries to simplify common tasks as much as possible, however
if you want to query the node for more specific information you'll
have to resort to RPCs.

.. _get_protocol_constants:

For example to check the value of important
:ref:`constants <protocol_constants>` in Mavryk, which may differ between Mainnet and other
:ref:`test networks<test_networks>`, you can use::

   mavkit-client rpc get /chains/main/blocks/head/context/constants | jq
   {
     "proof_of_work_nonce_size": 8,
     "nonce_length": 32,
     ...
   }

Another interesting use of RPCs is to inspect the receipts of the
operations of a block::

  mavkit-client rpc get /chains/main/blocks/head/operations

It is also possible to review the receipt of the whole block::

  mavkit-client rpc get /chains/main/blocks/head/metadata

An interesting block receipt is the one produced at the end of a
cycle as many delegates receive back part of their unfrozen accounts.


You can find more info on RPCs in the :doc:`RPCs' page <../active/rpc>`.

Other binaries
--------------

In this short tutorial we will not use some other binaries, but let's briefly review their roles.

.. _mavkit-admin-client:

Admin Client
~~~~~~~~~~~~

The admin client enables you to interact with the peer-to-peer layer in order
to:

- check the status of the connections
- force connections to known peers
- ban/unban peers

A useful command to debug a node that is not syncing is:

::

   mavkit-admin-client p2p stat

The admin client uses the same format of configuration file as the client (see :ref:`client_conf_file`).

Codec
~~~~~

The Mavkit codec (``mavkit-codec``) is a utility that:

- provides documentation for all the encodings used in the ``mavkit-node`` (and other binaries), and
- allows to convert from JSON to binary and vice-versa for all these encodings.

It is meant to be used by developers for tests, for generating documentation when writing libraries that share data with the node, for light scripting, etc.
For more details on its usage, refer to its :ref:`online manual <codec_manual>` and to :doc:`../developer/encodings`.

Protocol compiler
~~~~~~~~~~~~~~~~~

The protocol compiler (``mavkit-protocol-compiler``) can compile protocols within the limited environment that the shell provides.
This environment is limited to a restricted set of libraries in order to constrain the possible behavior of the protocols.

It is meant to be used:

- by developers to compile the protocol under development,
- by the packaging process to compile protocols that are pre-linked in the binaries,
- by the Mavkit node when there is an on-chain update to a protocol that is not pre-linked with the binary.

Summary
-------

In this tutorial, you have learned:

- to start an Mavkit node and set up its basic configuration;
- to use the Mavkit client to create implicit accounts and do transfers between them;
- to deploy and interact with a simple predefined smart contract;
- to distinguish between the various costs associated to transactions such as burnt mav, fees, storage costs, and gas consumption;
- some further concepts such as transaction validation and the RPC interface;
- the role of other binaries, less frequently used than the client and the node.

You may now explore Mavryk further, and enjoy using it!

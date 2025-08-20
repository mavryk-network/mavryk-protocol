Sandboxed mode
--------------

To run a ‘localhost-only’ instance of a Mavryk network, we provide two
helper scripts:

-  ``./src/bin_node/mavkit-sandboxed-node.sh``
-  ``./src/bin_client/mavkit-init-sandboxed-client.sh``

For the moment these scripts are expected to be run on the ``master``
branch (see :ref:`Build from sources<build_from_sources>`; in
particular, use ``git checkout master`` instead of ``git checkout
latest-release``).

Run a sandboxed node
~~~~~~~~~~~~~~~~~~~~

For instance, if you want to run a local network with two nodes, in the
first terminal, the following command will initialize a node listening
for peers on port ``19731`` and listening for RPC on port ``18731``.

::

    ./src/bin_node/mavkit-sandboxed-node.sh 1 --connections 1

This node will store its data in a temporary directory
``/tmp/mavkit-node.xxxxxxxx`` which will be removed when the node is
stopped.
The option ``--connections`` is just to remove the spurious “Too few
connections” warnings by lowering the number of expected connection.

To launch the second node, run the following command in another terminal, and
it will listen on port ``19739`` and ``18739``:

::

    ./src/bin_node/mavkit-sandboxed-node.sh 9

You might replace ``1`` or ``9`` by any number in between if you want to
run more than two nodes.


Use the sandboxed client
~~~~~~~~~~~~~~~~~~~~~~~~

Once your node is running, open a new terminal and initialize the
“sandboxed” client data in a temporary directory:

::

    eval `./src/bin_client/mavkit-init-sandboxed-client.sh 1`

It will also define in the current shell session an alias ``mavkit-client``
preconfigured for communicating with the same-numbered node.

When you bootstrap a new network, the network is initialized with a
dummy economic protocol, called *genesis*. If you want to run the whole implemented
protocol, ``init-sandboxed-client`` also defines an
alias ``mavkit-activate-alpha``, that you need to execute once for
activating the whole network.
For instance:

::

    $ mavkit-client rpc get /chains/main/blocks/head/metadata
      "next_protocol": "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P"
    $ mavkit-activate-alpha
      Injected BMV9KnSPE1yw
    $ mavkit-client rpc get /chains/main/blocks/head/metadata
      "protocol": "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P"

We now have the possibility to send transactions to the sandboxed network.
As the genesis block used to initialize the sandboxed network differs from the
one used in :ref:`test networks<test_networks>`, it is not possible to activate
accounts obtained from the faucet. However, we can use the
preconfigured accounts which can be listed with:

::

   $ mavkit-client list known addresses

     activator: mv1XLiKa1vywAuPWuLF9WEYB3BPvRRQ8oCsp (unencrypted sk known)
     bootstrap5: mv1S14SxfuavHMGDXxZJoBERZafLTyX3Z6Dx (unencrypted sk known)
     bootstrap4: mv1PVMnW8iyYxCoqLfPAha8EAPRxjTx7wqbn (unencrypted sk known)
     bootstrap3: mv1TxMEnmav51G1Hwcib1rBnBeniDMgG8nkJ (unencrypted sk known)
     bootstrap2: mv1V73YiKvinVumxwvYWjCZBoT44wqBNhta7 (unencrypted sk known)
     bootstrap1: mv18Cw7psUrAAPBpXYd9CtCpHg9EgjHP9KTe (unencrypted sk known)

We can run the following command to transfer some Mav from one account to
another:

::

   $ mavkit-client transfer 42 from bootstrap1 to bootstrap2 &
   ...
   Waiting for the operation to be included...

You will notice that this command doesn't terminate (hence the ``&``),
as usual it is waiting for the network to include the transaction in a
block.
Given that we are in a sandbox we need to bake a block ourselves and
we can do so with the following command:

::

   $ mavkit-client bake for --minimal-timestamp

If the previous transaction is valid, the operation is included in the
chain and the transfer terminates returning the usual receipt.
Note that the ``bake for`` command of the client is exclusively for
testing purposes, all baking should be done using the ``mavkit-baker``
binary.


Tune protocol Alpha parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``mavkit-activate-alpha`` alias uses parameters from
``src/proto_alpha/parameters/sandbox-parameters.json`` to activate protocol
Alpha. It can be useful to tune these parameters when you need to debug
something, for example, change the number of blocks per cycle, the time between
blocks, etc.


Preserve data
~~~~~~~~~~~~~

If you want to preserve data and configuration files at the end of your run, you
can use the ``DATA_DIR`` environment variable.

::

    mkdir /tmp/mv-data
    DATA_DIR='/tmp/mv-data' ./src/bin_node/mavkit-sandboxed-node.sh 1 --connections 1

You can even provide a custom ``identity.json`` and ``config.json`` to the
sandboxed node by placing them in the data directory.

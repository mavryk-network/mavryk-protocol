Mavkit & Protocol versioning
============================

Due to the fact that the Mavryk blockchain is self-amending, versioning concerns both the Mavryk protocol and several components of Mavkit. This page explains the various corresponding versioning schemes, which are mostly independent of each other. Though, some relations do exist (e.g. when a new protocol is proposed, a new Mavkit release is usually delivered embedding the new proposal, for convenience); this is explained in some versioning schemes below.

Mavkit versions
---------------

The whole Mavkit software is versioned by releases, see :doc:`../releases/releases`.

Protocol versions
-----------------

The Mavryk economic protocol is versioned at a different pace, according to a :doc:`voting process <../active/voting>`, see :doc:`../protocols/naming`.

Protocol environment versions
-----------------------------

The economic protocol can interact with the rest of the Mavkit software through a sandboxed API called a protocol environment.
When new features are needed by a proposed protocol, or if the protocol API is changed, a new environment version is created,
see :ref:`Protocol environment versions <environment_versions>`.
The new environment is delivered as part of a new Mavkit release.


RPC Versioning
--------------

In Mavkit, RPCs can be versioned using a query parameter called
``version``. This query parameter exists only for RPCs which have at
least two different versions. For example:

::

   ./mavkit-client rpc get /chains/main/mempool/pending_operations?version=0

If the RPC is called with a bad version number (a negative or an
unsupported version) the call fails with an error message like:

::

   Fatal error:
   Command failed: The RPC was called with version number '2' which is not supported. Version numbers accepted are '0, 1'.

For technical reasons, the default version number of an RPC cannot be
retrieved easily yet.

New Version
~~~~~~~~~~~

Whenever a new version of an RPC is added (see
:ref:`RPC-versioning-dev-adding-an-rpc`), there is a corresponding
entry in the :doc:`changelog<../CHANGES>` in the release of Mavkit
which includes the new version.

For example::

   Added version 5 to RPC GET chains/main/mempool/pending_operations.
   It can be used by calling the RPC with the parameter ?version=5
   (default version is still 4).

New Default Version
~~~~~~~~~~~~~~~~~~~

Whenever an Mavkit release changes the default version of an RPC, there
is a corresponding entry in the :doc:`changelog<../CHANGES>`.

For example::

   The default version for RPC GET chains/main/mempool/pending_operations
   is now 5 (previously 4). You can still use the previous version
   by calling the RPC with the parameter ?version=4.

As a general rule (that we may break exceptionnaly), changing the
default version number of an RPC always follows a deprecation period.

Deprecated Version
~~~~~~~~~~~~~~~~~~

Whenever an Mavkit release deprecates an RPC version, there is a
corresponding entry in the :doc:`changelog<../CHANGES>`.

For example::

   The version 4 for RPC GET chains/main/mempool/pending_operations
   is deprecated and may be removed in the next major release of Mavkit.

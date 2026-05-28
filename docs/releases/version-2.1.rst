Version 2.1 (Mavkit v20.4)
==========================

.. note::

   Mavryk Version 2.1 is a maintenance release of Version 2 (Boreas).
   The corresponding git tag is ``mavkit-v20.4``.

Version 2.1 is a maintenance release of the Mavkit executables. The on-chain protocol remains
**Boreas** (``PtBoreas``) — no protocol upgrade is included. This release focuses on
hardware wallet compatibility, Apple Silicon support, and updated Linux distribution packages.

Network Compatibility
~~~~~~~~~~~~~~~~~~~~~

Mavkit v20.4 nodes are **fully compatible** with v20.3 nodes on the network. Both versions
participate in the same Boreas protocol without issues.

However, Mavkit v20.3 is **not compatible** with the upcoming Mavryk Ledger applications.
Users who intend to use a Ledger hardware wallet must upgrade to v20.4.

Ledger Hardware Wallet Support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

v20.4 introduces full compatibility with the upcoming **Mavryk Wallet** and **Mavryk Baking**
Ledger applications (v1.0.0). These are the first Ledger apps purpose-built for the Mavryk
blockchain and will be available on `Ledger Live <https://www.ledger.com/>`_ once approved.

Supported devices: **Nano S Plus**, **Nano X**, **Stax**, **Flex**.

Changes in the Mavkit signer backend:

- **Native Mavryk derivation path**: BIP-44 coin type updated to ``1969``
  (``m/44'/1969'/...``), replacing the legacy ``1729`` path. The new Ledger apps use
  this path exclusively.
- **New OCaml bindings**: the signer backend now uses
  `ledgerwallet-mavryk <https://github.com/mavryk-network/ocaml-ledger-wallet>`_ (v0.4.1),
  with dedicated ``Mavryk`` and ``MavBake`` app classes.
- **Removed legacy code paths**: Version gates that maintained backwards compatibility with
  Ledger Baking app versions older than 2.0.0 have been removed. The ``authorize ledger``
  command now returns a clean deprecation message directing users to
  ``setup ledger to bake for``.
- **Minimum app version**: Ledger app version requirement set to 1.0.0.

For detailed usage instructions, see the
`Ledger Wallet app guide <https://docs.mavryk.org/node-validating/ledger/wallet-app>`_ and the
`Ledger Baking app guide <https://docs.mavryk.org/node-validating/ledger/baking-app>`_.

macOS Apple Silicon Support
~~~~~~~~~~~~~~~~~~~~~~~~~~~

v20.4 fixes build dependency issues on **macOS ARM64 (Apple Silicon)**. Pre-built Homebrew
bottles are available for **macOS 14 Sonoma** on Apple Silicon (``arm64_sonoma``).

Install via Homebrew::

  brew tap mavryk-network/mavryk https://github.com/mavryk-network/mavryk-packaging
  brew install mavryk-node mavryk-client mavryk-baker-PtBoreas

Ubuntu (Launchpad PPA)
~~~~~~~~~~~~~~~~~~~~~~

Pre-built ``.deb`` packages are published to the `Mavryk Launchpad PPA <https://launchpad.net/~mavrykdynamics/+archive/ubuntu/mavryk>`_.
The following LTS releases are supported (unchanged from v20.3):

- Ubuntu 20.04 (Focal Fossa)
- Ubuntu 22.04 (Jammy Jellyfish)
- Ubuntu 24.04 (Noble Numbat)

Add the PPA and install::

  sudo add-apt-repository ppa:mavrykdynamics/mavryk
  sudo apt-get update
  sudo apt-get install mavryk-node mavryk-client mavryk-baker-ptboreas

.. note::

   Debian package names require lowercase, so the protocol suffix is ``ptboreas`` (not ``PtBoreas``).

For Debian (non-Ubuntu) systems, add the PPA manually::

  sudo apt-get install software-properties-common gnupg
  sudo add-apt-repository 'deb http://ppa.launchpad.net/mavrykdynamics/mavryk/ubuntu jammy main'
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 37B8819B7D0D183812DCA9A8CE5A4D8933AE7CBB
  sudo apt-get update
  sudo apt-get install mavryk-node mavryk-client mavryk-baker-ptboreas

Fedora (Copr)
~~~~~~~~~~~~~

RPM packages are published to the `Mavryk Copr repository <https://copr.fedorainfracloud.org/coprs/g/MavrykDynamics/Mavryk/>`_.
Supported versions updated from 40, 41, 42 to **42, 43, 44** — Fedora 40 and 41 have been dropped.

Enable the Copr repository and install::

  sudo dnf copr enable @MavrykDynamics/Mavryk
  sudo dnf install mavryk-node mavryk-client mavryk-baker-PtBoreas

GitLab Release vs. Package Managers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Packages are available from two different sources that carry **different distribution targets**:

- **GitLab releases** (`release page <https://gitlab.com/mavryk-network/mavryk-protocol/-/releases>`_):
  Built by the protocol CI pipeline. Contains ``.deb`` packages for Ubuntu (focal, jammy, noble),
  ``.rpm`` packages for **Fedora 39, 40, 41** and **Rocky Linux 9.3**, and static binaries.
  These are attached directly to the release tag.

- **Launchpad PPA** (`ppa:mavrykdynamics/mavryk <https://launchpad.net/~mavrykdynamics/+archive/ubuntu/mavryk>`_)
  and **Copr** (`@MavrykDynamics/Mavryk <https://copr.fedorainfracloud.org/coprs/g/MavrykDynamics/Mavryk/>`_):
  Built and published separately by the packaging repository. The PPA carries Ubuntu packages for the
  same three LTS releases (focal, jammy, noble). Copr carries RPM packages for **Fedora 42, 43, 44** —
  these are not available on the GitLab release page.

.. note::

   The Fedora RPMs on the GitLab release page target older versions (39–41) that are no longer
   supported on Copr. Conversely, Fedora 42+ packages are only available through Copr, not on the
   GitLab release page. For Ubuntu, both sources provide the same three LTS releases.
   **We recommend using the Launchpad PPA and Copr repositories** for automatic updates and the
   latest supported distribution targets.

Docker Images
~~~~~~~~~~~~~

Docker images have been updated to v20.4. Static binaries are built for both ``amd64``
and ``arm64`` architectures.

Update Instructions
-------------------

To update from sources::

  git fetch
  git checkout mavkit-v20.4
  make clean
  opam switch remove . # To be used if the next step fails
  make build-deps
  eval $(opam env)
  make

If you are using Docker instead, use the ``v20.4`` Docker images of Mavkit.

Via Homebrew (macOS)::

  brew update
  brew upgrade mavryk-node mavryk-client mavryk-baker-PtBoreas

Via Ubuntu PPA::

  sudo apt-get update
  sudo apt-get upgrade mavryk-node mavryk-client mavryk-baker-ptboreas

Via Fedora Copr::

  sudo dnf upgrade mavryk-node mavryk-client mavryk-baker-PtBoreas

Further Reading
---------------

- `Mavryk protocol documentation <https://protocol.mavryk.org>`_
- `Boreas protocol changelog <https://protocol.mavryk.org/protocols/002_boreas.html>`_
- `Ledger Wallet app guide <https://docs.mavryk.org/node-validating/ledger/wallet-app>`_
- `Ledger Baking app guide <https://docs.mavryk.org/node-validating/ledger/baking-app>`_
- `Mavryk Wallet browser extension <https://mavryk.org/wallet>`_
- `Block explorer <https://nexus.mavryk.org/explorer>`_
- `Validating guide <https://docs.mavryk.org/node-validating/validating/introduction>`_
- `Node deployment guide <https://docs.mavryk.org/node-validating/deploy-a-node/installation>`_

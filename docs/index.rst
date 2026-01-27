.. Mavryk documentation master file, created by
   sphinx-quickstart on Sat Nov 11 11:08:48 2017.
   You can adapt this file completely to your liking, but it should at least
   contain the root ``toctree`` directive.

.. TODO https://gitlab.com/tezos/tezos/-/issues/2170:
   search shifted protocol name/number & adapt

Welcome to the Mavkit and Protocol Documentation!
=================================================

To start browsing, either follow one of the guided paths below, or directly pick any topics in the documentation menu.

.. raw:: html

    <details>
    <summary><img alt="Discover Mavkit & the Mavryk protocol" class="normal" src="discover_tezos_1.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Never heard of Mavkit?** Let's get acquainted!

Mavkit & the Mavryk protocol are an implementation of the `Mavryk blockchain <https://mavryk.org>`__ , a
distributed consensus platform with meta-consensus
capability.

This means that, unlike other blockchains like Bitcoin or Ethereum, Mavryk comes to consensus not only about the state of its ledger, but also about how the protocol and the nodes should adapt and upgrade.

This is a fundamental design choice, allowing Mavryk to be seamlessly upgradable and continuosly evolving.
Due to this feature, Mavryk is built to last, and always stay at the leading edge of blockchain technology.

To learn more about Mavryk, the `Mavryk documentation <https://mavryk.org>`__.

To learn more about how Mavkit & the protocol fit into Mavryk and its ecosystem, see :doc:`introduction/mavryk`.

.. raw:: html

    </div></details><br/>

    <details>
    <summary><img alt="Getting started" class="normal" src="getting_started_2.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Newcomer to Mavkit?** Start participating to Mavryk using Mavkit!

Start participating to Mavryk by following the ``Introduction`` section in the documentation menu.

These tutorials explain:

- how to :doc:`get the latest release of Mavkit <introduction/howtoget>` (a complete, open-source implementation of Mavryk) in various forms,
- how to :doc:`start using Mavkit to join Mavryk <introduction/howtouse>`,
- different :doc:`ways to participate to the network <introduction/howtorun>`,

and more.

.. raw:: html

    </div></details><br/>

    <details>
    <summary><img alt="Using Mavkit" class="normal" src="using_mavkit_3.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Already a user?** Here is everything you need to know!

If you already installed Mavkit and can participate in the Mavryk blockchain, the most useful resources are grouped in the ``User manual`` section in the documentation menu.
These pages:

- present the key concepts and mechanisms for setting up Mavkit, including :doc:`user/setup-client`, :doc:`user/setup-node`, for different production or testing configurations;
- empowers you to take advantage of Mavkit' basic and more advanced features, such as :doc:`user/key-management`, :doc:`user/multisig`, :doc:`user/logging`, and much more.

If you intend to participate to Mavryk not just as a user, but rather as a baker, you should also check more specialized documentation such as the  `Baking section on the Mavryk Documentation <https://documentation.mavryk.org/node-baking/overview/>`__.

.. raw:: html

    </div></details><br/>

    <details>
    <summary><img alt="Understanding" class="normal" src="understanding_mavkit_4.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Want to know how it works?** It's no secret, let us explain!

If you want to know more about the *technology* underlying Mavkit and the Mavryk protocol, the ``Reference manual`` section in the documentation present their rationale, main design principles, and some high-level implementation principles:

- Page ``Mavkit software architecture`` explains how the :ref:`architecture of the Mavkit implementation <packages>` instantiates the high-level :ref:`architectural principles of any Mavryk implementation <the_big_picture>`, consisting in a "shell" and a "protocol" .

- Page ``Mavkit Shell`` details some major subsystems of :doc:`shell/shell`.

- Page ``Mavkit Protocol`` explains the design principles and the salient features of the Mavryk protocol. In fact, these pages are versioned for several Mavryk protocols, current or upcoming, such as: the :doc:`active protocol <active/protocol>`, a :doc:`protocol proposal under development <alpha/protocol>`, and possibly some protocol(s) that are currently candidate(s) for future adoption.

- Other pages are related to the important Smart Rollups feature, and present tools such as the Smart rollup node and Data Availability Committees.

.. raw:: html

    </div></details><br/>

    <details>
    <summary><img alt="Developer reference" class="normal" src="building_on_tezos_5.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Are you a Mavryk developer?** Find here some useful reference pages!

If you are a developer on the Mavryk platform, you must know the `Mavryk Developer Portal <https://mavryk.org/developers/>`__ or `Mavryk Documentation <https://documentation.mavryk.org>`__, giving accessible and pedagogical expositions on how to write smart contracts or Dapps.

This website complements those resources with reference documentation, mostly in section ``Developer reference``, including:

- Principles of the RPC interface such as the :doc:`developer/rpc`
- RPC references such as :doc:`shell/rpc`, :doc:`api/openapi`, or :doc:`api/errors`
- A complete reference of :doc:`active/michelson`
- Guidelines for writing smart contracts in Michelson, such as :doc:`active/michelson_anti_patterns`.

.. raw:: html

    </div></details><br/>

    <details>
    <summary><img alt="Contributing" class="normal" src="contributing_to_mavkit_6.png" style="width:min(95%,1000px); cursor: pointer;" />
    </summary><div style="max-width:min(90%,1000px); margin-top:1em; margin-left:2em">

**Are you a platform developer?** Here are the nuts and bolts!

One major focus of this website is on resources for platform developers, that is, contributors to Mavkit (Mavkit developers) and contributors to the Mavryk protocol (protocol developers).

Platform developers can find a rich set of explanations, tutorials, and howtos, mainly in the ``Contributing`` section, including:

- a tutorial on the various forms of contributing (:doc:`developer/contributing`), and guidelines such as :doc:`developer/guidelines`
- programming tutorials covering various libraries and frameworks specific to the Mavkit OCaml implementation, such as using :doc:`developer/gadt`, using :doc:`developer/error_monad`, using :doc:`developer/clic`, :doc:`developer/event_logging_framework`, etc.
- howtos for specific maintenance tasks such as :doc:`developer/michelson_instructions`, :doc:`developer/protocol_environment_upgrade`, or :doc:`developer/howto-freeze-protocols`
- a whole subsection on the :doc:`various testing frameworks <developer/testing_index>` for Mavkit, explaining how to use them and how to add different kinds of tests
- presentations of various tools for platform developers, such as support for :doc:`developer/profiling` and :doc:`developer/snoop`.

Platform developers are also provided reference materials for internal APIs of Mavkit, such as:

- The :doc:`API of OCaml libraries and modules <api/api-inline>` reference
- The :doc:`shell/p2p_api` reference
- The :doc:`developer/merkle-proof-encoding-formats` reference.

.. raw:: html

    </div></details><br/>


.. toctree::
   :maxdepth: 2
   :caption: Introduction
   :hidden:

   introduction/mavryk
   introduction/howtoget
   introduction/howtouse
   introduction/howtorun
   introduction/versioning
   BREAKING CHANGES <introduction/breaking_changes>

.. toctree::
   :maxdepth: 2
   :caption: Mavkit User manual
   :hidden:

   user/setup-client
   user/setup-node
   user/multisig
   user/fa12
   user/logging
   user/exits

.. toctree::
   :maxdepth: 2
   :caption: Mavkit Reference manual
   :hidden:

   shell/the_big_picture
   shell/shell
   shell/data_availability_committees
   shell/dal
   shell/smart_rollup_node
   shell/p2p_api
   shell/cli-commands
   shell/rpc

.. toctree::
   :maxdepth: 2
   :caption: Protocol Reference Manuals
   :hidden:

   Atlas Protocol Reference <active/index>
   Boreas Protocol Reference <boreas/index>
   Alpha Dev Protocol Reference <alpha/index>

.. toctree::
   :maxdepth: 2
   :caption: Mavryk developer Reference
   :hidden:

   developer/rpc
   api/errors
   api/openapi

.. toctree::
   :maxdepth: 2
   :caption: Changes in Mavkit releases
   :hidden:

   releases/releases
   releases/version-2
   releases/version-1
   releases/history

.. toctree::
   :maxdepth: 2
   :caption: Changes in protocol versions
   :hidden:

   protocols/naming
   protocols/001_atlas
   protocols/002_boreas
   protocols/alpha
   protocols/history

.. toctree::
   :maxdepth: 2
   :caption: Contributing
   :hidden:

   developer/contributing_index
   developer/programming
   developer/testing_index
   developer/maintaining
   README
   developer/tools
   developer/encodings
   developer/merkle-proof-encoding-formats
   api/api-inline

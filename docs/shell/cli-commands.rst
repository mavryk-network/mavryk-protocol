**********************
Command Line Interface
**********************

This document is a prettier output of the documentation produced by
the command ``man`` of the different Mavkit binaries. You can
obtain similar pages using shell commands such as:

::

   mavkit-admin-client man -verbosity 3

The rest of this page documents the protocol-independent tools.
The protocol-dependent tools are documented :doc:`here <../active/cli-commands>`.


.. _admin_client_manual:

Admin-client manual
===================

.. raw:: html
         :file: ../api/mavkit-admin-client.html


.. _signer_manual:

Signer manual
=============

.. raw:: html
         :file: ../api/mavkit-signer.html


.. _benchmark_tool_manual:

Benchmark tool manual
=====================

.. raw:: html
         :file: ../api/mavkit-snoop.html


.. _codec_manual:

Codec manual
============

.. raw:: html
         :file: ../api/mavkit-codec.html


.. _node_manual:

Node manual
===========

The command line of the Mavkit node is documented in Unix ``man`` format, as shown below. You can also obtain this manual by running ``mavkit-node --help``.

The manual briefly shows the available node commands.
Each command accepts its own set of options and arguments, that you can discover by running ``mavkit-node <command> --help``.
For more details on the node invocation and configuration, see :doc:`../user/node-configuration`.

.. include:: ../api/mavkit-node.txt

.. _proxy_server_manual:

Proxy server manual
===================

The command line of the :doc:`Mavkit proxy server <../user/proxy-server>` is documented in Unix ``man`` format, as shown below. You can also obtain this manual by running ``mavkit-proxy-server --help``.

.. include:: ../api/mavkit-proxy-server.txt

.. _dac_node_manual:

DAC node manual (Experimental)
==============================
.. raw:: html
        :file: ../api/mavkit-dac-node.html

.. _dac_client_manual:

DAC client manual (Experimental)
================================
.. raw:: html
        :file: ../api/mavkit-dac-client.html


.. _smart_rollup_node_manual:

Smart rollup node manual
========================

.. raw:: html
         :file: ../api/mavkit-smart-rollup-node.html

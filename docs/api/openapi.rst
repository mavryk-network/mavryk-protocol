RPCs - OpenAPI reference
========================

`OpenAPI <https://swagger.io/specification/>`_ is a specification format for REST APIs.
This format is supported by several tools, such as
`Swagger UI <https://swagger.io/tools/swagger-ui/>`_ which allows you to browse
a specification and perform API calls from your browser.
Several code generators also exist to generate API libraries for various
programming languages.

The REST API served by the Mavkit node on the RPC port is described by the union of several OpenAPI specifications:

- ``rpc-openapi(-rc).json``, containing the protocol-independent (or "shell") RPCs
- For each protocol in use:

  + ``$PROTOCOL-openapi.json`` (served under the prefix: ``/chains/<chain-id>/blocks/<block-id>``)
  + ``$PROTOCOL-mempool-openapi.json`` (served under the prefix: ``/chains/<chain-id>/mempool``)

For instance, for an RPC listed as ``GET /filter`` in ``$PROTOCOL-mempool-openapi.json``, its real endpoint is ``GET /chains/<chain-id>/mempool/filter``.

These OpenAPI specifications, detailed below, can be generated by running the Mavkit node as shown in section :ref:`openapi_generate`.
For convenience, the files generated from the most recent release(s) are provided in this page, annotated each time with the corresponding release (in parentheses).

.. note::
    There exists an alternative reference for the node RPCs, presented in more static pages (e.g. :doc:`../active/rpc` for the active protocol).
    However, the static referece omits some RPCs, such as the ones related to the mempool.

.. warning::
    The links below to the different OpenAPI specifications are opened using the Swagger UI integrated in GitLab.
    This UI can be used for browsing the OpenAPIs (no need to install Swagger UI for that).
    However, the interactive use suggested in this UI does not currently work because:

    - the UI does not allow one to specify a server (which should correspond to a runnning Mavryk node), and
    - browsers may block some of the generated requests or responses for security issues.

Shell RPCs
----------

.. Note: the links currently point to master because no release branch
.. currently has the OpenAPI specification.
..
.. As soon as an actual release has this specification we should update
.. this section and the next one. The idea would be to link to all release tags,
.. and have an additional link at the top to the latest-release branch.
.. We'll probably remove the link to the specification for version 7.5 at this point
.. since it does not make sense to keep it in master forever.

The node provides some RPCs which are independent of the protocol.
Their OpenAPI specification can be found at:

- `rpc-openapi.json (version 19.1) <https://gitlab.com/tezos/tezos/-/blob/master/docs/api/rpc-openapi.json>`_

.. TODO tezos/tezos#2170: add/remove section(s)

Atlas RPCs
------------

The OpenAPI specifications for RPCs which are specific to the Atlas (``PtAtLas``)
protocol can be found at:

- `atlas-openapi.json (version 19.3) <https://gitlab.com/mavryk-network/mavryk-protocol/-/blob/master/docs/api/atlas-openapi.json>`_

The OpenAPI specifications for RPCs which are related to the mempool
and specific to the Atlas protocol can be found at:

- `atlas-mempool-openapi.json (version 19.3) <https://gitlab.com/mavryk-network/mavryk-protocol/-/blob/master/docs/api/atlas-mempool-openapi.json>`_

Smart Rollup Node
~~~~~~~~~~~~~~~~~

The smart rollup node exposes different RPCs depending on the underlying L1
protocol in use. Their specification is given in the sections below.
(The exact versions of the rollup node for which these files are produced can be
seen in the field ``.info.version`` within each file.)

.. TODO tezos/tezos#2170: add/remove section(s)

Atlas RPCs
-----------

The OpenAPI specifications for the RPCs of the smart rollup node for the Atlas
(``PtAtLas``) protocol can be found at:

- `atlas-smart-rollup-node-openapi.json (version 19.1)
  <https://gitlab.com/mavryk-network/mavryk-protocol/-/blob/master/docs/api/atlas-smart-rollup-node-openapi.json>`_

.. _openapi_generate:

How to Generate
---------------

To generate the above files, run the ``src/bin_openapi/generate.sh`` script
from the root of the Mavkit repository.
It will start a sandbox node, activate the protocol,
get the RPC specifications from this node and convert them to OpenAPI specifications.

To generate the OpenAPI specification for the RPCs provided by a specific protocol,
update the following variables in :src:`src/bin_openapi/generate.sh`:

```sh
protocol_hash=ProtoALphaALphaALphaALphaALphaALphaALphaALphaDdp3zK
protocol_parameters=src/proto_alpha/parameters/sandbox-parameters.json
protocol_name=alpha
```

For ``protocol_hash``, use the value defined in ``MAVRYK_PROTOCOL``.


How to Test
-----------

You can test OpenAPI specifications using `Swagger Editor <https://editor.swagger.io/>`_
to check for syntax issues (just copy-paste ``rpc-openapi.json`` into it or open
it from menu ``File > Import file``).

You can run `Swagger UI <https://swagger.io/tools/swagger-ui/>`_ to get an interface
to browse the API (replace ``xxxxxx`` with the directory where ``rpc-openapi.json`` is,
and ``rpc-openapi.json`` by the file you want to browse)::

    docker pull swaggerapi/swagger-ui
    docker run -p 8080:8080 -e SWAGGER_JSON=/mnt/rpc-openapi.json -v xxxxxx:/mnt swaggerapi/swagger-ui

Then `open it in your browser <https://localhost:8080>`_.

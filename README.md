# Mavryk Mavkit implementation

## Introduction

Mavryk is a blockchain that offers both  _consensus_ and _meta-consensus_, by which we mean that Mavryk comes to consensus both about the state of its ledger, and  _also_ about how the
protocol and the nodes should adapt and upgrade.
For more information about the project, see https://mavrykdynamics.com.

## Getting started

Instructions to
[install](https://protocol.mavryk.org/introduction/howtoget.html), [start
using](https://protocol.mavryk.org/introduction/howtouse.html), and
[taking part in the
consensus](https://protocol.mavryk.org/introduction/howtorun.html) are
available at https://protocol.mavryk.org/.

## The Mavryk software

This repository hosts **Mavkit**, an implementation of the Mavryk blockchain.
Mavkit provides a node, a client, a baker, an accuser, and other tools, distributed with the Mavryk economic protocols of Mainnet for convenience.

In more detail, this git repository contains:
- the source code, in directory src/
- tests (mainly system tests) in an OCaml system testing framework for Mavryk called Tezt, under tezt/
- the developer documentation of the Mavryk software, under docs/
- a few third-party libraries, adapted for Mavryk, under vendors/

The Mavryk software may run either on the nodes of
the main Mavryk network (mainnet) or on [various Mavryk test
networks](https://protocol.mavryk.org/introduction/test_networks.html).

The documentation for developers, including developers of the Mavryk software
and developer of Mavryk applications and tools, is available
online at https://protocol.mavryk.org/. This documentation is always in
sync with the master branch which may however be slightly
desynchronized with the code running on the live networks.

The source code of Mavkit is placed under the [MIT Open Source
License](https://opensource.org/licenses/MIT).

## Contributing

### Development workflow

All development of the Mavryk code happens on
GitLab at https://gitlab.com/mavryk-network/mavryk-protocol. Merge requests
(https://gitlab.com/mavryk-network/mavryk-protocol/-/merge_requests) should usually
target the `master` branch; see [the contribution
instructions](https://protocol.mavryk.org/developer/contributing.html).

The issue tracker at https://gitlab.com/mavryk-network/mavryk-protocol/issues can be used
to report bugs and to request new simple features. The [Tezos Agora
forum](https://forum.tezosagora.org/) is another great place to
discuss the future of Mavryk with the community at large.

#### Continuous Integration

Running CI pipelines in your forks using GitLab's shared runners
may fail, for instance because tests may take too long to run.
The CI of `mavryk-network/mavryk-protocol` (i.e. https://gitlab.com/mavryk-network/mavryk-protocol)
uses custom runners that do not have this issue.
If you create a merge request targeting `mavryk-network/mavryk-protocol`, pipelines
for your branch will run using those custom runners.
To trigger those pipelines you need to be a developer in the
`mavryk-network/mavryk-protocol` project. Otherwise, reviewers can do that for you.

### Development of the Mavryk protocol

The core of the Mavryk software that implements the economic ruleset is
called the *protocol*. Unlike the rest of the source code, updates to the
protocol must be further adopted through the [Mavryk
on-chain voting
procedure](https://protocol.mavryk.org/whitedoc/voting.html). Protocol
contributors are encouraged to synchronize their contributions to
minimize the number of protocol proposals that the stakeholders have
to study and to maximize the throughput of the voting procedure.

## Community

Links to community websites are gathered at <https://protocol.mavryk.org/introduction/mavryk.html#the-community>.

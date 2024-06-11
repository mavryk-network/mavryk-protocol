Platform Development tools
==========================

The development and maintenance process of the Mavryk platform is facilitated by some specialized tools.
Some of these tools are included in the Mavkit repository, because of a close coupling with the code itself (see :doc:`repository_scope` for the policy of selecting such tools).
They provide, for example, support for profiling or for benchmarking different subsystems of Mavkit.

On the other hand, contributing to the development of the Mavkit repository requires installing some additional infrastructure, which is not needed by regular Mavkit users.
For instance, developers need Python for building the documentation, and also because :src:`the pre-commit hook <scripts/pre_commit/pre_commit.py>` (which executes some custom checks before committing changes) is currently written in Python.

The tools for platform developers, as well as the configuration of the additional infrastructure, are documented in the following pages.

.. toctree::
   :maxdepth: 2

   profiling
   snoop
   time_measurement_ppx
   python_environment
   pre_commit_hook

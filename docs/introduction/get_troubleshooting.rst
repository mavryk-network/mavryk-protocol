Installation troubleshooting
============================

This page groups information about known problems when installing Mavryk (more precisely, the "Mavkit" implementation of Mavryk software).
The different issues and their solutions are grouped per installation method, except for generic issues concerning all installation scenarios.

This page lists only the most frequent problems.
If you don't find your problem in this page, chances are that the problem is too specific.
Consult the :ref:`Mavryk community <mavryk_community>` (e.g. the Mavryk Stack Exchange) to see if others have encountered a similar problem, and whether a solution is known.

Generic issues
--------------

N/A

Compiling the sources
---------------------

These issues concern installing by :ref:`compiling the sources <build_from_sources>`.

Currently, the ``CONFIG_SITE`` environment variable must not be
set during the installation process, or the ``stdcompat`` package
may be installed incorrectly. See `thierry-martinez/stdcompat#13
<https://github.com/thierry-martinez/stdcompat/issues/13>`__.

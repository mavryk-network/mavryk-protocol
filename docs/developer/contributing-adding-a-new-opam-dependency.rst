How to add or update opam dependencies
======================================

When a merge request (MR) introduces a new dependency to an opam package, or
updates an existing dependency to a different version of an opam package,
additional steps must be taken in the development and merge process.
This document explains those steps.

If you have already read this guide and only need a refresher, skip to the
:ref:`TL;DR <tldr>`.

Background
----------

The Mavkit project is built under a system that is somewhat stricter than
the default for OCaml projects. The goal is to make sure that users, developers
and the CI use the exact same dependencies, with the exact same versions.
To this end:

- the set of opam dependencies and their exact version number is stored in
  :src:`an opam lock file <opam/virtual/mavkit-deps.opam.locked>`;
- the hash of the commit to use from the public opam repository is stored
  in :src:`scripts/version.sh` in the variable ``full_opam_repository_tag``;
- ``make build-deps`` and ``make build-dev-deps`` use the lock file and the hash
  to select dependencies;
- the CI uses Docker images that come with those dependencies pre-compiled.

The Docker images for the CI are built by the CI of another repository,
the so-called `Tezos opam repository <https://gitlab.com/mavryk-network/opam-repository>`__.
The set of dependencies that is used to build those images is also defined
by a lock file and a commit hash from the public opam repository.
Both must be kept synchronized with their counterpart in the ``tezos/tezos`` repository.

.. note::

    Docker images contain additional dependencies
    such as ``odoc`` which are needed by the CI but not to build Mavkit.

Adding, removing or updating dependencies thus requires to work both
on the `main codebase <https://gitlab.com/tezos/tezos>`__ and on
the `Tezos opam repository <https://gitlab.com/mavryk-network/opam-repository>`__.
Moreover, work between those two components must happen in a specific order.

The rest of this document explains the process from the point-of-view of
a developer (you). The instructions below assume you have already
:ref:`set up your work environment <build_from_sources>`
but that you installed *development* dependencies
(``make build-dev-deps`` instead of ``make build-deps``).

Local work
----------

The simplest way of using a new dependency on the Mavkit codebase when working 
locally (i.e., on your own machine) is to install it using ``opam``.

Because you have used ``make build-dev-deps`` in order to install the
Mavkit dependencies, you have access to the default opam repository in
addition to the Tezos opam repository.

**Install your dependency:** ``opam install foo``

**Add dependencies to build files:** both opam files and dune files must
be updated.
Add the dependency to the relevant declarations in :src:`manifest/main.ml`. And
then use ``make -C manifest`` to update the opam and dune files accordingly.

For example, if you are modifying the Shell using the new
dependency, you must add an entry in the ``~deps`` list of the
``let mavkit_shell =`` entry of the :src:`manifest/main.ml` and then run
``make -C manifest``. You should see the changes propagated onto
:src:`opam/mavkit-libs.opam` and :src:`src/lib_shell/dune`,
as well as :src:`opam/virtual/mavkit-deps.opam`.

You can work on your feature, using the types and values provided by
your new dependency.

Making an MR
------------

Even though you can compile and run code locally, the CI will likely fail.
This is because its set of available dependencies is now different from yours.
You must follow the steps below in order to produce the necessary Docker images,
allowing your work to eventually be merged.

First, in your local copy of Mavkit, **update the**
``full_opam_repository_tag`` **variable in the** :src:`scripts/version.sh`
**file**. You should set this variable to the commit hash of a recent version of
the ``master`` branch of
`the default opam repository <https://github.com/ocaml/opam-repository/commits/master>`__.
(Note: this is not always necessary, but it is simpler for you to do so
than to check whether it is necessary to do so.)

Second, update the opam lock file. The safest way to do that is to
**execute the** :src:`scripts/update_opam_lock.sh` **script**.
It will ask opam to upgrade all Mavkit dependencies,
making sure that unwanted package versions are not selected for dependencies,
and will update the lock file accordingly.
Note that the diff may include a few more changes than what you strictly need.
Specifically, it might include some updates of some other dependencies. This is
not an issue in general but it might explain some changes unrelated to your work.

.. note::

    If you do not wish to upgrade all dependencies,
    you can also just run ``opam lock opam/virtual/mavkit-deps.opam``
    followed by ``mv mavkit-deps.opam.locked opam/virtual``,
    or even edit the lock file manually.
    Neither of these guarantees that packages are available in the commit
    identified by ``full_opam_repository_tag`` of the public opam repository,
    and even so, you may end up with unwanted versions of dependencies;
    so you should review the resulting lock file even more carefully.
    Editing the lock file manually is even less safe than running ``opam lock``
    as it does not guarantee that the set of dependencies is actually
    a valid solution that the opam solver could have chosen.

Third, **create an MR on the Tezos opam repository.**
This is the *opam repository MR*, its role is to prepare
the environment for the *Mavkit MR* that we will create below.

In order to create the opam repository MR:

- If you haven’t already done so, clone
  `the Tezos opam repository <https://gitlab.com/mavryk-network/opam-repository>`__.
- Create a branch from the repository's ``master`` and switch to it.
- Update file ``scripts/version.sh`` (in the Tezos opam repository)
  to set the value of ``opam_repository_commit_hash``
  to match the value of ``full_opam_repository_tag`` that you have set in
  :src:`scripts/version.sh` (in the Mavkit repository).
- Copy file :src:`opam/virtual/mavkit-deps.opam.locked` (from the Mavkit repository)
  to the root of the Tezos opam repository.
- Commit the result. Take note of the commit hash, it will be useful later.
- Push your branch.
- Create the opam repository MR from this branch.

You can test the MR locally using the command
``OPAM_REPOSITORY_TAG=<commit-id> make build-deps``. This will rebuild the
dependencies locally using the ``<commit_id>`` of the opam-repository.

Fourth, back in your local copy of Mavkit, **update the** ``opam_repository_tag``
**variable in the** :src:`scripts/version.sh` **file**. Specifically, set it
to the hash of your commit on the opam repository MR.
Afterwards, you will also need to regenerate the GitLab CI configuration
by running ``make -C ci`` from the root of the repository.
Commit the change of ``scripts/version.sh`` and the GitLab configuration
with a title along the lines of “CI: use dependency ``foo``”.

This commit will point the build scripts and CI to the modified
opam-repository and the associated Docker images. Do note that the CI on your
branch of Mavkit will only be able to run after the CI on your branch of
opam-repository has completed.

Finally, still in your local copy of Mavkit, **push these changes and open
an MR on the tezos/tezos project**. Make sure you add links referencing the opam-repository MR from
the Mavkit MR and vice-versa. This gives the reviewers the necessary context to
review.

That’s it. You now have two MRs:

- The *opam-repository MR* from ``mavryk-network/opam-repository:<your-branch>``
  onto ``mavryk-network/opam-repository:master`` updates the environment in which
  the Mavkit libraries and binaries are built.
- The *Mavkit MR* from ``<your-organisation>/tezos:<your-branch>``
  onto ``tezos/tezos:master`` uses this new environment.

Merging the MR
--------------

This section is for the :doc:`Mavkit merge team <merge_team>`. It is the last
step in the lifetime
of the MRs you have opened. Understanding the basics of this process may
help you when communicating with the reviewers and the mergers of your
MR. Understanding all the minutiae and details is not necessary. For
this reason, this final section is addressed to whichever member of the
Mavkit merge team takes care of this MR (you).

After the iterative review-comment-edit process has reached a satisfying
fixpoint, you can merge the two MRs opened by the developer. To avoid
interference with other MRs, it is better to perform all the steps
described below relatively quickly (the same day).

First, **mention the MR on the** ``#opam-repo`` **Slack channel** and make sure
there isn't another merge ongoing.

Second, **merge the opam-repository MR**.
Make sure that **the commit hash of** ``master`` **is the value of**
``opam_repository_tag`` in :src:`scripts/version.sh`.
The hash could have changed if a merge commit was introduced, if the branch
had to be rebased, if it was squashed, etc.
This is important because the name of the Docker images is based on this hash.

Finally, **assign the Mavkit MR to Marge Bot** for merging.

.. _tldr:

TL;DR
-----

As a developer:

- You have an Mavkit MR from ``<your-organisation>/mavryk-protocol:<your-branch>``
  onto ``mavryk-network/mavryk-protocol:master`` introducing a dependency to ``foo``.
- You amend the :src:`manifest/main.ml` file to declare the dependency.
- You propagate the changes to ``opam`` and ``dune`` files by running ``make -C manifest``.
- You update the ``full_opam_repository_tag`` to the commit hash of
  a recent version of the public default opam repository.
- You update :src:`opam/virtual/mavkit-deps.opam.locked`,
  for instance by executing :src:`scripts/update_opam_lock.sh`.
- You open an opam repository MR from ``mavryk-network/opam-repository:<your-branch>``
  onto ``mavryk-network/opam-repository:master`` that updates:

  - variable ``opam_repository_commit_hash`` in ``scripts/version.sh``;
  - file ``mavkit-deps.opam.locked`` at the root.

- You update ``opam_repository_tag`` to the hash of the last commit of your opam repository MR
  and regenerate the CI configuration.
- You push the changes to your Mavkit MR.
- You update the descriptions of your MRs to include links between them.

As a merger:

- You test, review, etc. the code.
- You merge the opam repository MR.
- You make sure the commit hash has been preserved by merging
  (no squashing, no rebasing, no merge commit…).
- You assign the Mavkit MR to Marge Bot.

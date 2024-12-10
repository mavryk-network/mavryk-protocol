#!/bin/sh

## Sourceable file with common variables for other scripts related to release

# shellcheck disable=SC2034
architectures='x86_64 arm64'

current_dir=$(cd "$(dirname "${0}")" && pwd)
scripts_dir=$(dirname "$current_dir")
src_dir=$(dirname "$scripts_dir")
script_inputs_dir="$src_dir/script-inputs"

binaries="$(cat "$script_inputs_dir/released-executables")"

mavkit_source_content="$script_inputs_dir/mavkit-source-content"

### Compute GitLab release names from git tags

# Git tags for mavkit releases are on the form `mavkit-vX.Y`, `mavkit-vX.Y-rcZ` or `mavkit-vX.Y-betaZ`.

# Full mavkit release tag
# mavkit-vX.Y, mavkit-vX.Y-rcZ or mavkit-vX.Y-betaZ
gitlab_release=$(echo "${CI_COMMIT_TAG}" | grep -oE '^mavkit-v([0-9]+)\.([0-9]+)$' || :)

# Strips the leading 'mavkit-v'
# X.Y, X.Y-rcZ or X.Y-betaZ
gitlab_release_no_v=$(echo "${CI_COMMIT_TAG}" | sed -e 's/^mavkit-v//g')

# Replace '.' with '-'
# X-Y or X-Y-rcZ
# shellcheck disable=SC2034
gitlab_release_no_dot=$(echo "${gitlab_release_no_v}" | sed -e 's/\./-/g')

# X
gitlab_release_major_version=$(echo "${CI_COMMIT_TAG}" | sed -nE 's/^mavkit-v([0-9]+)\.([0-9]+)(-rc[0-9]+)?$/\1/p')
# Y
gitlab_release_minor_version=$(echo "${CI_COMMIT_TAG}" | sed -nE 's/^mavkit-v([0-9]+)\.([0-9]+)(-rc[0-9]+)?$/\2/p')
# Z
gitlab_release_rc_version=$(echo "${CI_COMMIT_TAG}" | sed -nE 's/^mavkit-v([0-9]+)\.([0-9]+)(-rc)?([0-9]+)?$/\4/p')

# Is this a release candidate?
if [ -n "${gitlab_release_rc_version}" ]; then
  # Yes, release name: X.Y~rcZ
  # shellcheck disable=SC2034
  gitlab_release_name="Mavkit Release Candidate ${gitlab_release_major_version}.${gitlab_release_minor_version}~rc${gitlab_release_rc_version}"
  opam_release_tag="${gitlab_release_major_version}.${gitlab_release_minor_version}~rc${gitlab_release_rc_version}"
else
  # No, release name: Mavkit Release X.Y
  # shellcheck disable=SC2034
  gitlab_release_name="Mavkit Release ${gitlab_release_major_version}.${gitlab_release_minor_version}"
  opam_release_tag="${gitlab_release_major_version}.${gitlab_release_minor_version}"
fi

### Compute GitLab generic package names

gitlab_mavkit_binaries_package_name="mavkit-binaries-${gitlab_release_no_v}"
gitlab_mavkit_debian_bookworm_package_name="mavkit-debian-bookworm-${gitlab_release_no_v}"
gitlab_mavkit_ubuntu_focal_package_name="mavkit-ubuntu-focal-${gitlab_release_no_v}"
gitlab_mavkit_ubuntu_jammy_package_name="mavkit-ubuntu-jammy-${gitlab_release_no_v}"
gitlab_mavkit_ubuntu_noble_package_name="mavkit-ubuntu-noble-${gitlab_release_no_v}"
gitlab_mavkit_fedora_package_name="mavkit-fedora-${gitlab_release_no_v}"
gitlab_mavkit_rockylinux_package_name="mavkit-rockylinux-${gitlab_release_no_v}"
gitlab_mavkit_source_package_name="mavkit-source-${gitlab_release_no_v}"

# X.Y or X.Y-rcZ
gitlab_package_version="${gitlab_release_no_v}"

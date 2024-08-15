#!/usr/bin/env bash

set -e

ci_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"
script_dir="$(dirname "$ci_dir")"

opam_repository_fork="git@github.com:mavryk-network/opam-repository"
opam_dir="opam-repository"

log() {
  printf '\e[1m%s\e[0m' "$1"
}

# shellcheck source=./scripts/ci/mavkit-release.sh
. "$ci_dir/mavkit-release.sh"

# set up ssh credentials to access github
mkdir -p "$HOME/.ssh"
echo "$MAVRYK_GITHUB_OPAM_REPOSITORY_MACHINE_USER_PRIVATE_SSH_KEY" | base64 -d > "$HOME/.ssh/id_rsa"
# cp "$MAVRYK_GITHUB_OPAM_REPOSITORY_MACHINE_USER_PRIVATE_SSH_KEY" "$HOME/.ssh/id_rsa"
cat "$GITHUB_SSH_HOST_KEYS" >> "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/id_rsa"
chmod 700 "$HOME/.ssh"
log "Done setting up credentials."

# call opam-release.sh with the correct arguments
echo "$script_dir/opam-release.sh" \
  "$opam_release_tag" \
  "https://gitlab.com/mavryk-network/mavryk-protocol/-/archive/$CI_COMMIT_TAG/$gitlab_mavkit_source_package_name.tar.gz" \
  "$opam_dir"

"$script_dir/opam-release.sh" \
  "$opam_release_tag" \
  "https://gitlab.com/mavryk-network/mavryk-protocol/-/archive/$CI_COMMIT_TAG/$gitlab_mavkit_source_package_name.tar.gz" \
  "$opam_dir"

# Matches the corresponding variable in /scripts/opam-release.sh.
branch_name="mavkit-$(echo "$opam_release_tag" | tr '~' -)"

log "While we're here, update master on the fork..."
cd "$opam_dir"
git remote add github "$opam_repository_fork"
git push github master:master

log "Pushing $branch_name to $opam_repository_fork..."
git push --force-with-lease github "${branch_name}:${branch_name}"

log "Create the pull request at:"
log "https://github.com/ocaml/opam-repository/compare/master...mavryk-network:opam-repository:${branch_name}"

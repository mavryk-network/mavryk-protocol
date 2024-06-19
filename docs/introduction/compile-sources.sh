#!/bin/sh
# shellcheck source=/dev/null
# for not checking the existence of sourced file $HOME/.cargo/env
# shellcheck disable=SC2046
# for omitting quotes in: eval $(opam env)
# shellcheck disable=SC2086
# for omitting quotes in: source $HOME/.cargo/env

usage () {
    cat >&2 <<!EOF
usage:
  $0 [<repo> <branch>]
!EOF
}

if [ $# -eq 2 ]
then
  REPO=$1
  BRANCH=$2
elif [ $# -eq 0 ]  # don't remove this branch used for an example in the doc!
then
  # [select branch]
  REPO="mavryk-network/mavryk-protocol"
  BRANCH="latest-release"
  # [end]
else
  usage
  exit 1
fi

set -e
set -x
cd
# [install prerequisites]
sudo apt-get update
sudo apt-get install -y sudo
export OPAMYES=true
# [install packages]
# [Temporary fix: removes mavryk folder from PATH if added with Mavkit <= v13 instructions]
PATH=${PATH##"$HOME"/tezos/:}
sudo apt-get install -y rsync git m4 build-essential patch unzip wget opam jq bc
# [install rust]
wget https://sh.rustup.rs/rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh --profile minimal --default-toolchain 1.71.1 -y
# [source cargo]
. $HOME/.cargo/env
# [get sources]
git clone https://gitlab.com/"$REPO".git mavryk
cd mavryk
git checkout $BRANCH
# [install Mavkit dependencies]
opam init --bare
make build-deps
# [compile sources]
eval $(opam env)
make
# [optional setup]
# puts Mavkit binaries in PATH:
# export PATH=$PWD/_build/install/default/bin/:$PATH
# if using bash, enables autocompletion:
# source ./src/bin_client/bash-completion.sh
# removes Mainnet/testnet disclaimers:
# export MAVRYK_CLIENT_UNSAFE_DISABLE_DISCLAIMER=Y
# [test executables]
./mavkit-client --version
./mavkit-node --version
./mavkit-baker-alpha --version
./mavkit-accuser-alpha --version

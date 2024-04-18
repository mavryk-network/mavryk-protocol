#!/bin/sh

usage () {
    cat >&2 <<!EOF
usage:
  $0 [rc]
!EOF
}

if [ $# -eq 1 ] && [ "$1" = "rc" ]
then
  # [setup rc repository]
  REPO="@Serokell/Tezos-rc"
  # [end]
elif [ $# -eq 0 ]
then
  # [setup stable repository]
  REPO="@Serokell/Tezos"
  # [end]
else
  usage
  exit 1
fi

# TODO tezos/tezos#2170: search shifted protocol name/number & adapt
set -e
set -x
# [install prerequisites]
dnf install -y dnf-plugins-core
# [install tezos]
dnf copr enable -y $REPO && dnf update -y
dnf install -y mavryk-client
dnf install -y mavryk-node
dnf install -y mavryk-baker-PtNairob
dnf install -y mavryk-accuser-PtNairob
# [test executables]
mavkit-client --version
mavkit-node --version
mavkit-baker-PtNairob --version
mavkit-accuser-PtNairob --version

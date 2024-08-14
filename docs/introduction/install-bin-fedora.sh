#!/bin/sh

usage() {
  cat >&2 << !EOF
usage:
  $0 [rc]
!EOF
}

if [ $# -eq 1 ] && [ "$1" = "rc" ]; then
  # [setup rc repository]
  REPO="@MavrykDynamics/Mavryk-rc"
  # [end]
elif [ $# -eq 0 ]; then
  # [setup stable repository]
  REPO="@MavrykDynamics/Mavryk"
  # [end]
else
  usage
  exit 1
fi

# TODO mavryk-network/mavryk-protocol#2170: search shifted protocol name/number & adapt
set -e
set -x
# [install prerequisites]
dnf install -y dnf-plugins-core
# [install mavryk]
dnf copr enable -y $REPO && dnf update -y
dnf install -y mavryk-client
dnf install -y mavryk-node
dnf install -y mavryk-baker-PtAtLas
dnf install -y mavryk-accuser-PtAtLas
# [test executables]
mavkit-client --version
mavkit-node --version
mavkit-baker-PtAtLas --version
mavkit-accuser-PtAtLas --version

#!/bin/sh

usage() {
  cat >&2 << !EOF
usage:
  $0 [rc]
!EOF
}

if [ $# -eq 1 ] && [ "$1" = "rc" ]; then
  # [setup rc repository]
  REPO="ppa:mavrykdynamics/mavryk-rc"
  # [end]
elif [ $# -eq 0 ]; then
  # [setup stable repository]
  REPO="ppa:mavrykdynamics/mavryk"
  # [end]
else
  usage
  exit 1
fi

# TODO: https://gitlab.com/tezos/tezos/-/issues/6552
# Mavryk ubuntu packages cannot be installed in a k8s pod.
if [ -n "${FF_KUBERNETES_HONOR_ENTRYPOINT}" ]; then
  echo "Container orchestrated by Kubernetes detected, need to create the file /.dockerenv."
  echo "See https://github.com/mavryk-network/mavryk-packaging/issues/734 for further explanation."
  echo "Note: Remove this workaround when the issue above is fixed."
  touch /.dockerenv
fi
# TODO mavryk-network/mavryk-protocol#2170: search shifted protocol name/number & adapt
set -e
set -x
# [install prerequisites]
apt-get update
apt-get install sudo
apt-get install -y software-properties-common < /dev/null
# [install mavryk]
sudo add-apt-repository -y $REPO && sudo apt-get update
sudo apt-get install -y mavryk-client
sudo apt-get install -y mavryk-node
sudo apt-get install -y mavryk-baker-ptatlas
sudo apt-get install -y mavryk-accuser-ptatlas
# [test executables]
mavkit-client --version
mavkit-node --version
mavkit-baker-PtAtLas --version
mavkit-accuser-PtAtLas --version

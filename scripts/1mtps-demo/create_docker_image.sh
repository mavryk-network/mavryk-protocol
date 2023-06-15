#!/bin/bash

target="${1}"
docker_base=""
install_script=""

case "${target}" in
  "archlinux")
    docker_image="archlinux:base"
    install_script="scripts/1mtps-demo/install_archlinux.sh"
    ;;
  *)
    echo "unsupported distribution target: ${target}"
    exit 1
    ;;
esac

docker build -f scripts/1mtps-demo/demo.Dockerfile \
  --build-arg "BASE_IMAGE_AND_VERSION=${docker_image}" \
  --build-arg "INSTALL_SCRIPT=${install_script}" \
  -t "1mtps-demo-$target:latest" \
  "."

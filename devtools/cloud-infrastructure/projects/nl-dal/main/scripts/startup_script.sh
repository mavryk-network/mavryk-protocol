#!/bin/bash

# FIXME https://gitlab.com/tezos/tezos/-/issues/6216
#
# We need to parameterize these variables.

docker_registry_url="europe-west1-docker.pkg.dev/nl-dal/docker-registry"

docker_image_name="debian-mavryk"

docker run -p 30000-30999:30000-30999 --name mavryk $docker_registry_url/$docker_image_name:latest


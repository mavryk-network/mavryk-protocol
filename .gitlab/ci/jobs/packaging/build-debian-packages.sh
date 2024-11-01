#!/bin/sh
set -e

deps_opam_repository_tag=$(cat /root/mavryk/opam_repository_tag)
. scripts/version.sh

if [ "$deps_opam_repository_tag" != "$opam_repository_tag" ]; then
  echo "Dependency tag: $deps_opam_repository_tag"
  echo "Actual tag: $opam_repository_tag"
  echo "The dependency image is outdated. Please rebuild before lunching this job"
  exit 1
fi

BUILDDIR=$(pwd)

# Prepare the building area: copying all files from
# the dependency image a staging area. This is necessary
# to build on arm64 where the BUILDDIR is in ram.
cp -a ./* /root/mavryk/
cd /root/mavryk/

# Build mavryk as usual
eval "$(opam env)"
make all

# Prepare the packaging by copying all the freshly compiled binaries
mkdir -p scripts/packaging/mavkit/binaries
mkdir -p scripts/packaging/mavkit/zcash-params
cp mavkit-* scripts/packaging/mavkit/binaries/

# Copy the zcash parametes to be packaged
cp -a _opam/share/zcash-params scripts/packaging/mavkit/

# Build the debian packages
cd scripts/packaging/mavkit/
DEB_BUILD_OPTIONS=noautodbgsym dpkg-buildpackage -b --no-sign -sa

# Move the debian package to be packed as artifacts
mkdir -p "$BUILDDIR/packages/$DISTRIBUTION/$RELEASE"
mv ../*.deb "$BUILDDIR/packages/$DISTRIBUTION/$RELEASE"

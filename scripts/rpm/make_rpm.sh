#!/bin/sh

# RPM package build for Mavkit
#
# (c) Chris Pinnock 2023, Supplied under a MIT license.
# see ../pkg-common/utils.sh for more detail

set -eu

# Setup
#
myhome=scripts/rpm
common=scripts/pkg-common
dieonwarn=${dieonwarn:-1}

#shellcheck disable=SC1091
. ${common}/utils.sh
protocols=${protocols:?protocols not specified}

warnings
pkg_vers=$(getMavkitVersion)

### RPM specifc

# Checking prerequisites
#
if ! which rpmbuild >/dev/null 2>&1; then
  echo "Needs to run on a system with rpmbuild in path" >&2
  echo "yum install rpmdevtools"
  exit 2
fi

rpmdev-setuptree
rpmbuild_root=$HOME/rpmbuild  # Seems to be standard
spec_dir="${rpmbuild_root}/SPECS"
rpm_dir="${rpmbuild_root}/RPMS"
src_dir="${rpmbuild_root}/SOURCES"

# Get the local architecture
#
rpm_arch=$(uname -m)

# For each spec file in the directory, build a package
#
for specfile in "$myhome"/*spec.in; do
  pg=$(basename "$specfile" | sed -e 's/-spec.in$//g')
  echo "===> Building package $pg v$pkg_vers rev $MAVKIT_PKGREV"

  # Derivative variables
  #
  rpm_name=${MAVKIT_PKGNAME}-${pg}
  init_name=${MAVKIT_REALNAME}-${pg}
  rpm_fullname="${rpm_name}-${pkg_vers}-${MAVKIT_PKGREV}.${rpm_arch}.rpm"

  binaries=$(fixBinaryList "${common}/${pg}-binaries")


  if [ -f "$rpm_fullname" ]; then
    echo "built already - skipping"
        continue
  fi

  tar_name=${rpm_name}-${pkg_vers}
  # Populate the staging directory with control scripts
  # binaries and configuration as appropriate
  #
  staging_dir="_rpmbuild"
  build_dir="${staging_dir}/${tar_name}"

  rm -rf "${staging_dir}"
  mkdir -p "${build_dir}"

  if [ -n "$binaries" ]; then
    echo "=> Populating directory with binaries"
    mkdir -p "${build_dir}/usr/bin"
    for bin in ${binaries}; do
      if [ -f "${bin}" ]; then
        echo "${bin}"
        install -s -t "${build_dir}/usr/bin" "${bin}"
      else
        echo "WARN: ${bin} not found"
                                [ "$dieonwarn" = "1" ] && exit 1
      fi
    done
  fi


  # init.d scripts
  #
  initdScripts "${common}/${pg}.initd.in" "${init_name}" "${build_dir}"
    if [ "$pg" = "baker" ]; then
    initdScripts "${common}/vdf.initd.in" mavkit-vdf \
      "${build_dir}"
  fi


  # Configuration files
  #
  if [ -f "${common}/${pg}.conf" ]; then
    echo "=> Config files"
    mkdir -p "${build_dir}/etc/mavkit"
    expand_PROTOCOL "${common}/${pg}.conf" > "${build_dir}/etc/mavkit/${pg}.conf"
  fi

  # Zcash parameters must ship with the node
  #
  zcashParams "${common}/${pg}-zcash" "${build_dir}/usr/share/zcash-params"

  # Edit the spec file to contain real values
  #
  spec_file="${pg}.spec"
  sed -e "s/@ARCH@/${rpm_arch}/g" -e "s/@VERSION@/$pkg_vers/g" \
    -e "s/@REVISION@/${MAVKIT_PKGREV}/g" \
    -e "s/@MAINT@/${MAVKIT_PKGMAINTAINER}/g" \
    -e "s/@PKG@/${rpm_name}/g" \
    -e "s/@DPKG@/${MAVKIT_PKGNAME}/g" \
    -e "s/@FAKESRC@/${tar_name}.tar.gz/g" < "$specfile" \
    > "${spec_dir}/${spec_file}"

  # Stage the package
  #
  echo "=> Staging ${pg}"
  (cd ${staging_dir} && tar zcf "${src_dir}/${tar_name}.tar.gz" "${tar_name}" )

  # Build the package
  #
  echo "=> Constructing RPM package ${rpm_fullname}"
  _flags="--quiet"
  rpmbuild -bb ${_flags} "${spec_dir}/${spec_file}"
  if [ -f "${rpm_dir}/${rpm_arch}/${rpm_fullname}" ]; then
    mv "${rpm_dir}/${rpm_arch}/${rpm_fullname}" .
  fi
done

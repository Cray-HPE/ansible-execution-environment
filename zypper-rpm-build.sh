#!/bin/bash
#
# MIT License
#
# (C) Copyright 2025 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#

# * There is a bug in curl that breaks some operations
#   https://github.com/curl/curl/issues/13229
#   We know that it is not yet present in curl v8.5 and is fixed in v8.8.
# * There is a CVE that exists in curl v8 up until v8.8
#
# However, the latest curl version in the SLES repos (up through SP7,
# the latest available) is 8.6. So this workaround builds curl v8.15 from
# source

# Preconditions:
# 1. Following variables have been set in the Dockerfile: SP ARCH

set -e +xv
trap "rm -rf /root/.zypp" EXIT

# Get artifactory credentials and use them to set the csm-rpms stable sles15sp$SP repository URI
ARTIFACTORY_USERNAME=$(test -f /run/secrets/ARTIFACTORY_READONLY_USER && cat /run/secrets/ARTIFACTORY_READONLY_USER)
ARTIFACTORY_PASSWORD=$(test -f /run/secrets/ARTIFACTORY_READONLY_TOKEN && cat /run/secrets/ARTIFACTORY_READONLY_TOKEN)
CREDS=${ARTIFACTORY_USERNAME:-}
# Append ":<password>" to credentials variable, if a password is set
[[ -z ${ARTIFACTORY_PASSWORD} ]] || CREDS="${CREDS}:${ARTIFACTORY_PASSWORD}"
SLES_MIRROR_URL="https://${CREDS}@artifactory.algol60.net/artifactory/sles-mirror"
SLES_PRODUCTS_URL="${SLES_MIRROR_URL}/Products"
SLES_UPDATES_URL="${SLES_MIRROR_URL}/Updates"
PKG_DIR="/usr/src/packages"
RPM_DIR="${PKG_DIR}/RPMS"

DEST_REPO_DIR="/curl-rpms"

function run_cmd_retry
{
    local num rc
    num=0
    while [[ $num -lt 5 ]]; do
        [[ $num -eq 0 ]] || sleep 5
        echo "# $*"
        "$@" && return 0 || rc=$?
        echo "Command failed with rc $rc"
        let num+=1
    done
    echo "Command failed even after retries"
    return $rc
}

function add_zypper_repos {
    local label repo_sp
    label=$1
    if [[ $# -eq 2 ]]; then
        repo_sp=$2
    else
        repo_sp=${SP}
    fi
    run_cmd_retry zypper --non-interactive ar "${SLES_PRODUCTS_URL}/SLE-${label}/15-SP${repo_sp}/${ARCH}/product/?auth=basic" "sles15sp${repo_sp}-${label}-product"
    run_cmd_retry zypper --non-interactive ar "${SLES_UPDATES_URL}/SLE-${label}/15-SP${repo_sp}/${ARCH}/update/?auth=basic" "sles15sp${repo_sp}-${label}-update"
}

function remove_zypper_repos {
    local label repo_sp
    label=$1
    if [[ $# -eq 2 ]]; then
        repo_sp=$2
    else
        repo_sp=${SP}
    fi
    run_cmd_retry zypper --non-interactive rr "sles15sp${repo_sp}-${label}-product"
    run_cmd_retry zypper --non-interactive rr "sles15sp${repo_sp}-${label}-update"
}

function zypper_in
{
    echo "run_cmd_retry zypper --non-interactive in --force-resolution --no-confirm --no-recommends --solver-focus Installed $*"
    run_cmd_retry zypper \
        --non-interactive in \
        --force-resolution \
        --no-confirm \
        --no-recommends \
        --solver-focus Installed \
        "$@"
}

function zypper_src_in
{
    run_cmd_retry zypper \
        --non-interactive source-install \
        --force-resolution \
        --no-recommends \
        --solver-focus Installed \
        "$@"
}

function build_rpm
{
    pushd "${PKG_DIR}"
    rpmbuild -ba SPECS/${1}.spec
    popd
}


if [[ ${SP} -lt 5 ]]; then
    # The mirrors for these earlier SLES SPs are no longer available
    echo "ERROR: SP == $SP, but must be 5+" >&2
    exit 1
fi

run_cmd_retry zypper --non-interactive rr --all
run_cmd_retry zypper --non-interactive clean -a

for MODULE in Basesystem Certifications Containers Development-Tools Python3; do
    add_zypper_repos "Module-${MODULE}"
done

run_cmd_retry zypper --non-interactive --gpg-auto-import-keys refresh

zypper_in \
    libopenssl1_1 \
    python311-devel \
    python311-pip gcc \
    libopenssl-devel \
    openssh \
    less \
    catatonit \
    rsync \
    glibc-locale-base \
    jq \
    ca-certificates \
    rpm-build \
    createrepo_c

run_cmd_retry zypper --non-interactive ar https://download.opensuse.org/tumbleweed/repo/src-oss/ tumbleweed-src-oss
run_cmd_retry zypper --non-interactive --gpg-auto-import-keys refresh

# nghttp3-devel and libnghttp3 are needed to build curl, so first we build those
zypper_src_in nghttp3

build_rpm nghttp3

TMPREPO=$(mktemp -d)
mkdir -pv ${RPM_DIR}/noarch ${RPM_DIR}/${ARCH}
mv -v ${RPM_DIR}/noarch ${RPM_DIR}/${ARCH} ${TMPREPO}
mkdir -pv ${RPM_DIR}/noarch ${RPM_DIR}/${ARCH}
createrepo_c ${TMPREPO}
run_cmd_retry zypper --non-interactive ar --refresh --no-gpgcheck ${TMPREPO} built-rpms
zypper --non-interactive search -r built-rpms '*' \
    | grep -E '\| package$' \
    | cut -d\| -f2 \
    | xargs zypper \
        --non-interactive in \
        --force-resolution \
        --no-confirm \
        --no-recommends \
        --solver-focus Installed
run_cmd_retry zypper --non-interactive rr built-rpms
rm -rf ${TMPREPO}

zypper_src_in 'curl>=8.8' 'libcurl4>=8.8'

# We are done with the source repo
run_cmd_retry zypper --non-interactive rr tumbleweed-src-oss

build_rpm curl
mkdir /built-rpms
mkdir -pv ${RPM_DIR}/noarch ${RPM_DIR}/${ARCH}
mv -v ${RPM_DIR}/noarch ${RPM_DIR}/${ARCH} ${DEST_REPO_DIR}
createrepo_c ${DEST_REPO_DIR}

exit 0

#!/bin/bash
#
# MIT License
#
# (C) Copyright 2023-2024 Hewlett Packard Enterprise Development LP
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

# This script is called during the Docker image build.
# It isolates the zypper operations, some of which require artifactory authentication,
# and scrubs the zypper environment after the necessary operations are completed.

# Preconditions:
# 1. Following variables have been set in the Dockerfile: SP ARCH CSM_SSH_KEYS_VERSION
# 2. zypper-refresh-patch-clean.sh script has also been copied into the current directory

# Based in part on: https://github.com/Cray-HPE/uai-images/blob/main/uai-images/broker_uai/zypper.sh

set -e +xv
trap "rm -rf /root/.zypp" EXIT

# Get artifactory credentials and use them to set the csm-rpms stable sles15sp$SP repository URI
ARTIFACTORY_USERNAME=$(test -f /run/secrets/ARTIFACTORY_READONLY_USER && cat /run/secrets/ARTIFACTORY_READONLY_USER)
ARTIFACTORY_PASSWORD=$(test -f /run/secrets/ARTIFACTORY_READONLY_TOKEN && cat /run/secrets/ARTIFACTORY_READONLY_TOKEN)
CREDS=${ARTIFACTORY_USERNAME:-}
# Append ":<password>" to credentials variable, if a password is set
[[ -z ${ARTIFACTORY_PASSWORD} ]] || CREDS="${CREDS}:${ARTIFACTORY_PASSWORD}"
CSM_SLES_REPO_URI="https://${CREDS}@artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp${SP}?auth=basic"
CSM_NOOS_REPO_URI="https://${CREDS}@artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/noos?auth=basic"
SLES_MIRROR_URL="https://${CREDS}@artifactory.algol60.net/artifactory/sles-mirror"
SLES_PRODUCTS_URL="${SLES_MIRROR_URL}/Products"
SLES_UPDATES_URL="${SLES_MIRROR_URL}/Updates"

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
    run_cmd_retry zypper \
        --non-interactive in \
        --force-resolution \
        --no-confirm \
        --no-recommends \
        --solver-focus Installed \
        "$@"
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

# libopenssl1_1 is needed for cray-aee
zypper_in libopenssl1_1

#############################################################################
# curl bug workaround pt 1
#############################################################################
# * There is a bug in curl that breaks some operations
#   https://github.com/curl/curl/issues/13229
#   We know that it is not yet present in curl v8.5 and is fixed in v8.8.
# * There is a CVE that exists in curl v8 up until v8.8
#
# However, the latest curl version in the SLES repos (up through SP7,
# the latest available) is 8.6. So this workaround builds curl v8.15 from
# source

function zypper_src_in
{
    run_cmd_retry zypper \
        --non-interactive source-install \
        --force-resolution \
        --no-recommends \
        --solver-focus Installed \
        "$@"
}

PKG_DIR="/usr/src/packages"

function get_rpms
{
    RPMS=$(ls ${PKG_DIR}/RPMS/noarch/*.rpm ${PKG_DIR}/RPMS/${ARCH}/*.rpm 2>/dev/null || true)
    [[ -z ${RPMS} ]] || return 0
    echo "ERROR: No RPMs found under ${PKG_DIR}/RPMS/noarch or ${PKG_DIR}/RPMS/${ARCH}" 1>&2
    exit 1
}

function build_rpm
{
    pushd "${PKG_DIR}"
    rpmbuild -ba SPECS/${1}.spec
    popd
}

# rpm-build will be needed to build packages, which we do later
zypper_in rpm-build

run_cmd_retry zypper --non-interactive ar https://download.opensuse.org/tumbleweed/repo/src-oss/ tumbleweed-src-oss
run_cmd_retry zypper --non-interactive --gpg-auto-import-keys refresh

# nghttp3-devel and libnghttp3 are needed to build curl, so first we build those
zypper_src_in nghttp3

# We are done with the source repo
run_cmd_retry zypper --non-interactive rr tumbleweed-src-oss

build_rpm nghttp3

# This will set the $RPMS variable to the RPMs we want to install
get_rpms
zypper_in --allow-unsigned-rpm ${RPMS}
rm -v ${RPMS}

zypper_src_in 'curl>=8.8' 'libcurl4>=8.8'
build_rpm curl

# We are now done with rpm builds
run_cmd_retry zypper --non-interactive rm --no-confirm --force-resolution --no-clean-deps rpm-build

#############################################################################
# end curl bug workaround pt 1
#############################################################################

run_cmd_retry zypper --non-interactive ar --no-gpgcheck "${CSM_SLES_REPO_URI}" csm-sles
run_cmd_retry zypper --non-interactive ar --no-gpgcheck "${CSM_NOOS_REPO_URI}" csm-noos
run_cmd_retry zypper --non-interactive --gpg-auto-import-keys refresh
run_cmd_retry zypper --non-interactive in --no-confirm python311-devel python311-pip gcc libopenssl-devel openssh less catatonit rsync glibc-locale-base jq ca-certificates
run_cmd_retry zypper --non-interactive in -f --no-confirm csm-ssh-keys-${CSM_SSH_KEYS_VERSION}
# Lock the version of csm-ssh-keys, just to be certain it is not upgraded inadvertently somehow later
run_cmd_retry zypper --non-interactive al csm-ssh-keys
# Apply security patches (this script also does a zypper clean)
./zypper-refresh-patch-clean.sh

#############################################################################
# curl bug workaround pt 2
#############################################################################

# Replacing curl will break zypper, libzypp, and container-suseconnect
# Kind of sad to make zypper uninstall itself, but nothing to be done about it.
run_cmd_retry zypper --non-interactive rm --no-confirm --force-resolution --no-clean-deps container-suseconnect zypper libzypp

# This will set the $RPMS variable to the RPMs we want to update (the curl RPMs we built earlier)
get_rpms
rpm -F --nosignature ${RPMS}

# Remove RPM build dir entirely
rm -rvf "${PKG_DIR}"

#############################################################################
# end curl bug workaround pt 2
#############################################################################

# Scrub the zypper directory 
[[ ! -d /etc/zypp ]] || rm -rf /etc/zypp

# Manually set the links that SLES neglects to do for us
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3.11 99
update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 99
update-alternatives --install /usr/bin/pydoc3 pydoc3 /usr/bin/pydoc3.11 99
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 99

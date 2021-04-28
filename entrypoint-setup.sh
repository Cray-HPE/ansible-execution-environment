#!/usr/bin/env sh
# Copyright 2019-2021 Hewlett Packard Enterprise Development LP
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# (MIT License)
#
# Script for setting up the Ansible content

set -e

# Add Cray defaults to group_vars/all
CRAY_DEFAULTS_FILE=/cray_ansible_defaults.yaml
ANSIBLE_DIR=/etc/ansible
INVENTORY_DIR=${ANSIBLE_DIR}/hosts
GROUPVARS_DIR=${INVENTORY_DIR}/group_vars
GROUPVARS_FILE=${GROUPVARS_DIR}/all
CRAY_GROUPVARS_FILE=${GROUPVARS_FILE}/cray_cfs_environment.yaml
INVENTORY_COMPLETE_FILE=/inventory/complete


# Copy the immutable content mounted in the inventory directory into the ansible
# inventory directory. This can be a no-op (there isn't any custom config content
# pumped in).
until [ -f "${INVENTORY_COMPLETE_FILE}" ] ;
do
  echo "Waiting for Inventory"
  sleep 3
done

COMPLETE=$(cat $INVENTORY_COMPLETE_FILE)
if [ -n "${COMPLETE}" ] && [ $COMPLETE -ne 0 ]; then
  echo "Inventory generation failed. Exiting";
  exit 1
fi
echo "Inventory generation completed"

mkdir -p /root/.ssh
cp -a /inventory/ssh/* /root/.ssh
chmod 600 /root/.ssh/id_ecdsa
echo "SSH keys migrated to /root/.ssh"

cp -r /inventory/* /etc/ansible/

if [ ! -d "${GROUPVARS_DIR}" ]; then
  mkdir $GROUPVARS_DIR
fi
if [ -d "${GROUPVARS_FILE}" ] ; then
    echo "---" > $CRAY_GROUPVARS_FILE;
    cat $CRAY_DEFAULTS_FILE >> $CRAY_GROUPVARS_FILE;
else
    if [ -f "${GROUPVARS_FILE}" ]; then
        cat $CRAY_DEFAULTS_FILE >> $GROUPVARS_FILE
    else
    	echo "---" > $GROUPVARS_FILE;
        cat $CRAY_DEFAULTS_FILE >> $GROUPVARS_FILE;
    fi
fi

until curl --head localhost:15000 ;
do
  echo "Waiting for Sidecar"
  sleep 3
done
echo Sidecar available

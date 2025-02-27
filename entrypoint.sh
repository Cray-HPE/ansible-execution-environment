#!/usr/bin/env sh
#
# MIT License
#
# (C) Copyright 2019-2025 Hewlett Packard Enterprise Development LP
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
# Entrypoint for CMS Ansible Execution Environment (aee)

/entrypoint-setup.sh

if [ $? -ne 0 ]; then
    exit 1;
fi

ANSIBLE_DIR=/etc/ansible

export ARA_DEFAULT_LABELS=$SESSION_NAME
export ARA_RECORD_CONTROLLER=false
export ARA_RECORD_USER=false

for layer in $(echo "${@}" | jq -c .[]); do
    export SESSION_CLONE_URL=$(echo "${layer}" | jq -r .clone_url)
    export SESSION_PLAYBOOK=$(echo "${layer}" | jq -r .playbook)
    export LAYER_CURRENT=$(echo "${layer}" | jq -r .layer)
    LAYER_DIR=${ANSIBLE_DIR}/layer${LAYER_CURRENT}
    PLAYBOOK_PATH=${LAYER_DIR}/${SESSION_PLAYBOOK}
    export ANSIBLE_ROLES_PATH=${LAYER_DIR}/roles

    if [[ "$LAYER_CURRENT" == "_debug" ]]; then
        echo "Running $SESSION_PLAYBOOK from the debug playbooks"
    else
        echo "Running $SESSION_PLAYBOOK from repo $SESSION_CLONE_URL"
    fi
    ansible-playbook $PLAYBOOK_PATH $ANSIBLE_ARGS
    ANSIBLE_EXIT=$?
    if [ $ANSIBLE_EXIT -ne 0 ]; then
        echo "Playbook $SESSION_PLAYBOOK from repo $SESSION_CLONE_URL failed"
        if [ -n "$DEBUG_WAIT_TIME" ] && [ $DEBUG_WAIT_TIME -gt 0 ]; then
            echo "This session has failed and will remain running for $DEBUG_WAIT_TIME seconds to allow debugging"
            echo "Touch \"/tmp/complete\" to complete the session early and cleanly"
            timeout $DEBUG_WAIT_TIME bash -c 'until [ -f /tmp/complete ]; do sleep 1; done'
        fi
        exit $ANSIBLE_EXIT;
    fi
done

echo "All playbooks completed successfully"

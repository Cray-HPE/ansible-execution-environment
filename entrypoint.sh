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
# Entrypoint for CMS Ansible Execution Environment (aee)

PREVIOUS_LAYER_DIR=/inventory/layer${LAYER_PREVIOUS}
CURRENT_LAYER_DIR=/inventory/layer${LAYER_CURRENT}

create_complete() {
  mkdir -p ${CURRENT_LAYER_DIR}
  echo $1 > ${CURRENT_LAYER_DIR}/complete
}

wait_for_previous() {
  PREVIOUS_FLAG=${PREVIOUS_LAYER_DIR}/complete
  until [ -f ${PREVIOUS_FLAG} ]
  do
       sleep 5
       echo "Waiting for the previous configuration layer to complete"
  done
  echo "Previous layer completed"
  COMPLETE=$(cat $PREVIOUS_FLAG)
  if [ $COMPLETE -ne 0 ]; then
      echo "The previous configuration layer encountered an error, so this layer will not be run.";
  fi
  return $COMPLETE
}

/entrypoint-setup.sh

if [ $? -ne 0 ]; then
    create_complete 1
    exit;
fi

if [ ! -z ${LAYER_PREVIOUS:+x} ]; then
  wait_for_previous
fi

if [ $? -ne 0 ]; then
    create_complete 1
    exit;
fi

"$@" 2>&1
ANSIBLE_EXIT=$?

create_complete $ANSIBLE_EXIT
exit $ANSIBLE_EXIT

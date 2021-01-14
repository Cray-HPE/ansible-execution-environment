#!/usr/bin/env sh
# Copyright 2019-2020 Hewlett Packard Enterprise Development LP
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

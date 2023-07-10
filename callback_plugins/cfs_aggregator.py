#
# MIT License
#
# (C) Copyright 2019-2023 Hewlett Packard Enterprise Development LP
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
import os
import logging
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from ansible.plugins.callback import CallbackBase


DOCUMENTATION = '''
    callback: cfs_aggregator
    short_description: Per host status aggregation to the CFS API
    version_added: "2.5"
    description:
        - This callback tracks running, failure, and success events for each host
    type: aggregate
'''

LOGGER = logging.getLogger(__name__)


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'cfs'

    # only needed if you ship it and don't want to enable by default
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        # make sure the expected objects are present, calling the base's __init__
        super(CallbackModule, self).__init__()

        # Capture the Session Name
        self.cfs_session_name = os.environ.get('SESSION_NAME', None)

    def v2_playbook_on_stats(self, stats):
        disable_state_recording = (os.environ.get('DISABLE_STATE_RECORDING', 'false').lower() == 'true')
        if not disable_state_recording:
            handler = CfsComponentsHandler()
            handler.update_component_status(stats)


class CfsComponentsHandler(object):
    # COMPONENT STATUS HANDLING
    def __init__(self):
        self.shared_directory = '/inventory'
        self.endpoint = 'http://cray-cfs-api/v3/components/'
        self.max_retries = 10
        self.exception_header = False

        self.session = self._get_cfs_client()
        self.cfs_session_name = os.environ.get('SESSION_NAME', '')
        self.clone_url = os.environ.get('SESSION_CLONE_URL', '')
        self.playbook = os.environ.get('SESSION_PLAYBOOK', '')
        self.layer = os.environ.get('LAYER_CURRENT')
        self.repo_directory = os.path.join(self.shared_directory, 'layer' + self.layer)
        self.commit_id = self._get_commit()

    def update_component_status(self, stats):
        session_failed = stats.custom.get('_run', {}).get('playbook_failed', False)
        for host in stats.processed:
            success = self._success(host, stats)
            self._send_update(host, session_failed, success)

    def _get_cfs_client(self):
        session = requests.session()
        retries = Retry(total=self.max_retries, backoff_factor=2)
        session.mount(self.endpoint, HTTPAdapter(max_retries=retries))
        return session

    def _get_commit(self):
        try:
            fname = os.path.join(self.repo_directory, '.git/HEAD')
            with open(fname, 'r') as f:
                commit_id = f.read().strip()
            if commit_id.startswith('ref:'):
                fname = os.path.join(self.shared_directory, '.git',
                                     commit_id.split(':')[-1].strip())
                with open(fname, 'r') as f:
                    commit_id = f.read().strip()
            return commit_id
        except Exception as e:
            self._log_exception_header()
            LOGGER.error("CFS Status Aggregator: Unable to find commit hash")
            raise(e)

    def _success(self, host, stats):
        if stats.failures.get(host, 0) or stats.dark.get(host, 0):  # dark = unreachable
            return False
        return True

    def _get_new_error_count(self, host):
        """
        Returns the new error count for a failed session,
        or None if the old count can't be retrieved
        """
        response = self.session.get(self.endpoint + host)
        response.raise_for_status()
        data = response.json()
        return data['error_count'] + 1

    def _send_update(self, host, session_failed, success):
        error_count = None
        commit_id = self.commit_id
        if not success:
            commit_id = commit_id + '_failed'
            try:
                error_count = self._get_new_error_count(host)
            except Exception as e:
                self._log_exception_header()
                LOGGER.warning('CFS Status Aggregator: '
                               'Failed to retrieve error count for {}: {}'.format(host, e))
                return  # If we couldn't retrieve the data for a node, we won't be able to update it
        else:
            if session_failed:
                commit_id = commit_id + '_incomplete'
            else:
                error_count = 0
        data = {
            'state_append': {
                'session_name': self.cfs_session_name,
                'clone_url': self.clone_url,
                'playbook': self.playbook,
                'commit': commit_id
            }
        }
        if error_count is not None:
            data['error_count'] = error_count
        try:
            response = self.session.patch(self.endpoint + host, json=data)
            response.raise_for_status()
        except Exception as e:
            self._log_exception_header()
            LOGGER.warning('CFS Status Aggregator: '
                           'Failed to update status for {}: {}'.format(host, e))

    def _log_exception_header(self):
        if not self.exception_header:
            LOGGER.warning('CFS Status Aggregator encountered a problem. '
                           'The Ansible play has completed, '
                           'and the following errors impact only status reporting.')
            LOGGER.warning('These warnings can be ignored if the component is not expected to be '
                           'managed by CFS and is not expected in the CFS components database.')
        self.exception_header = True

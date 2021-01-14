# Copyright 2019-2020 Hewlett Packard Enterprise Development LP

import os
import redis
import logging
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from ansible.plugins.callback import CallbackBase


DOCUMENTATION = '''
    callback: cfs_aggregator
    short_description: Per host status aggregation to a Redis Server
    version_added: "2.5"
    description:
        - This callback tracks running, failure, and success events for each host
    type: aggregate
    requirements:
      - A redis server IP needs to be provided via the REDIS_IP environment variable.
      - A redis server port needs to be provided via the REDIS_PORT environment variable.
      - Users must manually remove values from the Redis server to clear state
'''

LOGGER = logging.getLogger(__name__)


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 1.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'cfs'

    # only needed if you ship it and don't want to enable by default
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        # make sure the expected objects are present, calling the base's __init__
        super(CallbackModule, self).__init__()

        # This is the set of hosts that we have reported upstream to the calling
        # CFS parent. For reasons of brevity, we only want to communicate the
        # set of hosts which we have already reported up.
        self.running = set()

        # This is the set of hosts that we have reported failures on; these can
        # be explicit failures, or failures as a function of unreachable. Rather
        # than simply report this upstream, we cache a local copy of this
        # variable so that we categorically know which of the running operations
        # have succeeded.
        self.failed = set()

        # Capture the Session Name
        self.cfs_session_name = os.environ.get('SESSION_NAME', None)

        # Capture the Redis Client ip/port
        self.redis_ip = os.environ.get('REDIS_IP', None)
        self.redis_port = os.environ.get('REDIS_PORT', 6379)

        # Obtain Redis Reporting
        if self.redis_ip:
            self.redis_client = redis.Redis(self.redis_ip, port=self.redis_port, db=0)
        else:
            self.redis_client = None

        # Setup key shortcuts
        self.running_key = 'sessions/%s/running' % self.cfs_session_name
        self.success_key = 'sessions/%s/success' % self.cfs_session_name
        self.failed_key = 'sessions/%s/failed' % self.cfs_session_name

    def make_running(self, host):
        if self.redis_client and host not in self.running:
            _ = self.redis_client.sadd(self.running_key, host)
        self.running.add(host)

    def make_failed(self, host):
        self.make_running(host)
        if self.redis_client and host not in self.failed:
            _ = self.redis_client.sadd(self.failed_key, host)
        self.failed.add(host)

    def v2_runner_on_ok(self, result):
        host = result._host.get_name()
        self.make_running(host)

    def v2_runner_on_skipped(self, result):
        host = result._host.get_name()
        self.make_running(host)

    def v2_runner_on_failed(self, result, ignore_errors=False, *args, **kwargs):
        host = result._host.get_name()
        if not ignore_errors:
            self.make_failed(host)

    def v2_playbook_on_stats(self, stats):
        handler = CfsComponentsHandler()
        handler.update_component_status(stats)

        # In case we missed any hosts via the processed field, set them. This
        # should generally not be needed, but newer versions of ansible may
        # extend the callback spec to implement new callback operations not
        # implemented outside of this function. Putting this here gives us a
        # little bit of future proofing.
        for host in stats.processed:
            self.make_running(host)

        # All hosts which are have run without failure have succeeded
        if self.redis_client:
            success = self.running - self.failed
            if success:
                _ = self.redis_client.sadd(self.success_key, *success)

        # This is the last stop on the AEEeeee train, all passengers must exit
        # quickly and safely onto the next boarding platform
        if self.redis_client and self.running:
            _ = self.redis_client.srem(self.running_key, *list(self.running))

    def v2_runner_on_unreachable(self, result):
        host = result._host.get_name()
        self.make_failed(host)


class CfsComponentsHandler(object):
    # COMPONENT STATUS HANDLING
    def __init__(self):
        self.shared_directory = '/inventory'
        self.endpoint = 'http://cray-cfs-api/v2/components/'
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
        return data['errorCount'] + 1

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
            'stateAppend': {
                'sessionName': self.cfs_session_name,
                'cloneUrl': self.clone_url,
                'playbook': self.playbook,
                'commit': commit_id
            }
        }
        if error_count is not None:
            data['errorCount'] = error_count
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
        self.exception_header = True

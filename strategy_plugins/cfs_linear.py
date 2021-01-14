# Copyright 2020, Cray Inc., A Hewlett Packard Enterprise Company

from ansible.plugins.strategy.linear import StrategyModule as LinearStrategyModule


class StrategyModule(LinearStrategyModule):
    def run(self, iterator, play_context):
        result = super(StrategyModule, self).run(iterator, play_context)
        if (result & self._tqm.RUN_FAILED_BREAK_PLAY) != 0:
            self._tqm._stats.set_custom_stats('playbook_failed', True)
        return result

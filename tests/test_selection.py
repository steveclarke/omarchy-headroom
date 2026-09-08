import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from test_collector import c


class SelectionTest(unittest.TestCase):
    def dispatch(self, args):
        class Output(io.StringIO):
            buffer = io.BytesIO()
        output = Output()
        output.buffer = io.BytesIO()
        with patch.object(c.sys, 'argv', ['headroom-collect'] + args), patch.object(c.sys, 'stdout', output), patch.object(c.signal, 'signal'), patch.object(c, 'collect', side_effect=lambda id: {'id': id}) as quotas, patch.object(c, 'collect_cost', side_effect=lambda id: {'id': id}) as costs:
            c.main()
        return json.loads(output.buffer.getvalue()), quotas, costs

    def test_single_selection_and_explicit_empty_never_run_disabled_providers(self):
        for args, expected in [(['--providers', 'codex'], ['codex']), (['--providers'], [])]:
            report, quotas, costs = self.dispatch(args)
            self.assertEqual([p['id'] for p in report['providers']], expected)
            self.assertEqual([call.args[0] for call in quotas.call_args_list], expected)
            costs.assert_not_called()

    def test_cost_selection_keeps_requested_order_and_does_not_request_quotas(self):
        report, quotas, costs = self.dispatch(['--costs', '--providers', 'codex', 'claude'])
        self.assertEqual([p['id'] for p in report['providers']], ['codex', 'claude'])
        self.assertEqual({call.args[0] for call in costs.call_args_list}, {'codex', 'claude'})
        quotas.assert_not_called()

    def test_invalid_or_duplicate_selection_rejected_before_collection(self):
        for ids in [['unknown'], ['claude', 'claude'], ['$(command)']]:
            with patch.object(c.sys, 'argv', ['headroom-collect', '--providers'] + ids), patch.object(c.sys, 'stderr', io.StringIO()), patch.object(c, 'collect') as run:
                with self.assertRaises(SystemExit) as failure:
                    c.main()
                self.assertEqual(failure.exception.code, 2)
                run.assert_not_called()

    def test_missing_collector_is_local_to_provider_and_checks_do_not_collect(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(c, 'COLLECTOR_DIR', Path(directory)), patch.object(c, 'run_collector') as run, patch.object(c, 'read_probe_cache') as cache:
            record = c.collect('codex')
            self.assertEqual(record['state'], 'unavailable')
            self.assertIn('collector missing', record['message'])
            checks = c.dependency_checks(['codex'])
            self.assertEqual(checks[0], {'id': 'codex-collector', 'available': False, 'optional': False})
            self.assertNotIn('claude-collector', [check['id'] for check in checks])
            run.assert_not_called()
            cache.assert_not_called()

import importlib.machinery
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
import os

path = Path(__file__).resolve().parents[1] / 'bin/headroom-collect'
loader = importlib.machinery.SourceFileLoader('collector', str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
c = importlib.util.module_from_spec(spec)
loader.exec_module(c)


class CollectorTest(unittest.TestCase):
    def setUp(self):
        self.limits = [{'label':'Session (5-hour)', 'percent':.4, 'resetsAt':'2030-01-01T05:00:00Z'}]
        self.record = {'schemaVersion':1, 'id':'claude', 'limits':self.limits, 'usageStatusText':'', 'tierLabel':'Max'}

    def test_silent_cached_failure_is_not_fresh(self):
        cache = {'fetchedAtMs':900, 'limits':self.limits}
        result = c.observation(self.record, 'claude', 2000, 3000, cache, cache)
        self.assertEqual(result['state'], 'stale')
        self.assertEqual(result['windows'][0]['used'], .4)
        self.assertEqual(result['observedAt'], 0)

    def test_unchanged_usage_with_new_probe_is_fresh(self):
        before = {'fetchedAtMs':900, 'limits':self.limits}
        after = {'fetchedAtMs':2500, 'limits':self.limits}
        result = c.observation(self.record, 'claude', 2000, 3000, before, after)
        self.assertEqual(result['state'], 'fresh')
        self.assertEqual(result['observedAt'], 2500)

    def test_missing_mismatched_or_future_metadata_disables_prediction(self):
        for cache in [None, {'fetchedAtMs':2500, 'limits':[]}, {'fetchedAtMs':999999, 'limits':self.limits}]:
            self.assertEqual(c.observation(self.record,'claude',2000,3000,None,cache)['state'], 'stale')

    def test_codex_rpc_observation_and_plan(self):
        self.record['id'] = 'codex'
        self.assertEqual(c.observation(self.record,'codex',2000,3000)['observedAt'],3000)

    def test_invalid_percentage_and_record(self):
        for value in [None, True, '40', float('nan'), -1]:
            self.assertIsNone(c.normalize_window({'percent':value},'claude'))
        with self.assertRaises(c.CollectionError):
            c.observation({},'codex',0,1)

    def test_duration_never_comes_from_arbitrary_model_text(self):
        base = {'percent':.4,'resetsAt':''}
        w = c.normalize_window(dict(base,label='Opus 5 (1M context)'),'claude')
        self.assertEqual(w['durationMs'],0)
        w = c.normalize_window(dict(base,label='Fable Weekly'),'claude')
        self.assertEqual(w['durationMs'],604800000)
        w = c.normalize_window(dict(base,label='30m window'),'codex')
        self.assertEqual(w['durationMs'],1800000)

    def test_errors_do_not_echo_sensitive_output(self):
        for script in ["print('synthetic-private-value')", "import sys; print('synthetic-private-value'); sys.exit(1)"]:
            with self.assertRaises(c.CollectionError) as caught:
                c.run_collector([sys.executable,'-c',script])
            self.assertNotIn('synthetic-private-value',str(caught.exception))

    def test_timeout_and_missing_command(self):
        with self.assertRaisesRegex(c.CollectionError,'timed out'):
            c.run_collector([sys.executable,'-c','import time; time.sleep(5)'],timeout=.05)
        with self.assertRaisesRegex(c.CollectionError,'unavailable'):
            c.run_collector(['/nonexistent/headroom-synthetic-collector'])
        self.assertFalse(c.ACTIVE)

    def test_oversized_output_is_bounded(self):
        with self.assertRaisesRegex(c.CollectionError,'too large'):
            c.run_collector([sys.executable,'-c',f"print('x' * {c.MAX_OUTPUT + 1})"])

    def test_timeout_stops_app_server_descendants(self):
        with tempfile.TemporaryDirectory() as directory:
            pid_file = Path(directory) / 'child.pid'
            script = "import subprocess,sys,time; from pathlib import Path; p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(20)']); Path(sys.argv[1]).write_text(str(p.pid)); time.sleep(20)"
            with self.assertRaises(c.CollectionError):
                c.run_collector([sys.executable,'-c',script,str(pid_file)],timeout=.3)
            pid = int(pid_file.read_text())
            stat = Path(f'/proc/{pid}/stat')
            # A killed child can briefly remain a zombie until init reaps it.
            self.assertTrue(not stat.exists() or stat.read_text().split()[2] == 'Z')


if __name__ == '__main__':
    unittest.main()

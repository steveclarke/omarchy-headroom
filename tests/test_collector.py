import importlib.machinery
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
import os
import signal
import subprocess
import time

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
            try:
                state = stat.read_text().rsplit(')', 1)[1].split()[0]
            except (FileNotFoundError, ProcessLookupError):
                state = None
            self.assertIn(state, (None, 'Z'))

    def test_launcher_kill_stops_collectors_and_grandchildren(self):
        def alive(pid):
            try:
                return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[0] != 'Z'
            except (FileNotFoundError, ProcessLookupError):
                return False

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for provider in ('claude', 'codex'):
                stub = root / ('omarchy-agent-usage-' + provider)
                stub.write_text('#!/usr/bin/env python3\nimport os,subprocess,sys,time\nfrom pathlib import Path\np=subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)"])\nPath(__file__+".pids").write_text(str(os.getpid())+" "+str(p.pid))\ntime.sleep(30)\n')
                stub.chmod(0o755)
            env = dict(os.environ, PATH=directory + os.pathsep + os.environ['PATH'], XDG_CACHE_HOME=directory)
            runner = root / 'runner.py'
            runner.write_text('import runpy,sys\nfrom pathlib import Path\nm=runpy.run_path(sys.argv[1])\nm["collect"].__globals__["COLLECTOR_DIR"]=Path(sys.argv[2])\nsys.argv=[sys.argv[1],"--parent",sys.argv[3]]\nm["main"]()\n')
            launcher = subprocess.Popen(['/usr/bin/sh', '-c', '/usr/bin/python3 -I -S "$1" "$2" "$3" "$$" & wait', 'headroom', str(runner), str(path), directory],
                                        env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            tracked = []
            try:
                deadline = time.monotonic() + 5
                while len(list(root.glob('*.pids'))) < 2 and time.monotonic() < deadline:
                    time.sleep(.02)
                files = list(root.glob('*.pids'))
                tracked = [int(pid) for file in files for pid in file.read_text().split()]
                self.assertEqual(len(tracked), 4, 'Both collectors and their children must start')
                launcher.kill()
                launcher.wait(timeout=2)
                deadline = time.monotonic() + 3
                while any(alive(pid) for pid in tracked) and time.monotonic() < deadline:
                    time.sleep(.02)
                self.assertFalse([pid for pid in tracked if alive(pid)])
            finally:
                if launcher.poll() is None:
                    launcher.kill()
                    launcher.wait(timeout=2)
                for pid in tracked:
                    if alive(pid):
                        os.kill(pid, signal.SIGKILL)


if __name__ == '__main__':
    unittest.main()

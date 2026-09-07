import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from test_collector import c

path = Path(__file__).resolve().parents[1] / 'bin/setup-costs'
loader = importlib.machinery.SourceFileLoader('setup_costs', str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
setup = importlib.util.module_from_spec(spec)
loader.exec_module(setup)


class SecurityTest(unittest.TestCase):
    def test_only_future_claude_cache_forces_native_probe(self):
        record = {'schemaVersion': 1, 'id': 'claude', 'limits': [{'percent': .4, 'label': 'Weekly'}]}
        for stamp, forced in ((None, False), (1000000, False), (4600000, True)):
            cache = None if stamp is None else {'fetchedAtMs': stamp, 'limits': record['limits']}
            with patch.object(c, 'read_probe_cache', return_value=cache), patch.object(c.time, 'time', return_value=1000), patch.object(c, 'run_collector', return_value=record) as run:
                c.collect('claude')
                command = run.call_args.args[0]
                self.assertEqual(command[0], '/usr/share/omarchy/bin/omarchy-agent-usage-claude')
                self.assertEqual('--force' in command, forced)

    def test_cache_rejects_special_files_and_redirected_parents_without_blocking(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            valid = root / 'valid.json'
            valid.write_text('{"fetchedAtMs":1}')
            self.assertEqual(c.read_probe_cache(valid), {'fetchedAtMs': 1})
            link = root / 'link.json'; link.symlink_to(valid)
            self.assertIsNone(c.read_probe_cache(link))
            parent = root / 'redirect'; parent.symlink_to(root, target_is_directory=True)
            self.assertIsNone(c.read_probe_cache(parent / 'valid.json'))
            hard = root / 'hard.json'; os.link(valid, hard)
            self.assertIsNone(c.read_probe_cache(valid))
            fifo = root / 'fifo'; os.mkfifo(fifo)
            # A regression must fail a deadline, not hang the test runner.
            probe = 'import runpy,sys; from pathlib import Path; m=runpy.run_path(sys.argv[1]); assert m["read_probe_cache"](Path(sys.argv[2])) is None'
            subprocess.run([sys.executable, '-c', probe, c.__file__, str(fifo)], timeout=2, check=True)

    def test_deep_json_and_huge_numbers_fail_closed(self):
        with self.assertRaises(c.CollectionError):
            c.run_collector([sys.executable, '-c', 'print("["*2000+"0"+"]"*2000)'])
        self.assertFalse(c.numeric(10**1000))

    def test_setup_refuses_planted_destination_and_metadata_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            victim = root / 'victim'; victim.write_text('keep me')
            headroom = root / 'headroom'; headroom.mkdir(mode=0o700)
            dest = headroom / 'ccusage-20.0.20'
            with patch.dict(os.environ, XDG_DATA_HOME=str(root)), patch.object(setup.shutil, 'which', return_value='/usr/bin/false'), patch.object(setup.subprocess, 'run') as run:
                dest.symlink_to(root, target_is_directory=True)
                with self.assertRaises(OSError): setup.install()
                dest.unlink(); dest.mkdir(mode=0o700)
                (dest / 'package.json').symlink_to(victim)
                with self.assertRaises(OSError): setup.install()
                self.assertEqual(victim.read_text(), 'keep me')
                run.assert_not_called()

    def test_matching_metadata_does_not_hide_a_missing_reader(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dest = root / 'headroom/ccusage-20.0.20'
            dest.mkdir(parents=True, mode=0o700)
            runtime = path.parents[1] / 'runtime'
            for name in ('package.json', 'bun.lock'):
                (dest / name).write_bytes((runtime / name).read_bytes())
            with patch.dict(os.environ, XDG_DATA_HOME=str(root)), patch.object(setup.shutil, 'which', return_value='/usr/bin/false'):
                with self.assertRaisesRegex(ValueError, 'Reader files are missing'):
                    setup.install()
            self.assertTrue((dest / 'bun.lock').is_file())

    def test_failed_setup_removes_only_its_own_staging_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            keep = root / 'keep'; keep.write_text('keep me')
            with patch.dict(os.environ, XDG_DATA_HOME=str(root)), patch.object(setup.shutil, 'which', return_value='/usr/bin/false'), patch.object(setup.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, 'fixture')):
                with self.assertRaises(subprocess.CalledProcessError): setup.install()
            self.assertEqual(list((root / 'headroom').iterdir()), [])
            self.assertEqual(keep.read_text(), 'keep me')

    def test_cost_environment_exposes_only_selected_history_and_no_preloads(self):
        with patch.dict(os.environ, {'HOME': '/synthetic/home', 'CODEX_HOME': '/synthetic/codex',
                        'CLAUDE_CONFIG_DIR': '/synthetic/claude', 'NODE_OPTIONS': '--require malicious',
                        'OPENCODE_DATA_DIR': '/synthetic/other'}):
            env = c.cost_environment('codex', '/empty')
            self.assertEqual(env['CODEX_HOME'], '/synthetic/codex')
            self.assertEqual(env['HOME'], '/empty')
            for name in ('CLAUDE_CONFIG_DIR', 'NODE_OPTIONS', 'OPENCODE_DATA_DIR'):
                self.assertNotIn(name, env)

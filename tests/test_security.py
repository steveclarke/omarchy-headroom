import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from test_collector import c

class SecurityTest(unittest.TestCase):
    def test_only_future_claude_cache_forces_native_probe(self):
        record = {'schemaVersion': 1, 'id': 'claude', 'limits': [{'percent': .4, 'label': 'Weekly'}]}
        for stamp, forced in ((None, False), (1000000, False), (4600000, True)):
            cache = None if stamp is None else {'fetchedAtMs': stamp, 'limits': record['limits']}
            with patch.object(c, 'read_probe_cache', return_value=cache), patch.object(c.time, 'time', return_value=1000), patch.object(c, 'run_collector', return_value=record) as run, \
                    patch.object(c.Path, 'is_file', return_value=True), patch.object(c.os, 'access', return_value=True):
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

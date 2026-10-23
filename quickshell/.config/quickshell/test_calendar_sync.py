import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('calendar_sync', Path(__file__).with_name('calendar_sync.py'))
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

class CalendarSyncTests(unittest.TestCase):
    def test_failure_isolated_and_retry_only_failed_source(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d)/'status.json'
            calls=[]
            def runner(command):
                calls.append(command[0])
                return 'offline' if command[0]=='tennis' else ''
            jobs={'tennis':['tennis'],'nba':['nba'],'mlb':['mlb']}
            self.assertEqual(sync.sync(jobs,path,runner),1)
            state=json.loads(path.read_text())
            self.assertTrue(state['sources']['nba']['lastSuccess'])
            self.assertFalse(state['running'])
            self.assertTrue(state['partial'])
            calls.clear()
            self.assertEqual(sync.sync(jobs,path,lambda c: calls.append(c[0]) or ''),0)
            self.assertEqual(calls,['tennis'])
            self.assertFalse(json.loads(path.read_text())['partial'])
    def test_force_runs_all_sources_and_preserves_success_on_failure(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'status.json'
            jobs={'nba':['nba'],'mlb':['mlb']}
            sync.sync(jobs,path,lambda c:'')
            before=json.loads(path.read_text())['sources']['nba']['lastSuccess']
            sync.sync(jobs,path,lambda c:'offline',force=True)
            self.assertEqual(json.loads(path.read_text())['sources']['nba']['lastSuccess'],before)
    def test_missing_executable_is_reported(self):
        self.assertEqual(sync.run_job(['/no/such/calendar-tool']), 'Command not found')

if __name__ == '__main__': unittest.main()

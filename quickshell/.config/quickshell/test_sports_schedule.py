import importlib.util
from datetime import date
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

module_path=Path(__file__).resolve().parents[3]/'bin/.local/bin/sports_schedule.py'
spec=importlib.util.spec_from_file_location('sports_schedule',module_path)
sports=importlib.util.module_from_spec(spec);spec.loader.exec_module(sports)

def game(**status):
    return {'gamePk':123,'gameDate':'2026-10-23T01:00:00Z','status':status,
            'teams':{'away':{'team':{'abbreviation':'CLE','name':'Away'}},'home':{'team':{'abbreviation':'PHI','name':'Home'}}}}

class ScheduleTests(unittest.TestCase):
    def test_timezone_and_cancellation(self):
        data=sports.normalize('mlb',game(detailedState='Postponed'))
        self.assertTrue(data['cancelled'])
        self.assertEqual(data['start'].isoformat(),'2026-10-23T01:00:00+00:00')
        with tempfile.TemporaryDirectory() as d:
            sports.write_event(Path(d),'mlb',data)
            text=(Path(d)/'123.ics').read_text()
            self.assertIn('STATUS:CANCELLED',text)
            self.assertIn('DTSTART:20261023T010000Z',text)
    def test_tbd_removes_previously_scheduled_game(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);sports.write_event(p,'mlb',sports.normalize('mlb',game()))
            sports.write_event(p,'mlb',sports.normalize('mlb',game(startTimeTBD=True)))
            self.assertFalse((p/'123.ics').exists())
    def test_reconcile_removes_only_our_missing_games_in_successful_range(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);sports.write_event(p,'mlb',sports.normalize('mlb',game()))
            (p/'manual.ics').write_text('BEGIN:VCALENDAR\nDTSTART:20261023T010000Z\nUID:personal\n')
            sports.reconcile(p,'mlb',set(),date(2026,10,22),date(2026,10,30))
            self.assertFalse((p/'123.ics').exists());self.assertTrue((p/'manual.ics').exists())
    def test_network_failure_preserves_existing_files_and_returns_failure(self):
        with tempfile.TemporaryDirectory() as d, patch.object(sports.Path,'home',return_value=Path(d)), patch.object(sports,'fetch',side_effect=OSError('offline')):
            p=Path(d)/'.local/share/khal/calendars/sports_mlb';p.mkdir(parents=True)
            (p/'123.ics').write_text('unchanged')
            self.assertEqual(sports.main('mlb'),1)
            self.assertEqual((p/'123.ics').read_text(),'unchanged')
    def test_ics_escaping_and_path_rejection(self):
        self.assertEqual(sports.text('a,b;c\nd'),r'a\,b\;c\nd')
        bad=game();bad['gamePk']='../escape'
        with self.assertRaises(ValueError): sports.normalize('mlb',bad)

if __name__=='__main__':unittest.main()

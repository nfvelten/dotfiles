import unittest
from unittest.mock import patch
import tmux_bridge as bridge

class TerminalTests(unittest.TestCase):
    def test_reuses_session_terminal_through_shell_ancestry(self):
        clients = [dict(pid=8, session='$1'), dict(pid=9, session='$2')]
        windows = [dict(pid=1), dict(pid=2)]
        parents = {8: 7, 7: 1, 9: 2}
        self.assertEqual(bridge.terminal_for(clients, windows, parents, '$2')[1]['pid'], 2)
        self.assertEqual(bridge.terminal_for(clients, windows, parents, '$3')[1]['pid'], 1)
    def test_no_matching_terminal(self):
        self.assertIsNone(bridge.terminal_for([dict(pid=8, session='$1')], [], {8: 8}, '$1'))
    def test_rejects_stale_window(self):
        with patch.object(bridge, 'listing', return_value=[]):
            with self.assertRaises(ValueError): bridge.resume('$1', '@9')
    def test_invalid_identifiers(self):
        with self.assertRaises(ValueError): bridge.resume('work; whoami', '@1')
    def test_empty_server(self):
        from subprocess import CompletedProcess
        with patch.object(bridge, 'run', return_value=CompletedProcess([], 1, '', 'no server running')):
            self.assertEqual(bridge.listing(), [])

class ActivityTests(unittest.TestCase):
    def capture(self, text):
        from subprocess import CompletedProcess
        return patch.object(bridge, 'run', return_value=CompletedProcess([], 0, text, ''))
    def test_last_meaningful_line_skips_agent_chrome(self):
        screen = '● Editing TmuxView.qml\n✻ Working… (12s · esc to interrupt)\n✢ Imagining… (1m 38s · ↓ 6.6k tokens)\n────\n❯ \n────\n  ⏵⏵ auto mode on (shift+tab to cycle)\n'
        with self.capture(screen):
            a = bridge.activity('$1:@1')
        self.assertFalse(a['waiting'])
        self.assertEqual(a['line'], 'Editing TmuxView.qml')
    def test_permission_prompt_is_waiting(self):
        with self.capture('Bash command\n  rm -rf build\nDo you want to proceed?\n❯ 1. Yes\n  2. No\n'):
            a = bridge.activity('$1:@1')
        self.assertTrue(a['waiting'])
        self.assertEqual(a['line'], 'Do you want to proceed?')

if __name__ == '__main__': unittest.main()

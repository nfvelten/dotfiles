import importlib.util
import io
import json
import os
from unittest.mock import patch
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('bridge', Path(__file__).with_name('org_bridge.py'))
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class SearchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        bridge.ROOT = Path(self.tmp.name)
        (bridge.ROOT / 'projeto.org').write_text('#+title: Configuração\n#+filetags: :desktop:\n* Áudio\nUsar fones Bluetooth\n* Capturas\nMarcar screenshots\n')
    def test_accent_title_and_tags(self):
        self.assertEqual(bridge.search('configuracao')[0]['orgLine'], 1)
        self.assertEqual(len(bridge.search('desktop')), 1)
    def test_content_opens_heading(self):
        result = bridge.search('fones')[0]
        self.assertEqual(result['orgLine'], 3)
        self.assertEqual(result['title'], 'Áudio')
    def test_no_hidden_or_symlink_notes(self):
        (bridge.ROOT / '.private').mkdir()
        (bridge.ROOT / '.private' / 'hidden.org').write_text('secret-only')
        (bridge.ROOT / 'linked.org').symlink_to(bridge.ROOT / 'projeto.org')
        self.assertEqual(bridge.search('secret-only'), [])
        self.assertEqual(len(bridge.search('configuracao')), 1)
    def test_capture_rejects_multiline(self):
        with self.assertRaises(ValueError): bridge.main(['capture', 'task\n* injected'])
    def test_open_rejects_outside_vault(self):
        with self.assertRaises(ValueError): bridge.main(['open', '/tmp/outside.org', '1'])
    def test_today_checkboxes(self):
        p = bridge.today_path()
        p.parent.mkdir(parents=True)
        p.write_text('#+title: Hoje\n- [ ] Fazer algo\n- [X] Feito\n- [ ]\n')
        self.assertEqual(bridge.home()['taskCount'], 1)

class IndexTests(SearchTests):
    def test_unchanged_files_are_not_read_again(self):
        index = bridge.SearchIndex()
        expected = bridge.search('fones', index)
        with patch.object(Path, 'read_text', side_effect=AssertionError('Unexpected reread')):
            self.assertEqual(bridge.search('fones', index), expected)

    def test_edit_create_rename_and_delete(self):
        index = bridge.SearchIndex()
        self.assertTrue(bridge.search('fones', index))
        path = bridge.ROOT / 'projeto.org'
        stamp = path.stat()
        path.write_text('#+title: Outro\n* Novo\nconteudo atualizado\n')
        os.utime(path, ns=(stamp.st_atime_ns, stamp.st_mtime_ns))
        self.assertEqual(bridge.search('fones', index), [])
        self.assertTrue(bridge.search('atualizado', index))
        renamed = path.rename(bridge.ROOT / 'renomeado.org')
        self.assertEqual(bridge.search('atualizado', index)[0]['orgPath'], str(renamed))
        renamed.unlink()
        self.assertEqual(bridge.search('atualizado', index), [])
        path.write_text('#+title: Criado\nnovo documento')
        self.assertTrue(bridge.search('Criado', index))

    def test_unreadable_and_symlink_replacements_evict_cached_content(self):
        index = bridge.SearchIndex()
        path = bridge.ROOT / 'projeto.org'
        self.assertTrue(bridge.search('fones', index))
        path.write_bytes(b'\xff')
        self.assertEqual(bridge.search('fones', index), [])
        path.write_text('fones')
        self.assertTrue(bridge.search('fones', index))
        path.unlink()
        path.symlink_to(bridge.ROOT / 'absent.org')
        self.assertEqual(bridge.search('fones', index), [])
        self.assertEqual(index.cache, {})

    def test_worker_protocol_recovers_after_invalid_request(self):
        output = io.StringIO()
        bridge.serve_search(io.StringIO('"fones"\ninvalid json\n"configuracao"\n'), output)
        responses = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(responses[0]['query'], 'fones')
        self.assertTrue(responses[0]['entries'])
        self.assertIn('error', responses[1])
        self.assertTrue(responses[2]['entries'])

if __name__ == '__main__': unittest.main()

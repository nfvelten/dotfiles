import unittest
from unittest.mock import patch
import idle_bridge as bridge

ORG = """* Feeds :elfeed:
** Emacs
*** https://planet.emacslife.com/atom.xml
** YouTube
*** [[https://www.youtube.com/feeds/videos.xml?channel_id=X][Channel]]
** Paperboy
*** Podcast :paperboy:podcast:
**** https://lexfridman.com/feed/podcast/
*** Software :paperboy:software:
**** https://matklad.github.io/feed.xml
"""
RSS = b"""<rss><channel><title>Arch</title><item><title>News</title><link>https://a/1</link><pubDate>Tue, 06 Oct 2026 10:00:00 +0000</pubDate></item></channel></rss>"""
ATOM = b"""<feed xmlns="http://www.w3.org/2005/Atom"><title>matklad</title><entry><title>Post</title><link href="https://m/1"/><updated>2026-10-05T08:00:00Z</updated></entry></feed>"""

class IdleTests(unittest.TestCase):
    def test_feed_urls_skip_podcasts_and_keep_links(self):
        self.assertEqual(bridge.feed_urls(ORG), ['https://planet.emacslife.com/atom.xml', 'https://www.youtube.com/feeds/videos.xml?channel_id=X', 'https://matklad.github.io/feed.xml'])
    def test_parse_rss_and_atom(self):
        self.assertEqual(bridge.parse('u', RSS)[0], dict(title='News', link='https://a/1', source='Arch', date='Tue, 06 Oct 2026 10:00:00 +0000'))
        atom = bridge.parse('u', ATOM)[0]
        self.assertEqual((atom['title'], atom['link'], atom['source']), ('Post', 'https://m/1', 'matklad'))
        self.assertGreater(bridge.to_epoch(atom['date']), 0)
    def test_rss_hides_opened_and_old_items(self):
        now = 1_800_000_000
        cache = dict(updated=now, opened=['https://seen'], items=[
            dict(link='https://seen', epoch=now - 60), dict(link='https://new', epoch=now - 60), dict(link='https://old', epoch=now - 8 * 86400)])
        with patch.object(bridge, 'load_cache', return_value=cache):
            result = bridge.rss(now)
        self.assertEqual([i['link'] for i in result['items']], ['https://new'])
        self.assertFalse(result['stale'])
    def test_rss_one_item_per_source(self):
        now = 1_800_000_000
        cache = dict(updated=now, opened=[], items=[dict(link=f'https://tc/{i}', source='TechCrunch', epoch=now - i) for i in range(5)] + [dict(link='https://m', source='matklad', epoch=now - 10)])
        with patch.object(bridge, 'load_cache', return_value=cache):
            self.assertEqual([i['source'] for i in bridge.rss(now)['items']], ['TechCrunch', 'matklad'])
    def test_rss_target(self):
        self.assertEqual(bridge.rss_target('https://www.youtube.com/watch?v=abc'), 'mpv')
        self.assertEqual(bridge.rss_target('https://youtu.be/abc'), 'mpv')
        self.assertEqual(bridge.rss_target('https://example.com/article'), 'emacs')

if __name__ == '__main__': unittest.main()

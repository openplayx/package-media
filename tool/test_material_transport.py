import pathlib
import tempfile
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request

from material_transport import AndroidMaterials


class TransportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = pathlib.Path(self.temporary.name)
        self.transport = AndroidMaterials('test-device')
        # Exercise HTTP without adb or an emulator; device forwarding is only
        # a routing layer above this same loopback server.
        self.thread = threading.Thread(target=self.transport.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.transport.server.shutdown()
        self.transport.server.server_close()
        self.thread.join()
        self.temporary.cleanup()

    def file(self, name, content=b'0123456789'):
        path = self.directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def sample(self, path, ext, **expect):
        return self.transport.sample({'path': str(path), 'ext': ext, 'expect': expect},
                                     self.directory / 'rewritten')

    def test_ranges_and_only_registered_files_are_served(self):
        path = self.file('a space.mp4')
        request = urllib.request.Request(self.transport.url(path), headers={'Range': 'bytes=2-5'})
        with urllib.request.urlopen(request) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.read(), b'2345')
        self.file('secret')
        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(f'http://127.0.0.1:{self.transport.port}/secret')
        error.exception.close()

    def test_pointer_and_relative_playlist_targets_are_relocated(self):
        media = self.file('targets/song.wav')
        asx = self.file('song.asx', f'<asx><ref href="{media.as_uri()}"/></asx>'.encode())
        sample = self.sample(asx, 'asx')
        self.assertTrue(sample['path'].startswith('OPX_LOCAL/'))
        with urllib.request.urlopen(sample['device_files'][0]['url']) as response:
            self.assertIn(self.transport.url(media).encode(), response.read())
        media = self.file('song.wav')
        playlist = self.file('list.m3u', b'#EXTM3U\nsong.wav\n')
        sample = self.sample(playlist, 'm3u')
        with urllib.request.urlopen(urllib.parse.urljoin(sample['path'], 'song.wav')) as response:
            self.assertEqual(response.read(), media.read_bytes())

    def test_later_pointer_preserves_rewritten_sibling_routes(self):
        media = self.file('targets/movie.mp4')
        asx = self.file('test.asx', f'<ASX><REF HREF="{media.as_uri()}"/></ASX>'.encode())
        strm = self.file('test.strm', media.as_uri().encode())
        for first, second in [(asx, strm), (strm, asx)]:
            with self.subTest(first=first.suffix):
                sample = self.sample(first, first.suffix[1:])
                self.sample(second, second.suffix[1:])
                with urllib.request.urlopen(sample['device_files'][0]['url']) as response:
                    text = response.read()
                self.assertIn(self.transport.url(media).encode(), text)
                self.assertNotIn(b'file://', text)

    def test_discs_and_split_volumes_keep_local_filesystem_semantics(self):
        first = self.file('movie.mkv.001')
        self.file('movie.mkv.002')
        sample = self.sample(first, '001')
        self.assertEqual(len(sample['device_files']), 2)
        self.assertEqual(sample['path'], 'OPX_LOCAL/split/movie.mkv.001')
        self.file('dvd/VIDEO_TS/VTS_01_1.VOB')
        directory = self.directory / 'dvd'
        sample = self.transport.sample({'path': f'dvd://{directory}', 'ext': 'dvd', 'expect': {}},
                                       self.directory / 'rewritten')
        self.assertEqual(sample['path'], 'dvd://OPX_LOCAL/disc')
        self.assertEqual(sample['device_files'][0]['name'], 'disc/VIDEO_TS/VTS_01_1.VOB')

    def test_external_subtitle_pairs_are_staged_with_their_names(self):
        media = self.file('video.mp4')
        subtitle = self.file('captions.idx')
        self.file('captions.sub')
        sample = self.sample(media, 'mp4', external_subtitle=str(subtitle))
        self.assertEqual(sample['expect']['external_subtitle'], 'OPX_LOCAL/subtitles/captions.idx')
        self.assertEqual({x['name'] for x in sample['device_files']},
                         {'subtitles/captions.idx', 'subtitles/captions.sub'})


if __name__ == '__main__':
    unittest.main()

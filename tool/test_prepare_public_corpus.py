"""Reference-audio regressions; run with python3 -m unittest discover -s tool."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

from prepare_public_corpus import reference_audio


@unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg is required")
class ReferenceAudioTest(unittest.TestCase):
    def test_quiet_signal_is_distinct_from_silence(self):
        with tempfile.TemporaryDirectory() as directory:
            quiet = pathlib.Path(directory) / "quiet.wav"
            silent = pathlib.Path(directory) / "silent.wav"
            for path, source, filters in [
                (quiet, "sine=frequency=440:duration=1", ["-af", "volume=0.001"]),
                (silent, "anullsrc=r=48000:cl=stereo", []),
            ]:
                subprocess.run(
                    ["ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi",
                     "-i", source, "-t", "1", *filters, "-c:a", "pcm_f32le",
                     str(path)], check=True, capture_output=True,
                )
            reference = reference_audio(quiet)
            self.assertIsNotNone(reference)
            rms = reference["reference_audio_rms"]
            self.assertGreater(rms, 0)
            self.assertLess(rms, 0.001)  # The old absolute cutoff rejected it.
            self.assertAlmostEqual(reference["reference_audio_seconds"], 1, places=2)
            self.assertEqual(reference_audio(silent)["reference_audio_rms"], 0)

    def test_invalid_source_does_not_relax_the_audio_check(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "invalid.wav"
            path.write_bytes(b"invalid media")
            self.assertIsNone(reference_audio(path))


if __name__ == "__main__":
    unittest.main()

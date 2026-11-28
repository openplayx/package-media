"""Regression tests for the material gate, including missing/stale result handling."""
import copy
import json
import os
import pathlib
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from test_materials import collect, evaluate, execute, fingerprint, read_baseline, resolve_device, unexpected_flutter_errors, prepare_project

SCRIPT = pathlib.Path(__file__).with_name("test_materials.py")


def baseline():
    return {"schema": 1, "platform": "macos", "cases": [
        {"suite": "formats", "engine": "auto", "id": "good", "expected": "pass"},
        {"suite": "formats", "engine": "auto", "id": "known-bad",
         "expected": "allow_failure", "reason": "Known decoder limitation"},
    ]}


class GateTest(unittest.TestCase):
    def setUp(self):
        self.baseline = baseline()
        self.results = {
            ("formats", "auto", "good"): {"id": "good", "result": "passed"},
            ("formats", "auto", "known-bad"): {"id": "known-bad", "result": "failed"},
        }

    def test_known_failure_does_not_fail_the_gate(self):
        self.assertEqual(evaluate(self.baseline, self.results, [])["overall"], "passed")

    def test_one_regression_fails_the_whole_gate(self):
        self.results[("formats", "auto", "good")]["result"] = "failed"
        summary = evaluate(self.baseline, self.results, [])
        self.assertEqual(summary["overall"], "failed")
        self.assertEqual(summary["counts"]["regression"], 1)

    def test_allowlisted_case_can_improve_without_failing(self):
        self.results[("formats", "auto", "known-bad")]["result"] = "passed"
        self.assertEqual(evaluate(self.baseline, self.results, [])["counts"]["improved"], 1)

    def test_missing_skipped_and_unknown_statuses_fail(self):
        for identity in self.results:
            for status in [None, "skipped", "not_run", "unknown"]:
                with self.subTest(identity=identity, status=status):
                    records = copy.deepcopy(self.results)
                    if status is None:
                        del records[identity]
                    else:
                        records[identity]["result"] = status
                    self.assertEqual(evaluate(self.baseline, records, [])["overall"], "failed")

    def test_case_specific_preparation_failure_obeys_the_baseline(self):
        self.results[("formats", "auto", "known-bad")]["stage"] = "prepare"
        self.assertEqual(evaluate(self.baseline, self.results, [])["overall"], "passed")
        self.results[("formats", "auto", "good")].update(result="failed", stage="prepare")
        self.assertEqual(evaluate(self.baseline, self.results, [])["overall"], "failed")

    def test_infrastructure_error_is_never_allowlisted(self):
        self.assertEqual(evaluate(self.baseline, self.results, ["Flutter timed out"])["overall"], "failed")

    def test_late_flutter_error_cannot_hide_behind_an_allowed_failure(self):
        records = list(self.results.values())
        self.assertFalse(unexpected_flutter_errors('00:02 +1 -1: known-bad [E]', records))
        self.assertTrue(unexpected_flutter_errors('00:02 +1 -1: good [E]', records))
        self.assertTrue(unexpected_flutter_errors('00:02 +1 -1: (tearDownAll) [E]', records))

    def test_unverified_failure_is_not_an_automatic_waiver(self):
        self.baseline['cases'][1]['expected'] = 'unverified'
        summary = evaluate(self.baseline, self.results, [])
        self.assertEqual(summary['overall'], 'failed')
        self.assertEqual(summary['counts']['unverified_failure'], 1)
        self.results[("formats", "auto", "known-bad")]['result'] = 'passed'
        self.assertEqual(evaluate(self.baseline, self.results, [])['counts']['new_pass'], 1)
        self.assertEqual(self.baseline['cases'][1]['expected'], 'unverified')

    def fixture(self, report):
        group = report / "runs/formats-auto"
        group.mkdir(parents=True)
        (group / "group.json").write_text(json.dumps({"suite": "formats", "engine": "auto"}))
        (group / "results-0001.json").write_text(json.dumps({"results": list(self.results.values())}))
        (report / "execution.json").write_text(json.dumps({"errors": []}))
        (report / "run.json").write_text(json.dumps({
            "baseline_sha256": fingerprint(self.baseline), "mode": "test"}))
        path = report / "baseline.json"
        path.write_text(json.dumps(self.baseline))
        return group, path

    def test_duplicate_and_corrupt_files_cannot_hide_a_regression(self):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory)
            group, _ = self.fixture(report)
            (group / "results-0002.json").write_text(json.dumps({"results": [{"id": "good", "result": "failed"}]}))
            results, errors = collect(self.baseline, report)
            self.assertTrue(errors)
            self.assertEqual(evaluate(self.baseline, results, errors)["overall"], "failed")
            (group / "results-0002.json").write_text("{broken")
            self.assertTrue(collect(self.baseline, report)[1])

    def test_cli_exit_codes_and_partial_run_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory)
            group, path = self.fixture(report)
            command = [sys.executable, str(SCRIPT), "--baseline", str(path), "--check", str(report)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            (group / "results-0001.json").write_text(json.dumps({"results": [self.results[("formats", "auto", "known-bad")]]}))
            # A stale summary saying "passed" must not matter.
            self.assertEqual(subprocess.run(command + ["--only", "known-bad"], capture_output=True).returncode, 1)
            path.write_text(json.dumps({**self.baseline, "changed": True}))
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)

    def test_interrupted_run_has_no_success_verdict(self):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory)
            self.fixture(report)
            (report / "execution.json").unlink()
            self.assertTrue(collect(self.baseline, report)[1])

    def test_other_platform_results_and_baselines_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory)
            group, path = self.fixture(report)
            (group / 'group.json').write_text(json.dumps({
                'suite': 'formats', 'engine': 'auto', 'platform': 'android'}))
            records, errors = collect(self.baseline, report)
            self.assertEqual(evaluate(self.baseline, records, errors)['overall'], 'failed')
            command = [sys.executable, str(SCRIPT), '--platform', 'ios', '--baseline', str(path), '--list']
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 2)

    def test_platform_lists_cover_the_same_auto_material_cases(self):
        baseline_path = SCRIPT.parents[1] / 'formats' / 'material-tests.json'
        raw = json.loads(baseline_path.read_text(encoding='utf-8'))
        self.assertIsInstance(raw, list)
        self.assertEqual(len(raw), 405)
        expected_keys = list(raw[0].keys())
        self.assertIn('path', expected_keys)
        self.assertIn('properties', expected_keys)
        expected_prop_keys = list(raw[0]['properties'].keys())
        seen_props = set()
        for row in raw:
            self.assertEqual(list(row.keys()), expected_keys)
            self.assertIsInstance(row['path'], str)
            self.assertTrue(row['path'].strip())
            self.assertNotIn('/Users/', row['path'])
            self.assertEqual(list(row['properties'].keys()), expected_prop_keys)
            prop_sig = json.dumps(row['properties'], sort_keys=True)
            self.assertNotIn(prop_sig, seen_props, f"duplicate properties: {row['id']}")
            seen_props.add(prop_sig)
        mac = read_baseline(baseline_path, platform='macos')
        self.assertEqual(mac['platform'], 'macos')
        identities = {(c['suite'], c['engine'], c['id']) for c in mac['cases'] if c['engine'] == 'auto'}
        self.assertEqual(len(identities), 405)
        for platform in ['android', 'ios', 'tvos', 'linux', 'windows']:
            other = read_baseline(baseline_path, platform=platform)
            self.assertEqual(other['platform'], platform)
            self.assertEqual({(c['suite'], c['engine'], c['id']) for c in other['cases']}, identities)

    def test_flat_table_validation_defaults_and_per_platform_fingerprint(self):
        table = [
            {
                "suite": "formats",
                "engine": "auto",
                "id": "good",
                "macos": "pass",
                "macos_reason": "",
                "android": "allow_failure",
                "android_reason": "Known decoder limitation",
            },
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "material-tests.json"
            path.write_text(json.dumps(table))
            mac_before = read_baseline(path, platform="macos")
            and_before = read_baseline(path, platform="android")
            # A platform without explicit columns defaults to pass for all materials.
            linux_default = read_baseline(path, platform="linux")
            self.assertEqual(mac_before["cases"][0]["expected"], "pass")
            self.assertEqual(and_before["cases"][0]["expected"], "allow_failure")
            self.assertEqual(and_before["cases"][0]["reason"], "Known decoder limitation")
            self.assertEqual(linux_default["cases"][0]["expected"], "pass")
            # Changing android's expectation must not invalidate macOS's fingerprint.
            modified = copy.deepcopy(table)
            modified[0]["android"] = "pass"
            modified[0]["android_reason"] = ""
            path.write_text(json.dumps(modified))
            self.assertEqual(fingerprint(mac_before), fingerprint(read_baseline(path, platform="macos")))
            self.assertNotEqual(fingerprint(and_before), fingerprint(read_baseline(path, platform="android")))
            # Inconsistent keys across objects or allow_failure without reason must fail.
            broken_keys = copy.deepcopy(table) + [{**table[0], "id": "other", "extra": 1}]
            path.write_text(json.dumps(broken_keys))
            with self.assertRaises(ValueError):
                read_baseline(path, platform="macos")
            missing_reason = copy.deepcopy(table)
            missing_reason[0]["android_reason"] = ""
            path.write_text(json.dumps(missing_reason))
            with self.assertRaises(ValueError):
                read_baseline(path, platform="macos")

    def test_default_device_selection_uses_a_simulator_of_the_requested_platform(self):
        devices = [
            {'id': 'phone', 'targetPlatform': 'ios', 'emulator': False},
            {'id': 'sim', 'targetPlatform': 'ios', 'emulator': True},
            {'id': 'android', 'targetPlatform': 'android-arm64', 'emulator': True},
        ]
        with patch('test_materials.subprocess.run') as run:
            run.return_value.stdout = json.dumps(devices)
            self.assertEqual(resolve_device('ios', None)['id'], 'sim')
            self.assertEqual(resolve_device('android', None)['id'], 'android')
            with self.assertRaises(ValueError):
                resolve_device('android', 'sim')
            with self.assertRaises(ValueError):
                resolve_device('ios', 'phone')

    def test_build_failure_stops_instead_of_rebuilding_for_every_batch(self):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory)
            cases = [dict(self.baseline['cases'][0], engine=engine) for engine in ['auto', 'mpv']]
            b = dict(self.baseline, cases=cases)
            args = SimpleNamespace(cache=report / 'cache', prepare_only=False, batch_size=1,
                                   timeout=1, device='macos', project_dir=report)
            with patch('test_materials.prepare') as prepare, patch('test_materials.subprocess.run') as run, \
                    patch('test_materials.shutil.which', return_value=r'C:\flutter\bin\flutter.BAT'):
                prepare.return_value = {'good': {'id': 'good', 'path': '/fake.mp4', 'status': 'ok'}}
                run.return_value.returncode = 1
                execute(b, cases, args, report)
                self.assertEqual(run.call_count, 1)
                self.assertEqual(run.call_args.args[0][0], r'C:\flutter\bin\flutter.BAT')
            records, errors = collect(b, report)
            self.assertTrue(errors)
            self.assertEqual(evaluate(b, records, errors)['overall'], 'failed')

    def test_isolated_host_keeps_its_resolved_locks_and_plugin_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source, worker = root / 'example', root / 'example-wios'
            source.mkdir(); worker.mkdir()
            for folder in [source, worker]:
                (folder / 'pubspec.yaml').write_text('name: host')
            (source / 'pubspec.lock').write_text('old source resolution')
            (worker / 'pubspec.lock').write_text('new worker resolution')
            os.utime(source / 'pubspec.lock', (1, 1))
            os.utime(worker / 'pubspec.lock', (2, 2))
            (source / '.flutter-plugins-dependencies').write_text('macOS generated metadata')
            (worker / '.flutter-plugins-dependencies').write_text('iOS generated metadata')
            with patch('test_materials.ROOT', root):
                prepare_project('ios', None)
                self.assertEqual((worker / 'pubspec.lock').read_text(), 'new worker resolution')
                self.assertEqual((worker / '.flutter-plugins-dependencies').read_text(), 'iOS generated metadata')
                (source / 'pubspec.yaml').write_text('name: changed_host')
                prepare_project('ios', None)
                self.assertEqual((worker / 'pubspec.lock').read_text(), 'old source resolution')

    def test_reject_empty_duplicate_or_unexplained_allowlist(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "baseline.json"
            for cases in [[], self.baseline["cases"] * 2,
                          [{"suite": "formats", "engine": "auto", "id": "x", "expected": "allow_failure"}]]:
                path.write_text(json.dumps({**self.baseline, "cases": cases}))
                with self.assertRaises(ValueError):
                    read_baseline(path)


if __name__ == "__main__":
    unittest.main()

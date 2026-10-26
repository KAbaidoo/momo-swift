"""Synthetic verification tests for the OpenAPI baseline CLI."""

from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "openapi-baselines.py"
SPEC = importlib.util.spec_from_file_location("openapi_baselines", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
baselines = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(baselines)


API_NAMES = sorted(baselines.EXPECTED_APIS)


def spec_bytes(*, openapi: str = "3.0.1", operations: tuple[str, ...] = ("get",)) -> bytes:
    paths = {f"/v1/{index}": {method: {"responses": {"200": {"description": "ok"}}}}
             for index, method in enumerate(operations)}
    return json.dumps({"openapi": openapi, "info": {"title": "fixture", "version": "1"}, "paths": paths},
                      separators=(",", ":")).encode()


def fixture_manifest() -> tuple[dict, dict[str, bytes]]:
    entries = []
    files = {}
    for api in API_NAMES:
        raw = spec_bytes()
        files[api] = raw
        entries.append({
            "api": api,
            "revision": 1,
            "reviewedAt": "2026-10-26",
            "retrievedAt": "2026-10-26",
            "sourceUrl": f"https://momodeveloper.mtn.com/mapi/apis/{api};rev=1?export=true&api-version=2022-04-01-preview",
            "contentType": "application/vnd.oai.openapi+json",
            "openapiVersion": "3.0.1",
            "operations": 1,
            "sha256": hashlib.sha256(raw).hexdigest(),
            "baselineRole": "original",
            "archive": {
                "repository": "example/contracts",
                "commit": "a" * 40,
                "path": f"snapshots/2026-10-26/{api}.json",
            },
        })
    return {"schemaVersion": 1, "reviewedAt": "2026-10-26", "retrievedAt": "2026-10-26", "baselines": entries}, files


class ManifestTests(unittest.TestCase):
    def test_accepts_four_well_formed_original_baselines(self):
        manifest, _ = fixture_manifest()
        self.assertEqual(len(baselines.validate_manifest(manifest)), 4)

    def test_rejects_duplicate_api_and_missing_api(self):
        manifest, _ = fixture_manifest()
        manifest["baselines"][-1] = dict(manifest["baselines"][0])
        with self.assertRaisesRegex(baselines.BaselineError, "duplicate baseline"):
            baselines.validate_manifest(manifest)

        manifest, _ = fixture_manifest()
        manifest["baselines"].pop()
        with self.assertRaisesRegex(baselines.BaselineError, "exactly four APIs"):
            baselines.validate_manifest(manifest)

    def test_rejects_missing_provenance_field(self):
        manifest, _ = fixture_manifest()
        del manifest["baselines"][0]["sourceUrl"]
        with self.assertRaisesRegex(baselines.BaselineError, "missing sourceUrl"):
            baselines.validate_manifest(manifest)

    def test_rejects_malformed_metadata_types_and_values_cleanly(self):
        bad_values = [
            ("api", []),
            ("revision", True),
            ("operations", True),
            ("reviewedAt", "2026-99-88"),
            ("sourceUrl", None),
            ("contentType", 12),
            ("openapiVersion", []),
            ("baselineRole", "replacement"),
            ("archive", {"repository": "example/contracts", "commit": "a" * 40, "path": None}),
        ]
        for field, value in bad_values:
            with self.subTest(field=field):
                manifest, _ = fixture_manifest()
                manifest["baselines"][0][field] = value
                with self.assertRaises(baselines.BaselineError):
                    baselines.validate_manifest(manifest)

    def test_rejects_path_traversal_and_short_archive_commit(self):
        for field, value in (("path", "../../outside.json"), ("commit", "deadbeef")):
            with self.subTest(field=field):
                manifest, _ = fixture_manifest()
                manifest["baselines"][0]["archive"][field] = value
                with self.assertRaises(baselines.BaselineError):
                    baselines.validate_manifest(manifest)


class SnapshotVerificationTests(unittest.TestCase):
    def test_verifies_all_local_files_and_rejects_missing_or_tampered_bytes(self):
        manifest, files = fixture_manifest()
        entries = baselines.validate_manifest(manifest)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            for api, raw in files.items():
                (directory / f"{api}.json").write_bytes(raw)
            baselines.verify_directory(entries, directory, None)

            missing = directory / f"{API_NAMES[0]}.json"
            original = missing.read_bytes()
            missing.unlink()
            with self.assertRaisesRegex(baselines.BaselineError, "cannot read"):
                baselines.verify_directory(entries, directory, None)
            missing.write_bytes(original + b" ")
            with self.assertRaisesRegex(baselines.BaselineError, "SHA-256 mismatch"):
                baselines.verify_directory(entries, directory, None)

    def test_rejects_invalid_json_and_wrong_operation_count(self):
        manifest, _ = fixture_manifest()
        entry = manifest["baselines"][0]
        with self.assertRaisesRegex(baselines.BaselineError, "not valid UTF-8 OpenAPI JSON"):
            baselines.parse_and_check(b"not json", entry, "fixture")
        with self.assertRaisesRegex(baselines.BaselineError, "found 2 operations"):
            baselines.parse_and_check(spec_bytes(operations=("get", "post")), entry, "fixture")

    def test_reports_private_archive_cli_failure(self):
        manifest, _ = fixture_manifest()
        entry = manifest["baselines"][0]
        error = subprocess.CalledProcessError(1, ["gh", "api"], stderr=b"not found")
        with mock.patch.object(baselines.subprocess, "run", side_effect=error):
            with self.assertRaisesRegex(baselines.BaselineError, "cannot retrieve.*not found"):
                baselines.archive_bytes(entry)

    def test_fetch_is_idempotent_but_never_overwrites_different_content(self):
        manifest, files = fixture_manifest()
        entry = manifest["baselines"][0]
        api = entry["api"]
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            destination = baselines.write_fetched(directory, entry, files[api])
            self.assertEqual(destination.read_bytes(), files[api])
            self.assertEqual(baselines.write_fetched(directory, entry, files[api]), destination)
            with self.assertRaisesRegex(baselines.BaselineError, "refusing to overwrite"):
                baselines.write_fetched(directory, entry, b"different")
            self.assertEqual(destination.read_bytes(), files[api])


class CLITests(unittest.TestCase):
    def write_manifest(self, directory: Path, manifest: dict) -> Path:
        path = directory / "manifest.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def run_cli(self, manifest: Path, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--manifest", str(manifest), *args],
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )

    def test_validate_manifest_cli_success_and_malformed_provenance_exit(self):
        manifest, _ = fixture_manifest()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path = self.write_manifest(directory, manifest)
            result = self.run_cli(path, "validate-manifest")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Manifest valid: 4 original baselines", result.stdout)

            del manifest["baselines"][0]["sourceUrl"]
            path = self.write_manifest(directory, manifest)
            result = self.run_cli(path, "validate-manifest")
            self.assertEqual(result.returncode, 1)
            self.assertIn("missing sourceUrl", result.stderr)

    def test_fetch_cli_failure_is_reported_with_nonzero_exit(self):
        manifest, _ = fixture_manifest()
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            manifest_path = self.write_manifest(directory, manifest)
            gh = directory / "gh"
            gh.write_text("#!/bin/sh\necho 'archive unavailable' >&2\nexit 1\n", encoding="utf-8")
            gh.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{directory}:{env.get('PATH', '')}"
            result = self.run_cli(
                manifest_path,
                "fetch",
                "--api",
                "collection",
                "--output-dir",
                str(directory / "out"),
                env=env,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("cannot retrieve collection", result.stderr)
            self.assertIn("archive unavailable", result.stderr)
            self.assertFalse((directory / "out" / "collection.json").exists())


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.manifest, self.files = fixture_manifest()
        self.item = self.manifest["baselines"][0]

    def compare(self, current: bytes) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = baselines.compare_one(
                self.item, self.files[self.item["api"]], current, "fixture current export"
            )
        return result, output.getvalue()

    def test_identical_bytes_are_reported_as_identical(self):
        status, output = self.compare(self.files[self.item["api"]])
        self.assertEqual(status, 0)
        self.assertIn("IDENTICAL", output)

    def test_json_formatting_only_change_is_reported_without_diff(self):
        current = json.dumps(json.loads(self.files[self.item["api"]]), indent=4).encode()
        status, output = self.compare(current)
        self.assertEqual(status, 0)
        self.assertIn("FORMATTING-ONLY", output)

    def test_added_and_deleted_operations_are_content_changes_with_diff(self):
        for methods, expected_delta in (
            (("get", "post"), '"post"'),
            ((), '"get"'),
        ):
            with self.subTest(methods=methods):
                current = spec_bytes(operations=methods)
                status, output = self.compare(current)
                self.assertEqual(status, 1)
                self.assertIn("CONTENT CHANGED", output)
                self.assertIn(expected_delta, output)

    def test_openapi_version_change_is_content_change_with_diff(self):
        status, output = self.compare(spec_bytes(openapi="3.1.0"))
        self.assertEqual(status, 1)
        self.assertIn("CONTENT CHANGED", output)
        self.assertIn("3.1.0", output)

    def test_upstream_request_uses_unpinned_current_export_url(self):
        captured = {}

        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self):
                return b"{}"

        def fake_urlopen(request, timeout):
            captured["url"] = request.full_url
            captured["accept"] = request.get_header("Accept")
            return Response()

        with mock.patch.object(baselines.urllib.request, "urlopen", side_effect=fake_urlopen):
            baselines.fetch_upstream(self.item)
        self.assertNotIn(";rev=", captured["url"])
        self.assertIn("export=true", captured["url"])
        self.assertEqual(captured["accept"], self.item["contentType"])


if __name__ == "__main__":
    unittest.main()

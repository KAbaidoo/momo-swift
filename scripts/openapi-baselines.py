#!/usr/bin/env python3
"""Retrieve and compare the reviewed MTN OpenAPI baselines."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/openapi/manifest.json"
EXPECTED_APIS = {
    "collection",
    "disbursement",
    "remittance",
    "sandbox-provisioning-api",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
HTTP_METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}


class BaselineError(Exception):
    pass


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BaselineError(f"cannot read manifest {path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("baselines"), list):
        raise BaselineError("manifest must be a JSON object with a baselines array")
    return data


def validate_manifest(data: dict[str, Any]) -> list[dict[str, Any]]:
    if data.get("schemaVersion") != 1:
        raise BaselineError("manifest.schemaVersion must be 1")
    for key in ("reviewedAt", "retrievedAt"):
        value = data.get(key)
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise BaselineError(f"manifest.{key} must use YYYY-MM-DD")
        try:
            date.fromisoformat(value)
        except ValueError as error:
            raise BaselineError(f"manifest.{key} is not a valid calendar date") from error
    baselines = data["baselines"]
    by_api: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(baselines):
        prefix = f"baselines[{index}]"
        if not isinstance(item, dict):
            raise BaselineError(f"{prefix} must be an object")
        api = item.get("api")
        if not isinstance(api, str) or api not in EXPECTED_APIS:
            raise BaselineError(f"{prefix}.api must be one of {', '.join(sorted(EXPECTED_APIS))}")
        if api in by_api:
            raise BaselineError(f"duplicate baseline for {api}")
        for key in ("revision", "reviewedAt", "retrievedAt", "sourceUrl", "contentType", "openapiVersion", "operations", "sha256", "baselineRole", "archive"):
            if key not in item:
                raise BaselineError(f"{prefix} is missing {key}")
        if type(item["revision"]) is not int or item["revision"] < 1:
            raise BaselineError(f"{prefix}.revision must be a positive integer")
        if type(item["operations"]) is not int or item["operations"] < 1:
            raise BaselineError(f"{prefix}.operations must be a positive integer")
        for key in ("reviewedAt", "retrievedAt"):
            if not isinstance(item[key], str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", item[key]):
                raise BaselineError(f"{prefix}.{key} must use YYYY-MM-DD")
            try:
                date.fromisoformat(item[key])
            except ValueError as error:
                raise BaselineError(f"{prefix}.{key} is not a valid calendar date") from error
        if not isinstance(item["sha256"], str) or not SHA256_RE.fullmatch(item["sha256"]):
            raise BaselineError(f"{prefix}.sha256 must be a lowercase 64-character SHA-256")
        if item["baselineRole"] != "original":
            raise BaselineError(f"{prefix}.baselineRole must be original for this reviewed baseline")
        if item["contentType"] != "application/vnd.oai.openapi+json":
            raise BaselineError(f"{prefix}.contentType must identify the OpenAPI JSON export")
        if not isinstance(item["openapiVersion"], str) or not item["openapiVersion"]:
            raise BaselineError(f"{prefix}.openapiVersion must be a non-empty string")
        expected_url = (
            f"https://momodeveloper.mtn.com/mapi/apis/{api};rev={item['revision']}"
            "?export=true&api-version=2022-04-01-preview"
        )
        if item["sourceUrl"] != expected_url:
            raise BaselineError(f"{prefix}.sourceUrl must be the revision-qualified MTN export URL")
        archive = item["archive"]
        if not isinstance(archive, dict) or not all(key in archive for key in ("repository", "commit", "path")):
            raise BaselineError(f"{prefix}.archive must contain repository, commit, and path")
        if not isinstance(archive["repository"], str) or not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", archive["repository"]):
            raise BaselineError(f"{prefix}.archive.repository must be owner/repository")
        if not isinstance(archive["commit"], str) or not COMMIT_RE.fullmatch(archive["commit"]):
            raise BaselineError(f"{prefix}.archive.commit must be a full 40-character commit SHA")
        if not isinstance(archive["path"], str) or not archive["path"]:
            raise BaselineError(f"{prefix}.archive.path must be a repository-relative path")
        archive_path = PurePosixPath(archive["path"])
        if archive_path.is_absolute() or ".." in archive_path.parts or not archive_path.parts:
            raise BaselineError(f"{prefix}.archive.path must be a repository-relative path")
        by_api[api] = item
    missing = EXPECTED_APIS - by_api.keys()
    extra = by_api.keys() - EXPECTED_APIS
    if missing or extra:
        raise BaselineError(f"manifest must contain exactly four APIs; missing={sorted(missing)}, extra={sorted(extra)}")
    if any(item["reviewedAt"] != data["reviewedAt"] or item["retrievedAt"] != data["retrievedAt"] for item in by_api.values()):
        raise BaselineError("per-API review and retrieval dates must match the manifest dates")
    return [by_api[api] for api in sorted(by_api)]


def operation_count(document: Any, api: str) -> int:
    if not isinstance(document, dict) or not isinstance(document.get("paths"), dict):
        raise BaselineError(f"{api}: OpenAPI document has no paths object")
    count = 0
    for path_item in document["paths"].values():
        if isinstance(path_item, dict):
            count += sum(1 for key in path_item if key.lower() in HTTP_METHODS)
    return count


def parse_and_check(raw: bytes, item: dict[str, Any], label: str) -> Any:
    try:
        document = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise BaselineError(f"{label}: not valid UTF-8 OpenAPI JSON: {error}") from error
    if not isinstance(document, dict) or document.get("openapi") != item["openapiVersion"]:
        raise BaselineError(f"{label}: OpenAPI version does not match manifest ({item['openapiVersion']})")
    count = operation_count(document, item["api"])
    if count != item["operations"]:
        raise BaselineError(f"{label}: found {count} operations; manifest records {item['operations']}")
    return document


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def archive_bytes(item: dict[str, Any]) -> bytes:
    archive = item["archive"]
    endpoint = f"repos/{archive['repository']}/contents/{archive['path']}?ref={archive['commit']}"
    try:
        result = subprocess.run(
            ["gh", "api", "--header", "Accept: application/vnd.github.raw", endpoint],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as error:
        raise BaselineError("GitHub CLI 'gh' is required; install it and authenticate with access to the private baseline archive") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode("utf-8", errors="replace").strip()
        raise BaselineError(f"cannot retrieve {item['api']} from private archive: {detail or 'gh api failed'}") from error
    return result.stdout


def fetch_upstream(item: dict[str, Any]) -> bytes:
    url = (
        f"https://momodeveloper.mtn.com/mapi/apis/{item['api']}"
        "?export=true&api-version=2022-04-01-preview"
    )
    request = urllib.request.Request(url, headers={"Accept": item["contentType"]})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError) as error:
        raise BaselineError(f"cannot retrieve upstream export for {item['api']}: {error}") from error


def write_fetched(output_dir: Path, item: dict[str, Any], raw: bytes) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / f"{item['api']}.json"
    if destination.exists():
        existing = destination.read_bytes()
        if existing == raw:
            print(f"{item['api']}: already present and identical at {destination}")
            return destination
        raise BaselineError(f"refusing to overwrite existing file with different bytes: {destination}")
    destination.write_bytes(raw)
    print(f"{item['api']}: fetched {len(raw)} bytes to {destination}")
    return destination


def canonical(raw: bytes, item: dict[str, Any], label: str) -> str:
    try:
        document = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise BaselineError(f"{label}: not valid UTF-8 JSON: {error}") from error
    if not isinstance(document, dict) or not isinstance(document.get("openapi"), str) or not isinstance(document.get("paths"), dict):
        raise BaselineError(f"{label}: not a recognizable OpenAPI JSON document")
    return json.dumps(document, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def cmd_validate(args: argparse.Namespace) -> None:
    data = load_manifest(args.manifest)
    items = validate_manifest(data)
    print(f"Manifest valid: {len(items)} original baselines ({', '.join(item['api'] for item in items)})")


def cmd_fetch(args: argparse.Namespace) -> None:
    data = load_manifest(args.manifest)
    items = validate_manifest(data)
    selected = [item for item in items if args.api is None or item["api"] == args.api]
    for item in selected:
        raw = archive_bytes(item)
        digest = sha256(raw)
        if digest != item["sha256"]:
            raise BaselineError(f"{item['api']}: archived bytes hash to {digest}, expected {item['sha256']}")
        parse_and_check(raw, item, item["api"])
        write_fetched(args.output_dir, item, raw)


def verify_directory(items: list[dict[str, Any]], directory: Path, selected_api: str | None) -> None:
    selected = [item for item in items if selected_api is None or item["api"] == selected_api]
    for item in selected:
        path = directory / f"{item['api']}.json"
        try:
            raw = path.read_bytes()
        except OSError as error:
            raise BaselineError(f"{item['api']}: cannot read {path}: {error}") from error
        digest = sha256(raw)
        if digest != item["sha256"]:
            raise BaselineError(f"{item['api']}: SHA-256 mismatch: got {digest}, expected {item['sha256']}")
        parse_and_check(raw, item, str(path))
        print(f"{item['api']}: SHA-256 and OpenAPI metadata verified ({digest})")


def cmd_verify(args: argparse.Namespace) -> None:
    items = validate_manifest(load_manifest(args.manifest))
    if args.directory:
        verify_directory(items, args.directory, args.api)
        return
    with tempfile.TemporaryDirectory(prefix="momo-openapi-verify-") as temporary:
        directory = Path(temporary)
        for item in items:
            if args.api is not None and item["api"] != args.api:
                continue
            raw = archive_bytes(item)
            if sha256(raw) != item["sha256"]:
                raise BaselineError(f"{item['api']}: private archive checksum mismatch")
            parse_and_check(raw, item, item["api"])
            (directory / f"{item['api']}.json").write_bytes(raw)
        verify_directory(items, directory, args.api)


def compare_one(item: dict[str, Any], baseline: bytes, candidate: bytes, candidate_label: str) -> int:
    if candidate == baseline:
        print(f"{item['api']}: IDENTICAL ({candidate_label} bytes match reviewed baseline)")
        return 0
    old_canonical = canonical(baseline, item, f"reviewed baseline {item['api']}")
    new_canonical = canonical(candidate, item, candidate_label)
    if old_canonical == new_canonical:
        print(f"{item['api']}: FORMATTING-ONLY ({candidate_label} content is unchanged; raw bytes differ)")
        return 0
    print(f"{item['api']}: CONTENT CHANGED ({candidate_label}; canonical JSON diff follows)")
    diff = difflib.unified_diff(
        old_canonical.splitlines(),
        new_canonical.splitlines(),
        fromfile=f"reviewed/{item['api']}.json",
        tofile=f"candidate/{item['api']}.json",
        lineterm="",
    )
    for line in diff:
        print(line)
    return 1


def cmd_compare(args: argparse.Namespace) -> None:
    items = validate_manifest(load_manifest(args.manifest))
    if args.upstream_file and args.api is None:
        raise BaselineError("--upstream-file requires --api to select the API for the supplied export")
    selected = [item for item in items if args.api is None or item["api"] == args.api]
    changed = 0
    with tempfile.TemporaryDirectory(prefix="momo-openapi-compare-") as temporary:
        directory = Path(temporary)
        for item in selected:
            raw = archive_bytes(item)
            if sha256(raw) != item["sha256"]:
                raise BaselineError(f"{item['api']}: private archive checksum mismatch")
            parse_and_check(raw, item, item["api"])
            (directory / f"{item['api']}.json").write_bytes(raw)
        for item in selected:
            baseline = (directory / f"{item['api']}.json").read_bytes()
            if args.upstream_file:
                try:
                    candidate = args.upstream_file.read_bytes()
                except OSError as error:
                    raise BaselineError(f"cannot read candidate export {args.upstream_file}: {error}") from error
                candidate_label = str(args.upstream_file)
            else:
                candidate = fetch_upstream(item)
                candidate_label = "current unpinned MTN export"
            changed += compare_one(item, baseline, candidate, candidate_label)
    if changed:
        raise BaselineError("upstream contract content differs; reviewed snapshots were left unchanged")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST, help="manifest path (default: docs/openapi/manifest.json)")
    commands = result.add_subparsers(dest="command", required=True)

    validate = commands.add_parser("validate-manifest", help="validate public provenance metadata without private credentials")
    validate.set_defaults(function=cmd_validate)

    fetch = commands.add_parser("fetch", help="retrieve reviewed bytes from the private immutable archive")
    fetch.add_argument("--api", choices=sorted(EXPECTED_APIS), help="fetch one API (default: all four)")
    fetch.add_argument("--output-dir", type=Path, required=True, help="local output directory; existing differing files are never overwritten")
    fetch.set_defaults(function=cmd_fetch)

    verify = commands.add_parser("verify", help="verify local files or retrieve and verify the private archive")
    verify.add_argument("--api", choices=sorted(EXPECTED_APIS), help="verify one API (default: all four)")
    verify.add_argument("--directory", type=Path, help="verify API JSON files already in this directory")
    verify.set_defaults(function=cmd_verify)

    compare = commands.add_parser("compare", help="compare archived reviewed bytes with current MTN exports")
    compare.add_argument("--api", choices=sorted(EXPECTED_APIS), help="compare one API (default: all four)")
    compare.add_argument("--upstream-file", type=Path, help="compare a saved export file; requires --api")
    compare.set_defaults(function=cmd_compare)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        args.function(args)
        return 0
    except BaselineError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

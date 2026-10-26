#!/usr/bin/env python3
"""Validate release intent and publish an already verified main commit."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
NUMBER = r'(?:0|[1-9][0-9]*)'
IDENTIFIER = r'(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
SEMVER = re.compile(rf'{NUMBER}\.{NUMBER}\.{NUMBER}(?:-{IDENTIFIER}(?:\.{IDENTIFIER})*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\Z')
SHA = re.compile(r'[0-9a-f]{40}\Z')


class ReleaseError(Exception):
    pass


class APIError(ReleaseError):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


def command(args, **kwargs):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, **kwargs).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        detail = getattr(error, 'stderr', None) or str(error)
        raise ReleaseError(f'{args[0]} failed: {detail}') from error


def git(*args):
    return command(['git', *args], cwd=ROOT)


def git_file(sha, path, optional=False):
    # Only historical absence is optional; malformed JSON is never ignored.
    if optional and not git('ls-tree', sha, '--', path):
        return None
    return git('show', f'{sha}:{path}')


def parse_config(raw):
    try:
        config = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as error:
        raise ReleaseError(f'invalid release.json: {error}') from error
    if not isinstance(config, dict) or set(config) != {'version', 'publicationApproved', 'prerelease'}:
        raise ReleaseError('release.json requires exactly version, publicationApproved, and prerelease')
    version = config['version']
    if not isinstance(version, str) or not SEMVER.fullmatch(version):
        raise ReleaseError('version must be SemVer without a v prefix or leading zeroes')
    if type(config['publicationApproved']) is not bool or type(config['prerelease']) is not bool:
        raise ReleaseError('publicationApproved and prerelease must be booleans')
    if '-' in version.split('+')[0] and not config['prerelease']:
        raise ReleaseError('a SemVer prerelease must set prerelease=true')
    return config


def notes_path(config):
    return f"docs/releases/v{config['version']}.md"


def validate_notes(notes, config):
    if not notes.strip() or f"{config['version']}" not in notes or '.package(' not in notes:
        raise ReleaseError('release notes must include the version and SwiftPM installation instructions')


def release_intent(config, previous):
    return config['publicationApproved'] and (
        previous is None or previous['version'] != config['version'] or not previous['publicationApproved']
    )


class GitHub:
    def __init__(self, base_url=None):
        # Explicit loopback injection for local HTTP simulation only. Production
        # entry points never pass an override or read one from the environment.
        if base_url is not None:
            parsed = urlparse(base_url)
            if parsed.scheme != 'http' or parsed.hostname != '127.0.0.1' or parsed.username or parsed.password:
                raise ReleaseError('simulation URL must use http://127.0.0.1')
        self.base_url = base_url.rstrip('/') if base_url else None

    def call(self, method, endpoint, data=None, optional=False):
        if self.base_url:
            endpoint = f'{self.base_url}/{endpoint}'
        args = ['gh', 'api', '--method', method, endpoint]
        kwargs = {}
        if data is not None:
            args += ['--input', '-']
            kwargs['input'] = json.dumps(data)
        try:
            raw = subprocess.check_output(args, text=True, stderr=subprocess.PIPE, **kwargs)
        except (OSError, subprocess.CalledProcessError) as error:
            detail = getattr(error, 'stderr', None) or str(error)
            match = re.search(r'HTTP (\d{3})', detail)
            status = int(match[1]) if match else None
            if optional and status == 404:
                return None
            raise APIError(f'GitHub {method} {endpoint} failed: {detail}', status) from error
        return json.loads(raw)


def require_readiness(api, repository):
    issue = api.call('GET', f'repos/{repository}/issues/11')
    if issue.get('state') != 'closed' or 'pull_request' in issue:
        raise ReleaseError('issue #11 must be closed after release prerequisites are completed')


def candidate(sha):
    if not isinstance(sha, str) or not SHA.fullmatch(sha):
        raise ReleaseError('candidate must be a full lowercase commit SHA')
    # First-parent ancestry excludes commits that only lived on a merged feature branch.
    if sha not in git('rev-list', '--first-parent', 'origin/main').splitlines():
        raise ReleaseError('candidate is not a main first-parent commit')
    config = parse_config(git_file(sha, 'release.json'))
    parents = git('rev-list', '--parents', '-n', '1', sha).split()[1:]
    raw_previous = git_file(parents[0], 'release.json', optional=True) if parents else None
    previous = parse_config(raw_previous) if raw_previous is not None else None
    notes = git_file(sha, notes_path(config))
    validate_notes(notes, config)
    return config, notes, release_intent(config, previous)


def tag_sha(api, repository, tag):
    ref = api.call('GET', f'repos/{repository}/git/ref/tags/{quote(tag, safe="")}', optional=True)
    if ref is None:
        return None
    obj = ref['object']
    for _ in range(10):
        if obj['type'] == 'commit':
            return obj['sha']
        if obj['type'] != 'tag':
            break
        obj = api.call('GET', f"repos/{repository}/git/tags/{obj['sha']}")['object']
    raise ReleaseError(f'{tag} does not resolve to a commit')


def verify_consumer(repository_url, version, expected_sha):
    """Resolve/build through the actual version tag in a separate Swift package."""
    identity = Path(urlparse(repository_url).path).name.removesuffix('.git').lower()
    with tempfile.TemporaryDirectory(prefix='momo-release-consumer-') as temporary:
        directory = Path(temporary)
        (directory / 'Sources/Consumer').mkdir(parents=True)
        (directory / 'Sources/Consumer/main.swift').write_text('import MoMoSDK\n', encoding='utf-8')
        (directory / 'Package.swift').write_text(
            '// swift-tools-version: 6.2\nimport PackageDescription\n'
            'let package = Package(name: "ReleaseConsumer", platforms: [.macOS(.v13)], '
            f'dependencies: [.package(url: {json.dumps(repository_url)}, exact: {json.dumps(version)})], '
            'targets: [.executableTarget(name: "Consumer", dependencies: '
            f'[.product(name: "MoMoSDK", package: {json.dumps(identity)})])])\n', encoding='utf-8')
        command(['swift', 'build', '--package-path', str(directory)])
        resolved = json.loads((directory / 'Package.resolved').read_text(encoding='utf-8'))
        pins = [pin for pin in resolved['pins'] if pin['identity'] == identity]
        if len(pins) != 1 or pins[0]['state'].get('revision') != expected_sha or pins[0]['state'].get('version') != version:
            raise ReleaseError('external consumer did not resolve the exact verified SHA and version')
    print(f'External SwiftPM consumer built {version} at {expected_sha}')


def publish(api, repository, sha, config, notes, consumer=verify_consumer):
    tag = f"v{config['version']}"
    endpoint = f'repos/{repository}'
    existing_sha = tag_sha(api, repository, tag)
    release = api.call('GET', f'{endpoint}/releases/tags/{quote(tag, safe="")}', optional=True)
    if existing_sha is not None and existing_sha != sha:
        raise ReleaseError(f'{tag} already points to {existing_sha}; refusing to move it to {sha}')
    if release and (existing_sha is None or release.get('tag_name') != tag or release.get('prerelease') != config['prerelease']):
        raise ReleaseError('existing release conflicts with the requested tag or release type')
    if existing_sha is None:
        try:
            api.call('POST', f'{endpoint}/git/refs', {'ref': f'refs/tags/{tag}', 'sha': sha})
        except APIError as error:
            # A concurrently created matching tag is safe; never update an existing ref.
            if error.status != 422 or tag_sha(api, repository, tag) != sha:
                raise
    # A failed consumer check leaves the same tag available for a safe manual retry.
    consumer(f'https://github.com/{repository}.git', config['version'], sha)
    if tag_sha(api, repository, tag) != sha:
        raise ReleaseError('tag changed during consumer verification; refusing publication')
    if release and not release.get('draft', True):
        print(f'{tag} already published at the verified commit; no changes made')
        return
    marker = f'<!-- momo-swift-release-sha:{sha} -->'
    body = f'{notes.rstrip()}\n\nVerified main commit: `{sha}`.\n\n{marker}\n'
    payload = {'tag_name': tag, 'target_commitish': sha, 'name': f'MoMoSDK {tag}',
               'body': body, 'draft': False, 'prerelease': config['prerelease']}
    if release:
        api.call('PATCH', f"{endpoint}/releases/{release['id']}", payload)
    else:
        api.call('POST', f'{endpoint}/releases', payload)
    print(f'Published {tag} at {sha}')


def actions_context(env, publishing=False):
    if env.get('GITHUB_ACTIONS') != 'true' or env.get('GITHUB_REF') != 'refs/heads/main' or env.get('GITHUB_EVENT_NAME') not in {'push', 'workflow_dispatch'}:
        raise ReleaseError('publication is restricted to main push/manual GitHub Actions runs')
    if publishing and (env.get('VERIFICATION_RESULT') != 'success' or env.get('VERIFIED_SHA') != env.get('CANDIDATE_SHA')):
        raise ReleaseError('both reusable verification jobs must succeed for this exact SHA')
    repository = env.get('GITHUB_REPOSITORY', '')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ReleaseError('invalid GitHub repository')
    return repository


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['validate', 'prepare', 'publish'])
    args = parser.parse_args()
    try:
        if args.command == 'validate':
            config = parse_config((ROOT / 'release.json').read_text(encoding='utf-8'))
            validate_notes((ROOT / notes_path(config)).read_text(encoding='utf-8'), config)
            if not (ROOT / 'LICENSE').is_file():
                raise ReleaseError('LICENSE is required')
            print(f"Release configuration valid: v{config['version']}; publicationApproved={config['publicationApproved']}")
            return 0
        env = os.environ
        repository = actions_context(env, publishing=args.command == 'publish')
        sha = env.get('CANDIDATE_SHA', '')
        config, notes, eligible = candidate(sha)
        if args.command == 'prepare':
            if eligible:
                require_readiness(GitHub(), repository)
            with open(env['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
                output.write(f"eligible={str(eligible).lower()}\nsha={sha}\n")
            print(f'Release intent eligible: {eligible}')
            return 0
        if not eligible or git('rev-parse', 'HEAD') != sha:
            raise ReleaseError('checked-out commit must be the eligible verified release-intent commit')
        require_readiness(GitHub(), repository)
        publish(GitHub(), repository, sha, config, notes)
        return 0
    except (ReleaseError, OSError, KeyError, ValueError) as error:
        print(f'error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

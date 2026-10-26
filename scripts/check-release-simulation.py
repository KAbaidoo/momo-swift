#!/usr/bin/env python3
"""Exercise the real GitHub CLI transport against the local Postman simulation."""

import argparse
import importlib.util
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('base_url', help='Loopback github member URL from the simulation listening event')
    args = parser.parse_args()
    api = release.GitHub(args.base_url)
    # Never use real GitHub credentials in the local mock request/log.
    os.environ['GH_TOKEN'] = 'local-simulation-placeholder'
    repository = 'owner/repo'
    sha = 'a' * 40
    config = {'version': '0.1.0', 'publicationApproved': True, 'prerelease': True}
    notes = '# v0.1.0\n.package(url: "example", exact: "0.1.0")\n'
    # The real SwiftPM/tag build is tested separately against a local Git clone.
    consumer_calls = []
    consumer = lambda *values: consumer_calls.append(values)
    publish = lambda: release.publish(api, repository, sha, config, notes, consumer)

    api.call('POST', '__reset', {})
    release.require_readiness(api, repository)
    publish()
    publish()
    state = api.call('GET', '__state')
    assert (state['tagsCreated'], state['releasesCreated'], state['tag']) == (1, 1, sha), state

    api.call('POST', '__reset', {'failNextRelease': True})
    try:
        publish()
    except release.APIError as error:
        assert error.status == 500, error
    else:
        raise AssertionError('expected simulated release service failure')
    state = api.call('GET', '__state')
    assert state['tag'] == sha and state['release'] is None, state
    publish()
    state = api.call('GET', '__state')
    assert (state['tagsCreated'], state['releasesCreated']) == (1, 1), state

    api.call('POST', '__reset', {'tag': 'b' * 40})
    try:
        publish()
    except release.ReleaseError as error:
        assert 'refusing to move' in str(error), error
    else:
        raise AssertionError('conflicting tag must fail')
    state = api.call('GET', '__state')
    assert state['tagsCreated'] == state['releasesCreated'] == 0, state
    assert state['tag'] == 'b' * 40 and consumer_calls, state
    print('Real gh HTTP transport: first release, idempotent retry, 500 recovery, and conflict rejection passed.')


if __name__ == '__main__':
    main()

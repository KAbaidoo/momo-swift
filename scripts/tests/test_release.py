"""Release orchestration tests; no network requests, real tags, or releases."""

import copy
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SPEC = importlib.util.spec_from_file_location('momo_release', Path(__file__).resolve().parents[1] / 'release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)
SHA = 'a' * 40
CONFIG = {'version': '0.1.0', 'publicationApproved': True, 'prerelease': True}
NOTES = '# v0.1.0\n.package(url: "example", exact: "0.1.0")\n'


class FakeGitHub:
    def __init__(self, tag=None, existing_release=None):
        self.tag = tag
        self.release = existing_release
        self.mutations = []
        self.issue = {'state': 'closed'}

    def call(self, method, endpoint, data=None, optional=False):
        if method == 'GET':
            if '/git/ref/' in endpoint:
                return {'object': {'type': 'commit', 'sha': self.tag}} if self.tag else None
            if '/releases/tags/' in endpoint:
                return self.release
            if '/issues/' in endpoint:
                return self.issue
            raise AssertionError(endpoint)
        self.mutations.append((method, endpoint, copy.deepcopy(data)))
        if endpoint.endswith('/git/refs'):
            assert self.tag is None
            self.tag = data['sha']
        elif '/releases' in endpoint:
            self.release = dict(data, id=1)
        else:
            raise AssertionError(endpoint)
        return data


class ConfigurationTests(unittest.TestCase):
    def test_semver_and_boolean_validation(self):
        for version in ('0.1.0', '1.2.3', '1.0.0-rc.1', '1.2.3+build.1'):
            self.assertEqual(release.parse_config(json.dumps(dict(CONFIG, version=version)))['version'], version)
        for version in ('v0.1.0', '01.0.0', '1.0', '1.0.0-01', '1.0.0\n', '', None):
            with self.subTest(version=version), self.assertRaises(release.ReleaseError):
                release.parse_config(json.dumps(dict(CONFIG, version=version)))
        for field in ('publicationApproved', 'prerelease'):
            with self.assertRaises(release.ReleaseError):
                release.parse_config(json.dumps(dict(CONFIG, **{field: 'true'})))
        with self.assertRaises(release.ReleaseError):
            release.parse_config(json.dumps(dict(CONFIG, version='1.0.0-rc.1', prerelease=False)))

    def test_only_a_version_or_explicit_approval_transition_is_release_intent(self):
        self.assertTrue(release.release_intent(CONFIG, None))
        self.assertTrue(release.release_intent(CONFIG, dict(CONFIG, version='0.0.1')))
        self.assertTrue(release.release_intent(CONFIG, dict(CONFIG, publicationApproved=False)))
        self.assertFalse(release.release_intent(CONFIG, CONFIG))
        self.assertFalse(release.release_intent(dict(CONFIG, publicationApproved=False), None))

    def test_release_notes_must_have_installation_for_the_version(self):
        release.validate_notes(NOTES, CONFIG)
        for notes in ('', '# v0.1.0', '.package(exact: "0.0.1")'):
            with self.assertRaises(release.ReleaseError):
                release.validate_notes(notes, CONFIG)


class MainHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.patch = mock.patch.object(release, 'ROOT', self.root)
        self.patch.start()
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Release Test')
        self.git('config', 'user.email', 'release-test@example.invalid')
        (self.root / 'README').write_text('fixture\n')
        self.initial = self.commit('initial without version or tags')

    def tearDown(self):
        self.patch.stop()
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True, stderr=subprocess.PIPE).strip()

    def commit(self, message):
        self.git('add', '.')
        self.git('commit', '-m', message)
        sha = self.git('rev-parse', 'HEAD')
        self.git('update-ref', 'refs/remotes/origin/main', sha)
        return sha

    def write_config(self, approved):
        (self.root / 'release.json').write_text(json.dumps(dict(CONFIG, publicationApproved=approved)))
        path = self.root / release.notes_path(CONFIG)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(NOTES)

    def test_first_release_disabled_then_approved_then_ordinary_merge_and_retry(self):
        self.write_config(False)
        disabled = self.commit('release infrastructure disabled')
        self.assertFalse(release.candidate(disabled)[2])
        self.write_config(True)
        approved = self.commit('approve first version')
        self.assertTrue(release.candidate(approved)[2])
        (self.root / 'README').write_text('ordinary change\n')
        ordinary = self.commit('ordinary merge without version bump')
        self.assertFalse(release.candidate(ordinary)[2])
        self.assertTrue(release.candidate(approved)[2], 'manual retry of prior main commit remains eligible')
        self.assertEqual(self.git('tag', '--list'), '')

    def test_unmerged_and_merged_feature_commits_are_not_main_candidates(self):
        self.git('checkout', '-b', 'feat/change')
        self.write_config(True)
        feature = self.commit('feature version')
        self.git('update-ref', 'refs/remotes/origin/main', self.initial)
        with self.assertRaisesRegex(release.ReleaseError, 'main first-parent'):
            release.candidate(feature)
        self.git('checkout', 'main')
        self.git('merge', '--no-ff', 'feat/change', '-m', 'merge release intent')
        merge = self.git('rev-parse', 'HEAD')
        self.git('update-ref', 'refs/remotes/origin/main', merge)
        self.assertTrue(release.candidate(merge)[2])
        with self.assertRaisesRegex(release.ReleaseError, 'main first-parent'):
            release.candidate(feature)

    def test_disabled_main_preparation_skips_without_reading_readiness_or_writing_remote_state(self):
        self.write_config(False)
        sha = self.commit('disabled release intent')
        output = self.root / 'outputs'
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main',
               'GITHUB_EVENT_NAME': 'push', 'GITHUB_REPOSITORY': 'owner/repo',
               'CANDIDATE_SHA': sha, 'GITHUB_OUTPUT': str(output)}
        with mock.patch.dict(os.environ, env, clear=True), mock.patch('sys.argv', ['release.py', 'prepare']), \
                mock.patch.object(release, 'GitHub') as api:
            self.assertEqual(release.main(), 0)
            api.assert_not_called()
        self.assertIn('eligible=false', output.read_text())


class PublicationTests(unittest.TestCase):
    def publish(self, api, consumer=None):
        release.publish(api, 'owner/repo', SHA, CONFIG, NOTES, consumer or mock.Mock())

    def test_first_release_and_successful_retry_create_exactly_one_tag_and_release(self):
        api = FakeGitHub()
        consumer = mock.Mock()
        self.publish(api, consumer)
        self.assertEqual(api.tag, SHA)
        self.assertFalse(api.release['draft'])
        self.assertIn(SHA, api.release['body'])
        self.assertEqual(api.release['target_commitish'], SHA)
        consumer.assert_called_once_with('https://github.com/owner/repo.git', '0.1.0', SHA)
        self.assertEqual(len(api.mutations), 2)
        self.publish(api)
        self.assertEqual(len(api.mutations), 2)

    def test_tag_only_failure_then_manual_retry_completes_without_retagging(self):
        api = FakeGitHub()
        with self.assertRaisesRegex(release.ReleaseError, 'consumer failure'):
            self.publish(api, mock.Mock(side_effect=release.ReleaseError('consumer failure')))
        self.assertEqual(api.tag, SHA)
        self.assertIsNone(api.release)
        self.publish(api)
        self.assertEqual([m[0] for m in api.mutations], ['POST', 'POST'])

    def test_existing_draft_is_published_without_duplicate_or_tag_update(self):
        api = FakeGitHub(SHA, {'id': 4, 'tag_name': 'v0.1.0', 'prerelease': True, 'draft': True})
        self.publish(api)
        self.assertEqual(len(api.mutations), 1)
        self.assertEqual(api.mutations[0][0:2], ('PATCH', 'repos/owner/repo/releases/4'))
        self.assertFalse(api.release['draft'])

    def test_conflicting_tags_or_releases_fail_without_mutations(self):
        states = [
            FakeGitHub('b' * 40),
            FakeGitHub(SHA, {'tag_name': 'v9.9.9', 'prerelease': True}),
            FakeGitHub(SHA, {'tag_name': 'v0.1.0', 'prerelease': False}),
            FakeGitHub(None, {'tag_name': 'v0.1.0', 'prerelease': True}),
        ]
        for api in states:
            with self.assertRaises(release.ReleaseError):
                self.publish(api)
            self.assertEqual(api.mutations, [])

    def test_tag_changed_during_consumer_build_prevents_publication(self):
        api = FakeGitHub(SHA)
        with self.assertRaisesRegex(release.ReleaseError, 'tag changed'):
            self.publish(api, lambda *args: setattr(api, 'tag', 'b' * 40))
        self.assertEqual(api.mutations, [])

    def test_release_api_failure_after_tag_creation_is_recoverable(self):
        api = FakeGitHub()
        original = api.call

        def fail_release(method, endpoint, data=None, optional=False):
            if method == 'POST' and endpoint.endswith('/releases'):
                raise release.APIError('temporary release API failure', 500)
            return original(method, endpoint, data, optional)

        with mock.patch.object(api, 'call', side_effect=fail_release):
            with self.assertRaises(release.APIError):
                self.publish(api)
        self.assertEqual(api.tag, SHA)
        self.assertIsNone(api.release)
        self.publish(api)
        self.assertEqual(len(api.mutations), 2)

    def test_concurrent_matching_tag_is_reused_but_conflicting_tag_is_rejected(self):
        for new_sha in (SHA, 'b' * 40):
            api = FakeGitHub()
            original = api.call

            def raced(method, endpoint, data=None, optional=False):
                if method == 'POST' and endpoint.endswith('/git/refs'):
                    api.tag = new_sha
                    raise release.APIError('reference exists', 422)
                return original(method, endpoint, data, optional)

            with mock.patch.object(api, 'call', side_effect=raced):
                if new_sha == SHA:
                    self.publish(api)
                    self.assertIsNotNone(api.release)
                else:
                    with self.assertRaises(release.APIError):
                        self.publish(api)
                    self.assertIsNone(api.release)

    def test_annotated_tag_is_peeled_to_verified_commit(self):
        api = mock.Mock()
        api.call.side_effect = [{'object': {'type': 'tag', 'sha': 'b' * 40}},
                                {'object': {'type': 'commit', 'sha': SHA}}]
        self.assertEqual(release.tag_sha(api, 'owner/repo', 'v0.1.0'), SHA)


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REF': 'refs/heads/main',
                    'GITHUB_EVENT_NAME': 'push', 'GITHUB_REPOSITORY': 'owner/repo',
                    'VERIFICATION_RESULT': 'success', 'VERIFIED_SHA': SHA, 'CANDIDATE_SHA': SHA}

    def test_exact_sha_success_is_required_and_non_main_pr_or_local_runs_rejected(self):
        self.assertEqual(release.actions_context(self.env, publishing=True), 'owner/repo')
        for field, value in (('GITHUB_ACTIONS', 'false'), ('GITHUB_REF', 'refs/heads/feat/change'),
                             ('GITHUB_EVENT_NAME', 'pull_request'), ('VERIFICATION_RESULT', 'failure'),
                             ('VERIFICATION_RESULT', 'skipped'), ('VERIFIED_SHA', 'b' * 40)):
            with self.subTest(field=field, value=value), self.assertRaises(release.ReleaseError):
                release.actions_context(dict(self.env, **{field: value}), publishing=True)

    def test_open_readiness_issue_prevents_release(self):
        api = FakeGitHub()
        api.issue['state'] = 'open'
        with self.assertRaisesRegex(release.ReleaseError, '#11'):
            release.require_readiness(api, 'owner/repo')
        self.assertEqual(api.mutations, [])

    def test_failed_verification_stops_publish_cli_before_any_github_request(self):
        env = dict(self.env, VERIFICATION_RESULT='failure')
        with mock.patch.dict(os.environ, env, clear=True), mock.patch('sys.argv', ['release.py', 'publish']), \
                mock.patch.object(release, 'GitHub') as api:
            self.assertEqual(release.main(), 1)
            api.assert_not_called()

    def test_only_404_is_optional_not_auth_or_network_failure(self):
        for status in (404, 403, 500):
            error = subprocess.CalledProcessError(1, ['gh'], stderr=f'gh: error (HTTP {status})')
            with mock.patch.object(release.subprocess, 'check_output', side_effect=error):
                if status == 404:
                    self.assertIsNone(release.GitHub().call('GET', 'example', optional=True))
                else:
                    with self.assertRaises(release.APIError):
                        release.GitHub().call('GET', 'example', optional=True)


if __name__ == '__main__':
    unittest.main()

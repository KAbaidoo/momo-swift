# Publishing a source release

The [publication workflow](../.github/workflows/release.yml) publishes a version tag and GitHub Release from `main`. Swift Package Manager consumers install through the repository URL; there are no binary assets. The [version source](../release.json) is explicit:

```json
{
  "version": "0.1.0",
  "publicationApproved": false,
  "prerelease": true
}
```

`version` is SemVer without a `v` prefix. The tag is `v<version>`. Pre-release identifiers cannot contain numeric leading zeroes. `prerelease` controls the GitHub Release flag; a SemVer prerelease suffix requires it to be true. The initial `0.1.0` is an experimental GitHub prerelease, consistent with the selected support policy.

## First-release prerequisites

Publication is disabled until `publicationApproved` is explicitly set to true **and** [issue #11](https://github.com/KAbaidoo/momo-swift/issues/11) is closed after its readiness work is complete. The pipeline reads the issue state before verification and again before publishing. Merging this automation alone must not enable a first release.

Before scope approval, complete the [readiness record](RELEASE_READINESS.md) with authorized operator evidence for claimed capabilities or explicit exclusions, license/support decisions, and owner approval. The owner-approved experimental v0.1.0 scope excludes operator verification and production-readiness claims. Closing issue #11 records that scope decision; it does not mark operator behavior as verified. Retain any sensitive evidence in its restricted location. The pipeline cannot independently certify operator evidence.

After scope approval, the [release checklist](RELEASE_CHECKLIST.md), explicit publication activation, and exact-main-commit verification still apply. Issue closure alone does not enable publication or bypass checks.

No live transactions, tags, releases, or changes to issue #11 are required to test this automation. Tests use temporary Git repositories and an in-memory GitHub transport.

For real HTTP transport verification without GitHub writes, use the [local Postman simulation](../postman/simulations/release/release.context.md). Its executable harness covers initial publication, duplicate prevention, tag-only recovery after an HTTP 500, and conflicting tags with placeholder credentials.

## Select and publish a version

1. Start a `feat/` or `fix/` branch from current `develop`. Set the new SemVer in `release.json` and add `docs/releases/v<version>.md`. For the first release, the selected target is `0.1.0`; complete the prerequisites before setting `publicationApproved` to true. For subsequent releases, keep approval false while preparing if needed, then intentionally approve the candidate.
2. Include installation instructions for that exact version, migration/setup guidance, supported products/platforms, requirements, verification limits, and any changed capability claims in the release notes. Commit the notes with the version source. Review the complete candidate before merging through `develop` to `main`.
3. Run local validation and use the normal PR checks:

   ```sh
   python3 scripts/release.py validate
   python3 -m unittest discover -s scripts/tests -v
   git diff --check
   ```

4. Merge the intentional release configuration change to `main`. An approved version change, or a deliberate transition from unapproved to approved, is release intent. The pipeline compares the candidate with its first parent; it does not depend on a previous tag. An ordinary merge with unchanged version/approval is skipped, even when the version is not yet released.
5. Inspect **Publish MoMoSDK**. It verifies that the candidate is a first-parent `main` commit, then calls the same [SDK verification workflow](../.github/workflows/ci.yml) used by PRs. Both Linux and Apple must succeed for that exact SHA. The Apple job covers root/nested tests, consumer build, deployment floors, and the simulator demo; Linux covers root tests and the consumer build. Public contract/tooling validation also runs.
6. The serialized publishing job rechecks readiness and tag/release state, creates a lightweight tag at the verified SHA, then resolves/builds an independent Swift package through that version tag. It checks `Package.resolved` for both the version and verified SHA. Only then does it publish the GitHub Release using the committed notes and appended verified SHA.

The pipeline uses the repository's `GITHUB_TOKEN` through `GH_TOKEN`. Only the publishing job has `contents: write`; other jobs have read permissions. No personal token is required. Tags/releases created using this token may not start additional workflows, so publication performs its consumer check directly and does not rely on tag-triggered CI.

Protect `main`, require reviewed changes, and restrict edits to workflows, release configuration, release notes, and approval records to authorized maintainers. The pipeline is release automation, not a substitute for repository access controls.

## Manual retry and partial recovery

Use the original **release-intent main SHA**, not a later ordinary merge's SHA. It must remain on `main`'s first-parent history. Either re-run the failed workflow or dispatch the workflow from `main` with that full commit SHA:

```sh
gh workflow run release.yml --ref main -f sha=<40-character-release-intent-main-sha>
```

Leaving the input blank evaluates the current run's main SHA; it does not search history for unreleased versions. Both full verification jobs run again before any publication. Publication jobs share a single concurrency group with cancellation disabled. GitHub may replace an older pending job when several are queued; dispatch a canceled eligible SHA again if necessary.

| Observed state | Retry behavior |
| --- | --- |
| No tag or release | Creates the tag at the verified SHA, checks the versioned consumer, and creates the release |
| Matching tag, no release (for example, consumer/build or API failure) | Keeps the tag, repeats consumer verification, and creates the release |
| Matching tag and draft release | Verifies the consumer, then publishes that draft with the reviewed notes |
| Matching tag and published release | Verifies the consumer, then succeeds without editing the release or creating duplicates |
| Tag resolves to another SHA, release type differs, or release exists without its tag | Fails without changing the conflicting state |
| Verification/readiness check fails | Does not create a tag or release |

Never force-push, delete, or move a release tag to make a retry pass. Investigate a conflicting version; choose a new version for different code. A failed consumer check can leave an unpublished but externally visible tag, because resolving the real version requires that tag to exist. Treat that version as reserved for its exact commit and retry that commit. The publisher never edits an already published release.

## Evidence and limits

The implementation tests first-release history without tags, ordinary merges, feature/PR restrictions, exact-SHA verification guards, conflicting tags/releases, draft/tag-only recovery, and idempotent reruns. A separate local exercise resolved and built the actual SDK from a disposable local version tag. Those checks do not claim a successful production GitHub publication or prove the behavior of repository branch/tag rules. The first authorized main publication must still be observed, including its tag SHA, release, and remote versioned-consumer build.

GitHub references: [reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), [GITHUB_TOKEN permissions](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token), and [Git reference API](https://docs.github.com/en/rest/git/refs).

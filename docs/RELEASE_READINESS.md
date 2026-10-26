# Initial release readiness

Status as of 26 October 2026: **experimental v0.1.0 prerelease scope approved by the repository owner**. This record tracks issue [#11](https://github.com/KAbaidoo/momo-swift/issues/11). Release claims cover offline-tested SDK contract behavior and recorded build compatibility. Operator behavior remains unverified, and production-readiness claims are excluded. Publication activation and verification of the exact main release commit remain required.

## License, version, and support

- License: [MIT](../LICENSE), selected following the owner's request for an open-source recommendation. It covers this project's software; third-party MTN specifications and services retain their own terms.
- Selected initial version: **v0.1.0**, following the owner's instruction to use the recommended open-source defaults. No version tag or GitHub release has been created by this work.
- Stability policy: experimental, pre-1.0 API. Source and behavior changes may occur between minor versions; document breaking changes in [MIGRATION.md](MIGRATION.md). Patch releases should preserve the documented API and behavior except for necessary bug fixes.
- Support expectations: best-effort maintenance through GitHub issues, with no response-time or production support commitment. Consumers must pin a reviewed version or commit and validate their own operator integration.
- Declared requirements remain Swift 6.2+, iOS 16, macOS 13, watchOS 8, tvOS 15, and Linux. Build evidence does not establish runtime behavior on every supported OS/device.

The owner delegated selection of these open-source defaults on 26 October 2026. The license, version target, and support policy are selected; publication remains subject to the gates below. A versioned release must not claim operator certification from offline evidence.

## Available engineering evidence

The verification baseline is develop commit `48c9e830a2ecdebfbcd981563cd26cdc1bb7709c`, before the license/documentation changes. [SDK verification run 40338051382](https://github.com/KAbaidoo/momo-swift/actions/runs/40338051382) passed the Apple and Linux jobs for that exact commit.

The current implementation baseline is develop commit `95ba4e40fe87e9e735018afcbf137ee05d6806c4`, including the release pipeline. [SDK verification run 40369268108](https://github.com/KAbaidoo/momo-swift/actions/runs/40369268108) passed Apple and Linux verification for that commit. This is engineering evidence for the approved scope; the eventual main release commit must still pass its own pipeline verification.

Contract preservation [PR #14](https://github.com/KAbaidoo/momo-swift/pull/14) is merged into develop at `2856ff5b4d801057ed0fc6eaa432ed7630126657`, the base for this readiness change. Its [PR verification run](https://github.com/KAbaidoo/momo-swift/actions/runs/40345741418) passed both Apple and Linux jobs. The [contract manifest](openapi/manifest.json) and [maintainer guide](openapi/README.md) record the immutable private archive, original checksums, and authenticated verification procedure.

Local checks on 26 October 2026 passed 52 root tests, 46 nested SDK tests, the independent SmokeClient build, all 20 Apple module/platform deployment-floor checks, and the iOS Simulator demo build. These checks exercise synthetic responses and compilation; they do not provide authorized operator integration evidence. The [issue #9 handoff](ISSUE_9_HANDOFF.md) records the submission-recovery behavior and verification commands. The [original review](REVIEW.md) remains dated historical evidence rather than a report for a future release commit.

Repeat the [release checklist](RELEASE_CHECKLIST.md) against the final candidate commit and record its exact SHA and CI run links before approving a tag. Test counts and prior green runs alone cannot approve a different candidate.

## Operator verification and claim exclusions

No authorized operator evidence has been supplied for this release record. For experimental v0.1.0, every operator behavior below is **unverified and excluded from release claims**. These exclusions allow the SDK's offline-tested behavior and recorded build compatibility to be published without asserting operator certification or production readiness. SDK APIs remain available for experimental integration under these documented limits.

Before any future release claims operator verification, evidence must identify the exact SDK commit, product, environment, date, authorized operator/test scope, expected outcome, actual outcome, and a durable restricted evidence location. Keep credentials, access tokens, personal identifiers, and financial details out of public issues and logs; reference sanitized results or access-controlled records.

| Capability | Evidence needed before an operator verification claim | v0.1.0 claim status |
| --- | --- | --- |
| Product authentication and entitlements | Collections, Disbursements, and Remittance authentication and enabled capabilities in the intended operator/environment | Unverified; excluded |
| Transaction state handling | Accepted, pending, successful, and failed outcomes with status reconciliation for each claimed financial flow | Unverified; excluded |
| Duplicate references | Operator response to duplicate references and proof the client does not replay a financial request | Unverified; excluded |
| Uncertain submission | Lost/ambiguous submission response followed by reconciliation using the persisted original reference | Unverified; excluded |
| Callbacks | Registered HTTPS host, delivery and correlation, and recovery after missing callbacks | Unverified; excluded |
| Consumer consent | Applicable authorization, token exchange/refresh, interval/expiry, denial, and pending behavior | Unverified; excluded |
| Refunds | Operator entitlement, applicable versions, outcomes, and reconciliation | Unverified; excluded |
| Product-specific requirements | Applicable currency, amount/message limits, fees, settlement, and originating-IP/environment rules | Unverified; excluded |

This register does not authorize live transactions. Operator validation requires a separately authorized test scope and eligible credentials. Excluded operator claims must remain visibly unverified until supported by evidence.

## Release claim boundaries

- Approved release claims cover offline SDK contract behavior and the recorded build configurations. Production readiness, production interoperability, settlement, fees, operator entitlements, and callback delivery are explicitly excluded from v0.1.0 claims and remain unverified.
- Voucher methods remain deprecated/unverified. The two suspicious Remittance routes and narrative-only consent financial operations remain excluded, as recorded in [API_COVERAGE.md](API_COVERAGE.md).
- Aggregator `transferType` is an optional payload compatibility field; supported values and operator eligibility remain unverified. Accepting the field is not an operator support claim.
- Consent and refund APIs have offline contract coverage; their operator behavior is unverified and excluded from release claims. The demo's successful build is not evidence of a completed sandbox or production transaction.

## Final approval record

On 26 October 2026, the repository owner explicitly instructed that this experimental scope be finalized, that its approval be recorded, and that issue #11 be closed. Approval covers MIT licensing, the experimental v0.1.0 prerelease with best-effort support, offline/build claims, and the operator/production exclusions above. It does not assert live integration success, waive exact-commit verification, or enable publication.

| Gate | State | Required completion |
| --- | --- | --- |
| License | MIT merged into develop through PR #15 | Carry the license into the main release candidate |
| Version/stability policy | v0.1.0 experimental, best-effort support approved | Carry this policy into the main release candidate |
| Contract baseline preservation | [PR #14](https://github.com/KAbaidoo/momo-swift/pull/14) merged; four original hashes verified on 26 October 2026 | Retain authorized archive access and reverify for the final candidate |
| Operator claim scope | Approved exclusions; operator behavior remains unverified | Preserve these exclusions in release documentation; require evidence before expanding claims |
| Experimental scope approval | Granted by the owner on 26 October 2026 | Close issue #11 with a reference to this record |
| Final candidate verification | Required for the exact main SHA; not yet established by this record | Pipeline must pass Apple/Linux verification and the versioned-consumer build before publishing |
| Publication activation | Disabled: `publicationApproved: false` | Separately approve activation in release.json and merge the release-intent change into main |

Issue #11 can be closed on the basis of the owner-approved experimental scope and explicit exclusions. Closing it completes the scope decision; final candidate verification and publication activation remain mandatory pipeline gates. No tag or release should be created from this readiness document alone.

The publication automation uses [release.json](../release.json) with `publicationApproved: false`. It also requires issue #11 to be closed after scope approval. See [RELEASING.md](RELEASING.md) for activation and recovery; the automation does not supply missing operator evidence or authorize live transactions.

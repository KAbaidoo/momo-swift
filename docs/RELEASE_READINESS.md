# Initial release readiness

Status as of 26 October 2026: **not ready for a versioned release**. This record tracks issue [#11](https://github.com/KAbaidoo/momo-swift/issues/11). Offline tests and builds pass; operator validation and the final release decision remain open.

## License, version, and support

- License: [MIT](../LICENSE), selected following the owner's request for an open-source recommendation. It covers this project's software; third-party MTN specifications and services retain their own terms.
- Selected initial version: **v0.1.0**, following the owner's instruction to use the recommended open-source defaults. No version tag or GitHub release has been created by this work.
- Stability policy: experimental, pre-1.0 API. Source and behavior changes may occur between minor versions; document breaking changes in [MIGRATION.md](MIGRATION.md). Patch releases should preserve the documented API and behavior except for necessary bug fixes.
- Support expectations: best-effort maintenance through GitHub issues, with no response-time or production support commitment. Consumers must pin a reviewed version or commit and validate their own operator integration.
- Declared requirements remain Swift 6.2+, iOS 16, macOS 13, watchOS 8, tvOS 15, and Linux. Build evidence does not establish runtime behavior on every supported OS/device.

The owner delegated selection of these open-source defaults on 26 October 2026. The license, version target, and support policy are selected; publication remains subject to the gates below. A versioned release must not claim operator certification from offline evidence.

## Available engineering evidence

The verification baseline is develop commit `48c9e830a2ecdebfbcd981563cd26cdc1bb7709c`, before the license/documentation changes. [SDK verification run 40338051382](https://github.com/KAbaidoo/momo-swift/actions/runs/40338051382) passed the Apple and Linux jobs for that exact commit.

Contract preservation [PR #14](https://github.com/KAbaidoo/momo-swift/pull/14) is merged into develop at `2856ff5b4d801057ed0fc6eaa432ed7630126657`, the base for this readiness change. Its [PR verification run](https://github.com/KAbaidoo/momo-swift/actions/runs/40345741418) passed both Apple and Linux jobs. The [contract manifest](openapi/manifest.json) and [maintainer guide](openapi/README.md) record the immutable private archive, original checksums, and authenticated verification procedure.

Local checks on 26 October 2026 passed 52 root tests, 46 nested SDK tests, the independent SmokeClient build, all 20 Apple module/platform deployment-floor checks, and the iOS Simulator demo build. These checks exercise synthetic responses and compilation; they do not provide authorized operator integration evidence. The [issue #9 handoff](ISSUE_9_HANDOFF.md) records the submission-recovery behavior and verification commands. The [original review](REVIEW.md) remains dated historical evidence rather than a report for a future release commit.

Repeat the [release checklist](RELEASE_CHECKLIST.md) against the final candidate commit and record its exact SHA and CI run links before approving a tag. Test counts and prior green runs alone cannot approve a different candidate.

## Operator evidence register

No authorized operator evidence has been supplied for this release record. Every row remains pending. Evidence must identify the exact SDK commit, product, environment, date, authorized operator/test scope, expected outcome, actual outcome, and a durable restricted evidence location. Keep credentials, access tokens, personal identifiers, and financial details out of public issues and logs; reference sanitized results or access-controlled records.

| Capability | Required evidence | Status |
| --- | --- | --- |
| Product authentication and entitlements | Collections, Disbursements, and Remittance authentication and enabled capabilities in the intended operator/environment | Pending |
| Transaction state handling | Accepted, pending, successful, and failed outcomes with status reconciliation for each claimed financial flow | Pending |
| Duplicate references | Operator response to duplicate references and proof the client does not replay a financial request | Pending |
| Uncertain submission | Lost/ambiguous submission response followed by reconciliation using the persisted original reference | Pending |
| Callbacks | Registered HTTPS host, delivery and correlation, and recovery after missing callbacks | Pending |
| Consumer consent | Applicable authorization, token exchange/refresh, interval/expiry, denial, and pending behavior | Pending |
| Refunds | Operator entitlement, applicable versions, outcomes, and reconciliation | Pending |
| Product-specific requirements | Applicable currency, amount/message limits, fees, settlement, and originating-IP/environment rules | Pending |

This register does not authorize live transactions. Operator validation requires a separately authorized test scope and eligible credentials. If a capability is excluded from the intended release claims, replace its pending status with an explicit exclusion and rationale; do not mark it verified.

## Release claim boundaries

- Current evidence supports offline SDK contract behavior and the recorded build configurations. Production interoperability, settlement, fees, operator entitlements, and callback delivery are unverified.
- Voucher methods remain deprecated/unverified. The two suspicious Remittance routes and narrative-only consent financial operations remain excluded, as recorded in [API_COVERAGE.md](API_COVERAGE.md).
- Aggregator `transferType` is an optional payload compatibility field; supported values and operator eligibility remain unverified. Accepting the field is not an operator support claim.
- Consent and refund APIs have offline contract coverage, but their operator behavior remains pending. The demo's successful build is not evidence of a completed sandbox or production transaction.

## Final approval record

| Gate | State | Required completion |
| --- | --- | --- |
| License | MIT added on this branch | Merge the license into the release candidate |
| Version/stability policy | v0.1.0 experimental, best-effort support selected | Merge this policy into the release candidate |
| Contract baseline preservation | [PR #14](https://github.com/KAbaidoo/momo-swift/pull/14) merged; four original hashes verified on 26 October 2026 | Retain authorized archive access and reverify for the final candidate |
| Operator evidence | Pending | Complete the register for claimed capabilities; explicitly record exclusions |
| Final candidate verification | Pending | Record candidate SHA, passing Apple/Linux CI links, and completed release checklist |
| Publication approval | Pending | Owner approves the exact candidate and tag only after all preceding gates are satisfied |

Issue #11 remains open while these gates are incomplete. No tag or release should be created from this readiness document alone.

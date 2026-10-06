# MTN MoMo Swift SDK implementation plan

The deliverable is a robust Swift Package Manager library for MTN MoMo, with a small sandbox demonstration app. This plan turns the public documentation review of 4 October 2026 into implementation tasks, acceptance criteria, and independent review gates.

## Scope and evidence

- Current public exports: Collections revision 7 (23 operations), Disbursements revision 6 (16), Remittance revision 4 (14, including two suspicious basic-user-info variants), Sandbox provisioning revision 1 (3).
- Sources: [API reference](https://momodeveloper.mtn.com/API-collections), [authentication](https://momodeveloper.mtn.com/api-documentation/api-description), [use cases](https://momodeveloper.mtn.com/api-documentation/use-cases), [callbacks](https://momodeveloper.mtn.com/api-documentation/callback), [sandbox scenarios](https://momodeveloper.mtn.com/api-documentation/testing), [best practices](https://momodeveloper.mtn.com/best-practices).
- Implement verified contracts; record contradictions instead of inventing fields or silently claiming production compatibility. Voucher operations, narrative-only consent payments, and suspicious Remittance paths require clarification.
- Preserve existing user changes in the package manifest and demo configuration. Do not submit real or sandbox financial transactions during automated verification. Do not commit credentials, publish a release, or change a remote repository as part of this work.

## Work allocation and sequence

The core agent owns transport, authentication, consent, polling, and provisioning. The Collections agent owns that product's contracts and tests. The payouts agent owns Disbursements and Remittance. The integration lead owns package integration, the demo, documentation, and CI. A separate skeptical reviewer checks each implementation and the final integration without treating a successful build as proof of correctness.

Shared interfaces are agreed first. Product work proceeds in parallel behind those interfaces. Integration and public-client compilation follow. Reviewer findings return to the responsible implementer, and affected checks rerun before sign-off.

## 1 Correct existing contracts

### Collections

- [x] Update invoice creation, status, and cancellation to v2 routes.
  - Match `validityDuration`, payee, references, expiry, and `errorReason` fields.
  - Represent `CREATED` independently of completed financial states.
  - Supply cancellation reference headers and external-ID body.
- [x] Correct preapproval v2 creation/status.
  - Add validity time and decode `status` rather than `transactionStatus`.
  - Separate approved mandates from asynchronous request results.
  - Model mandate statuses and cancel using the system mandate ID.
- [x] Correct account validation and identity handling.
  - Decode a false result under HTTP 200; never assume all 2xx responses mean active.
  - Escape path components and represent endpoint-specific identity types/casing.
- [x] Correct delivery notification headers and optional language.
  - Use the caller's message consistently.
  - Document success-only sequencing and notification-specific errors.

### Disbursements

- [x] Encode `payeeNote` for transfers; decode `payee`, not `payer`.
- [x] Preserve documented refund/deposit response fields and optional errors.
- [x] Correct account validation and basic-user-info handling.
- [x] Expose V1/V2 deposits and refunds explicitly, retaining v1 status lookup.

### Compatibility

- [x] Keep existing call sites where their meaning remains valid; deprecate misleading names with replacements.
- [x] Document unavoidable model/API migrations.
- [x] Mark existing voucher methods unverified; do not infer supported contracts from narrative descriptions alone.

Acceptance: synthetic request/response tests assert methods, versioned paths, exact wire keys, required headers, identifier encoding, false account results, and distinct status families. The demo compiles against corrected APIs.

## 2 Harden transport and transaction behavior

- [x] Introduce a Sendable injectable transport with a URLSession implementation.
  - Support FoundationNetworking where available.
  - Keep HTTP transport independent of UI and Keychain.
- [x] Validate URL/environment configuration before making requests.
  - Require secure production URLs and safe single-segment path encoding.
  - Avoid accidentally replacing authority or leaking credentials through redirects.
- [x] Remove unredacted network printing.
- [x] Preserve structured HTTP status, MTN reason code/message, and useful response metadata.
  - Distinguish decoding errors, transport errors, cancellation, polling exhaustion, and business failure.
  - Retain unknown server values for forward compatibility.
- [x] Add bounded retries for safe reads only.
  - Respect retry timing and cancellation.
  - Never automatically replay a financial POST after an uncertain outcome.
- [x] Improve token caching and concurrent refresh.
  - Reuse valid product tokens; coalesce refreshes; clear failed refresh state.
  - Support invalidation and bounded safe-read recovery from authorization failure.
- [x] Centralize polling.
  - Validate policy before initiating a transaction.
  - Bound attempts/duration and delay growth; stop only on known terminal states.
  - Preserve the reference ID on uncertain submission and polling failures.
  - Expose separate initiate and wait/status APIs so callers can persist/reconcile state.

Acceptance: deterministic tests cover coalescing, expiry, failure recovery, cancellation, retry bounds, no write replay, malformed/empty data, and recoverable reference IDs. No test requires real credentials or waits through real transaction intervals.

## 3 Expand verified API coverage

- [x] Collections: payments v2/status, balance by currency, withdrawal v2.
- [x] Disbursements: basic user information, balance by currency, deposit/refund v2.
- [x] Add a separate Remittance library product.
  - Transfer/status, cash transfer/status, balances, active-account lookup, basic user info.
  - Preserve cash-transfer wire spelling and identity metadata.
  - Keep the two suspicious cloned paths outside supported coverage.
- [x] Add consumer consent support for all three products.
  - Form-encode back-channel authorization and token exchange.
  - Model CIBA request ID, interval/expiry, scopes, online/offline consent, refresh tokens.
  - Keep consumer tokens distinct from product access tokens.
  - Expose consent user-info retrieval and document product-specific auth ambiguities.
- [x] Expand sandbox provisioning.
  - Separate create user, create key, and get user operations.
  - Retain a convenient combined provisioning method.
- [x] Accommodate documented aggregator `transferType` without hardcoding production-specific values.
- [x] Publish a coverage matrix that distinguishes implemented, unverified, and excluded operations.

Acceptance: each supported operation has request-shape or shared contract coverage; representative success, pending, failure, and optional-field responses decode; uncertain documentation remains visible to consumers.

## 4 Establish meaningful verification and cross-platform checks

- [x] Replace the empty test placeholder with meaningful module tests.
- [x] Use actor-isolated mock transports and synthetic fixtures.
- [x] Test public entry points, not only internal encoders.
- [x] Build/test on the available macOS toolchain.
- [x] Build the iOS simulator demo with signing disabled.
- [x] Check declared Apple deployment floors and Swift concurrency diagnostics.
- [x] Add CI for macOS and Linux with an explicit Swift version.
- [x] Add an external-package consumer smoke check using the repository root package.
- [x] State which checks actually ran locally; a workflow file is not evidence that remote CI passed.

Acceptance: local checks pass, platform limitations are stated, and CI commands reproduce documented setup. Independent review must identify untested contracts and remaining gaps.

## 5 Improve developer experience and release readiness

- [x] Document supported products, platforms, prerequisites, and both root/nested SPM package layouts.
- [x] Provide concise examples for initiate/persist/poll, account queries, consent, and remittance.
- [x] Explain product-specific credentials, sandbox EUR fixtures, callbacks, and production backend secret handling.
- [x] Explain timeout/uncertain outcome recovery without initiating duplicate payments.
- [x] Document migration paths and unresolved MTN documentation conflicts.
- [x] Improve demo sequencing, setup persistence errors, default scenarios, and task cancellation.
- [x] Make fresh-checkout configuration reproducible without touching local secrets.
- [x] Add release checklist and versioning guidance; do not choose a license or publish without owner direction.

Acceptance: examples compile, installation instructions describe the actual package, demo instructions work without credential disclosure, and release gaps are explicit.

## Independent skeptical review

- [x] Review contracts against the downloaded MTN definitions, including optionality and response-body semantics.
- [x] Challenge retries, cancellation, token refresh, and reference-ID recovery under adversarial failures.
- [x] Challenge DX: public construction, imports, naming, error inspection, compatibility, and examples.
- [x] Review portability, CI coverage, credential handling, and documentation claims.
- [x] Run independent tests and report prioritized findings with reproducible evidence.
- [x] Resolve blocking findings and rerun affected checks.
- [x] Record completion evidence and remaining limitations in `REVIEW.md`.

## Known external limits

Production credentials, operator entitlements, originating-IP allowlists, callback delivery, and real transaction settlement cannot be proven by offline tests. MTN's public sources disagree on some limits and schemas. Those differences remain tracked requirements for live integration validation rather than reasons to fabricate compatibility.

## Completion evidence — 4 October 2026

The planned implementation and independent offline review are complete. Root and nested packages, a standalone public consumer, the iOS demo, and declared Apple deployment-floor compilation were checked. Independent review passed 40 tests and reported no remaining blocking implementation findings. See [REVIEW.md](REVIEW.md) for exact commands, evidence, and limitations. Linux CI is configured but has not been executed here; operator/live integration and release publication remain explicit external gates.

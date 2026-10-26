# Issue #9 implementation handoff

## Ownership and dependencies

- SDK implementor: `MoMoError`, `MoMoAPIClient`, and the `requestToPay`/`deposit` entry points. Publishes the error and submission-helper contract before demo integration.
- Demo implementor: the two actual payment/deposit view models. Depends on the SDK classification; storage injection can proceed independently.
- Verification agent: SDK regressions, macOS-only targets compiling the actual demo view models, demo regressions, and build/check execution. Depends on both implementations for final verification.
- Primary agent: integration review against issue acceptance criteria, this handoff, and final verification reporting. Branch creation, commit, and push were subsequently authorized by the repository owner; release publication remains outside this change.

## SDK contract

- `MoMoError.preSubmissionFailure(referenceId:underlying:)` identifies a financial request that never reached its transport.
- `MoMoError.isKnownPreSubmissionFailure` exposes that explicit classification. Reference, cancellation and HTTP status accessors retain their existing meanings for both error wrappers.
- `MoMoAPIClient.executeAuthenticatedSubmission(_:referenceId:tokenProvider:)` obtains a product token and performs a write without replay. Token/preflight failures and cancellation before transport invocation are known pre-submission failures.
- A per-invocation dispatch flag is set immediately before calling `transport.data(for:)`. Every error after that boundary remains `transactionFailure`, even when transport cannot establish whether bytes were sent.
- Only `requestToPay` and `deposit` opt in, including their local input validation. Generic execution, unrelated financial operations, and polling-policy validation retain existing behavior.

## Demo integration

Both view models use injected `UserDefaults` (default `.standard`) with existing keys. Only an explicit pre-submission failure caught around the initial financial submission clears the reference and unresolved keys and displays: “Request was not sent. You can try again.”

Submission failures after transport invocation, polling errors, and status-check errors retain the unresolved reference. Authentication errors or 404 while reconciling an existing request never clear it. Terminal statuses resolve as before. Existing persisted references are not retroactively classified or discarded.

## Verification and acceptance

Tests must exercise both actual demo view models with actual SDK clients, isolated defaults suites, and controlled transports. They must establish safe retry after known pre-submission failures, restoration without stale blocking state, preservation after uncertain dispatch, and no additional financial submission while unresolved. Cancellation gates should be deterministic rather than sleep-based.

Required commands:

```sh
swift test --parallel
swift test --package-path MoMoSDK
swift build --package-path Examples/SmokeClient
python3 scripts/check-apple-platforms.py
xcodebuild -workspace MoMo.xcworkspace -scheme MoMoDemoApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

On a restricted local host, direct Swift/Clang caches and build output to `/tmp`, use `--disable-sandbox` for SwiftPM if required, and give Xcode access to its simulator services. There is no repository lint configuration; inspect compiler diagnostics and whitespace without reformatting unrelated files.

## Results and limits

All three agents completed their work. The primary agent reviewed the combined SDK, demo, manifest, and test changes against the acceptance criteria after their handoffs, then independently ran the root suite with `--parallel`. No remaining implementation findings were identified.

Verified locally on 26 October 2026 with Swift 6.2.4:

| Check | Result | Evidence |
| --- | --- | --- |
| Root suite, including actual demo view models | 52 tests passed with `--parallel` | `/tmp/momo-issue9-root-final.log` |
| Nested SDK suite | 46 tests passed | `/tmp/momo-issue9-nested.log` |
| Independent SmokeClient build | Passed | `/tmp/momo-issue9-smoke.log` |
| Apple deployment floors | All five modules passed on watchOS 8, tvOS 15, iOS 16, macOS 13 | `python3 scripts/check-apple-platforms.py` |
| iOS Simulator demo build | Passed | `/tmp/momo-issue9-xcodebuild.log` |
| Whitespace and diagnostics | `git diff --check` passed; no configured lint gate | Reviewed SwiftPM/Xcode logs |

Local SwiftPM checks used `CLANG_MODULE_CACHE_PATH=/tmp/momo-issue9-clang`, `SWIFTPM_MODULECACHE_OVERRIDE=/tmp/momo-issue9-swift`, `--disable-sandbox`, and scratch directories under `/tmp`. The final root run used `--scratch-path /tmp/momo-issue9-root`. Per-user cache write warnings were environmental; Xcode emitted an App Intents metadata warning because the demo has no AppIntents dependency. No new source warnings or unhandled-source warnings remained.

Acceptance review:

- Token rejection, transport failure, invalid token response, and cancellation before submission clear both demo flows' blocking state; reconstructed models can retry without stale references.
- Deterministic cancellation of the actual caller task during a gated shared token refresh results in zero financial submissions and cleared state. A cached-token SDK test cancels during request construction and verifies the final cancellation check prevents dispatch.
- After financial transport invocation, timeout/cancellation retain references across model reconstruction and prevent another financial POST.
- Polling 404, repeated status-check 404, status authentication failures, and status cancellation preserve existing references. Terminal success and failure resolve as before.
- SDK validation errors retain caller references without network calls. An uncertain outer error never becomes a known pre-submission failure because of its underlying error.

The latest remote main run at `920d478` passed both Apple and Linux jobs: https://github.com/KAbaidoo/momo-swift/actions/runs/37459762141. It verifies the base commit only. At local verification time, this change had not been committed or pushed; remote CI for the changed code must be checked after pushing the fix branch. Local Linux execution was unavailable because Docker's daemon socket was absent.

Shared-token refresh cancellation latency is unchanged. Existing ambiguous saved references remain unresolved. Controlled transport tests prove local classification and state handling; they do not certify MTN settlement, operator interoperability, or callback delivery. Remote CI on the base commit does not establish CI success for unpushed changes.

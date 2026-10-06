# Verification and independent review

Verification date: 4 October 2026. Toolchain: Swift 6.2.4, Xcode 26.3 with Apple 26.2 SDKs, macOS arm64. No live MTN financial transactions were submitted.

## Independent review

A separate skeptical agent reviewed all three product implementations and shared core against the four downloaded public OpenAPI exports, challenged tests and public API construction, and ran its own scratch builds. Its final independent SDK run passed **40 meaningful Swift Testing tests**, with zero failures. The independent external consumer package also compiled and linked.

Review found and resolved:

- Disbursement basic-user-info MSISDN casing and missing alias/ID construction. Added a typed product identity and regression tests.
- Missing Collections preflight monetary/party/callback validation. Invalid inputs now fail before network access.
- Cancellation could lose an internally generated financial reference. Submission/wait errors preserve it; `MoMoError.isCancellation` allows inspection.
- Consent optional fields and numeric types needed fuller contract coverage. Added exported payout consent fields, fractional numbers, and tolerant address decoding.
- UUIDv4 validation needed RFC variant checking. Version and variant now validate.
- Deployment-floor compilation exposed legacy `Duration` APIs unavailable on watchOS 8/tvOS 15. Those overloads are availability-gated; policy-based alternatives support the declared floors.

The initial suggestion that a structured consent address violated the response export was corrected: the export declares string and has an unreferenced object component. Supporting both is compatibility handling, not proof of a documented object response.

Final reviewer conclusion: no remaining blocking implementation findings. Review is offline contract verification, not MTN/operator certification.

## Checks actually executed

| Check | Command/evidence | Result |
| --- | --- | --- |
| Root SDK tests | `swift test --scratch-path /tmp/momo-integration-build` | 40 tests passed |
| Independent reviewer tests | `swift test --scratch-path /tmp/momo-independent-review-build` | 40 tests passed |
| Nested SDK package | `swift test --package-path MoMoSDK --scratch-path /tmp/momo-core-build` | Passed; same sources/tests |
| External package/examples | `swift build --package-path Examples/SmokeClient --scratch-path /tmp/momo-smoke-build` | Compiled/linked; examples type-checked, not invoked |
| Independent external consumer | `swift build --package-path Examples/SmokeClient --scratch-path /tmp/momo-independent-consumer-build` | Passed |
| iOS simulator demo | `xcodebuild -workspace MoMo.xcworkspace -scheme MoMoDemoApp -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/momo-demo-build CODE_SIGNING_ALLOWED=NO build` | Build succeeded |
| Apple minimum versions | `python3 scripts/check-apple-platforms.py` | All five modules compiled for iOS 16, macOS 13, watchOS 8, tvOS 15 |

The floor check emits modules with Swift 6 diagnostics; it establishes source/API availability, not execution on old operating systems or device linking. The demo was compiled, not interactively exercised with live credentials. The local Xcode project reports a pre-existing local config-file resource warning; private config/project edits were preserved.

Tests cover wire routes/versions, headers, exact decimal strings, sparse/unknown statuses, optional reasons, account false/404/error behavior, encoded identities, consent form fields and authentication, provisioning, malformed responses, token coalescing/expiry/failure recovery, safe-read retries/Retry-After/401, no financial replay, cancellation, reference recovery, and invalid polling policies/inputs. These representative tests do not exhaust every possible operator response.

## Remaining verification and release gates

- Linux CI is defined in `.github/workflows/ci.yml` using Swift 6.2.4. Linux execution was unavailable locally; no remote CI run is claimed.
- Production credentials, originating-IP rules, callbacks, consent permissions, aggregator contracts, fees, settlement, and actual operator response differences need authorized integration validation.
- Public docs have ambiguities recorded in [API_COVERAGE.md](API_COVERAGE.md). Two suspicious Remittance routes and narrative-only consent payments remain excluded; vouchers remain deprecated/unverified.
- Cancellation awaiting a shared token refresh is checked after that refresh finishes; transport timeout is 60 seconds. It does not instantly abort a refresh shared by other callers.
- The package root and nested manifests share sources and equivalent products/dependencies; both remain to preserve the existing workspace.
- License choice, version tagging, publication, and live integration are owner/operator release gates in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

No credential file was read by the independent reviewer, and no credentials were copied into documentation or tests. Existing local configuration edits were preserved. No commits, remote repository changes, or releases were created.

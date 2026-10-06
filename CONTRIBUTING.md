# Contributing to MoMo Swift

Thank you for improving the SDK and its developer experience. Contributions to code, tests, examples, and documentation are welcome. The package already implements MoMo operations; read the current [README](README.md) and [API coverage notes](docs/API_COVERAGE.md) before proposing an addition.

## Find a useful change

Check existing issues and pull requests first. Small bug fixes and documentation corrections can go straight to a pull request. For a new operation, a public API change, or a larger refactor, open an issue describing the developer use case and linking the relevant [official MTN MoMo documentation](https://momodeveloper.mtn.com/). State the product, API version, authentication, request and response shapes, and whether a transaction has a later status or callback.

The [implementation plan](docs/IMPLEMENTATION_PLAN.md), [migration notes](docs/MIGRATION.md), and [release checklist](docs/RELEASE_CHECKLIST.md) identify known work and validation still needed. The [Android community SDK](https://mtn-momo-sdk.rekast.io/) can inspire documentation, but use the MTN API contract and this repository's Swift code as the source of truth.

## Set up locally

Use Swift 6.2 or newer. On macOS, install a compatible Xcode. The root `Package.swift` supports Git URL and local SwiftPM use; `MoMoSDK/Package.swift` is retained for the Xcode workspace.

```sh
git clone https://github.com/KAbaidoo/momo-swift.git
cd momo-swift
swift test
swift test --package-path MoMoSDK
swift build --package-path Examples/SmokeClient
```

The tests use synthetic responses and require no API keys or live transactions. On macOS, the demo can be built with:

```sh
xcodebuild -workspace MoMo.xcworkspace -scheme MoMoDemoApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

To run the demo against MTN's sandbox, follow the [README's sandbox setup](README.md#sandbox-demo). Keep subscription keys out of source control and do not place production merchant credentials in a distributed client app.

## Make a change

- Keep each pull request focused and explain the user or contributor problem it solves.
- Put shared networking, authentication, validation, and models in `MoMoCore`; keep product-specific code in its product target. Update both package manifests if target or product definitions change.
- Preserve transaction reference IDs across initiation, polling, cancellation, and errors. HTTP 202 means accepted, not settled. A lost response must not trigger an automatic replay of a financial write.
- Use typed public APIs, document new public declarations, and update [API coverage](docs/API_COVERAGE.md) and usage examples when behavior changes.
- Add deterministic offline tests for request construction, decoding, error handling, and transaction states. Use the injectable transport rather than real credentials in the normal test suite.
- Check the [verification evidence](docs/REVIEW.md) before claiming platform or production support. Offline tests do not establish live settlement or callback delivery.

## Open a pull request

Run the relevant checks above and review your diff for secrets, personal data, generated files, and unrelated edits. The [pull request template](.github/pull_request_template.md) asks for verification and any API assumptions. Include a link to the MTN contract for API-facing changes and note behavior that still needs operator validation.

Maintainers may request a smaller scope, tests, documentation, or compatibility discussion before merging a public API change. Keep review comments specific and respectful.

## Security and sensitive data

Do not post subscription keys, API user credentials, Bearer tokens, real subscriber identifiers, or full transaction payloads in issues, pull requests, fixtures, logs, or screenshots. Use synthetic values and redact examples before sharing them.

Report suspected vulnerabilities privately through GitHub's private vulnerability reporting if it is enabled for this repository, or through a private channel published by the maintainer. Do not disclose exploit details or credentials in a public issue.

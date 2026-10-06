# MoMo Swift

A Swift Package Manager SDK for MTN MoMo Collections, Disbursements, Remittance, consumer consent, and sandbox provisioning. Uses async/await, Sendable clients, injectable networking, decimal money strings, and recoverable transaction references.

Requires Swift 6.2+. Declared platforms: iOS 16, macOS 13, watchOS 8, tvOS 15, and Linux. See [verification evidence](docs/REVIEW.md) for platforms actually checked. Production interoperability requires your operator's credentials and entitlements; offline contract tests cannot establish settlement or callback delivery.

## Installation

Add this repository's Git URL in Xcode or a Swift package dependency. The root `Package.swift` supports normal repository installation; the nested `MoMoSDK/Package.swift` remains for the existing demo workspace. Choose `MoMoSDK` for the umbrella import, or the individual `MoMoCore`, `MoMoCollections`, `MoMoDisbursements`, and `MoMoRemittance` products.

For a local checkout:

```swift
.package(path: "../momo-swift")
// In your target dependencies:
.product(name: "MoMoSDK", package: "momo-swift")
```

No external library dependencies are required. [Examples/SmokeClient](Examples/SmokeClient) compiles the public API from an independent package.

## Submit once, then reconcile

```swift
import Foundation
import MoMoSDK

let client = MoMoCollectionClient(credentials: credentials, environment: .sandbox)
let reference = UUID()
// Persist reference.uuidString in your order store BEFORE calling requestToPay.
let payload = RequestToPayRequest(
    amount: "12.50", currency: "EUR", externalId: "order-123",
    payer: Party(partyIdType: .msisdn, partyId: "46733123470"),
    payerMessage: "Order 123", payeeNote: "Order 123"
)
try await client.requestToPay(payload: payload, referenceId: reference)
let result = try await client.waitForRequestToPay(referenceId: reference.uuidString)
if result.status == .successful {
    // Fulfil the order. A FAILED status is a business outcome, not an HTTP error.
}
```

HTTP 202 means accepted, not completed. Never repeat a financial submission just because a response was lost or polling timed out. Check the stored reference with `getTransactionStatus`, or resume its wait. A 404 after an uncertain submission is not proof that it was never accepted. Unknown status values retain `rawValue` and do not terminate polling.

Financial submissions are never automatically retried. GET retries are bounded, respect `Retry-After`, and may refresh a rejected product token once. Polling has bounded attempts, exponential delays, and cancellation. Uncertain submission/poll errors expose `MoMoError.referenceId`; cancellation during those operations exposes `isCancellation`. Stopping a Swift task stops waiting, not the remote payment. Prefer caller-owned references even when using `AndWait` conveniences.

Use positive decimal strings such as `"0.10"`; converting through `Double` can lose monetary precision. Product access tokens are cached and refreshed per client. Reuse client instances. Credentials consist of an API user, API key, and subscription key for the selected product.

## Other products

```swift
let payouts = MoMoDisbursementClient(credentials: payoutCredentials, environment: .sandbox)
let balance = try await payouts.getAccountBalance(currency: "EUR")
let remit = MoMoRemittanceClient(credentials: remittanceCredentials, environment: .sandbox)
let transfer = RemittanceTransferRequest(amount: "10.00", currency: "EUR", payee: payer)
try await remit.transfer(payload: transfer, referenceId: UUID())
```

Deposits, refunds, and withdrawals expose explicit `.v1`/`.v2` selection; status lookups remain v1. Invoice/payment/preapproval creation uses current v2 contracts. Consumer consent uses a separate client and token model:

```swift
let consent = MoMoConsentClient(credentials: credentials, product: .disbursement)
let authorization = try await consent.authorize(loginHint: "ID:46733123470/MSISDN",
    scopes: ["openid"], accessType: .offline)
// Wait for consumer approval; respect authorization.interval and expiresIn.
let token = try await consent.exchange(authRequestId: authorization.authRequestId)
let user = try await consent.userInfo(accessToken: token.accessToken)
```

The library does not automatically poll CIBA token exchange. Applications must respect the returned interval/expiry and handle pending/denied consent errors. Collections back-channel authorization requires an explicit merchant bearer under the current export; Disbursements and Remittance use Basic credentials. Confirm the operator's production contract before use.

See [API coverage and documentation conflicts](docs/API_COVERAGE.md), [migration notes](docs/MIGRATION.md), and the [implementation plan](docs/IMPLEMENTATION_PLAN.md).

## Sandbox demo

Open `MoMo.xcworkspace`, select `MoMoDemoApp`, and set Run → Arguments → Environment Variables:

- `MOMO_COLLECTION_SUBSCRIPTION_KEY`
- `MOMO_DISBURSEMENT_SUBSCRIPTION_KEY`

Run the app to provision sandbox API users and keys. Credentials are saved in Keychain. The demo uses EUR and MTN's successful phone fixture `46733123470`; its buttons perform actual sandbox requests when you press them. Unresolved references are persisted and must be checked before starting another request. Keychain persistence failures surface in setup.

No local config source file is needed. Keep production merchant credentials on a trusted backend; never distribute them in a client app. Callbacks must use HTTPS and match the host registered with MTN. MTN documents a single callback attempt, so retain polling/reconciliation as fallback. Delivery notifications follow successful payment; notification failure does not reverse settlement.

## Verification

```sh
swift test
swift test --package-path MoMoSDK
swift build --package-path Examples/SmokeClient
xcodebuild -workspace MoMo.xcworkspace -scheme MoMoDemoApp \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Tests use synthetic responses and require no keys or live transactions. CI defines macOS and Linux jobs. [Release checklist](docs/RELEASE_CHECKLIST.md) records remaining operator validation and packaging decisions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local checks, documentation expectations, security guidance, and the pull request process. Bug reports and feature proposals have issue templates to help contributors supply the relevant API context.

## License

MoMo Swift is available under the [MIT License](LICENSE). This is an independent community project and is not affiliated with or endorsed by MTN. MTN and MoMo are trademarks of their respective owners.

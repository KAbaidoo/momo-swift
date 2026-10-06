# Migration notes

This is an unreleased contract-correction pass. Source changes that cannot preserve the original meaning are explicit:

- `InvoiceRequest` requires `validityDuration` and `payee`; creation/status/cancellation use v2. `cancelInvoice(invoiceReferenceId:externalId:referenceId:callbackURL:)` needs the documented external-ID body and a separate cancellation reference. `InvoiceStatus.errorReason` replaces `reason` (deprecated alias retained).
- `PreApprovalRequest` requires positive `validityTime`. `PreApprovalStatus.status` replaces `transactionStatus` (deprecated alias retained). Approved mandate lists return `[ApprovedPreApproval]`; use the returned system `preApprovalId` to cancel a mandate.
- Transfer JSON encodes `payeeNote` and result JSON decodes `payee`. Deprecated payer spellings forward to these meanings where supported.
- Request-to-pay/withdrawal and payout response metadata can be absent; unwrap optional amount/currency/party fields. Payout `status` is optional. Unknown states are preserved, not coerced into failure.
- Use `CollectionAccountIdentity` or `DisbursementAccountIdentity` for basic-user-info alias/ID lookups. Their casing differs by product. Active-account lookup supports MSISDN/email and returns false for explicit false/404; other HTTP failures propagate.
- Prefer policy-based wait APIs and caller-owned references. Legacy attempts/duration overloads remain. Cancelled transaction waits/submissions now report `MoMoError` with recoverable `referenceId` and `isCancellation`, rather than necessarily throwing bare `CancellationError`.
- HTTP failures use `MoMoError.httpError` with status, server code/message, and selected correlation/retry metadata. Inspect wrapped transaction errors' `statusCode` or underlying error. No raw response logging is performed.
- Money, callback URLs, identity values, and UUIDv4 references are validated. Negative amounts, exponent notation, lowercase currencies, and HTTP callbacks are rejected before financial submission.
- Consent numeric interval/expiry/timestamp values use `Double` because MTN declares JSON numbers. `MoMoConsentAddress` accepts a textual address or a structured object.
- Voucher APIs are deprecated and unverified: they are absent from the current Collections export. Do not depend on them for new production integrations.

The root package adds standard Git URL installation; existing consumers of the nested package and Xcode workspace remain supported. New `MoMoCore` and `MoMoRemittance` products can be imported individually or through `MoMoSDK`.

`Duration`-based legacy wait overloads require watchOS 9/tvOS 16 because of Swift standard-library availability. Policy-based wait APIs support the declared watchOS 8/tvOS 15 floors.

# API coverage and contract evidence

Reviewed on 4 October 2026 against MTN's public narrative documentation and current public OpenAPI exports. “Implemented” means an SDK entry point follows the published contract and has offline verification; it does not mean live operator certification.

The exports contain 56 operations. The SDK covers 54 standard operations, including authentication through shared core clients. Two suspicious Remittance basic-user-info variants remain excluded. Existing voucher APIs remain deprecated/unverified; consent-based financial operations mentioned only in narrative documentation are not claimed as supported.

## Export evidence

Exports were obtained from `https://momodeveloper.mtn.com/mapi/apis/{api}?export=true&api-version=2022-04-01-preview`, requesting OpenAPI JSON. SHA-256 values identify the exact source bytes used for review, rather than implying the hosted documentation will remain unchanged.

| Export | Revision | Operations | SHA-256 |
| --- | --- | --- | --- |
| collection | 7 | 23 | `dd84d9ddf2815f29ddc89c2b9b9a5c7efca4f934181ae98439f8eb7b39b07411` |
| disbursement | 6 | 16 | `863db0171506d89cb9197c770c95a43245e4ed37da4c6f0e6af24f0bfda9dfa4` |
| remittance | 4 | 14 | `bdbc9f7bd5678a93fce96c2c5db17b6bd2fe36aebe39d72edd6e6fff4087170c` |
| sandbox-provisioning-api | 1 | 3 | `bb26a39193e71df06bb7812487bbde08b248b294ba9a23e734de4dcca3462e42` |

## Operation matrix

Paths below are relative to each product base (`/collection`, `/disbursement`, `/remittance`); sandbox provisioning paths are gateway-relative. Both API versions are exposed where listed. Shared request shape/version tests cover related routes; test coverage is summarized in REVIEW.md.

| Product | Operation | SDK entry point/status |
| --- | --- | --- |
| collection | `GET /v1_0/account/balance` | getAccountBalance |
| collection | `GET /v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/active` | isAccountHolderActive |
| collection | `POST /v1_0/requesttopay` | requestToPay |
| collection | `GET /v1_0/requesttopay/{referenceId}` | getTransactionStatus |
| collection | `POST /v1_0/bc-authorize` | MoMoConsentClient.authorize |
| collection | `GET /v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/basicuserinfo` | getBasicUserInfo |
| collection | `POST /v1_0/requesttopay/{referenceId}/deliverynotification` | sendDeliveryNotification |
| collection | `GET /v1_0/account/balance/{currency}` | getAccountBalance |
| collection | `POST /v1_0/requesttowithdraw` | requestToWithdraw |
| collection | `POST /v2_0/requesttowithdraw` | requestToWithdraw |
| collection | `GET /v1_0/requesttowithdraw/{referenceId}` | getWithdrawalStatus |
| collection | `POST /v2_0/invoice` | createInvoice |
| collection | `GET /v2_0/invoice/{x-referenceId}` | getInvoiceStatus |
| collection | `DELETE /v2_0/invoice/{referenceId}` | cancelInvoice |
| collection | `POST /v2_0/preapproval` | requestPreApproval |
| collection | `GET /v2_0/preapproval/{referenceId}` | getPreApprovalStatus |
| collection | `POST /v2_0/payment` | createPayment |
| collection | `GET /v2_0/payment/{x-referenceId}` | getPaymentStatus |
| collection | `POST /oauth2/token/` | MoMoConsentClient.exchange / refresh |
| collection | `GET /oauth2/v1_0/userinfo` | MoMoConsentClient.userInfo |
| collection | `POST /token/` | MoMoTokenProvider (used by product clients) |
| collection | `GET /v1_0/preapprovals/{accountHolderIdType}/{accountHolderId}` | getPreApprovals |
| collection | `DELETE /v1_0/preapproval/{preapprovalid}` | cancelPreApproval |
| disbursement | `GET /v1_0/account/balance` | getAccountBalance |
| disbursement | `GET /v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/active` | isAccountHolderActive |
| disbursement | `GET /v1_0/transfer/{referenceId}` | getTransferStatus |
| disbursement | `GET /v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/basicuserinfo` | getBasicUserInfo |
| disbursement | `POST /v1_0/bc-authorize` | MoMoConsentClient.authorize |
| disbursement | `GET /v1_0/account/balance/{currency}` | getAccountBalance |
| disbursement | `POST /v1_0/deposit` | deposit |
| disbursement | `POST /v2_0/deposit` | deposit |
| disbursement | `GET /v1_0/deposit/{referenceId}` | getDepositStatus |
| disbursement | `POST /v1_0/refund` | refund |
| disbursement | `POST /v2_0/refund` | refund |
| disbursement | `GET /v1_0/refund/{referenceId}` | getRefundStatus |
| disbursement | `POST /oauth2/token/` | MoMoConsentClient.exchange / refresh |
| disbursement | `GET /oauth2/v1_0/userinfo` | MoMoConsentClient.userInfo |
| disbursement | `POST /token/` | MoMoTokenProvider (used by product clients) |
| disbursement | `POST /v1_0/transfer` | transfer |
| remittance | `GET /v1_0/account/balance` | getAccountBalance |
| remittance | `GET /v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/active` | isAccountHolderActive |
| remittance | `POST /v1_0/transfer` | transfer |
| remittance | `GET /v1_0/transfer/{referenceId}` | getTransferStatus |
| remittance | `GET /v1_0/accountholder/msisdn/{accountHolderMSISDN}/basicuserinfo` | getBasicUserInfo |
| remittance | `POST /v1_0/bc-authorize` | MoMoConsentClient.authorize |
| remittance | `GET /v1_0/account/balance/{currency}` | getAccountBalance |
| remittance | `POST /oauth2/token/` | MoMoConsentClient.exchange / refresh |
| remittance | `GET /oauth2/v1_0/userinfo` | MoMoConsentClient.userInfo |
| remittance | `POST /token/` | MoMoTokenProvider (used by product clients) |
| remittance | `POST /v2_0/cashtransfer` | cashTransfer |
| remittance | `GET /v2_0/cashtransfer/{referenceId}` | getCashTransferStatus |
| remittance | `GET /clone-671b0/v1_0/accountholder/msisdn/{accountHolderMSISDN}/basicuserinfo` | Excluded: suspicious cloned path |
| remittance | `GET /v1_0/accountholder/msisdn/999{accountHolderMSISDN}999/basicuserinfo` | Excluded: suspicious cloned path |
| sandbox-provisioning-api | `POST /v1_0/apiuser` | MoMoSandboxProvisioner: createUser / createKey / getUser |
| sandbox-provisioning-api | `POST /v1_0/apiuser/{X-Reference-Id}/apikey` | MoMoSandboxProvisioner: createUser / createKey / getUser |
| sandbox-provisioning-api | `GET /v1_0/apiuser/{X-Reference-Id}` | MoMoSandboxProvisioner: createUser / createKey / getUser |

## Public documentation discrepancies and limits

- [API documentation](https://momodeveloper.mtn.com/api-documentation) and public exports are the baseline; narrative-only operations do not justify inventing contracts.
- [Authentication](https://momodeveloper.mtn.com/api-documentation/api-description) and exported Collections `bc-authorize` differ in authentication descriptions. The SDK follows the export's explicit bearer requirement; payout products use Basic credentials. Confirm production behavior with the operator.
- Consent responses declare numeric values; fractional interval/expiry/timestamps decode. Address is a string in response schemas, but a separate object component also exists; the SDK accepts both forms. Token exchange remains caller-driven and must respect CIBA timing.
- [Use cases](https://momodeveloper.mtn.com/api-documentation/use-cases) describe optional aggregator `transferType`. It is exposed as an open, optional payload string for Collections request-to-pay/payment and Disbursements transfer, omitted by default. It is absent from exported request schemas; actual values and eligibility require operator confirmation. It is not a header or a Remittance feature inferred by this SDK.
- Preapproval expiration is described as an ISO timestamp but declared an integer. `PreApprovalExpiration` preserves either representation.
- Active-account exports omit a useful response schema. Explicit false/404 is handled; decoding failures are never silently converted to true. Collections accepts literal booleans and a `result` object compatibility form.
- Monetary values remain decimal strings. Sparse response metadata is optional where the export omits required fields. Unknown status/code strings remain accessible.
- Note/message limits differ across published material (128 vs 160). The SDK does not guess one universal limit; validate the operator's contract.
- [Callbacks](https://momodeveloper.mtn.com/api-documentation/callback) document one attempt. Callback URLs require HTTPS and must match the registered host; the library cannot verify remote registration. V1/V2 request variants can change callback HTTP method (POST/PUT).
- [Sandbox testing](https://momodeveloper.mtn.com/api-documentation/testing) uses EUR and fixture MSISDNs. The demo selects the success fixture; other fixtures can remain pending or fail.
- Delivery notification requires a successful request-to-pay. A notification error does not change transaction success. MTN documents errors for premature, expired, and excessive notification attempts.
- The two Remittance routes containing `clone-671b0` and `999{accountHolderMSISDN}999` look like accidental variants; no public SDK methods implement them.

Offline request tests verify URL methods/versions, headers, encoded values, money precision, product authentication, and representative responses. Production network access, callbacks, fees, entitlements, and settlement remain operator integration gates.

# Release checklist

## Repository verification

- Run root/nested package tests and the independent consumer build.
- Run macOS and Linux CI; compile all declared Apple deployment floors and the iOS demo.
- Review API snapshot diffs when MTN revises contracts; update offline fixtures deliberately.
- Audit published files for credentials. Preserve private setup outside tracked source.
- Choose a license and release version with the repository owner. No license was inferred in this implementation pass.
- Tag a release only after independent review and required checks. No tag or publication was performed here.

## Operator integration gate

- Confirm each product's subscription and production API credentials, target-environment value, gateway, and originating-IP restrictions.
- Confirm consumer consent authentication, optional fields/scopes, pending responses, and refresh-token entitlement.
- Confirm aggregator `transferType` values and eligibility before setting narrative-only fields.
- Confirm note/message limits (public sources disagree), preapproval expiration representation, and active-account response shape.
- Register HTTPS callback host; verify delivery and status reconciliation after missing callbacks.
- Verify accepted/pending/success/failure transactions, uncertain submission, duplicate reference handling, refund eligibility, and delivery notifications with operator-approved test procedures.
- Supply production reference persistence and reconcile unresolved transactions before permitting resubmission.

Offline tests establish SDK behavior against captured contracts; they cannot prove production settlement, fees, operator entitlements, or callback availability.

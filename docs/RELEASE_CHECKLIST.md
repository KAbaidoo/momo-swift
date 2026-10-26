# Release checklist

Record the exact candidate commit, owner decisions, evidence links, and exclusions in [RELEASE_READINESS.md](RELEASE_READINESS.md). The initial release remains blocked until its pending gates are resolved.

## Repository verification

- Run root/nested package tests and the independent consumer build.
- Run macOS and Linux CI; compile all declared Apple deployment floors and the iOS demo.
- Run `python3 scripts/openapi-baselines.py validate-manifest` and review [the MTN baseline instructions](openapi/README.md). With private archive access, verify archived checksums and compare upstream exports before updating offline fixtures.
- Audit published files for credentials. Preserve private setup outside tracked source.
- Confirm the candidate contains the selected [MIT license](../LICENSE) and the `v0.1.0` experimental, best-effort support policy recorded in the readiness record.
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

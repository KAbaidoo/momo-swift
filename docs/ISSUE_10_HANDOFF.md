# Issue #10 implementation handoff

## Ownership and dependencies

- Archive implementor: preserved the four raw exports, confirmed archive privacy, and published the public provenance manifest. Handed the immutable archive commit and verified checksums to both other agents.
- Tooling implementor: agreed the manifest interface before implementation, then consumed its archive references for retrieval, verification, comparison, maintainer documentation, and public CI.
- Validation agent: authored synthetic CLI tests independently, exercised authenticated retrieval from a clean temporary directory, and ran the existing SDK/build checks after updating from develop.
- Primary agent: integrated on `fix/issue-10-contract-baselines` from develop commit `48c9e830a2ecdebfbcd981563cd26cdc1bb7709c`, waited for all three agents, independently checked archive privacy/inventory and the tooling tests, and reviewed all acceptance criteria.

## Archive and tooling interface

The restricted archive is [KAbaidoo/momo-swift-contract-baselines](https://github.com/KAbaidoo/momo-swift-contract-baselines), pinned to commit `ce587fb25fbbb1f47dc9cdaf527f1925d7ba5fe8`. The four files live under `snapshots/2026-10-26/`; their bytes match every checksum recorded for the 4 October 2026 review. The 26 October date records re-retrieval, not a new contract review or replacement baseline.

The public [manifest](openapi/manifest.json) records API/revision, review/retrieval dates, revision-qualified source URL, content type, OpenAPI version, operation count, raw SHA-256, original-baseline role, and archive repository/commit/path. The [maintainer guide](openapi/README.md) documents access, commands, and future baseline adoption. No raw MTN export was added to this public repository.

The standard-library CLI provides `validate-manifest`, `fetch`, `verify`, and `compare`. Retrieval uses the authenticated GitHub CLI and a full archive commit SHA. Verification checks raw hashes and OpenAPI metadata. Comparison fetches the current unpinned MTN export or an explicitly supplied local candidate, and distinguishes byte identity, formatting-only changes, and content differences, including changed versions and operation counts. Existing different files and archived baselines are never overwritten. Public CI uses only metadata and synthetic fixtures.

## Verification and acceptance

Verified locally on 26 October 2026:

| Check | Result |
| --- | --- |
| Public manifest validation | Four original baselines accepted |
| Synthetic Python tooling suite | 16 tests passed |
| Clean-directory archive fetch, local verification, direct archive verification, and `shasum` | All four original checksums matched |
| Current upstream comparison | All four exports byte-identical to archived originals |
| Root Swift suite | 52 tests passed |
| Nested SDK suite | 46 tests passed |
| Independent SmokeClient build | Passed |
| Apple deployment floors | All 20 module/platform combinations passed |
| iOS Simulator demo build | Passed |
| Whitespace | `git diff --check` passed |

The negative tests reject missing/duplicate APIs, absent or malformed provenance, invalid archive paths/commits, missing/tampered snapshots, invalid JSON, incorrect operation counts, failed authenticated retrieval, and overwrites. Comparison tests cover formatting changes, added/deleted operations, and changed OpenAPI versions. CLI subprocess tests check exit behavior and error reporting.

All four issue requirements are met: each original baseline is archived and checksum-verifiable; provenance includes API/revision/date/source; maintainers have executable verification and comparison instructions; original reviewed bytes are explicitly distinguished from future replacement snapshots. No SDK public API changed.

No configured lint gate or installed Swift/Python lint tool was found. Local checks do not establish remote CI success; the updated workflow still needs its normal push/PR run. Archive access requires GitHub read permission, and maintainers must retain the private repository and pinned commit. MTN revision URLs are a secondary retrieval source rather than the sole retained copy.

Archive creation and authenticated verification used the already-authenticated owner account `KAbaidoo`. The previously active GitHub CLI account, `kelvin-abaidoo`, was restored after verification; future archive commands must select an account with read access.

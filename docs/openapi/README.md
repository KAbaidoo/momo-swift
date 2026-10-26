# MTN OpenAPI baselines

The SDK review used four raw MTN OpenAPI JSON exports. Their exact bytes are held in the private, immutable repository and commit listed in [`manifest.json`](manifest.json). The manifest in this repository is public metadata; it does not contain or redistribute the specification files. Each entry names the MTN API and revision, source URL, original review date, retrieval date, SHA-256, operation count, and private archive location. The bytes were re-retrieved on 26 October 2026; their hashes match the exports recorded for the 4 October 2026 review.

The baseline files are raw source exports. Keep them unchanged. A later export, if needed, must be stored as a separately dated snapshot and documented as superseding the original hash; it must not replace the original path or be described as the reviewed original.

You need Python 3 and the GitHub CLI (`gh`) authenticated with read access to the private archive repository. If access is missing, ask the repository owner to grant read access through the private repository's **Settings → Collaborators and teams** page, then authenticate and confirm the account:

```sh
gh auth login
gh auth status
```

If multiple GitHub accounts are already authenticated, select one with archive access using `gh auth switch --hostname github.com --user <authorized-account>`. The archive owner's account is `KAbaidoo`.

Downloads go to `.openapi-baselines/`, which is ignored by Git, and the fetch command refuses to overwrite a different existing file.

```sh
python3 scripts/openapi-baselines.py validate-manifest
python3 scripts/openapi-baselines.py fetch --output-dir .openapi-baselines
python3 scripts/openapi-baselines.py verify --directory .openapi-baselines
shasum -a 256 .openapi-baselines/*.json
```

`validate-manifest` checks the public provenance metadata without credentials. `fetch` retrieves the immutable archived files and verifies their raw SHA-256 and OpenAPI operation counts. `verify` checks already downloaded files; `shasum` prints the exact raw digests for comparison with the per-API values in [`manifest.json`](manifest.json) and [`API_COVERAGE.md`](../API_COVERAGE.md). To verify directly from the private archive without retaining local copies, run:

```sh
python3 scripts/openapi-baselines.py verify
```

To compare the archived review baseline with the current MTN export, run:

```sh
python3 scripts/openapi-baselines.py compare
```

For one API, append `--api collection`, `--api disbursement`, `--api remittance`, or `--api sandbox-provisioning-api` to `fetch`, `verify`, or `compare`. Comparison uses MTN's current export endpoint, while the manifest records the revision-qualified URL for retrieving the reviewed bytes. It reports whether the upstream response is byte-identical, formatting-only, or has a content change. For content changes it prints a canonical JSON diff and exits with status 1. It reads both sources into temporary storage and leaves the archived baseline unchanged. A matching SHA-256 from `verify` is the exact-byte checksum check; the same expected values are recorded in `manifest.json` and `docs/API_COVERAGE.md`.

To compare an export already saved locally, pass its file and select the API:

```sh
python3 scripts/openapi-baselines.py compare --api collection --upstream-file /path/to/collection.json
```

When adopting a later upstream baseline, preserve the existing files and hashes. Retrieve the new export at its dated revision, verify its raw hash and operation count, and archive the bytes at a new dated path and immutable commit in the private repository. Add a distinct manifest entry that labels it as a replacement and names the hash it supersedes; retain the original entry and update this guide, the coverage table, and the CLI schema and validation deliberately. Do not point the original entry at the new bytes.

CI validates the public metadata and runs the synthetic CLI tests. It does not need private archive credentials. The authenticated retrieval and upstream comparison are maintainer commands.

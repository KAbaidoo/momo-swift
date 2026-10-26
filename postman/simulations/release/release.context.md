# Release simulation context

Verified 26 October 2026 with Postman CLI 1.73.0. GitHub's owning-workspace search was unavailable because Postman was signed out; this local stand-in models the narrow official REST contract linked in its handler. Nothing was pushed to Postman cloud.

## Purpose

Exercise the publisher's real `gh api` HTTP transport, including state read after write and a release-service failure after tag creation. The simulation member is GitHub, not the publisher. See `postman/mocks/github-release/default.js` for the focused contract and control routes.

## Execution

From the repository root, start:

```sh
postman simulation run postman/simulations/release/release.sim.yaml --port auto --output ndjson --no-history > /tmp/momo-release.ndjson 2> /tmp/momo-release.err
```

Wait for `listening` in the log. In another terminal, run `python3 scripts/check-release-simulation.py http://127.0.0.1:<observed-port>/github`. Use the bound port from the event, not a guessed port. The check replaces its process's GitHub token with a placeholder. Inspect `request` events for the GitHub member and the injected HTTP 500, then stop the server with Ctrl-C. Logs stay outside Git.

## Assumptions

- The mock models only Git refs, release state, and readiness on the exercised path. It does not reproduce GitHub authentication, permissions, branch/tag rules, or Actions scheduling. A mock pass cannot approve publication. (observed 2026-10-26)
- SwiftPM consumer verification is supplied separately; the harness does not serve Git protocol. The actual SDK was resolved and built through a disposable local version tag in a separate exercise. (observed 2026-10-26)
- CLI simulation members require the explicit `config.yaml` path on this installation; a directory path fails before startup. (observed 2026-10-26)

## Observations

<!-- begin:observations -->
2026-10-26: the sole member, `github-release`, served real GitHub CLI requests for first publication, a successful no-op retry, HTTP 500/tag-only recovery, and conflicting-tag rejection. No member stayed silent. The request log confirmed tag/release writes and the injected failure; fixture counters confirmed no duplicate creations.
<!-- end:observations -->

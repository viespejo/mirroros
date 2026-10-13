# Installation postconditions

This internal component checks the installed configuration, read-only, after the engine's last plan operation and before cleanup. It is not a public command, a repair tool, or runtime readiness verification. The normative inputs, checks, result format, and non-secret detail rules live in the [postconditions contract](../../contracts/installation-postconditions.md).

## Layout

- `check` — Bash entry point. Validates arguments and the confirmed plan before observing the still-mounted target; prints one result document and writes no file.
- `lib/common.sh` — NUL-delimited observation transport.
- `lib/observe.sh` — native read-only queries: files, mounts, UUIDs, the package database, service enablement, initramfs listings, and swapfile offset and attributes. No mount, write, service mutation, or repair is allowed.
- `evaluate.mjs` — Node ESM comparison with the approved plan and validation of the format 1 result. Uses the existing plan validator and digest binding, never mutable installation policy.

## Engine boundary

The engine invokes `check --plan <file> --digest <hex> --target-root <dir>` without a password or inherited secret descriptors. Every applicable check runs even after a failure. UUIDs and resume offsets are independently observed, not supplied from engine records.

A passed result exits 0; failed checks exit 4. Invalid inputs exit 2 and internal contract failures exit 6. The engine validates the result against the plan and the checker exit status, stores it in format 2 `engine-run.json`, and reports `installed`/0 or `not_verified`/4. An absent or invalid answer is an execution failure (`failed`/5), not a failed postcondition. All terminal paths use normal engine cleanup and retain diagnostic records.

## Tests and qualification

[`tests/install/postconditions/`](../../tests/install/postconditions/) covers each check passing and failing, all storage options with and without hibernation, result validation, and read-only inspection with command doubles and a byte-identical target tree. Engine contract tests cover withheld completion, invalid checker answers, cleanup, and secret exclusion.

These tests do not establish bootability, active zram, effective runtime sysctl settings, network connectivity, or real hibernation/resume. Reference-VM qualification and later runtime readiness checks own those boundaries; see the [test procedure](../../docs/procedures/test.md).

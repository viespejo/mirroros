# Installation engine

This directory owns the native Arch installation engine that executes an approved installation plan (Story 2.5). It is an internal component of the guided live installer: it has no public command, no non-interactive mode, and no bypass option. The only way to reach it is through `mirroros-install`, after the bound confirmation, the protected password entry, and the final revalidation.

The normative behavior (invocation, pre-check order, per-kind operations and engine constants, evidence, reasons, exit statuses, failure and cleanup rules) lives in the [installation engine contract](../../contracts/installation-engine.md) and in [ADR 0008](../../docs/adr/0008-installation-engine-execution-boundary.md). This README only describes how the files are organized.

## Layout

- `apply` — Bash orchestrator. Parses the internal inputs, runs the pre-checks in the contract's order, and executes the plan's operations in plan order through a `kind → function` dispatch table. The first failure stops all later operations. After the last operation, invokes the read-only [postconditions checker](../postconditions/README.md); only a passed result continues to configure before cleanup.
- `load-plan.mjs` — Node plan loader. Reads the plan once, validates it with `install/plan/validate-plan.mjs`, recomputes the digest with `install/plan/digest-plan.mjs`, checks the code identity embedded in the artifact, and emits a NUL-delimited, shell-safe step stream. It never reads the mutable plan policy source.
- `engine-record.mjs` — Node record writer. Writes format 3 `engine-run.json` and `state.json` atomically with mode 0600 and rejects secret-looking keys. Validates the checker's result against the approved plan and exit status, and records every applicable check.
- `lib/common.sh` — shared helpers: logging to `engine.log`, state publication, record calls, postconditions invocation, signal and cleanup handling.
- `lib/configure.sh` — final phase: copies the rerun code and launcher to the target, invokes configure in its target context, publishes positioned step markers, and records configure outcome and evidence before normal cleanup.
- `lib/precheck.sh` — lock verification, keyring check, password read, and the final block before the first destructive operation.
- `lib/storage.sh`, `lib/btrfs.sh`, `lib/system.sh`, `lib/accounts.sh`, `lib/boot.sh` — one function per operation kind, grouped by concern.

## Rules that shape the code

- Functions use plan `parameters`, apply-time resolved values, and the constants enumerated in the contract; nothing else.
- The account password arrives once on file descriptor 3, lives in a local non-exported variable, and is fed on stdin to `chpasswd` inside the target chroot. It never appears in arguments, the environment, logs, records, or terminal output.
- The engine is a non-interactive child (stdin is `/dev/null`); the assistant owns the terminal.
- Nothing outside `/run/mirroros/target` is unmounted, and a failed run is never re-wiped or resumed.
- `installed`/0 requires every operation and base postcondition to pass, followed by configure outcome 0. Failed postconditions produce `not_verified`/4 without running configure; an invalid checker answer produces `failed`/5. Configure failure or interruption produces `not_configured`/4, preserving its own outcome, failed step, and target-relative evidence path. All terminal paths use normal cleanup and retain records, with no repair or retry from the live medium. Recovery is `sudo mirroros-configure` on the installed system.

## Tests

The engine is tested with command doubles in [`tests/install/engine/`](../../tests/install/engine/) (Node tests for the loader and the record writer, Bats contract tests for `apply`). Real installations are qualified only through `vm/reference/qualify-install`; see the [test procedure](../../docs/procedures/test.md).

# Installation prototype harness

Shared, prototype-owned harness for Story 2.1, Track 1. Both engines run through it, so the
installation engine is the only difference between `archinstall-json-cli/run` and
`native-arch/run`. It is non-production: production paths never source it.

## Boundaries

- The VM shape is read from `vm/reference/reference-vm.conf`, which is never modified.
  The 01-05 launch, NoCloud, and stop/cleanup logic is copied and adapted here, not sourced.
- The qualified ISO is used unmodified. The bundle is admitted only when its `SHA256SUMS` match.
- Disks and outputs exist only under `build/prototypes/installation/<engine>/<run-id>/` and
  `evidence/prototypes/installation/<engine>/<run-id>/`. Symlinks and other paths are refused.
- No host root and no `qemu-nbd`. No project-owned Python. No automatic retries.

## Engine contract

An engine's `run` sets `PROTO_ENGINE_NAME` and `PROTO_ENGINE_DIR`, sources `lib/harness.sh`, and calls
`proto_main "$@"`. The engine provides `guest/install`, executed in the live environment with:

| Input | Meaning |
| --- | --- |
| `MIRROROS_RUN_ID`, `MIRROROS_VARIANT`, `MIRROROS_TARGET_DISK` | Run parameters (`/dev/vda`) |
| `MIRROROS_HTTPS_URL`, `MIRROROS_HTTPS_TIMEOUT_SECONDS` | Network postcondition parameters |
| `MIRROROS_SEED_DIR` | Mounted NoCloud medium (guest helpers, verification files) |
| `MIRROROS_UNATTENDED` | `1` for the prototype-only unattended mode, `0` when attended |
| file descriptor 3 | The two credentials, user first, root second |

The script sources `${MIRROROS_SEED_DIR}/common.sh`, reads the credentials with
`mirroros_proto_read_secrets`, installs the system onto `MIRROROS_TARGET_DISK`, calls
`mirroros_proto_install_verifier <target-root>`, and exits with its own status.

## Run flow

1. Admit the bundle, check preconditions, and create private run directories.
2. Generate two synthetic, disposable, per-run passwords (user and root). They are the canaries.
3. Build the temporary NoCloud medium and scan it with redacted Gitleaks.
4. Boot 1: the bundle ISO, the fresh qcow2 disk, and the NoCloud medium. The runner waits for the live
   environment, applies the unreachable mirrorlist in the failure variant, records the effective
   mirrorlist, runs the engine, records the disk state, and powers off.
5. Boot 2: the installed disk only. The verification unit emits a run-bound JSON report over serial.
6. Stop QEMU, delete the run's build directory after the exit is confirmed, search the evidence for
   both canaries, enforce the allowlist, write `result.json`, and scan the evidence.

`--variant unreachable-mirrors` delivers a mirrorlist through NoCloud that points to
`mirror.invalid`, which never resolves. Boot 2 is skipped and the run never exits 0.

## Exit statuses

| Status | Meaning |
| --- | --- |
| 0 | Engine succeeded and every postcondition passed |
| 2 | Refusal, failed precondition, or a scan or canary finding |
| 3 | The engine failed (engine and run exit statuses are both recorded) |
| 4 | A postcondition failed |
| 5 | Infrastructure failure: deadline, missing report, medium or disk failure |
| 6 | Internal error or damaged checkout |
| 130, 143 | Interrupted |

## Deadlines

The 300 s deadline belongs to the 01-05 qualification contract and does not apply here. The harness
defines its own, in `config.sh`:

| Deadline | Seconds | Scope |
| --- | --- | --- |
| Installation (boot 1) | 1800 | Time until the guest powers off |
| Verification (boot 2) | 600 | Time until the report arrives |
| Attended session | 7200 | Documented limit for an attended boot (not enforced by a timer) |

The observed durations are recorded in each `result.json`.

## Credentials and the canary exclusion

- Credentials are delivered only through protected channels: a 0600 file in `build/`, the read-only
  NoCloud medium, and file descriptor 3 in the guest. They are never passed as arguments.
- The Gitleaks scan of the temporary NoCloud medium in `build/` excludes exactly the two synthetic
  values, through a temporary configuration (`build/.../gitleaks-nocloud.toml`) that is deleted with
  the run directory. **This exclusion applies only to that scan.** Every other scan has no exclusion:
  the evidence scan, the working-tree scan, the history scan, and the `build/` scan.
- After each run the evidence is searched for both values with `grep -F` fed through a descriptor.
  Only the outcome is recorded, never a value.
- `negative-control.sh` plants a synthetic canary under `build/` and requires the search to detect it.

## Evidence

`evidence/prototypes/installation/<engine>/<run-id>/` holds directories at 0700 and files at 0600. Only
these files are retained; anything else is removed: `result.json`, `run-metadata.json`,
`serial-install.log`, `serial-verify.log`, `qemu-install-diagnostics.log`, `qemu-verify-diagnostics.log`,
`install-report.json`, `verify-report.json`, `mirrorlist.txt`, `disk-state.txt`, `gitleaks-nocloud.json`,
`gitleaks-evidence.json`, and `canary-search.json`. Every record stores the commit and `dirty`.

## Known prototype contamination

The installed system carries the systemd unit `mirroros-proto-verify.service`, its check script, and
`/etc/mirroros-proto/verify.env`. They are identical for both engines, exist only in prototype
installations, and must not be treated as part of any installation plan. The unit checks that the
passwords are usable (`passwd -S`) but cannot prove their values, because the values are not stored on
the installed disk.

## Attended mode (`--attended`)

Boot 1 only, with the serial console connected to the terminal. The runner prints the helper command
and starts `serial-getty@ttyS0` instead of running the engine. Ctrl-C reaches the guest, and Ctrl-A x
quits QEMU. This path is unverified until its first use; any problem found is recorded, not worked
around silently.

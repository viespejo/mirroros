# Test procedure

The `operations/test` command qualifies the bootstrap medium of a MirrorOS bundle in one fixed, headless reference VM. Success shows that the unchanged ISO boots through the supported UEFI/OVMF path and reaches a usable, networked live installation environment. It does not install anything, and it does not verify capabilities, accept an artifact as known-good, or make it eligible for a target laptop. A passing run only makes the artifact eligible for later installation-engine prototypes.

## Invocation

Run the command by path from any working directory; it does not need to be installed on `PATH`.

| Invocation | Behavior |
| --- | --- |
| `operations/test <bundle-directory>` | Validates the bundle, boots its ISO in the reference VM, runs the guest checks, and writes evidence. |
| `operations/test --help` | Prints help and exits `0` without side effects. It is also available when invoked as root and needs no QEMU, KVM, OVMF, or Gitleaks. |

These are the only accepted forms. A missing argument, an unknown option, several arguments, or `--help` combined with anything else exits `2` with a stderr diagnostic before any file is created or any domain tool is invoked. The no-argument diagnostic names the missing bundle directory. A relative bundle path resolves against the caller's working directory, and paths with spaces are supported. A missing or unloadable shared helper or domain implementation exits `6` as an incomplete or damaged checkout; restore it from Git or reclone.

The shared lifecycle help header may retain generic availability wording; this procedure is authoritative for test-specific behavior.

## Prerequisites and privilege boundary

The test must run as a normal user; a root invocation exits `2`. The following must be installed and usable by that user:

- Functional KVM: `/dev/kvm` must actually work for the invoking user, not merely exist.
- OVMF firmware code and variables from the edk2 package (`/usr/share/edk2/x64/OVMF_CODE.4m.fd` and `/usr/share/edk2/x64/OVMF_VARS.4m.fd`).
- `qemu-system-x86_64`, `qemu-img`, `xorriso` (builds the NoCloud medium), Node.js, Gitleaks, Git, and `timeout`.

If a prerequisite is missing, the command exits `2` with guidance and creates no VM resource. It never uses `sudo`, installs packages, changes groups, device permissions, or services, or falls back to software emulation. Enable virtualization and grant your user access to `/dev/kvm` yourself, then retry.

## Input bundle

The argument must be a Story 1.3 bundle directory (for example `dist/<run-id>/`) containing the ISO, `SHA256SUMS`, `artifact-metadata.json`, and the native package manifest. Before any VM resource exists, the test checks that the required files are present, that the checksum file matches the ISO, and that the metadata is coherent with the checksums and the manifest. Any missing, incoherent, or mismatched item exits `2`. The bundle is read-only input and is never modified.

## Reference VM

The configuration is versioned in `vm/reference/reference-vm.conf`; changing it changes the qualification contract and requires an explicit decision.

| Setting | Value |
| --- | --- |
| Machine and acceleration | x86_64 `q35`, KVM, CPU `host` |
| Resources | 2 vCPUs, 4 GiB memory |
| Disk | New sparse 32 GiB qcow2 on a VirtIO controller, empty |
| Network | One VirtIO NIC on SLIRP user-mode NAT, no port forwarding |
| Firmware | Read-only OVMF code, fresh per-run vars copy, Secure Boot disabled |
| Display | Headless, with a serial channel to a private file |

The guest receives only the ISO, the empty disk, the NoCloud medium, the firmware, and the control channels. No host directory, credential, device, or environment is shared. The effective configuration and the QEMU and OVMF versions are recorded in the result.

## Guest checks

A per-run, temporary cloud-init NoCloud medium carries the checks and the run ID. Its text is scanned with Gitleaks before the medium is attached. The checks install no packages, start no installer, and do not touch the disk. They emit one JSON report on the serial console. The harness accepts only a complete, consistent report bound to the current run ID, validated in Node. Log keywords or the absence of failures never grant qualification.

The checks confirm:

- UEFI boot mode;
- a working root shell;
- runtime availability of the native installation tools;
- a usable IPv4 address and a default route;
- DNS resolution of `archlinux.org`;
- an HTTPS request to `https://archlinux.org/` with TLS validation, the body discarded, and HTTP `200`, within at most 30 seconds.

## Deadlines, stopping, and cleanup

The global deadline is 5 minutes from QEMU launch. When the checks finish, fail, exceed the deadline, or the run is interrupted, only this run's QEMU process is stopped: `SIGTERM`, then after at most 10 seconds `SIGKILL`, then a wait of at most 5 seconds. The test disk, vars copy, and NoCloud medium are deleted only after QEMU exit is confirmed. Evidence is retained. If exit cannot be confirmed, the resources are preserved and reported, and success is never claimed. No other VM is affected, and nothing is retried automatically.

## Paths and permissions

Each run uses an ID of the form `YYYYMMDDTHHMMSSZ-<uuid>`. Directories are created `0700` and generated files `0600`. An occupied reserved run location or a symlinked output base is refused without being touched. No earlier run is recovered, reused, or deleted.

| Path | Contents and handling |
| --- | --- |
| `build/reference-vm/<run-id>/` | Temporary disk, vars copy, NoCloud medium, and guest report. Removed after confirmed QEMU exit; preserved otherwise. |
| `evidence/reference-vm/<run-id>/` | Retained evidence, described below. |

Both locations are ignored by Git and must never be committed.

## Evidence and secret scanning

`evidence/reference-vm/<run-id>/` holds one `result.json` with the artifact identity and checksum, the test-code identity (commit and dirty state), the effective VM configuration, QEMU and OVMF versions, per-check results, duration, the failing stage and next action, the final status, original tool statuses, scan outcomes, cleanup outcomes, and an explicit note that an auxiliary NoCloud medium was used.

Logs are limited to the guest serial output (`guest-serial.log`) and QEMU diagnostics (`qemu-diagnostics.log`), plus redacted Gitleaks reports. The NoCloud text, the result, the logs, and the reports are scanned before qualification is accepted; the scope follows [ADR 0001](../adr/0001-build-secret-scan-scope.md). Findings block qualification and stay private. The terminal shows only progress and a summary derived from the same result, never raw guest logs. No screenshots, memory dumps, or host inventories are collected.

## Normalized outcomes

| Status | Meaning |
| --- | --- |
| `0` | Checks passed, evidence passed scanning, and cleanup completed. |
| `2` | Invalid arguments, inadmissible bundle, unmet prerequisite, or secret-scan findings. |
| `4` | Checks ran but the guest failed a criterion, including external connectivity. |
| `5` | QEMU, deadline, tool, scanner-execution, or cleanup failure. |
| `6` | Damaged checkout or internal contract violation. |
| `130` / `143` | Interrupted by `SIGINT` / `SIGTERM`. |

The first non-success outcome is kept; a later cleanup failure never replaces it. A cleanup failure after an otherwise successful run yields `5`.

## Limits and eligibility

A passing run shows only what the checks above observed. It does not establish:

- an unseeded boot: the NoCloud medium is an auxiliary input, so the guest was seeded;
- an orderly guest shutdown: the guest is stopped by the harness;
- Wi-Fi, LAN, or laptop networking: only SLIRP NAT is exercised;
- a graphical console or desktop;
- the availability of any mirror, or the absolute absence of secrets;
- installation, capability verification, known-good status, or target-laptop eligibility.

Contract tests exercise the logic with simulated tools; only a real run exercises the real KVM, OVMF, NoCloud, and serial integration, and evidence must be read with that distinction in mind.

## Recovering a residual run

A run that could not confirm QEMU exit, or that was killed abruptly, can leave `build/reference-vm/<run-id>/` behind. There is no recovery command and no automatic cleanup; recover manually:

1. Identify the run ID from the diagnostic, or from the directory name under `build/reference-vm/`.
2. Confirm that this run's QEMU has exited, for example with `pgrep -af "reference-vm/<run-id>"`. If it is still running, stop only that process.
3. Remove only `build/reference-vm/<run-id>/`.
4. Keep `evidence/reference-vm/<run-id>/`; it documents the failed run.

Never remove directories of other runs, and never remove the bundle under `dist/`.

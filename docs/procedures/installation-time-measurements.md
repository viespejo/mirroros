# Installation time measurements

## Purpose and authorization

Measure the current installation and identify its largest measured contributors. This procedure does not
compare, select, or implement optimizations. It follows the accepted [interview decisions](../technical-interviews/installation-time-measurements_log.md)
and [consolidated design](../technical-interviews/installation-time-measurements_plan.md); DEC-020 supersedes
DEC-019. The approved measurement scope is only the `default` qualification case: Btrfs with Limine,
hibernation enabled, and root locked. No additional storage-case matrix is required here.

Reading this procedure or approving its plan authorizes no execution. Obtain explicit authorization before
running tests, a build, any VM run, or a commit. Request build and each of the three qualification invocations
separately unless the maintainer explicitly authorizes a batch. Each default invocation includes both the
installation boot and the disk-only login boot, and erases only the fresh disposable disk created by the harness.
Build uses privileged Docker; qualification requires functional KVM as a normal user. Do not install tools,
change permissions, start services, or repair the host as part of measurement.

## Timing contract

The normative field definitions are [guided timing](../../contracts/installation-confirmation.md#guided-timing),
[engine timing](../../contracts/installation-engine.md#engine-timing), and
[configure timing](../../capabilities/README.md#configure-timing-evidence).

New writers emit confirmation format `7`, engine-run format `4` (engine state remains `3`), and configure TSV
run format `2`. Supported pre-timing confirmation `6`, engine-run `3`, and historical configure TSV remain
readable without adding historical measurements. A readable legacy record is not an instrumented baseline.

`operations/lib/timing.sh` reads the first `/proc/uptime` value with Bash builtins, without a process per sample
or a new runtime dependency. Configure remains usable without Node.js. Available `duration_ms` values are
non-negative integer milliseconds, multiples of 10: effective resolution is **10 ms**, not 1 ms. UTC timestamps
are chronological metadata, not elapsed-time inputs. Wall-clock changes do not affect these intervals.

JSON measurements are either `{"status":"available","duration_ms":120}` or
`{"status":"unavailable","reason":"clock_unreadable"}`. Unavailable measurements omit `duration_ms`, never
substituting null or zero. Safe failure reasons are `clock_unreadable`, `clock_malformed`, `clock_regressed`,
and `duration_overflow`; JSON builders also reserve `not_sampled` for missing samples. There is no wall-time
fallback. A genuine measured zero is valid. A failed visit makes its accumulated interval unavailable even if
later visits can be sampled. Timing availability never changes installation outcomes or readiness requirements.

| Owner / metric | Boundaries and interpretation |
| --- | --- |
| `install-run.json`: `timing.total` | Starts at guided-flow entry, before run initialization; stops at outcome finalization, sampled before the final record write. Excludes live boot, final serialization, and the outcome menu. Includes welcome, configuration screens, initial cleanup, and orchestration not assigned to a named stage. |
| Guided `timing.intervals` | Actual reached-stage intervals, accumulated across visits, independent of the deduplicated `stages` list. `review`, `confirmation`, and `password` are interactive; `preparation` is mixed; `discovery_initial`, `plan`, `discovery_final`, and `engine` are automated. Discovery retries exclude intervening recovery menus; plan timing covers validation/generation, not failure-recovery prompts. Final discovery includes safety/digest checks. Guided `engine` includes result processing. |
| `engine-run.json`: `timing.total` | Starts after argument validation, before the lock; ends after terminal cleanup and before final serialization. |
| Engine `timing.intervals` | `prechecks`, nested `precheck.*`, each `operation.<plan-operation-id>` with immediate checks, `postconditions`, `configure`, and `cleanup`, only when reached. `configure` includes rerun-code delivery, invocation, progress handling, and native record retention. |
| `configure-run.tsv` | `total` starts at shared-helper loading and ends in the finalizer before serialization. `validation` includes preflight, argument/prerequisite/package checks, and evidence initialization; it is not charged to the first capability. Each `step.<capability-path>` includes execution and postconditions. |

Configure timing rows have five tab-separated columns: `timing`, interval id, status, duration_ms, reason.
Duration is empty when unavailable; reason is empty when available. The timing section header is `record`,
`interval`, `timing_status`, `duration_ms`, `reason`; distinguish it from the unchanged four-column step-status
section. Not-run steps retain status rows but have no timing row. Guided/engine unstarted items have no timing
entry. Handled failures and cancellations close reached intervals where existing evidence can be written;
hard kills and unwritable evidence gain no persistence guarantee.

These measurements are nested: engine total is inside guided `engine`; configure total is inside engine
`configure`; configure validation and steps are inside configure total; `precheck.*` is inside `prechecks`.
Never add nested totals. Parent/child differences can include orchestration, sampling boundaries, and
quantization; do not label every residual as a measured operation. Classification describes an interval,
not exact human-time accounting or a basis for subtracting human time from mixed work.

The existing success-duration line is preserved. No live step timings or final timing table are introduced.

## Prepare one artifact

1. Review the candidate instrumentation and its authorized contract-test results using the
   [repository validation timing checks](repository-validation.md#installation-timing-contract-checks).
   Review helper delivery in ISO capture, development overlay, and installed rerun code. Do not reopen earlier
   tasks or infer real-VM acceptance from command doubles.
2. After separate build authorization, follow [Build](build.md) and run `operations/build` once. Keep rolling
   repositories, existing mirror policy, package selections, cache behavior, and deadlines unchanged. Record the
   actual build invocation and cache mode; do not clear host caches or change repositories to stabilize timings.
3. Select the published `dist/<build-run-id>/` bundle only after reviewing its execution result and scans.
   Record the build run id, commit/dirty state, embedded source identity, ISO SHA-256, artifact metadata,
   native package manifest, tool versions, prebuilt package identities, and build mirrorlist identity.
   Reuse this exact bundle for all three runs; do not rebuild between them or edit source during capture/runs.
4. Preserve existing qualification prerequisites. Any required bootstrap `operations/test` execution also
   requires separate authorization; measurement does not waive promotion or readiness gates.

For counted qualification, the bundle and test checkout must be clean at the same commit, with no overlay;
committing requires its own authorization. Dirty or mismatched development evidence must remain explicitly
`counted: false`, not be relabeled as qualified. This baseline uses embedded instrumentation, not
`--development-overlay`. If authorization or prerequisites prevent a suitable artifact, stop and report the
baseline blocked rather than changing the protocol.

## Three default runs

Follow [Installation qualification](test.md#installation-qualification) and the actual command's help text.
After authorization for run 1, invoke from the repository root as a normal user:

```bash
vm/reference/qualify-install --case default <bundle-directory>
```

Replace `<bundle-directory>` with the same selected bundle path each time. Capture the native exit status
immediately and associate it with the printed run id. Review the result, scans, and cleanup before requesting
run 2 authorization. Repeat the exact invocation for run 2 and, after its review and separate authorization,
run 3. A batch authorization permits these three sequential invocations, not retries or extra cases.

The harness creates a fresh sparse 32 GiB qcow2 and a fresh OVMF vars copy for every run; do not reuse a disk or
add an external reset. Keep `vm/reference/reference-vm.conf` unchanged: version 2, q35/KVM, CPU host, 2 vCPUs,
4096 MiB RAM, VirtIO disk/NIC, SLIRP NAT, headless display, and Secure Boot disabled. Compare effective settings
and recorded QEMU/OVMF versions across results, rather than assuming the configuration file alone proves equality.

The unchanged installation deadline is 2700 seconds from QEMU launch to the guest report, including live boot,
setup, installation, and configure. Disk-only login uses the existing global deadline. Stop and report an
unexpected outcome, scan failure, deadline overrun, or incomplete cleanup. Preserve the failed run; do not
silently replace it, retry, increase deadlines, or weaken qualification. An incomplete set leaves baseline
acceptance blocked pending an explicit maintainer decision.

The driver exercises the real `--plan` guided route with a pty, Gum, protected canary password, and bound
confirmation. Its prompt-driven answers are **automated driver timings**, not representative human reading or
password-entry times. Guest discovery/planning before the guided flow are outside guided total. No human-time
estimate should be inferred from these runs.

## Evidence and observed conditions

Keep native evidence under `evidence/reference-vm/install/<run-id>/` and build evidence under
`evidence/archiso-build/<build-run-id>/`. Maintain a private report and any analysis outputs under
`evidence/installation-time-measurements/<measurement-id>/`. All these paths, plus temporary `build/` and
bundles in `dist/`, are ignored. Never commit generated evidence or artifacts. Use private permissions
(`0700` directories, `0600` files), no symlinked output bases, and no overwritten run directories.

For each run retain references to:

- `result.json`: run identity, native normalized status, `counted`, artifact checksum/source identity,
  test-code identity, effective VM settings, versions, installation/boot checks, scans, and cleanup.
- `install/install-run.json`, `install/approval-record.json`, recorded plan/digest, `install/install.log`,
  and `install/engine/engine-run.json`, with timing availability and native outcomes intact.
- `install/engine/configure/configure-run.tsv`, `packages.tsv`, and `sources.tsv` when present. These are
  allowlisted regular-file copies of this configure invocation, retained through existing recursive VM
  collection; originals remain on the installed target under `/var/log/mirroros/configure/<run-id>/`.
  Missing copies are missing data, not permission to remount or export arbitrary target content.
- Engine `target-packages.txt` (base transaction), configure package/repository mappings and consumed-source
  versions/commits, artifact package manifest, engine mirror server list/hash, and existing regional-selection
  diagnostics. These are observations, not a complete transitive final-system inventory or proof of which
  server supplied each download. A mirrorlist hash alone does not identify the server actually used.
- Existing guest observations, serial/QEMU diagnostics, and disk comparison/cleanup results. Fresh-disk
  provenance is the distinct harness run and disk-creation path, not a reused image or a retained disk after
  normal cleanup. Record missing provenance explicitly.

Record relevant **already-observed**, non-secret network context, known host load, run ordering, and known cache
warmth, including build-cache mode. Fresh guest disks do not imply cold host page caches, upstream caches, or
network conditions. Mark unobserved conditions `unknown`. Do not add speed tests, DNS/HTTP probes, host
inventories, cache clearing, or repository pinning. Existing harness/discovery checks remain unchanged.
Never collect passwords, canary values, SSIDs, MAC addresses, credentials, private connection details,
user configuration, or secret-bearing command arguments.

Before sharing evidence or the report, review the harness's redacted Gitleaks and canary scan outcomes.
After report creation, obtain scan authorization and run a redacted directory scan over the report directory:

```bash
gitleaks dir --no-banner --redact evidence/installation-time-measurements/<measurement-id>
```

Retain the native scanner status and redact any findings; a finding or scanner failure blocks sharing.
Do not copy raw private evidence into tracked documentation or the plan summary.

## Report and calculations

Write `evidence/installation-time-measurements/<measurement-id>/report.md` in English with:

1. Scope, authorizations, artifact/build/source identity, reference settings, and links to all three native
   run directories. Include each outcome, qualification/counting status, scan status, and fresh-disk provenance.
2. Observed versions, sources, mirrors, network context, load/cache information, and explicit unknowns or
   differences. Same ISO does not freeze rolling package repositories or moving external configuration sources.
3. Individual guided totals, engine totals and phase/operation breakdowns, configure totals/validation/steps,
   guided classifications, and unavailable reasons. Keep units and nested ownership visible in tables.
4. A separate QEMU qualification context column for `result.json.duration_seconds`. This existing field is
   wall-clock seconds from harness outcome initialization before resource preparation to result writing after
   disk-only boot, stopping, comparison, and cleanup; it is not a monotonic installation or QEMU-only interval.
   It may be rewritten after a scan failure. The QEMU-launch-to-report deadline is a different boundary and
   does not itself provide a precise elapsed measurement. Do not derive boot time by subtracting guided total
   from this field, or claim the new 10 ms timing guarantees for it. If precise QEMU-launch duration is not
   retained, mark it unavailable rather than inventing it.
5. For each available comparable metric, list all individual values, the number available (`n/3`), median,
   minimum, maximum, and range (`max - min`). For three sorted values `a <= b <= c`, median is `b` and range
   is `c - a`; for two available values use their arithmetic mean as median and label it a partial sample.
   For one value report that value with `n=1`; for none report unavailable. Never substitute zero, mix units,
   mix incompatible outcomes/boundaries, or hide missing values. Keep exact milliseconds for calculations;
   presentation in seconds is allowed if labeled and not given false precision.
6. Rank contributors at each non-overlapping level separately: engine sibling phases/operations, then
   configure validation/steps, and guided named stages. Use comparable available medians, show sample counts
   and min/max, distinguish partial rankings, and note uncovered overhead. Do not add engine configure and
   its steps together, or rank nested parent and child totals as independent contributions.
7. Limitations and acceptance verdict: three runs are diagnostic, not a causal experiment or representative
   human session; rolling/network/cache/load differences remain uncontrolled. Missing timing or a failed run
   is explicit. Success is not full runtime readiness or hibernate/resume proof. Make no optimization decision
   or implementation proposal; further decisions belong to a separate plan.

Review calculations against the native records, common artifact SHA-256, unchanged effective VM settings,
outcomes, availability, fresh-disk provenance, and non-secret content. Submit the private report for explicit
maintainer approval. Without three successful measured default installations and report review, AC-5 remains
incomplete; documentation and source tests alone do not complete the measurement plan.

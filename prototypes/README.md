# Prototypes

Prototypes are disposable, evidence-producing experiments. They answer bounded questions that
[`docs/architecture.md`](../docs/architecture.md) gates behind an ADR. They are not product code.

## Rules

- Prototypes are non-production. Production paths (`operations/`, `image/`, `vm/`, `tests/`,
  and future `install/`, `configure/`, `contracts/`) never import or source anything under
  `prototypes/`.
- Raw results, logs, and run artifacts live only under ignored `evidence/prototypes/`. They are
  never committed.
- Stable conclusions are recorded in the READMEs under `prototypes/` and in accepted ADRs.
- A winning approach is implemented through the stable production boundary. It is not promoted
  by renaming a prototype directory.
- Prototype code may use conveniences that production forbids (for example an unattended mode).
  Such conveniences set no precedent for production.
- Prototypes do not define production installation policy.

## Track register

| Track | Status | Question | Stop condition | Exclusions |
| --- | --- | --- | --- | --- |
| 1. Installation engine (`installation/`) | Executed by plan 02-01 | Which installation engine, Archinstall JSON/CLI or native Arch commands, best fits the fixed reference-VM scenario, judged by plan visibility, editability, confirmation, cancellation, credentials, diagnostics, exits, recovery evidence, dependencies, and maintenance cost? | Archinstall would need its Python API, a plugin, or project-owned Python (the item is marked unsupported). The qualified bundle fails to boot or official mirrors fail persistently (`blocked_external`). Any need to modify `vm/reference/`, `reference-vm.conf`, or production code. | Storage/recovery and frontend work; `install/engine/apply`; target discovery; plan schema; digest-bound confirmation; desktop, Niri, NVIDIA, and real hibernation; physical disks and Wi-Fi. |
| 2. Storage/recovery (`storage/`) | Executed by plan 02-02; outcome in [ADR 0003](../docs/adr/0003-storage-and-recovery-baseline.md) | Does the ext4/systemd-boot control with independent rescue media, Btrfs/Snapper with rescue-based rollback (`btrfs-rescue`), or Btrfs/Snapper with Limine snapshot boot entries (`btrfs-limine`) best recover reproducible userspace (D1) and boot-path (D2) damage, including hibernation, on one shared scenario? | The Limine snapshot tools need the CachyOS repository or Chaotic-AUR, or cannot be pinned (`btrfs-limine` is marked unsupported, no workaround). The VM cannot hibernate reliably even with the control (`blocked_external`). Any need to modify `vm/reference/`, `reference-vm.conf`, `native-arch/guest/install`, or production code. | Adopting Btrfs, Snapper, or Limine requires an ADR; no `install/`; no target laptop or physical disks. |
| 3. Frontend | In progress (plan 02-03) | Can existing widgets such as Gum present the installation flow with mock data only? | Not started. It is optional and follows the engine ADR in a later plan. | The architecture currently excludes a custom TUI. The frontend never determines the engine. Mock data only. Not prototyped by plan 02-01. |

## Layout

- `installation/`: Track 1 comparison, shared harness (`lib/`), and one directory per engine.
- Raw results: `evidence/prototypes/installation/<engine>/<run-id>/` (ignored, allowlisted, secret-scanned).

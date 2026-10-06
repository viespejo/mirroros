# Story 2.1 — Installation Engine Research: Decision Log

Starting point: `/tmp/mirroros-story-2-1-handoff.KW74QV/handoff.md` (Story 2.1 initial research phase handoff). Dependency: `01-05-reference-vm-bootstrap-validation`.

## DEC-001
- **Question**: What is the scope of the first plan under the Story 2.1 research umbrella, and should the three research tracks (installation engine, storage/recovery, frontend) be split?
- **Context/Nuances**: The handoff groups three independent tracks under one umbrella associated with Story 2.1. That grouping does not amend Story 2.1 acceptance criteria nor authorize architectural exceptions (ext4 + systemd-boot, no custom TUI, no project-owned Python). Tracks 2 and 3 end in their own ADRs and must not drive the engine choice. Suggested sequence: engine comparison on the current baseline, then recovery experiment, separate ADRs, then combined validation. Rejected alternative: a documentation-only research charter as plan 02-01 (adds a plan without evidence).
- **User Response**: Agreed with the proposal; numbering 02-01 accepted.
- **Decision**: Split into three plans in new phase `02` (Epic 2). Plan 02-01 establishes the `prototypes/` frame (`prototypes/README.md` plus a record of the three tracks with their questions, stop conditions, and exclusions) and executes only Track 1: shared fixed scenario, `archinstall-json-cli` and `native-arch` prototypes, comparison, and engine ADR if evidence is conclusive. Plan 02-02 covers storage/recovery on top of the selected engine. Plan 02-03 (optional) covers a mock-data frontend demonstration. Plan 02-01 depends only on `01-05-reference-vm-bootstrap-validation`.
- **Status**: Accepted

## TODO-001
- **Description**: Plan 02-02 — storage and recovery investigation (Btrfs/Snapper, rescue-based recovery vs Limine snapshot integration) after the engine ADR.
- **Status**: Pending

## TODO-002
- **Description**: Decide whether plan 02-03 (mock-data frontend demonstration, e.g. Gum) is worth executing.
- **Status**: Pending

## DEC-002
- **Question**: Which locale and keyboard values does the shared fixed scenario require?
- **Context/Nuances**: System `LANG`, generated locales, optional `LC_*` overrides, console keymap, and compositor keyboard layouts are distinct settings. Archinstall's locale model holds a single system language/encoding and one console keymap, so additional locales may require native finalization before reboot. No desktop exists in plan 02-01 to consume graphical layouts.
- **User Response**: Console keymap `us` (not `es`); `LANG` in English; graphical layouts out of scope for now.
- **Decision**: Generated locales `en_US.UTF-8` and `es_ES.UTF-8`; `LANG=en_US.UTF-8`; no additional `LC_*` overrides; console keymap `us`. Graphical keyboard layouts (order and switching shortcut) are out of scope for plan 02-01 and no minimal Niri session is built.
- **Status**: Accepted

## TODO-003
- **Description**: Define graphical keyboard layouts (layout order and switching shortcut) when the desktop work is planned.
- **Status**: Pending

## DEC-003
- **Question**: How is the shared fixed scenario defined?
- **Context/Nuances**: The user installs Arch manually by following the Arch Installation Guide. Testing Archinstall only against isolated examples (multiple locales) under-represents the real installation. Architecture already fixes UEFI, GPT, systemd-boot, unencrypted ext4 root, resizeable swapfile, and the official `linux` kernel; those are not reopened. Desktop, Niri, dotfiles, NVIDIA, CachyOS, and hibernation verification belong to Story 2.6 and later epics. Story 2.3 owns production plan defaults and their provenance labels.
- **User Response**: Proposed walking the Installation Guide to capture everything needed and check whether Archinstall can do it; accepted the bounded method.
- **Decision**: Derive the scenario by walking the Arch Installation Guide section by section, up to *Reboot* plus the minimal post-installation needed to boot and log in (user, sudo, network). Each item is classified as fixed by architecture, personal preference, or technical necessity. The comparison marks each item for Archinstall as expressible through JSON/CLI, requiring native finalization before reboot, or unsupported. The scenario is prototype-only and does not define production installation policy.
- **Status**: Accepted

## DEC-004
- **Question**: Which partition layout, ESP placement, and mount configuration does the scenario use (Installation Guide: partition, format, mount)?
- **Context/Nuances**: Architecture fixes GPT, UEFI, systemd-boot, and unencrypted ext4. systemd-boot only reads kernels from the ESP or an XBOOTLDR partition, so mounting the ESP at `/boot` keeps kernel and initramfs on it without extra mechanisms; 1 GiB leaves room for fallback images and a later parallel kernel (CachyOS experiment). `/efi` plus XBOOTLDR was rejected as unnecessary complexity. The layout is expected to be expressible in Archinstall's `disk_config`. Swapfile handling is decided separately.
- **User Response**: Accepted the recommendation.
- **Decision**: On the reference VM's 32 GiB disk: GPT with two partitions only — a 1 GiB FAT32 ESP mounted at `/boot` and an ext4 root using the remaining space with default mount options (`relatime`); no separate `/home` or swap partition; fstab generated by UUID (`genfstab -U`).
- **Status**: Accepted

## DEC-005
- **Question**: How are the swapfile and hibernation resume configuration defined in the scenario?
- **Context/Nuances**: Architecture requires a resizeable swapfile for swap and hibernation, with resume device and offset managed and verified whenever the swapfile is created or resized. Hibernation cycle verification is out of scope (DEC-003), but resume configuration is an installation-time responsibility. Relying on systemd's `HibernateLocation` EFI variable without explicit parameters was rejected because architecture requires explicit offset management. Archinstall's swap option is zram, so the swapfile and resume configuration are expected to require native finalization, and Archinstall's zram must be disabled so it does not compete with the swapfile; this adaptation cost is recorded in the comparison. The laptop swapfile size is a target override, not part of this scenario.
- **User Response**: Accepted the recommendation.
- **Decision**: `/swapfile` on the ext4 root, 4 GiB (reference VM RAM), created with `mkswap --size 4G --file /swapfile` and an fstab entry. The systemd-boot entry carries explicit `resume=UUID=<root>` and `resume_offset=<offset>` (offset computed with `filefrag`); the default systemd-based initramfs is used. Before the first boot of the installed system, a postcondition verifies that the entry's UUID and offset match the actual swapfile. Performing a real hibernation cycle in the VM is out of scope; it may only appear as an optional, non-blocking check if cheap.
- **Status**: Accepted

## DEC-006
- **Question**: Which base package set and repository configuration does the scenario install?
- **Context/Nuances**: The user's former installer repository `viespejo/VARBS` (last commit `a0975875b35f58ba6ebc6284f44837143d5dd96b`, 2021-02-02) was reviewed as a reference for personal habits, not as a template. It installed `base base-devel` via pacstrap, used `neovim`, ran `reflector` inside the target, enabled `multilib` (used for wine), enabled NetworkManager, installed `intel-ucode`, and used GRUB. GRUB is superseded by systemd-boot (architecture); microcode is a hardware selection (Story 2.6; the target laptop is AMD). `base-devel` is only needed for AUR builds, which are user-level `configure` work, and it does not discriminate between engines. `pacstrap` copies the live environment's mirrorlist (generated by releng's `reflector`) into the target, so `reflector` is not needed on the target. The network package is decided separately.
- **User Response**: Accepted the recommendation.
- **Decision**: Both prototypes install exactly `base linux linux-firmware sudo neovim man-db man-pages` plus the network package decided separately. `base-devel`, `reflector`, CPU microcode, and `multilib` are excluded from the base scenario. Both prototypes use the mirrorlist inherited from the live environment and record its content in their evidence so neither gains a network advantage.
- **Status**: Accepted

## TODO-004
- **Description**: CPU microcode (`amd-ucode` on the target laptop) is selected by hardware adaptation in Story 2.6, not by the base scenario.
- **Status**: Pending

## TODO-005
- **Description**: Enable `multilib` only when a capability that requires it is planned.
- **Status**: Pending

## DEC-007
- **Question**: How is networking configured on the installed system?
- **Context/Nuances**: VARBS confirms NetworkManager as the user's habit, and it suits laptop Wi-Fi. Archinstall's `network_config` offers a NetworkManager type that installs and enables it, so this item is expected to be expressible through JSON/CLI, pending prototype confirmation. Network profiles from the live environment are not copied; Wi-Fi credentials are secrets and must not be transferred into the target.
- **User Response**: Accepted the recommendation.
- **Decision**: Install `networkmanager` and enable `NetworkManager.service`, with its default Wi-Fi backend (`wpa_supplicant`, no `iwd`) and default DNS handling (no `systemd-resolved`). No predefined connections: the reference VM's VirtIO NIC uses automatic DHCP. Post-first-boot postcondition: a default route exists, `archlinux.org` resolves, and it answers over HTTPS (same check as the 01-05 bootstrap qualification).
- **Status**: Accepted

## DEC-008
- **Question**: Which time, clock, and hostname settings does the scenario use?
- **Context/Nuances**: VARBS used `Europe/Madrid`, `hwclock --systohc`, NTP only in the live environment, and a `127.0.1.1` `/etc/hosts` entry. The current Installation Guide no longer requires that entry because `myhostname` in `nsswitch.conf` resolves the local name. Laptop clocks drift, so persistent NTP is preferred; Archinstall exposes an `ntp` option. The hostname is a target value; the laptop's hostname comes from its target override, not this scenario.
- **User Response**: Accepted the recommendation.
- **Decision**: Time zone `Europe/Madrid`; hardware clock in UTC set with `hwclock --systohc`; `systemd-timesyncd` enabled; hostname `mirroros-ref` for the reference VM; no `127.0.1.1` entry in `/etc/hosts`. Postconditions: `timedatectl` reports `Europe/Madrid`, RTC in UTC, and NTP active; `hostnamectl` reports `mirroros-ref`.
- **Status**: Accepted

## DEC-009
- **Question**: How are accounts, sudo, and credentials handled in the scenario?
- **Context/Nuances**: Credentials are a Story 2.1 comparison criterion, and architecture requires secrets to stay out of process arguments, logs, artifacts, and retained evidence, with narrowly scoped privilege elevation. VARBS set a root password, added the user to `wheel,storage,power`, and used sudoers with partial `NOPASSWD` and `!tty_tickets`; `storage`/`power` are unnecessary with systemd/polkit, and the sudoers relaxations conflict with narrow elevation. Architecture already mandates independent rescue media, so a locked root does not remove recovery. The user's real username is personal configuration and stays out of the repository. Archinstall takes credentials through a separate JSON file (`--creds`); the comparison measures whether it accepts a protected temporary file or descriptor and whether credentials leak into its logs (`/var/log/archinstall/`) or configuration saved on the target.
- **User Response**: Accepted the recommendation, including locked root and removal of `NOPASSWD`/`!tty_tickets`.
- **Decision**: Root account locked without a password; administration only through `sudo`. Reference VM user `mirroros` in group `wheel` only, shell `bash`. A sudoers drop-in under `/etc/sudoers.d/` grants `%wheel ALL=(ALL:ALL) ALL` and is validated with `visudo -c`; no `NOPASSWD` or `!tty_tickets`. The user password is a synthetic disposable value generated per run, supplied only through a protected channel (stdin, file descriptor, or a `0600` temporary file removed afterwards), never as an argument, and used as a canary that scanning asserts is absent from all evidence and results. Postconditions: root locked (`passwd -S`), user exists in `wheel`, `sudo -l` grants password-authenticated access, `visudo -c` passes, and login with the synthetic password works.
- **Status**: Accepted — superseded in part by DEC-011 (root password)

## DEC-010
- **Question**: How are the initramfs and systemd-boot configured?
- **Context/Nuances**: Architecture fixes systemd-boot; DEC-004 places the ESP at `/boot` and DEC-005 defines the resume parameters. Current `mkinitcpio` defaults are systemd-based, which the resume configuration relies on. Unified kernel images are deferred together with Secure Boot (an architecture-deferred decision). Archinstall supports systemd-boot but names and fills its entries differently, so postconditions compare entry semantics rather than filenames; resume parameters remain native finalization (DEC-005).
- **User Response**: Accepted the recommendation.
- **Decision**: `mkinitcpio` with unmodified default hooks; classic `vmlinuz-linux` and `initramfs-linux.img` images, no UKI. Install with `bootctl install` and enable `systemd-boot-update.service`. `loader.conf`: default Arch entry, `timeout 3`, `editor no`. Entries: a primary entry and a fallback entry when the `linux` preset generates a fallback image. Kernel command line: `root=UUID=<root> rw resume=UUID=<root> resume_offset=<offset>`, without `quiet`. Postconditions: `bootctl status` reports no errors; the default entry references files present on the ESP; the installed system boots without the installation medium and `/proc/cmdline` contains the expected parameters. Postconditions compare kernel, initramfs, and parameters semantically, not entry filenames.
- **Status**: Accepted

## DEC-011
- **Question**: Should usernames and passwords be enterable at installation time, and is the root password optional rather than always locked?
- **Context/Nuances**: Architecture gives runtime private input the highest precedence and requires protected channels for credentials (Story 2.5). The user wants real targets to accept username, user password, and root password at installation time, beyond the scenario defaults. Running a second full installation only to cover the locked-root case is unnecessary; it can be checked at the configuration/contract level. The input interface (prompts and flow) belongs to Stories 2.3–2.5; this plan only measures engine support.
- **User Response**: Chose option (b): root password optional at installation time; locked when omitted.
- **Decision**: On real targets, the username, user password, and an optional root password are entered at installation time through a protected channel; when no root password is provided, root stays locked. Scenario values are prototype defaults. The fixed scenario also supplies a synthetic, disposable, per-run root password used as a second canary, so the full run exercises two secrets through protected channels. The omitted-root-password case is verified per engine at configuration/contract level (generated JSON or commands; whether Archinstall accepts omitting root when a superuser exists), not by a separate full installation. New postcondition: root has a password (`passwd -S`) and root login works with the synthetic value. Supersedes DEC-009's locked-root clause; DEC-009 otherwise remains in force.
- **Status**: Accepted

## DEC-012
- **Question**: Is the Magic SysRq setting from VARBS part of the scenario?
- **Context/Nuances**: Arch's default `kernel.sysrq` value is `16` (sync only); VARBS set `1` to allow full REISUB recovery of a hung system. Archinstall has no option for it, so it is expected to require native finalization and is counted as an adaptation item in the comparison.
- **User Response**: Include it with value `1`.
- **Decision**: Install `/etc/sysctl.d/90-sysrq.conf` with `kernel.sysrq = 1`. Postcondition: `sysctl kernel.sysrq` reports `1` after the first boot.
- **Status**: Accepted

## DEC-013
- **Question**: Which `pacman.conf` options and maintenance timers does the scenario include?
- **Context/Nuances**: Recent pacman releases may already enable `ParallelDownloads`, so postconditions check effective values rather than whether a line was edited. `paccache.timer` requires `pacman-contrib`, outside the DEC-006 package set, and belongs to `configure`. On the reference VM, `fstrim` skips devices without discard support without failing. Archinstall is believed to expose `parallel_downloads` but not `Color`, `VerbosePkgLists`, or `ILoveCandy`; the prototype confirms this.
- **User Response**: Accepted the recommendation and asked to add `ILoveCandy`.
- **Decision**: `pacman.conf` enables `Color`, `ParallelDownloads = 5`, `VerbosePkgLists`, and `ILoveCandy`. `fstrim.timer` is enabled. `paccache.timer`/`pacman-contrib` are excluded from the base scenario. Postconditions: `pacman-conf` reports the four options with the expected values and `fstrim.timer` is enabled.
- **Status**: Accepted

## DEC-014
- **Question**: How are the installation prototypes executed and verified?
- **Context/Nuances**: The qualified bundle ships `archinstall 4.5-1` with `python 3.14.7-1` as an upstream runtime. Plan 01-05 provides QEMU launch, NoCloud delivery, and run-id-bound serial reports under `vm/reference/lib/`, plus a 300 s qualification deadline that is too short for installation; changing `reference-vm.conf` changes the 01-05 qualification contract. Sourcing `vm/reference/lib/` would couple production scaffolding to prototype needs. Host-side disk inspection (`qemu-nbd`) needs host root, which architecture forbids for convenience. The 01-05 NoCloud medium is Gitleaks-scanned, and the synthetic secrets must travel inside it.
- **User Response**: Accepted the recommendation.
- **Decision**: A shared prototype-owned harness under `prototypes/installation/lib/` is used by both `archinstall-json-cli/run` and `native-arch/run`, so the engine is the only difference. `vm/reference/` is not modified: VM shape is read from `reference-vm.conf` read-only, minimal launch logic is copied and adapted rather than sourced, and installation deadlines are defined by the harness. Each run has two boots: boot 1 uses the unmodified qualified bundle ISO, a fresh disk, and a NoCloud medium carrying the engine script and synthetic secrets, then installs and powers off; boot 2 uses the disk only. The installation places one systemd verification unit, identical for both engines and documented as known prototype contamination, which checks postconditions on boot 2 and emits a run-id-bound JSON report over the serial console. Evidence lives in `evidence/prototypes/installation/<engine>/<run-id>/`, private, allowlisted, scanned, and explicitly searched for both canary values. The temporary NoCloud medium in `build/` excludes only the two canary values from its scan, and this is recorded; evidence scanning has no exceptions.
- **Status**: Accepted

## DEC-015
- **Question**: How are plan visibility, editability, confirmation, and cancellation measured?
- **Context/Nuances**: Unattended runs cannot exercise review, editing, confirmation, or cancellation. The handoff notes that Archinstall menu cancellation may exit `0`, requiring postcondition care. Target/digest-bound confirmation belongs to Story 2.4 and is not implemented by prototypes. A prototype-only unattended mode must not set a precedent for a generic non-interactive production option.
- **User Response**: Accepted the recommendation.
- **Decision**: Two run kinds. (1) Full unattended runs (DEC-014) measure outcome, postconditions, exits, duration, and credentials, using an unattended mode that exists only in the prototypes. (2) Attended observation sessions, one per engine, follow a versioned checklist in each prototype README and run with the user over the serial console against a disposable disk. They cover visibility and editability (Archinstall: reviewing `user_configuration.json` before applying and menu edit/re-review; native: the generated, readable command script is the plan), confirmation (Archinstall: actual behavior with and without `--silent`; native: a minimal typed confirmation without digest binding), and cancellation at two points: (a) rejection at confirmation, verifying the disk stays untouched (no partition table) and recording the exit status; (b) `SIGINT` during package installation, verifying a non-success exit, retained diagnostics, and recorded partial disk state. Manual observations are labeled "observed manually" in the comparison.
- **Status**: Accepted

## DEC-016
- **Question**: Which failure is injected to compare diagnostics, exits, and recovery evidence?
- **Context/Nuances**: Story 2.5 requires that upstream failures stop avoidable dependent operations, retain original non-secret diagnostics and child status, and never report success. A disk-full failure would require changing the VM disk size; cutting QEMU networking mid-run is timing-fragile; failures inside the chroot manifest differently per engine and are not comparable. Automatic retry is excluded by the architecture's destructive retry policy (the handoff notes Omarchy retries certain filesystem operations automatically).
- **User Response**: Accepted the recommendation.
- **Decision**: One reproducible, host-safe failure is injected in both engines through an unattended variant: an unreachable mirrorlist (for example `http://127.0.0.1:9/`) delivered through NoCloud only in that variant, failing package installation. Recorded per engine: engine and `run` exit statuses; whether the original pacman message is preserved or rewritten; whether dependent steps (boot loader, users) continue; partial disk state; and that the report never claims success. Recovery evidence records whether the engine leaves useful material for a retry (logs, saved configuration) and whether a retry needs a fresh disk; no automatic retry is tested.
- **Status**: Accepted

## DEC-017
- **Question**: Where is the comparison recorded, how is maintenance cost measured, and how many runs are made per engine?
- **Context/Nuances**: Architecture places stable prototype conclusions in prototype `README.md` files and accepted ADRs; raw results stay generated, ignored, and scanned. Plan 01-05 made only one formal run, giving no repeatability signal. Source reviews of upstream projects must be pinned to exact revisions.
- **User Response**: Accepted the recommendation.
- **Decision**: `prototypes/installation/README.md` holds the comparison; each prototype `README.md` holds its question, scenario, checklist, and result. The comparison contains (1) a scenario matrix listing each DEC-002–DEC-013 item with its classification (architecture, preference, necessity) and its Archinstall status (JSON/CLI, native finalization, unsupported), and (2) a table of the ten Story 2.1 criteria where each cell states its provenance (measured, observed manually, source-reviewed) and evidence run-id. Maintenance-cost metrics: item counts per Archinstall class; MirrorOS-owned lines per prototype excluding the shared harness; upstream configuration keys depended upon; upstream change exposure from pinned source review (breaking configuration-format changes across recent Archinstall major versions versus stability of `pacstrap`, `arch-chroot`, `bootctl`, `genfstab`); and added dependencies (Archinstall plus Python in the live environment versus `arch-install-scripts`). Runs per engine: two successful full unattended runs, one failure-injection run, and one attended session, all against the same qualified bundle (`20261005T190610Z-e22955f3-62e8-4985-86da-cd5d703659ab`), recorded in evidence.
- **Status**: Accepted

## DEC-018
- **Question**: How is the engine decision taken, recorded, and bounded, and when does the plan stop?
- **Context/Nuances**: Story 2.1 requires an accepted ADR documenting question, evidence, trade-offs, selection, and replacement boundary, and allows only the selected approach to populate `install/engine/apply`, whose implementation belongs to Story 2.5. `docs/architecture.md` currently describes Archinstall as a candidate (e.g. lines 70, 232, 413, 454). The handoff warns against forcing an ADR when evidence is inconclusive. Project-owned Python and Archinstall API/plugin use require an accepted ADR.
- **User Response**: Accepted the recommendation.
- **Decision**: After the comparison, a checkpoint lets the user decide; the agent drafts but does not select. If evidence is conclusive, `docs/adr/0002-installation-engine-selection.md` is Accepted with question, evidence (run-ids), trade-offs, selection, and replacement boundary behind `install/engine/apply`, and `docs/architecture.md` statements treating Archinstall as a candidate are updated in the same change (clarifying that project-owned Python remains forbidden if Archinstall wins). `install/engine/apply` is not created or populated. If evidence is inconclusive, no ADR is forced (Proposed or none), the README records the comparison and next required experiment, and Story 2.1 stays open. Stop conditions: (1) if covering the scenario with Archinstall would need its Python API, a plugin, or project-owned Python, that path stops and the item is marked unsupported, with no workaround; (2) if the qualified bundle fails to boot or official mirrors fail persistently, the run is recorded as `blocked_external` without changing VM or bundle; (3) if a prototype would require modifying `vm/reference/`, `reference-vm.conf`, or production code, work stops for consultation; (4) storage/recovery and frontend tracks are only registered in `prototypes/README.md` with question, stop condition, and exclusions, not started.
- **Status**: Accepted

## DEC-019
- **Question**: How is prototype code validated, and which documentation and attribution changes accompany the plan?
- **Context/Nuances**: Prototype code is disposable; real VM runs provide the engine evidence. Bats suites with doubles were judged premature until the production implementation follows the ADR. The canary search is the only harness function whose silent failure would hide a leak, and it can be covered by a one-off negative control like the repository Gitleaks drill. `docs/procedures/repository-validation.md` forbids Gitleaks allowlists or exceptions for repository scans; DEC-014's canary exclusion applies only to the harness's temporary NoCloud scan. The validation procedure and the pending Node 24 wording from 01-05 are outside this plan.
- **User Response**: Questioned the need for Bats in prototypes; accepted the revised proposal without them.
- **Decision**: Validation: `bash -n` and `shellcheck` on `prototypes/installation/**` with the repository `.shellcheckrc`; no Bats or contract tests for prototypes (tests come with the production implementation after the ADR); one recorded negative control of the canary search (synthetic canary planted in a temporary `build/` directory must be detected); boundary checks that no production path sources or imports `prototypes/`, no `*.py` file exists, and `vm/reference/` and `reference-vm.conf` have no diff; redacted Gitleaks on history, working tree, `build/`, and new evidence without exceptions. Documentation: the `docs/architecture.md` project tree adds `prototypes/installation/README.md` and `prototypes/installation/lib/` and replaces per-prototype `results/` with `evidence/prototypes/installation/<engine>/<run-id>/`; `docs/procedures/repository-validation.md` is unchanged; the harness README states that the canary exclusion applies only to the temporary NoCloud scan. Attribution: unchanged; external references use pinned revisions.
- **Status**: Accepted

## DEC-020
- **Question**: How are commits sequenced so that counted runs are traceable?
- **Context/Nuances**: Plan 01-05 bound its formal qualification to a clean committed checkout (`dirty: false`). A prototype defect found during counted runs (as with the 01-05 IDE bus issue) must not leave a single engine's evidence spread across different commits.
- **User Response**: Accepted the recommendation.
- **Decision**: Commit 1 (`feat(prototypes): ...`) contains the `prototypes/` frame with the three-track register, the harness, both prototypes, and the architecture tree update. Counted runs (two full, one failure-injection, one attended per engine) execute from that commit with a clean tree; every evidence record stores the commit and `dirty` state. Dirty development runs are allowed but never counted. Commit 2 (`docs(prototypes): ...`) records the comparison READMEs and, at the checkpoint, ADR 0002 with the architecture update when evidence is conclusive. A prototype defect found during counted runs is fixed in a new commit after consulting the user, and that engine's counted runs are repeated so its evidence references one commit.
- **Status**: Accepted

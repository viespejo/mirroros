# Story 2.3 — Generate an Explainable Installation Plan: Decision Log

## DEC-001
- **Question**: Where is the scope boundary between Story 2.3 (plan generation) and Story 2.4 (presentation and confirmation), in particular regarding Gum?
- **Context/Nuances**: Story 2.3 requires a rendered plan that reflects edits; Story 2.4 owns approval presentation, digest-bound confirmation, and cancellation status `3`. ADR 0004 makes Gum a presentation-only layer, and adding `gum` to `image/` requires live ISO console validation and a pinned version. Story 2.2 deferred `gum` to Story 2.3 or 2.4. Alternatives: Gum-based review (steps 1–5) in 2.3 with confirmation in 2.4, or interactive Gum editing in 2.3; both split Gum validation across two stories and couple editing to Gum.
- **User Response**: Accepted the recommendation (non-interactive 2.3).
- **Decision**: Story 2.3 is non-interactive: it generates, validates, digests, persists, and renders the plan as plain text. Gum and the interactive review and confirmation flow belong to Story 2.4. The render is derived only from the persisted plan; `gum` does not enter `image/` in this plan.
- **Status**: Accepted

## DEC-002
- **Question**: What is the command surface of plan generation and what does it take as input?
- **Context/Nuances**: Story 2.2 (its DEC-004) requires Stories 2.3–2.5 to extend `operations/install` rather than add parallel surfaces. The architecture requires independently invocable stages with structured inputs passed as explicit files. `discover` still writes `target-facts.json` as `invalid` on exit `2`. Alternatives: `plan --target <id>` running discovery and generation together (couples two stages and forces rediscovery on every regeneration), or accepting both forms (doubles tested paths).
- **User Response**: Accepted the recommendation.
- **Decision**: Add `operations/install plan --facts <file> [--choices <file>] [--output <dir>]`. It consumes an existing `target-facts.json` and never runs discovery. The `target_id` comes from the facts document, so no `--target` is repeated. Facts with `validation.status: invalid`, an unknown `format_version`, or failing `validate-facts.mjs` exit `2`. The existing `--help`, no-argument, and unknown-argument behaviors are kept. The exact shape of `--choices` and `--output` is decided later.
- **Status**: Accepted

## DEC-003
- **Question**: Where does the installation policy live and how is each default described?
- **Context/Nuances**: Only `install/discovery/policy.json` exists (three discovery keys with provenance). The architecture assigns base installation choices to installation policy and detected target-specific choices to hardware modules. The native prototype scenario matrix already classifies items as `architecture`, `preference`, or `necessity`, but it served prototypes only. Story 2.3 requires the four labels `personal_preference`, `hardware_detection`, `arch_guidance`, and `technical_necessity`. Alternatives: extending the discovery policy (mixes discovery thresholds with installation choices) or one file per domain (more validation surface without a current need).
- **User Response**: Accepted the recommendation.
- **Decision**: Installation policy lives in a new versioned `install/plan/policy.json` (`format_version: 1`), separate from the discovery policy. Each key declares `value`, `provenance` (one of the four labels), and `editable` (boolean). Architecture-fixed choices (UEFI, GPT, official `linux`, unencrypted root) are labeled `technical_necessity` or `arch_guidance` as appropriate and are not editable. The native prototype matrix is the initial source but not normative; each item is reviewed before adoption.
- **Status**: Accepted

## TODO-001
- **Question**: Which items of the native prototype matrix enter the installation policy, with which provenance label and editability?
- **Status**: Pending (next question)

## DEC-004
- **Question**: Which items of the native prototype matrix enter `install/plan/policy.json`, with which provenance label and editability? (Resolves TODO-001.)
- **Context/Nuances**: Proposed item by item from the native scenario matrix. Filesystem and bootloader are not separate keys: ADR 0003 defines storage options that bind filesystem, layout, bootloader, and resume-offset method together, so independent keys would create unqualified combinations. The user asked whether the root password is optional: the root account choice is explicit in the plan (so the digest covers it and Story 2.4 can show it) rather than inferred at runtime from whether a password is entered.
- **User Response**: Accepted the adjusted proposal.
- **Decision**: Adopted policy (value; provenance; editable):
  - `firmware_mode` `uefi` and `partition_table` `gpt`; technical_necessity; no.
  - `esp` 1 GiB FAT32 at `/boot`; arch_guidance; no.
  - `storage_option`: a single key replacing `root_filesystem` and `bootloader`; it determines filesystem, layout, bootloader, and resume-offset method; allowed values pending TODO-002. Bootloader options of the default (`timeout 3`, `editor no`, fallback entry) are personal_preference, not editable.
  - `kernel` official `linux`; technical_necessity; no.
  - `initramfs` default mkinitcpio hooks, no UKI; arch_guidance; no.
  - `kernel_cmdline` `root=UUID=… rw resume=UUID=… resume_offset=…`, no `quiet`; personal_preference; no.
  - `swapfile_size` 4 GiB at `/swapfile`; personal_preference; yes (hardware-derived sizing belongs to Story 2.6).
  - `zram` disabled; personal_preference; no.
  - `packages` `base linux linux-firmware sudo neovim man-db man-pages`; personal_preference; no.
  - `mirrorlist` inherited from the live environment and recorded; technical_necessity; no.
  - `locales` `en_US.UTF-8`, `es_ES.UTF-8` and `lang` `en_US.UTF-8`; personal_preference; yes.
  - `console_keymap` `us`; personal_preference; yes.
  - `timezone` `Europe/Madrid`; personal_preference; yes.
  - `hardware_clock` UTC; arch_guidance; no.
  - `time_sync` `systemd-timesyncd`; personal_preference; no.
  - `hostname` `mirroros`, overridable per target (for example `mirroros-ref`); personal_preference; yes.
  - `network` NetworkManager, no predefined connections; personal_preference; no.
  - `user` `mirroros`, `wheel`, `bash`; personal_preference; only the name is editable.
  - `sudo` drop-in `%wheel ALL=(ALL:ALL) ALL`; personal_preference; no.
  - `root_account` `locked` (default, no secret) or `password` (adds the `root_password` secret requirement, by name only); personal_preference; yes.
  - `sysrq` `kernel.sysrq = 1`; personal_preference; no.
  - `pacman_options` `Color`, `ParallelDownloads = 5`, `VerbosePkgLists`, `ILoveCandy`; personal_preference; no.
  - `fstrim_timer` enabled; personal_preference; no.
  The user password is always a required secret. Microcode (inherited TODO-004), graphics drivers, and `multilib` (inherited TODO-005) are out of this policy.
- **Status**: Accepted

## TODO-002
- **Question**: Which storage options does the Story 2.3 plan accept for `storage_option`, and with which support status?
- **Context/Nuances**: The user stated that all three options (`ext4-systemd-boot`, `btrfs-rescue`, `btrfs-limine`) will be possible and that none should be experimental. This conflicts with accepted ADR 0003, which classifies `btrfs-limine` as experimental with no support commitment until four conditions are met (ESP occupancy measured and ESP size decided, AUR dependencies routed through Story 3.2, and others). Changing a tier requires a new or superseding ADR; this plan must not resolve it silently.
- **Status**: Pending (next question)

## DEC-005
- **Question**: Which storage options does the plan accept for `storage_option`, and how is their support status shown? (Resolves TODO-002.)
- **Context/Nuances**: The user wants all three options possible and none experimental. Accepted ADR 0003 classifies `btrfs-limine` as experimental until its four conditions are met; repository rules make accepted ADRs normative, so changing the tier needs a superseding ADR and is not done in this plan. The engine (Story 2.5) does not exist yet, so this only defines what the plan accepts. Rejected: accepting all three without tiers (contradicts ADR 0003), writing a superseding ADR inside this plan (expands scope and skips the required measurements), and default-only (contrary to the user's intent).
- **User Response**: Accepted the recommendation.
- **Decision**: `storage_option` is editable and accepts `ext4-systemd-boot` (default), `btrfs-rescue`, and `btrfs-limine`. The plan shows each option's current support tier as read from a tier table in `install/plan/policy.json`, reflecting ADR 0003 today; a future ADR changes only that table, not plan code. Option-specific resume parameters are resolved in Story 2.5.
- **Status**: Accepted

## TODO-003
- **Question**: Promote `btrfs-limine` from experimental to supported.
- **Context/Nuances**: The user intends all three options to be supported. This requires an ADR superseding ADR 0003's tier and meeting its four conditions (ESP occupancy measurement and size decision, AUR dependency routing through Story 3.2, and the remaining validation conditions). Out of scope for this plan.
- **Status**: Pending (outside Story 2.3)

## DEC-006
- **Question**: How is the target disk selected in the plan?
- **Context/Nuances**: Discovery lists every disk as eligible or ineligible and never selects one; Story 2.2 deferred selection to Story 2.3. The architecture requires the plan to identify the device by path, model, size, and stable identifiers, and Story 2.4 binds confirmation to that identity. Rejected: always requiring manual selection (both supported targets have one internal disk and Story 2.4 re-confirms identity anyway) and picking the largest disk (an unsafe guess).
- **User Response**: Accepted the recommendation.
- **Decision**: `target_disk` is an editable choice expressed by the disk's stable identifier (`by_id`, preferring `nvme-eui.*`, then `wwn-*`). With exactly one eligible disk it is preselected with provenance `hardware_detection`. With several eligible disks the plan does not choose: it exits `2` with an actionable reason listing the candidates unless the choices file sets the disk. Choosing an ineligible or unknown disk exits `2`. The plan copies the disk's full identity (path, `by_id`, WWN, serial, model, size) and its current layout, presented as content to be destroyed. When no `by_id` exists, the path is a fallback with a plan warning, and Story 2.4 re-checks model and size; when neither exists, the plan exits `2`.
- **Status**: Accepted

## DEC-007
- **Question**: How are editable choices supplied, and where do they sit in the precedence model?
- **Context/Nuances**: Story 2.2 established `portable_baseline` < `detected` < `target_override` < `runtime_private`. User edits are a new layer. FR12 provenance answers why a default exists; it does not record which layer set the final value. Rejected: one flag per choice (larger surface, harder to reproduce a plan) and hand-editing the plan JSON followed by revalidation (breaks the separation between generated plan and input, and the digest would no longer correspond to a generation).
- **User Response**: Accepted the recommendation.
- **Decision**: Edits arrive only through `--choices <file>`, a flat JSON object with `format_version: 1` whose keys are restricted to the editable ones: `target_disk`, `storage_option`, `swapfile_size`, `locales`, `lang`, `console_keymap`, `timezone`, `hostname`, `user_name`, and `root_account`. Unknown or non-editable keys, invalid values (for example an unknown storage option, a nonexistent time zone, or a hostname violating RFC 1123), and any secret-like field (`password`, `*_password`) exit `2`; secrets never travel in this file. Precedence is `policy` < `detected` (hardware detection) < `target_override` < `choice`. Target overrides live in `targets/<id>/overrides/plan.json` with an allowlist that admits only `hostname` in Story 2.3. Secrets are outside this chain; the plan only names them. Every plan value records `provenance` (the FR12 class of the default) and `source` (`policy`, `detected`, `override`, or `choice`). The choices file belongs to the user and is not versioned under `targets/`.
- **Status**: Accepted

## DEC-008
- **Question**: At what granularity and in what form does the plan express proposed operations?
- **Context/Nuances**: Story 2.3 requires proposed operations; Story 2.5 must execute only operations represented by the approved digest; Story 2.4 highlights destructive ones. The native engine (ADR 0002) is a MirrorOS-owned Bash sequence; the prototype is a reference only. Rejected: concrete command lines (couples the plan and digest to the engine implementation) and a high-level summary only (insufficient for Story 2.5 to execute only what is represented).
- **User Response**: Accepted the recommendation.
- **Decision**: The plan contains an ordered list of declarative operations, each with a stable `id`, `kind`, `destructive` boolean, resolved `parameters`, and human-readable `description`, and no shell commands. Order is significant and declared by the contract. Reference sequence for `ext4-systemd-boot`: `wipe_disk_signatures`, `create_partition_table`, `create_partitions`, `format_filesystems` (all destructive), `mount_target`, `install_packages`, `generate_fstab`, `create_swapfile`, `configure_locale_time_console`, `configure_hostname_network`, `create_user` (requires `user_password`), `configure_root_account` (`locked`, or `password` requiring `root_password`), `configure_sudo_sysrq_pacman`, `install_bootloader`, `enable_services`. Btrfs options replace or add their own steps (subvolumes, Snapper and baseline snapshot, Limine). Values known only during apply (UUIDs, `resume_offset`) are declared `resolved_at_apply` with their method and no value. The `kind` vocabulary is part of the versioned plan contract, and Story 2.5 must reject unknown kinds.
- **Status**: Accepted

## DEC-009
- **Question**: What hardware-derived selections does the Story 2.3 plan contain?
- **Context/Nuances**: Story 2.3 requires hardware-derived selections to be identified. Story 2.6 owns hardware rules (graphics, battery, virtualization, storage, swap, resume) and the inherited microcode TODO-004. So far the only real hardware-derived selection is the `target_disk` preselection (DEC-006). Rejected: implementing the microcode rule now (resolves TODO-004 outside its story and sets the rule pattern before Story 2.6 designs it) and omitting the section (fails the acceptance criterion).
- **User Response**: Accepted the recommendation.
- **Decision**: The plan has a stable `hardware_selections` section whose entries carry `id`, `fact` (the dotted path in `effective`), `value`, `provenance: hardware_detection`, and `rule`. In Story 2.3 it holds the `target_disk` preselection when applicable and the 64-bit UEFI boot-mode check that confirms `firmware_mode` (a check, not a choice). An informational `detected_capabilities` block lists graphics vendor, battery, virtualization, and CPU with `rule: not_evaluated` and `next_story: 2.6`; none of them becomes a package or configuration. Microcode, graphics, and hardware-derived swap and resume stay in Story 2.6, which extends the section without changing its shape.
- **Status**: Accepted

## DEC-010
- **Question**: How is the plan digest computed, what does it cover, and how is the plan bound to its facts and policy?
- **Context/Nuances**: The architecture requires a digest over canonical persisted content; Story 2.3 requires a new digest on change; Story 2.4 invalidates approval when target state changes and needs to know which facts produced the plan. Only Node built-ins are allowed. Rejected: including timestamps in the signed content (every regeneration would change the digest even without a content change).
- **User Response**: Accepted the recommendation.
- **Decision**: SHA-256 in hex, stored as `digest: { algorithm: "sha256", value: "<hex>" }`, over an in-house canonical serialization inspired by RFC 8785 but restricted to the plan format: object keys sorted by code point, no whitespace, UTF-8, integers only (the contract forbids non-integer numbers). `undefined`, non-integer numbers, and non-JSON types are an internal error (exit `6`). The digest covers the whole document except the `digest` field. Signed content contains no timestamps or `run_id`; run metadata goes to a separate file. `facts_binding` records the SHA-256 of the canonical `target-facts.json`, its `run_id`, `target_id`, and the code `commit`/`dirty`; `policy_binding` records the SHA-256 of `install/plan/policy.json` and of any target override used. Determinism (same inputs, same digest) is a tested property.
- **Status**: Accepted

## DEC-011
- **Question**: How is the plan persisted, how does regeneration behave, and how does the original plan stay unapproved?
- **Context/Nuances**: Story 2.3 requires atomic persistence and that, after edit and regeneration, the original plan remains unapproved and cannot authorize execution. Approval does not exist until Story 2.4. `discover` writes `evidence/install/<run-id>/` with 0700 directories, 0600 files, and atomic writes, and still writes invalid facts.
- **User Response**: Accepted the recommendation.
- **Decision**: Every `plan` invocation creates a new `run_id` and writes to `evidence/install/<run-id>/` (or `--output`) three files: `installation-plan.json` (plan with digest), `installation-plan.txt` (render derived from the persisted JSON), and `plan-run.json` (run metadata: `run_id`, RFC 3339 timestamp, input paths, plan digest, exit status, reasons). Writes go to a temporary file in the same directory, are flushed, re-read and revalidated (validator and digest recomputation), then renamed. Unlike discovery, an invalid plan is never persisted as `installation-plan.json`; only `plan-run.json` with reasons and exit `2` is written. Regeneration never overwrites: each regeneration uses a new run and directory, leaving the earlier plan intact for comparison; an `--output` directory that already contains a plan exits `2`. The plan has no approval field, and the validator rejects unknown fields such as `approved` or `approval`, so a plan cannot approve itself; approval will be a separate digest-bound artifact in Story 2.4. Tests show a different digest after regeneration, an unchanged original plan, and rejection of an injected approval field.
- **Status**: Accepted

## DEC-012
- **Question**: What is the plan contract and how do schema and safety validation work?
- **Context/Nuances**: The architecture tree names `contracts/installation-plan.schema.json`, but Story 2.2 established a Markdown contract with an in-house validator (`contracts/target-facts.md`, `validate-facts.mjs`) and no JSON Schema or npm dependency. Story 2.3 requires rejecting malformed, incomplete, contradictory, and unknown safety-critical fields.
- **User Response**: Accepted the recommendation.
- **Decision**: The contract is `contracts/installation-plan.md` (`format_version: 1`), following the Story 2.2 pattern and indexed in `contracts/README.md`; it documents the `kind` vocabulary, provenance and source labels, the `--choices` format, `overrides/plan.json`, validation codes, and exits. `install/plan/validate-plan.mjs` validates four levels: malformed (invalid JSON, wrong types, non-integer numbers), incomplete (missing target, operations, digest, bindings, secret requirements, or per-value provenance/source), unknown (unknown fields rejected throughout the document, not only in safety-critical parts; extension requires a new `format_version`), and contradictory (operation sequence not matching `storage_option`; `root_account: password` without `root_password` or the requirement present with `locked`; `lang` not in `locales`; disk identity not matching the bound facts or disk not eligible; `swapfile_size` plus ESP plus base minimum exceeding disk size; destructive operation without `target_disk`; unknown `kind` or disallowed order; digest not matching content). Errors use the Story 2.2 `code`/`message`/`next_step` shape with documented codes. Invalid inputs (facts, choices, override) exit `2`; a generated plan failing its own validator exits `6`; an external tool failure exits `5`.
- **Status**: Accepted

## TODO-004
- **Question**: Should the architecture tree entry `contracts/installation-plan.schema.json` be corrected to `contracts/installation-plan.md` in this plan?
- **Status**: Pending (next question)

## DEC-013
- **Question**: Should the architecture tree entry for the plan contract be corrected? (Resolves TODO-004.)
- **Context/Nuances**: The `docs/architecture.md` tree lists `contracts/installation-plan.schema.json`, `verification-result.schema.json`, and `execution-result.schema.json`. Story 2.2 added `contracts/target-facts.md` without updating the tree. AGENTS.md requires documentation to change with what it governs. Rejected: leaving the drift in a normative document, and changing all three entries (anticipates future stories; the verification result is prototype-gated).
- **User Response**: Accepted the recommendation.
- **Decision**: In the `docs/architecture.md` tree, `installation-plan.schema.json` becomes `installation-plan.md` and `target-facts.md` is added. The other `.schema.json` entries are unchanged.
- **Status**: Accepted

## DEC-014
- **Question**: What shape do secret requirements take in the plan?
- **Context/Nuances**: Story 2.3 requires the plan to identify secret requirements; Story 2.4 shows them at confirmation (FR14); Story 2.5 collects them through protected channels. `target-facts.json` already has `runtime_private.required_inputs` with names only.
- **User Response**: Accepted the recommendation.
- **Decision**: The plan has a `secret_requirements` ordered list of entries `{name, purpose, required_by, channel, provenance}`: `name` is `user_password`, plus `root_password` when `root_account: password`; `purpose` is human-readable; `required_by` lists consuming operation ids; `channel: protected_prompt` declares the channel class without fixing the Story 2.5 mechanism; `provenance` is `technical_necessity` for `user_password` and `personal_preference` for `root_password`. No values, hashes, or length hints; the validator rejects extra fields in entries and secret-named keys elsewhere. Consistency is bidirectional: every operation needing a secret has it declared, and no declared secret lacks a consumer. Canary-based tests assert that a planted value never appears in `installation-plan.json`, `installation-plan.txt`, `plan-run.json`, stdout, or stderr.
- **Status**: Accepted

## DEC-015
- **Question**: What does the rendered plan look like and what does `plan` print on the console?
- **Context/Nuances**: DEC-001 fixes a plain-text render derived from the persisted plan; the architecture's review flow orders target, defaults with provenance, destructive operations, full plan, cancellation, confirmation. The user asked whether anything is shown on screen: a short stdout summary is shown, and the full plan lives in a file, because roughly 25 choices and 15+ operations would scroll off the live ISO console and paged interactive review belongs to Story 2.4. Printing the full plan always, or adding a `--show` option, were offered and not chosen. The user then proposed Markdown for a better look; it was dropped because the live ISO has no Markdown renderer (no `gum` or `glow` in this story) and well-laid-out plain text reads just as well.
- **User Response**: Accepted the plain-text render with emphasis on readability.
- **Decision**: `install/plan/render-plan.mjs` is a pure function of the validated plan producing `installation-plan.txt`: plain text laid out for the console, 80 columns, underlined section headers, aligned key/value pairs, `DESTRUCTIVE` as a textual marker, no ANSI or color. Eight sections in review-flow order: target (with the layout that will be destroyed), choices and defaults (value, `provenance`, `source`, `[editable]`), destructive operations, all operations, secret requirements, hardware selections (including `not_evaluated` capabilities), warnings, and digest with bindings. The `plan` stdout is a short summary (target, disk, storage option, destructive operation count, required secrets, digest, plan path) ending with "Review installation-plan.txt; approval is not part of this stage."; diagnostics go to stderr. Everything rendered is in the signed plan. Tests: fixture snapshots, render changes after an edit, the shown digest matches the JSON, and lines stay within 80 columns except unavoidable long values such as `by_id`.
- **Status**: Accepted

## DEC-016
- **Question**: How is plan generation delivered on the live ISO and qualified?
- **Context/Nuances**: Story 2.2 embeds MirrorOS code through an explicit capture list under `/usr/local/lib/mirroros/` and qualifies with counted VM runs on a clean commit (new bundle, `operations/test`, `qualify-discovery`). Plans are generated on the live ISO where discovery runs. Plan generation is non-destructive and fully fixture-testable, but only a real run proves `discover → plan` on real facts with embedded code. Rejected: unit and contract tests only (does not prove the live path until Story 2.4) and a separate `qualify-plan` harness (duplicates `qualify-discovery`).
- **User Response**: Accepted the recommendation.
- **Decision**: `install/plan/` is embedded through the existing `install` entry of the capture list in `image/builder/lib/source-capture.sh`, so the builder is not edited (corrected after code inspection, approved with the plan draft); it holds only `.mjs`, so no new `profiledef.sh` entries are needed unless executables are added. `vm/reference/qualify-discovery` gains a `plan` scenario that, in the VM, runs `discover --target reference-vm`, then `plan` with defaults (exit `0`), then `plan` with a choices file changing hostname and `storage_option` (exit `0`, different digest, original plan byte-identical), then `plan` with an invalid choices file (exit `2`), and checks disk identity (`qemu-img compare`), Gitleaks and canary scans, and permissions. Runs are counted on a clean commit after rebuilding the ISO and boot requalification (`operations/test`). Only `reference-vm` is qualified while the Framework identity remains pending capture (Story 2.2 TODO-002).
- **Status**: Accepted

## TODO-005
- **Question**: Confirm on the rebuild that the 180-second `container-stop` deadline (`88d5244`, Story 2.2 follow-up) is sufficient.
- **Status**: Pending (during execution)

## DEC-017
- **Question**: How does installation policy relate to the `portable_baseline` layer of `target-facts.json`?
- **Context/Nuances**: The Story 2.2 plan stated that `portable_baseline` would be filled by installation policy in Story 2.3. DEC-003 and DEC-007 instead resolve installation policy and its precedence in the plan. Rejected: moving installation policy into the facts' `layers.portable_baseline` (requires facts `format_version` 2, discovery validator changes, discovery requalification, and mixes discovered state with choices).
- **User Response**: Accepted the recommendation.
- **Decision**: `target-facts.json` keeps its format (`format_version: 1`, discovery policy as baseline); discovery and its validator are not changed. Installation policy and its precedence are resolved only in the plan, which records `provenance` and `source` per value. `contracts/target-facts.md` gains a one-line note pointing to `contracts/installation-plan.md`, superseding the Story 2.2 intention.
- **Status**: Accepted

## DEC-018
- **Question**: How is the work committed, which checkpoints apply, and which documentation changes?
- **Context/Nuances**: Earlier stories used phased commits with maintainer checkpoints and included the technical-interview artifacts in the implementation commit.
- **User Response**: Accepted the recommendation.
- **Decision**: One `feat(install)` implementation commit containing `install/plan/` (`policy.json`, `generate-plan.mjs`, `validate-plan.mjs`, canonical JSON and digest, `render-plan.mjs`, `write-plan.mjs`), the `plan` subcommand in `operations/install`, `targets/reference-vm/overrides/plan.json` (`hostname: mirroros-ref`) and both targets' override READMEs, `contracts/installation-plan.md`, `contracts/README.md`, the note in `contracts/target-facts.md`, the `docs/architecture.md` tree lines, `docs/procedures/install.md`, Node and Bats tests with fixtures, the embedded capture and the `plan` scenario of `qualify-discovery` (with `docs/procedures/test.md` as needed), and `docs/technical-interviews/story-2-3-installation-plan_{log,plan}.md`. Three checkpoints: contract and policy review before implementing the generator; review of commit changes before committing; review of counted evidence before closing. Defects found during counted runs are fixed in new `fix(...)` commits and the counted runs repeat at the new HEAD. No attribution change (no third-party content); `docs/epics.md` is not touched.
- **Status**: Accepted

# Story 2.4 — Plan confirmation and safe cancellation: Decision Log

## DEC-001
- **Question**: How is approval of an installation plan represented: an ephemeral, single-use in-process approval, or a persisted approval artifact consumed by a later `apply`?
- **Context/Nuances**: Story 2.4 must show that target or plan changes after approval invalidate it when execution is requested, but the execution engine (`install/engine/apply`) belongs to Story 2.5. The architecture requires that retries need renewed confirmation and that no generic non-interactive option bypasses destructive confirmation. Plan 02-05 made approval unrepresentable inside the plan. A persisted approval would be a reusable artifact that a non-interactive `apply` could consume, and would need expiry and consumption rules.
- **User Response**: Accepted option A ("yes").
- **Decision**: Approval is ephemeral and single-use, held only inside one process. A single command (tentatively `operations/install apply --plan <file>`) revalidates the plan and its digest, reruns read-only discovery, compares it with `facts_binding`, presents the six-step review flow, asks for confirmation, and re-checks target identity and digest immediately before execution. Approval is never persisted as anything that authorizes; only a non-reusable evidence record (`approval-record.json`: digest, target identity, outcome, timestamp) is written. In Story 2.4 the command ends at an "engine pending" boundary after confirmation; Story 2.5 connects it to `install/engine/apply`.
- **Status**: Accepted

## DEC-002
- **Question**: What command surface exposes confirmation, and where does the component live?
- **Context/Nuances**: DEC-001 requires confirmation and execution to share one process. The architecture tree already reserves `install/confirmation/confirm-plan`. ADR 0004 wrappers were defined in Bash and Gum is a CLI; the language policy puts structured logic in Node.js ESM. A separate `confirm` subcommand would create a confirmation that authorizes nothing and force duplication in a later `apply`.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: Public subcommand `operations/install apply --plan <file> [--output <dir>]`, delegated like `discover` and `plan`, calls the orchestrator `install/confirmation/confirm-plan` and, from Story 2.5, `install/engine/apply`. Pure logic (binding comparison, review content, status mapping) lives in Node `.mjs` modules under `install/confirmation/`; Gum interaction and the six ADR 0004 wrappers live in Bash under `install/confirmation/`.
- **Status**: Partially superseded by DEC-006 (`--plan` is optional, not the primary input; the component split stays)

## DEC-003
- **Question**: What does `apply` return after a valid confirmation in Story 2.4, when no installation engine exists yet?
- **Context/Nuances**: The architecture forbids representing anything not executed as success. Returning `0` would read as a successful installation to any consumer that only checks the status. Tests must distinguish approved, cancelled, and invalidated paths.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: After confirmation and the final re-check pass, `apply` exits `2` (unmet precondition) with reason `engine_not_available` (message: the installation engine is not part of this MirrorOS version and nothing was executed; next step: installation becomes available with Story 2.5), and `approval-record.json` records `outcome: "approved"`. Paths are distinguished by status plus outcome: approved → `2`/`approved`; cancelled → `3`/`cancelled`; invalidated → `2`/`invalidated` with a specific reason. The engine boundary is a single point (absent `install/engine/apply` → `engine_not_available`) that Story 2.5 replaces.
- **Status**: Accepted

## DEC-004
- **Question**: How is Ctrl+C (Gum status `130`, TODO-002 carried from ADR 0004) mapped during `apply`?
- **Context/Nuances**: ADR 0004 measured `130` on Ctrl+C and requires `confirm_status_map` to return it unmapped, delegating the mapping to Story 2.4. The architecture keeps normal shell conventions for signal termination, while the story AC requires rejecting or cancelling confirmation to return `3`. Mapping every SIGINT during `apply` would blur the signal convention outside interaction; never mapping contradicts the AC.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: SIGINT received during the interactive review and confirmation phase (steps 1–6 of the plan review flow) maps to `3` with `outcome: "cancelled"` and `approval-record.json` written. SIGINT outside that phase (for example during read-only revalidation or rediscovery) and every other signal (SIGTERM, SIGHUP) keep `128+n`. The mapping happens in the `confirm-plan` layer, not in the wrapper, so `confirm_status_map` stays as ADR 0004 states. ADR 0004 is not modified; the mapping is documented in the contract and the install procedure.
- **Status**: Accepted

## DEC-005
- **Question**: What is re-checked to detect that the target state changed after the plan was generated or approved?
- **Context/Nuances**: `facts_binding.facts_sha256` cannot be compared because facts include `source.run_id`, so every rediscovery hashes differently. A disk-identity-only check is cheaper but misses new partitions and policy changes between plan generation and `apply`. Network readiness is already a validity condition of the facts.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: `apply` reruns full read-only discovery through `install/discovery/discover` with the plan's `target_id`, storing its output in the `apply` run directory. Fresh facts must be valid; otherwise `2` with `outcome: "invalidated"` and the discovery reason. A safety projection is then compared between the plan and the fresh facts: `target_id`; `firmware.boot_mode` and `secure_boot`; the selected disk identity (`path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes`), `eligible == true`, and `current_layout` (partition table and partitions: uuid, partuuid, sizes, fstype, label, mountpoints); and `policy_binding`, recomputing the hashes of `install/plan/policy.json` and the target override. Any difference gives `2`, `outcome: "invalidated"`, a specific code (for example `target_identity_changed`, `target_layout_changed`, `policy_changed`), and next step "Regenerate and review the installation plan". The comparison runs twice: before the review is presented and again immediately after confirmation. Network is not part of the projection.
- **Status**: Accepted

## TODO-001
- **Question**: `contracts/installation-plan.md` (line 9) says approval is "a separate, digest-bound artifact of a later stage", which contradicts DEC-001.
- **Context/Nuances**: Under DEC-001 no persisted artifact authorizes execution; `approval-record.json` is evidence only.
- **Decision**: The implementation plan amends that sentence to describe ephemeral, in-process, digest-bound confirmation with a non-authorizing evidence record.
- **Status**: Pending

## DEC-006
- **Question**: Should this story deliver a single interactive installation flow with Gum-based editing of choices and automatic target detection, instead of separate `plan` and `apply` experiences?
- **Context/Nuances**: Story 2.3 made planning non-interactive (architecture: reproducible non-destructive operations support non-interactive execution; ADR 0004: plan and digest do not depend on Gum), so Gum has not entered production yet and no story covers interactive editing. The maintainer wants less fragmentation and to configure any combination of options. The PRD (line 174) excludes general-purpose hardware beyond the reference VM and target laptop, and Story 2.2 requires rejecting targets outside that boundary. Policy-fixed keys (kernel, packages, partition table, ESP, bootloader options, zram, sudoers, and others) are not editable under the Story 2.3 contract.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: Plan 02-06 delivers one interactive flow, `operations/install apply`: read-only discovery → plan generation through the existing generator → review (steps 1–5) with an edit loop in which every currently editable choice (`target_disk`, `storage_option`, `swapfile_size`, `locales`, `lang`, `console_keymap`, `timezone`, `hostname`, `user_name`, `root_account`) can be changed with Gum in any valid combination, each edit regenerating the plan with a new digest → confirmation (step 6) → final re-check → engine boundary (Story 2.5). `--target` is not required: the target definition is detected automatically from `targets/`; unknown hardware still exits `2` with an actionable reason. `--plan <file>` becomes optional for reviewing an existing plan. The non-interactive `discover` and `plan` subcommands remain as reusable, testable pieces.
- **Status**: Accepted (automatic target detection superseded by DEC-007)

## TODO-002
- **Question**: Should policy-fixed installation keys become editable?
- **Context/Nuances**: Changes the Story 2.3 contract; each key has safety or support implications.
- **Decision**: Out of scope for plan 02-06; requires its own decision.
- **Status**: Pending

## TODO-003
- **Question**: Should MirrorOS install on hardware other than the reference VM and the target laptop?
- **Context/Nuances**: The PRD excludes general-purpose hardware support from the MVP; Story 2.6 hardware rules and qualification gates depend on that boundary.
- **Decision**: Out of scope; requires an ADR and a PRD change.
- **Status**: Pending

## TODO-004
- **Question**: How does automatic target detection fit the `discover` contract, which currently requires `--target` (`target_missing`)?
- **Context/Nuances**: Detection could live inside discovery (making `--target` optional) or in the interactive flow before calling `discover --target <detected>`.
- **Decision**: Resolved by DEC-007: no automatic detection; the target is chosen with Gum and `discover --target` is unchanged.
- **Status**: Closed

## DEC-007
- **Question**: In the interactive flow, is the target chosen manually or detected automatically?
- **Context/Nuances**: A target definition does not drive plan options (those come from detected hardware and editable choices); it marks a qualified, supported machine (MVP boundary, VM-before-laptop qualification traceability) and carries device-specific overrides. Automatic detection would change `contracts/target-facts.md`, the facts validator, `discover`, and their tests to save a two-entry menu, and would let the system decide instead of verifying the user's stated intent.
- **User Response**: Asked for a recommendation; accepted manual selection ("yes").
- **Decision**: The interactive flow lists the definitions under `targets/` with `gum choose`; `discover --target <id>` is unchanged and verifies the hardware against the chosen target (`target_identity_mismatch` on mismatch; `target_identity_pending_capture` for the Framework until its DMI is captured). No facts or discovery contract change. Automatic detection may later be added as a menu preselection. Supersedes the automatic-detection part of DEC-006 and closes TODO-004.
- **Status**: Accepted

## DEC-008
- **Question**: What gesture does the final confirmation (review step 6) require?
- **Context/Nuances**: The binding to the plan digest is mechanical (DEC-001, DEC-005: the process holds the digest and re-checks after confirmation), so the human gesture only needs to break reflex confirmation and make the erased disk explicit. Typing 12 hex characters of the digest was judged too heavy; a confirm-only gesture can be passed with a reflexive `y` plus Enter; typing digest characters binds the gesture to the plan but not to the disk.
- **User Response**: Accepted the recommendation.
- **Decision**: `gum confirm` (or the `colorless_confirm` `gum choose` variant) with default focus on No, showing "Erase `<disk path> <model> <size>` and apply plan `<digest[0:12]>`?"; declining or Esc exits `3`. Then the user types the device kernel name (for example `vda`, `nvme0n1`) with `gum input`. A mismatch exits `3` with `outcome: "cancelled"` and reason `confirmation_mismatch`, without a second attempt; retrying means rerunning `apply`. Esc or Ctrl+C at either prompt exits `3` (DEC-004). Identical for virtual and physical targets.
- **Status**: Accepted

## DEC-009
- **Question**: How is Gum added to the live ISO, given ADR 0004's "pinned package version" and the architecture's rolling-repository model?
- **Context/Nuances**: The architecture treats observed versions as dated observations, not pins, and builds record actual versions (archiso, gitleaks, nodejs). `extra` currently ships `gum 2.0.2-1`, the version measured in plan 02-03. The build bundle already contains a package manifest whose SHA-256 is recorded in `artifact-metadata.json`, so the installed Gum version is recorded without builder changes. A true pin (local package or Arch Archive snapshot) contradicts the rolling model and is Story 3.2 provenance work.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: Add `gum` unpinned to `image/archiso/packages.x86_64`, like `nodejs`. "Pinned" is interpreted as recorded and checked: the bundle package manifest records the installed version; at runtime `apply` checks `gum --version` against the measured major version (2.x) and exits `6` with a reason that Gum behavior is not qualified if it differs (ADR 0004 revisit trigger); the actual version is recorded in `approval-record.json`. ADR 0004 is not amended; the interpretation is documented in the build procedure.
- **Status**: Accepted

## DEC-010
- **Question**: How is the interactive flow tested and qualified?
- **Context/Nuances**: The flow mixes pure logic, Gum interaction, signals, and real target state. Plan 02-03 drove real Gum under `script` with scripted keystrokes. ADR 0004 requires live ISO console validation. A Bats-only approach would not exercise real Gum on the ISO or invalidation by a real target change. The Framework cannot run (DMI pending capture).
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: Four layers. (1) `node --test` for pure logic: safety projection and codes, status and outcome mapping, choice edits to choices file to regeneration, review content. (2) Bats with a `gum` double on `PATH` covering every path: approved → `2`/`engine_not_available`; decline, Esc, Ctrl+C during review, and `confirmation_mismatch` → `3`; Ctrl+C outside review → `130`; tampered plan (`digest_mismatch`), target or layout changed before and after confirmation, and `policy_changed` → `2`/`invalidated`; no TTY or `--yes`/`--non-interactive` flags → `2`; `NO_COLOR`/`TERM=dumb` → `gum choose` variant; Gum major version other than 2 → `6`; a failing `sudo` double; a secret canary. (3) Counted reference-VM qualification: a new scenario (in `qualify-discovery` or a sibling `qualify-confirmation`, chosen while drafting) where the guest trigger runs `apply` under `script` with scripted keystrokes and real Gum: approve (`2`, identical disk), cancel (`3`, identical disk), name mismatch (`3`), and layout change after plan generation (the guest writes a partition table on the disposable VM disk between `plan` and `apply --plan` → `2`/`target_layout_changed`). (4) An attended checkpoint where the maintainer reviews rendering on the live ISO console (VM VT), recorded as evidence. The Framework is not run in this plan.
- **Status**: Accepted

## DEC-011
- **Question**: Does Story 2.4 collect secret values, or only show secret requirements?
- **Context/Nuances**: The plan declares `user_password` always and `root_password` when `root_account: password`, with channel `protected_prompt`. Story 2.4 requires secret requirements to be visible; Story 2.5 requires values through protected runtime channels. Collecting now would handle a secret with no consumer.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: The review shows each secret requirement by name, channel, and consumer (for example "`user_password` — protected prompt — required by `create_user`"); no value is requested in Story 2.4, not even after confirmation. Collection with `gum input --password` belongs to Story 2.5, immediately before execution. Editing `root_account` in the edit loop adds or removes `root_password` from the displayed list through the existing generator.
- **Status**: Accepted

## DEC-012
- **Question**: How does `apply` reuse the existing stages, and what is its evidence layout?
- **Context/Nuances**: The architecture requires components to communicate through arguments, explicit files, and exit statuses, not through each other's private implementation. Importing discovery and plan modules directly would save processes but couple to internals and lose the per-stage evidence the CLIs already produce.
- **User Response**: Accepted the recommendation ("yes").
- **Decision**: `apply` invokes `install/discovery/discover --target <id> --output <dir>` and `install/plan/plan --facts <file> --choices <file> --output <dir>` as processes. One run directory, `evidence/install/<run-id>/` or `--output`, with `0700`/`0600`: `apply-run.json` (run_id, timestamp, target_id, Gum version, digests in order, final digest, exit_status, outcome, reasons); `approval-record.json` (non-authorizing evidence: final digest, disk identity, outcome, reason, timestamp); `discovery/initial/` (facts for generation, or the pre-review check with `--plan`); `discovery/final/` (post-confirmation rediscovery); `plans/01/`, `plans/02/`, … (one per regeneration: `installation-plan.{json,txt}`, `plan-run.json`, `choices.json` without secrets); `apply.log` (plain text, no ANSI, no secrets). With `--plan <file>` the plan is copied into `plans/01/` after validation and the original is untouched. `apply-run.json` and `approval-record.json` are always written, including on cancellation and invalidation, except for argument or TTY errors before the run starts, which report on stderr with `2`.
- **Status**: Accepted

## DEC-013
- **Question**: What is the review and edit interface?
- **Context/Nuances**: Two throwaway demos (outside the repository, `/tmp/mirroros-ux-demo/`) compared a step-by-step wizard (A) with a single dashboard (B). The maintainer prefers B "for now". `gum pager` has a search defect and is avoided. The demos used the default pink `gum format` theme and a red border, which do not match the 02-03 prototype palette (`prototypes/frontend/lib/flow.sh`): grayscale only, header gradient 255→240 with rounded border 245, section titles bold 255, explanatory text 248, `DESTRUCTIVE` inverted (0 on 255), menus with cursor and selection 255 and items 245, confirm with the selected button inverted. Risk of B: the dashboard may not fit an 80×25 console without scrolling.
- **User Response**: Prefers B; asked for more top margin above the menu header and the prototype color scheme; accepted the summary ("yes").
- **Decision**: The review is a single dashboard rendered with `gum format`: plan digest in the header, target, choices with provenance, destructive operations, and required secrets, followed by a `gum choose` menu `Cancel` (first, safe) · `Edit a choice` · `Continue to confirmation`. No `gum pager`. The dashboard covers review steps 1–5; step 6 is DEC-008. Editing uses one widget per key (`gum choose` for `target_disk` among eligible disks, `storage_option` with tier labels, `lang` among current locales, `root_account`; `gum filter` for `console_keymap` and `timezone`; `gum filter --no-limit` for `locales`; `gum input` for `swapfile_size`, `hostname`, `user_name`). An invalid combination (`plan` exits `2`) shows `message`/`next_step`, discards the edit, keeps the previous plan, and returns to the dashboard. Each `choices.json` accumulates all edits of the run; with `--plan` the starting choices are the plan entries with `source: choice`. Esc inside an edit widget returns to the dashboard unchanged; only `Cancel`, the final No, or Ctrl+C cancel with `3`. Styling uses the 02-03 grayscale palette everywhere, with a project grayscale glamour style for `gum format` instead of the pink theme, and a larger top margin above the menu header (tuned during implementation). The attended live ISO console checkpoint verifies the dashboard fits 80×25; if not, it is compacted (grouped choices, non-destructive operations on one line) without returning to the wizard unless the maintainer agrees.
- **Status**: Accepted

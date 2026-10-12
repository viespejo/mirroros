# Installation confirmation (`mirroros-install`)

`format_version: 4`. Produced by `mirroros-install` (`operations/install`) without a subcommand, which runs the
guided live installer: one interactive Gum flow that prepares the live environment, discovers the machine
automatically, collects the installation choices, generates and reviews an
[installation plan](installation-plan.md), and requires a machine-, disk-, and digest-bound confirmation.
Confirmation is ephemeral and single-use: it exists only inside one process. No persisted file authorizes
anything. The two JSON documents below are evidence records. Unknown fields are rejected by
`install/confirmation/validate-records.mjs`, and records of `format_version` `1` (`apply-run.json`,
`apply.log`), `2`, and `3` (earlier `install-run.json` and `approval-record.json`) are historical evidence that
is neither read nor transformed. Version `4` adds the `password` and `engine` stages and the outcome `installed`,
and removes `approved` as a terminal outcome and the reason `engine_not_available`; it keeps
`machine.memory_total_bytes` and the choices of [installation plan](installation-plan.md) version 3, per
[ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md).

In this version a valid approval is followed by the protected password entry, a final revalidation, and one
invocation of the installation engine (`install/engine/apply`, defined in
[`installation-engine.md`](installation-engine.md)), which installs the base system. Exit `0` and the outcome
`installed` mean that the engine completed every operation of the approved plan; installation postconditions are
not verified in this version (Story 2.6). The engine is reachable only through this flow
([ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md)), and the assistant runs only the
`install/engine/apply` of its own artifact.

The live session and the assistant run as root, as on the Arch live ISO
([ADR 0006](../docs/adr/0006-guided-live-installation-boundaries.md)). Root privilege authorizes nothing: no
installation-disk operation is reachable without the confirmation below. The flow never calls `sudo` or any other
elevation, never branches on whether the machine is virtual or physical, and requests only the single account
password, through the protected prompt of [Password hand-over](#password-hand-over).

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted.

## Command

```text
mirroros-install [--plan <file>] [--output <dir>]
mirroros-install discover [--target <id>] [--output <dir>]
mirroros-install plan --facts <file> [--choices <file>] [--output <dir>]
mirroros-install --help
```

| Form | Description |
| --- | --- |
| no subcommand | The habitual guided installation, as described under [Flow](#flow). |
| `--plan <file>` | The same assistant, entering review with an existing plan instead of the configuration screens. The plan is validated (including its digest and its format) and, before review, rejected with `engine_version_mismatch` when the commit or dirty state it was generated with differs from the running artifact's; it is then copied to `plans/01/` and compared with fresh discovery; the original is untouched. It reaches the engine only through review, confirmation, password entry, and revalidation. A valid unchanged plan still requires fresh confirmation, and an edit generates a new plan. |
| `--output <dir>` | Run directory. Defaults to `evidence/install/<run-id>/`. |
| `discover`, `plan` | The independently invocable technical components, with their own contracts: [`target-facts.md`](target-facts.md) and [`installation-plan.md`](installation-plan.md). They start no assistant. |
| `--help` | Prints help. It is free of side effects and starts no assistant, discovery, or preparation. |

`apply` is not a subcommand: it is rejected like any unknown subcommand. `--yes`, `--non-interactive`, every
other bypass flag, and any unknown option exit `2` before any prompt, preparation, or discovery. The
internal `install/engine/apply` boundary keeps its name and is not a public command.

### Terminal gate

Before discovery or any prompt, the assistant requires all of the following, and otherwise exits `2` with a
message on stderr, no run directory, and no records:

1. Standard input and standard output are terminals. No environment variable or option bypasses this.
2. `TERM` is set and is not `dumb`.
3. `NO_COLOR` is unset or empty.

The supported presentation is the colored interactive console of the live ISO. There is no colorless variant,
and a terminal outside that scope is rejected rather than rendered differently
([ADR 0006](../docs/adr/0006-guided-live-installation-boundaries.md#colored-live-console-presentation)).

Then the installer lock is taken (see [Run exclusion and start-of-run cleanup](#run-exclusion-and-start-of-run-cleanup)), and the major version of `gum --version` must be `2`. A missing Gum or another major version exits `6` with the
reason `gum_not_qualified`; the run directory and records are written, with `gum_version` omitted when Gum was not
found.

### Run exclusion and start-of-run cleanup

Right after the terminal gate, and before the Gum check, the start-of-run cleanup, discovery, and the creation of
any run directory, the assistant takes a non-blocking exclusive lock with `flock -n` on
`/run/mirroros/install.lock` (tmpfs) and holds it until the flow and the engine end. The engine inherits the
descriptor (see [`installation-engine.md`](installation-engine.md#run-exclusion)). A second run exits `2` with
the reason `install_already_running` on stderr only: no run directory, no records, no mount touched, and no
waiting. The kernel releases the lock when its holder ends or dies, so leftovers of a dead attempt can still be
recovered by the next run. `discover`, `plan`, and `--help` take no lock.

Once the run directory exists, and before live preparation and discovery, the assistant recursively unmounts the
engine's own mount point `/run/mirroros/target` and turns off any swapfile beneath it, and records this in
`install.log`. It touches nothing else. A cleanup failure is logged and does not stop the run; discovery then
reports the disk as ineligible while it is still mounted.

## Flow

The screens and their order are the reference's, with the integration differences listed under
[Differences from the reference](#differences-from-the-reference).

1. **Gate, installer lock, and Gum check**, as above, then the start-of-run cleanup.
2. **Welcome and live keyboard.** The live keyboard applies to the live virtual consoles only. It does not
   change the installed-system keyboard, and cancelling does not revert it.
3. **Live preparation**, before discovery, drawing a screen only when something needs attention:
   - Route, name resolution, time readiness, and a validated HTTPS check are coordinated so that a clock failure
     is not reported as a generic network failure.
   - Time readiness relies on the ISO's enabled `systemd-timesyncd`. It reads `NTPSynchronized` with a monotonic
     wait of at most 60 seconds per attempt. It does not start or restart a service, change the clock, or bypass
     TLS or package signature verification.
   - When a check fails, the screen offers help, retry, or cancellation. Ethernet guidance, or Wi-Fi guidance
     through `iwctl` in another console (shown with `gum pager`), is for the live environment only. Wi-Fi
     credentials are never requested or retained, and live connections are not copied into the installed system.
   - After the network and clock checks, preparation waits for `pacman-init.service` to finish successfully, for
     at most 600 seconds. It draws a screen only while waiting or after failing (D16); the failure offers help,
     retry, or cancellation with the recoverable reason `live_keyring_not_ready`. It does not start the service
     or bypass package signature verification. The engine's own keyring check never waits.
   - This preparation does not replace discovery's connectivity validation.
4. **Automatic discovery** into `discovery/initial/`: `install/discovery/discover` without `--target`, as a
   process. The result shows the machine as recognized or unqualified (see
   [Machine check](#machine-check)).
5. **Configuration screens**, in order: installation disk, storage layout, hibernation (with swapfile size when
   enabled), timezone, system language, regional formats, installed keyboard, hostname, username, root policy.
   - Defaults and per-value validation come from the plan component's published helpers
     ([`installation-plan.md`](installation-plan.md#choice-helpers)) as processes; the assistant owns no policy.
   - The disk screen always lists the real eligible disks, including when there is only one. Labels and stable
     identifiers are kept separate.
   - The hibernation stage first offers Enabled or Disabled, initially Enabled, and shows the sizing screen only
     when enabled (see D15). Disabling removes any explicit size; re-enabling proposes the RAM-derived default
     again. A revisit shows the current choice. The stage is reachable from the edit menu like any other.
   - Advancing without changing a proposal keeps its provenance and source; only a changed value becomes a user
     choice.
   - Back or Esc returns to the previous screen without applying an incomplete answer and keeps confirmed
     answers.
6. **Review.** On entering review, `install/plan/plan` generates the first plan into `plans/01/` and validates the
   complete combination. The review shows the compact answers and the plan reference (the first 12 hex
   characters of the digest). The menu offers continuing to confirmation, inspecting the complete plan, and
   going back. The review shows the hibernation state: enabled with the swapfile size and, when the size is below
   detected memory, the persistent warning; or disabled, stating that no swapfile will be created. No additional
   confirmation dialog is added.
   - Inspecting the complete plan opens `gum pager` with the persisted plan text: disk and current layout, all
     choices with provenance and source, the destructive operations, warnings, secret requirements without
     values, and the plan reference. Leaving the pager returns to the review, preserves the answers, and grants no
     authorization.
   - After any answer changes, a new plan is generated into the next `plans/NN/` before review. An invalid
     combination shows its reason's `message` and `next_step`, keeps the last valid plan, and grants nothing.
     `choices.json` accumulates every edit of the run. With `--plan`, the starting choices are the plan entries whose
     source is `choice`.
7. **Confirmation.** The disk to erase and the plan reference are shown. `gum confirm` focuses on No. Then the
   user types the kernel device name (the basename of the disk path, for example `vda` or `nvme0n1`) with
   `gum input`. The digest is never typed.
8. **Password.** The single `account_password`, asked twice with a protected prompt (see
   [Password hand-over](#password-hand-over)).
9. **Final revalidation into `discovery/final/`.** Rediscovery, then the safety comparison and a digest re-check
   of the plan file on disk. A failed revalidation is `invalidated` and discards the password.
10. **Engine.** One invocation of the engine, with the progress screen (D17) while it runs and then the success
    (D18) or failure (D19) screen.

Going back from any screen after confirmation, including Esc at the password screen, clears the approval;
renewed review and confirmation are required before the flow can reach the password screen again.

### Machine check

Discovery reports the machine without a profile-selection screen:

- `profile.status` `matched`: the machine is shown as recognized, with the statement that it matches a known
  profile and that this does not guarantee that installation will work on it.
- `profile.status` `unqualified`: the machine passed the technical requirements but matches no known profile.
  The screen states that installation here is experimental, that compatibility is not guaranteed, and that no
  support is promised. The plan carries the warning `machine_unqualified`. The path asks for the same
  confirmation as a recognized machine and has no bypass.

### Failure handling

A failing phase is reported with its phase, cause, and next action. Only a recoverable failure offers correction
or retry, and only answers that remain valid are kept. Recoverable are: a failed live preparation check (network, clock, or package keyring), a
discovery result whose only reasons are `network_no_default_route`, `network_dns_failed`, or
`network_https_failed`, and an invalid choice combination at generation. Every other failure stops: an
unexpected failure retains its diagnostics in `install.log`, and any child status is kept in
`child_exit_status`. A failure during the engine stops the run, keeps its diagnostics under `engine/`, and is
never retried inside the run; retrying means a new run with a new plan and a new confirmation. A change of the machine (including its detected memory), the profile binding, the disk, the layout, eligibility,
policy, the configuration assets, or the plan invalidates approval (see [Reasons](#reasons)); it is never confused with cancellation, which exits
`3`.

## Safety projection

The comparison runs before the review of an existing plan (`--plan`) and again in the final revalidation, over
fresh facts and this projection:

| Field | Source |
| --- | --- |
| Machine | `target.machine` of the plan against the observed `architecture`, `memory_total_bytes`, `virtualization`, and DMI `sys_vendor` and `product_name`, compared by value and by availability. Detected memory that differs or is unavailable invalidates approval, including when hibernation is disabled. |
| Profile binding | `target.profile` against the facts' `profile`, and `profile_definition_sha256` recomputed from the matched profile's `target.json`. An unqualified machine must still be unqualified. |
| `firmware.boot_mode` | `choices.firmware_mode` of the plan against the facts `firmware`. |
| `firmware.secure_boot` | Not recorded in the plan: the Secure Boot state of the fresh facts is compared with the state in `discovery/initial/`. |
| Disk identity | `path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes` of the selected disk. |
| `eligible` | Must remain `true`. |
| `current_layout` | `partition_table` and, for each partition, `uuid`, `partuuid`, size, `fstype`, `label`, and `mountpoints`. |
| `policy_binding` | `policy_sha256` and `override_sha256`, recomputed from `install/plan/policy.json` and the matched profile's override. |
| Configuration assets | The `destination` and `source_sha256` of `configure_zram` and `configure_memory_reclaim` against the SHA-256 recomputed from the current allowlisted source assets under `install/plan/assets/`. A changed, missing, or damaged asset invalidates approval. |

No fabricated target id takes part. `facts_binding.facts_sha256` is not compared: facts include `source.run_id`, so
every rediscovery hashes differently. Network readiness is not part of the projection.

The engine repeats the disk identity, `current_layout`, and `eligible` rows immediately before its first
destructive operation, reusing the same comparison
([`installation-engine.md`](installation-engine.md#pre-check-order)).

## Reasons

Every reason uses the architecture's structured error shape: `code`, `stage` (`install`), `operation` (the flow
step that failed), `message`, `next_step`, and `child_exit_status` (only when a child process exists).

Invalidation reasons carry the `next_step` "Regenerate and review the installation plan."

| Code | Condition |
| --- | --- |
| `machine_identity_changed` | The machine projection, including detected memory, differs from the plan, including a field that appeared or disappeared. |
| `profile_binding_changed` | The profile classification, or the matched profile's definition hash, differs from the plan. |
| `target_identity_changed` | The firmware mode, the Secure Boot state, or the disk identity differs from the plan, including in the engine's final block. |
| `target_layout_changed` | The disk is no longer eligible, or its `current_layout` differs from the plan, including in the engine's final block. |
| `policy_changed` | The recomputed policy or override hash differs from `policy_binding`. |
| `configuration_assets_changed` | A configuration asset's hash or destination differs from the reviewed plan, or an asset is missing or damaged. |
| `digest_mismatch` | The plan file fails its digest, before review or in the re-check after confirmation. |
| Validator codes | A plan given with `--plan` fails `validate-plan.mjs`; its code passes through (see [`installation-plan.md`](installation-plan.md#validation)). A plan of an earlier format is `plan_format_unsupported`, with the instruction to regenerate it. |
| Discovery codes | Fresh facts are invalid or discovery fails; the code passes through (see [`target-facts.md`](target-facts.md#validation)), for example `profile_ambiguous`. |

Other reasons:

| Code | Condition |
| --- | --- |
| `confirmation_mismatch` | The typed device name differs from the expected kernel name. There is no second attempt. |
| `install_already_running` | Another run holds the installer lock. Reported on stderr only; no run directory or records. |
| `engine_version_mismatch` | The plan was generated by a different code identity (commit or dirty state) than the running artifact. The `next_step` asks to generate a new plan with this artifact. The run is `blocked` before review, so no confirmation or password is requested. |
| Engine codes | The engine's reasons pass through unchanged (see [`installation-engine.md`](installation-engine.md#reasons)): `target_disk_in_use`, `password_unavailable`, `engine_asset_mismatch`, `engine_interrupted`, and `stage_failed` with the failing operation. |
| `gum_not_qualified` | Gum is missing or its major version is not `2`. |
| `device_name_unavailable` | The selected disk has no kernel `path`, so the device name to type cannot be derived. The run is `blocked` before confirmation. |
| `live_network_not_ready` | Route, name resolution, or the validated HTTPS check failed during live preparation. Recoverable. |
| `live_clock_not_ready` | Time synchronization was not reported within the bounded wait. Recoverable. Distinct from `live_network_not_ready`. |
| `live_keyring_not_ready` | `pacman-init.service` did not finish successfully within the bounded wait of live preparation, or failed. Recoverable. Also used by the engine's non-waiting check, where it is `blocked`. |
| `stage_failed` | A phase failed unexpectedly; `operation` names the phase and `child_exit_status` keeps the original status. |

## Outcomes and exits

`outcome` and `exit_status` together distinguish every path.

| Exit | Outcome | Condition |
| --- | --- | --- |
| `0` | `installed` | The user confirmed, entered the password, the final revalidation passed, and the engine completed every operation of the plan (see [`installation-engine.md`](installation-engine.md#exit-statuses)). |
| `3` | `cancelled` | The user chose Cancel, answered No, pressed Esc at an authorization prompt, pressed Ctrl+C during the interactive phase, cancelled a failed preparation, or typed a device name that does not match (reason `confirmation_mismatch`). |
| `2` | `invalidated` | A machine, profile, disk, layout, eligibility, policy, configuration asset, or plan change was detected before review, after confirmation, or in the engine's final block before the first destructive operation. The reason is one of the invalidation codes above. |
| `2` | `blocked` | The run cannot reach review for an input reason: invalid facts, an explicit-assertion rejection, an ambiguous profile match, no eligible disk, missing detected memory (`memory_unavailable`, repeat discovery), an unrecoverable discovery result, a plan of a different code identity (`engine_version_mismatch`), or an engine pre-check that stops before any destructive operation (`live_keyring_not_ready`, `password_unavailable`, `target_disk_in_use`). |
| `5` | `failed` | An external tool failed unexpectedly, including an engine operation; the disk may be partially modified. |
| `6` | `failed` | Damaged checkout or embedded code, a damaged configuration asset or prebuilt package, or Gum that is missing or not qualified. |
| `128+n` | `failed` | A signal arrived during the engine; reason `engine_interrupted`, after the engine's cleanup. |
| `128+n` | none | Termination by a signal outside the interactive phase and the engine phase, and every signal other than SIGINT. |

Exit `0` is used only for `installed`. Arguments or terminal errors, and a concurrent run
(`install_already_running`), stop the run before it starts: they exit `2` and
report on stderr only: no run directory and no records are written. No persisted record can authorize another
run.

### Ctrl+C and Esc

SIGINT, or Gum status `130`, during the interactive phase (every screen, the pager, both authorization
prompts, and both password fields) maps to exit `3` with outcome `cancelled`. The mapping lives in the orchestrator; the
`confirm_status_map` wrapper still returns `130` unmapped, as
[ADR 0004](../docs/adr/0004-interactive-presentation-with-gum.md) states. The SIGINT trap covers only the
interactive phase: SIGINT during read-only revalidation or rediscovery keeps `130`, and SIGTERM and SIGHUP keep
`128+n`. During the engine phase the assistant forwards SIGINT, SIGTERM, and SIGHUP to the engine's process
group, waits for its cleanup, and ends `failed` with `engine_interrupted` and `128+n`.

Esc differs by prompt. In configuration steps and the review it goes back without applying an incomplete
answer; leaving the pager returns to the review. In either password field it returns to the review, discards any
entered value, and clears the approval. At the authorization prompts (the final
No and the device-name input) Esc cancels, as do a No answer and a name mismatch.

## Password hand-over

The assistant owns the whole interaction. In order:

1. The user reviews the plan and completes the bound confirmation.
2. The assistant requests the single `account_password` twice with `gum input --password` (`Password>` and
   `Confirm>`). The screen keeps the context of D10 and D12: one password for the user, and root either locked
   or sharing the same password, as the plan says. The only rules are a non-empty value and a matching pair; a
   blank or mismatched pair shows its message (D11) and asks both fields again, with no attempt limit and no
   strength policy. Esc in either field returns to the review, discards the value, and clears the approval.
   Ctrl+C in either field cancels with exit `3` and outcome `cancelled`, and the engine is never started.
3. The assistant revalidates the disk and the plan after the password was entered, so time spent answering
   cannot leave approval stale. A failed revalidation is `invalidated` and discards the password.
4. The assistant invokes `install/engine/apply` once (see below). The engine consumes the password; it provides
   no prompt and never returns control to ask for one.

The protected channel is a dedicated file descriptor. The value lives in a local, non-exported Bash variable of
the assistant and is written with the `printf` builtin through process substitution to fd 3 of the engine. It
never appears in a process argument or an environment variable and never reaches disk. The assistant discards its
own copy once the engine has started. The engine reads it exactly once at startup, before any destructive
operation, and gives it only to `chpasswd` on stdin inside the target ([`installation-engine.md`](installation-engine.md#password)).
It never enters a plan, a log, a record, evidence, or terminal output. The `password` stage is recorded in
`install-run.json` and `install.log` without the length or any other value-derived data.

### Engine invocation

```text
install/engine/apply --plan <run>/plans/NN/installation-plan.json --digest <confirmed digest> --output <run>/engine/
```

The `plans/NN/` directory and the digest are those of the confirmed plan. The password is on fd 3 and the
installer lock on fd 4. The engine runs with standard input `/dev/null` in its own process group. While it runs,
the assistant is the only owner of the console: it polls `engine/state.json` about every 0.5 seconds for the
progress screen (D17) and does not read the engine's output. When the engine ends, the assistant validates
`engine/engine-run.json` and maps the engine's exit status to the outcome of [Outcomes and exits](#outcomes-and-exits).
If the record is missing or invalid, the run is `failed` with exit `5`, reason `stage_failed`, operation `engine`,
and the engine's status in `child_exit_status`.

After the engine ends, the success screen (D18) or failure screen (D19) offers its menu. Restarting or powering
off the machine happens only when the user chooses it, never automatically. Choosing the shell ends the assistant
with the exit status of the run.

## Run directory

Each run writes to `evidence/install/<run-id>/`, or to `--output`, with `0700` directories and `0600` files:

| Path | Content |
| --- | --- |
| `install-run.json` | The run record. |
| `approval-record.json` | The non-authorizing evidence record. |
| `discovery/initial/` | Facts from the automatic discovery, or the pre-review check with `--plan`. |
| `discovery/final/` | The final rediscovery. Present only when that step was reached. |
| `plans/01/`, `plans/02/`, … | One directory per generated or regenerated plan: `installation-plan.json`, `installation-plan.txt`, `plan-run.json`, and `choices.json`. |
| `install.log` | Plain text, no ANSI sequences, no secret. Records each phase and its result, including the start-of-run cleanup. |
| `engine/` | Present only when the engine was started: `engine.log`, `state.json`, `engine-run.json`, and `target-packages.txt`, as defined in [`installation-engine.md`](installation-engine.md#evidence-and-state). |

`install-run.json` and `approval-record.json` are always written once the run has started, including on
cancellation, invalidation, and Gum failure. Each is written to a temporary file in the same directory, re-read,
validated, and renamed. `choices.json` follows the choices file format of the plan contract and never holds a
secret. Historical evidence from earlier versions is not renamed or transformed.

### `install-run.json`

| Field | Description |
| --- | --- |
| `format_version` | Always `4`. |
| `run_id` | Run identifier. |
| `timestamp` | RFC 3339 start time. |
| `entry` | `guided` or `plan_file`. |
| `machine` | The observed machine projection as in the plan's `target.machine`, including `memory_total_bytes`; omitted when discovery was not reached. |
| `profile` | `status` and, only for a match, `profile_id`; omitted when discovery was not reached. |
| `gum_version` | Output of `gum --version`; omitted when Gum was not found. |
| `stages` | The stages reached, in order, from `preparation`, `discovery_initial`, `plan`, `review`, `confirmation`, `password`, `discovery_final`, and `engine`. |
| `digests` | Plan digests in order of generation, one per `plans/NN/`. |
| `final_digest` | The digest of the plan shown last; omitted when no plan exists. |
| `exit_status` | The exit status of the run. |
| `outcome` | `installed`, `cancelled`, `invalidated`, `blocked`, or `failed`. |
| `reasons` | List of structured reasons; may be empty. |

### `approval-record.json`

A non-authorizing record: no stage reads it as permission, and a later run never accepts it in place of a fresh
confirmation.

| Field | Description |
| --- | --- |
| `format_version` | Always `4`. |
| `run_id` | Run identifier, the same as in `install-run.json`. |
| `timestamp` | RFC 3339 time the record was written. |
| `digest` | The final plan digest; omitted when no plan exists. |
| `machine` | As in `install-run.json`; omitted when none was reached. |
| `profile` | As in `install-run.json`; omitted when none was reached. |
| `disk` | Identity of the selected disk: `path`, `by_id`, `wwn`, `serial`, `model`, and `size_bytes`, as available. |
| `gum_version` | As in `install-run.json`. |
| `outcome` | As in `install-run.json`. |
| `reason` | The primary reason's `code`; omitted when none applies. |

Neither document contains a secret value, a hash of one, a Wi-Fi credential, or a secret-like key; the validator
rejects them. Recognition in `profile` is not a qualification claim.

## Differences from the reference

The reference is the frozen copy at
[`prototypes/frontend/guided-installer/`](../prototypes/frontend/guided-installer/README.md): its logo, Tokyo
Night palette, layout, centering, widgets, navigation, and screen order are reproduced. Only the differences
below are intended. Any other visual, wording, workflow, or widget difference needs the maintainer's approval
first. The wording shown is the proposed production text; every item awaits approval at plan 02-07, Task 4, except D15, which was approved at plan 02-08, Task 1, with the acceptance of [ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md). The rewording of D7 and D10 to D14 and the new items D16 to D19 are proposed by plan 02-09 and await approval at its Task 2; their fidelity is confirmed at its attended review.

| # | Reference | Production | Why |
| --- | --- | --- | --- |
| D1 | "Choose installation target" screen: manual selection of a machine profile. | Removed. Replaced at the same position by a "Machine check" screen showing the recognized or unqualified result with Continue and Cancel (see [Machine check](#machine-check)). | DEC-003, DEC-021: profiles are identified internally. |
| D2 | Synthetic discovery facts; the disk screen says "Example discovery facts, not the current disk state." | Current validated discovery. The line becomes "Disks detected on this machine just now." The other disk lines, the label format, and the single-disk behavior are unchanged. | Replace synthetic facts with real ones. |
| D3 | Live connectivity: one route and HTTPS probe, then "Preparing installation" / "Checking internet connection...". | The coordinated check of [Flow](#flow) step 3. When it passes there is no screen. Adds the gray line "Checking system clock..." during the check. | DEC-010: bounded clock readiness inside preparation. |
| D4 | None. | A clock failure screen titled "Waiting for the system clock": "Accurate time is needed to verify secure connections and package signatures." and "Automatic time synchronization is enabled. Make sure the network works, then retry." with Retry clock check and Cancel. | DEC-010: help, retry, or cancellation. |
| D5 | None. | A failure screen for a failed phase: red lines "Phase: …", "Cause: …", "Next: …", then Retry, Back, or Cancel for a recoverable failure only. | DEC-015. |
| D6 | Review row "Target: <profile>". | Row "Machine": "Recognized (<profile id>)" or "Unqualified (experimental)". A row "Plan" shows the plan reference. Other rows, including "Locales" and "Internet", are unchanged. | DEC-003, DEC-011, DEC-013. |
| D7 | Review footer: "Review only: this does not approve a plan or authorize disk changes." / "Next: simulated confirmation, then password explanation; no installation runs." / "A real flow needs bound plan/disk confirmation, then passwords, before execution." | The first line is kept. The others become "Next: confirm the disk to erase, then set the password. Installation starts after that." The third line is removed. | Remove simulation claims. |
| D8 | Review menu: "Continue to confirmation preview" / "Back". | "Continue to confirmation" / "Inspect complete plan" / "Back". "Inspect complete plan" opens `gum pager`. | DEC-011, DEC-012. |
| D9 | Title "Confirmation preview - simulation only"; "SIMULATION ONLY …" warning; menu "Simulate confirmation" / "Back" / "Cancel preview" selecting Back. | Title "Confirm installation". Shows the disk label, path, "Disk ID", and the layout, "Plan reference: <ref>", and the red line "This will erase all existing content on this disk." An unqualified machine adds the yellow line "Experimental: this machine matches no known profile." Then `gum confirm` ("Erase <path> and apply plan <ref>?", "Yes, erase" / "No", No focused), then `gum input` with the header "Type the device name (<name>) to confirm." and the prompt "Device name> ". There is no Back at this prompt. | DEC-013: real authorization. |
| D10 | Title "Password requirements - preview only"; "PREVIEW ONLY - do not enter a real password here." | Title "Password". The preview-only first line is removed. The line "A real flow asks for one password for $username, with repetition." becomes "One password is used for $username." The sudo and root lines are unchanged. | DEC-004, DEC-018. |
| D11 | Password screen header "No password collection in this prototype"; menu "Finish preview" / "Back". | Two inputs, "Password> " and "Confirm> " (`gum input --password`), and no menu. A blank value shows "Password can't be blank" and a mismatch shows "Passwords didn't match"; both fields are asked again, with no attempt limit and no strength policy. Esc returns to the review and clears the approval; Ctrl+C cancels. | Truthful wording. |
| D12 | Root screen: "The intended flow asks for one password, with repetition, after plan approval." / "This preview does not collect passwords or change accounts." | "One password is asked, with repetition, after you approve the plan." The preview-only closing line is removed. When password login is enabled, a gray line is added: "Sharing the password does not give root an independent recovery credential." | DEC-004, DEC-005. |
| D13 | Ending: "Presentation demo finished. No installation or disk operation executed." / "Synthetic example facts were used. No credentials or evidence were saved." | Replaced by the engine-phase screens D17 to D19. The run directory is named on the failure screen, and no approval is saved or can authorize a later run. | Truthful engine-unavailable ending. |
| D14 | Screen titles list includes "Choose installation target", "Confirmation preview - simulation only", and "Password requirements - preview only". | "Choose installation target" is replaced by "Machine check" (D1); the other two are replaced as in D9 and D10; a titled screen is added for the clock failure (D4). The remaining titles are unchanged, except the title of the stage changed by D15. Titled screens are added for the keyring wait (D16), the progress (D17), the success (D18), and the failure (D19). | Consequence of D1, D4, D9, D10, D15. |
| D15 | "Choose swapfile size" screen at the position after storage layout: gray lines "The swapfile is used for swap and hibernation." / "The default does not guarantee hibernation for every workload.", the range line, and the "Swapfile size (MiB)> " input. Review row "Swapfile": "<n> MiB". | The stage is titled "Choose hibernation" and is shown at the same position. A `gum choose` with the header "Hibernation" offers "Enabled" and "Disabled", with the current choice selected (Enabled initially) and the gray lines "Hibernation lets the machine power off and resume where it left off." / "Enabled keeps a swapfile on disk; it also serves as fallback swap when zram is full." Only when Enabled, the sizing screen titled "Choose swapfile size" follows, in the reference's style, with the gray lines "The swapfile holds the hibernation image and also serves as fallback swap after zram." / "The default does not guarantee hibernation for every workload.", the range line stating the RAM-derived minimum and maximum, and the unchanged input; it shows no warning. Back from the sizing returns to the hibernation choice. Disabling removes the explicit size and re-enabling proposes the RAM-derived default again. The review row "Swapfile" becomes "Hibernation": "Enabled (swapfile <n> MiB)", or "Disabled (no swapfile)" with the gray line "Hibernation is disabled: no swapfile will be created."; when the size is below detected memory, the persistent yellow line "Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space." appears under the rows. No additional confirmation dialog, and no claim that the default guarantees a successful resume. | DEC-013, DEC-014, DEC-028; [ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md): hibernation is optional and the swapfile size is RAM-derived. |
| D16 | None. | Drawn only while the package keyring is not ready. While waiting: a screen titled "Preparing the package keyring" with the gray line "Waiting for the package keyring to be initialized...". When the bound of 600 seconds expires or the service fails: a screen titled "Package keyring not ready" with "Package signatures cannot be verified until the keyring is ready." and "Wait a moment, then retry.", with Retry keyring check and Cancel. No screen is drawn when the keyring is already ready. | DEC-012, DEC-020: visible wait during live preparation, before any confirmation or password. |
| D17 | None. | Engine progress screen: the logo, the title "Installing MirrorOS", a 34-column progress bar, and the dimmed line "[<n>/<N>] <description>" with the current operation's plan description. The bar is the completed operations over the total, with no time-based curve and no tips. During package installation a second dimmed line shows "Packages installed: <count>"; the count never moves the bar. | DEC-008: progress must be backed by completed work. |
| D18 | None. | Success screen: the logo, "Installed MirrorOS in <duration>", the dimmed line "Base system installed. Installation postconditions are not verified in this version (Story 2.6).", and a menu "Restart now" / "Return to shell". There is no animated effect. The machine restarts only when "Restart now" is chosen. | DEC-007, DEC-008. |
| D19 | None. | Failure screen for an engine failure or interruption: the logo, the red title "MirrorOS installation stopped", "Failed operation: <id>", "Exit status: <status>", the red line "The disk was partially modified and installation did not complete." (or "The disk was not modified." when no destructive operation had started), the last 15 lines of `engine.log`, "Run directory: <path>", and a menu "View full log" (`gum pager`) / "Return to shell" / "Restart" / "Power off". It offers no log upload, no media diagnosis, and no automatic action. A stop before the first destructive operation (`blocked` or `invalidated`) uses the D5 screen instead. | DEC-006, DEC-008. |

Unchanged and not differences: the logo and its two-tone drawing, the palette and the VT-only palette setting, the
centering, the Gum widget styles, the welcome text and the live-keyboard screen (including "This layout is for the
live installation, not the installed system."), the Wi-Fi instruction text and its pager, the timezone,
installed-keyboard, hostname, username, root-policy, storage, and language and formats screens and
options, Back and Esc navigation in configuration steps, the cancellation message, and the console font (the
kernel default; the reference documents none).

Complete simultaneous fit within 80x25 is not required, and no colorless variant or dedicated pager feature test
is part of this contract.

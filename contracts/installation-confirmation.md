# Installation confirmation (`mirroros-install`)

`format_version: 7`. Produced by `mirroros-install` (`operations/install`) without a subcommand, which runs the
guided live installer: one interactive Gum flow that prepares the live environment, discovers the machine
automatically, collects the installation choices, generates and reviews an
[installation plan](installation-plan.md), and requires a machine-, disk-, and digest-bound confirmation.
Confirmation is ephemeral and single-use: it exists only inside one process. No persisted file authorizes
anything. The two JSON documents below are evidence records. Unknown fields are rejected by
`install/confirmation/validate-records.mjs`, and records of `format_version` `1` (`apply-run.json`,
`apply.log`), `2`, `3`, `4`, and `5` (earlier `install-run.json` and `approval-record.json`) are historical evidence
that is neither read nor transformed. Version `4` added the `password` and `engine` stages and the outcome
`installed`, and removed `approved` as a terminal outcome and the reason `engine_not_available`; it kept
`machine.memory_total_bytes` and the choices of [installation plan](installation-plan.md) version 3, per
[ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md). Version `5` accepts the outcome `not_verified`
(exit `4`) of the engine's [postconditions](installation-postconditions.md) and follows plan format 4, whose
hardware rule outcomes the review shows. Version `6` adds `not_configured` (exit `4`) for the engine's final
configure phase and follows engine run/state format `3`. Version `7` adds guided timing and follows engine run
format `4` (state remains `3`). Readers also accept pre-timing version `6`, unchanged: they do not add historical
measurements. Earlier versions retain their unsupported historical status.

In this version a valid approval is followed by the protected password entry, a final revalidation, and one
invocation of the installation engine (`install/engine/apply`, defined in
[`installation-engine.md`](installation-engine.md)), which installs the base system and configures the graphical
environment. Exit `0` and the outcome `installed` mean that every approved plan operation completed, every
read-only base [postcondition](installation-postconditions.md) passed, and configure returned `0` before the
first restart. Failed base postconditions produce `not_verified`/`4` without running configure. A configure
failure produces `not_configured`/`4`; neither outcome is reported as successful. The engine is reachable only through this flow
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
   going back. The review shows the outcome of every hardware rule (D21) and, under the rows, every warning of
   the plan, including the hardware warnings for an NVIDIA or unrecognized graphics device and for an
   unrecognized CPU vendor. None of them blocks continuing. The review shows the hibernation state: enabled with the swapfile size and, when the size is below
   detected memory, the persistent warning; or disabled, stating that no swapfile will be created. No additional
   confirmation dialog is added.
   - At every review redraw, the assistant measures terminal rows and columns and the fully rendered
     review, including wrapped rows, explanations, and warnings. It reserves the two-line top margin,
     title, native menu/help, and a cursor line. If the separate rows fit, they remain unchanged. Otherwise,
     Hostname/Username/Root and Timezone/Language/Locales may each share one line, independently and only
     when that entire group fits the form width. If the grouped review still exceeds the height, `gum pager`
     shows the complete review before navigation. The menu then also offers **Inspect review** to reopen it.
     This is presentation only: no content is dropped and neither pager grants authorization.
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
10. **Engine.** The live mirrorlist first receives the regional selection of
    [ADR 0013](../docs/adr/0013-regional-live-mirror-selection.md) from the plan's time zone, logged in
    `install.log`; it is recorded, not confirmed, and any doubt leaves it unchanged without stopping the run.
    Then one invocation of the engine, with the progress screen (D17) while it runs and then the success
    (D18), failure (D19), `not_verified` (D20), or `not_configured` (D22) screen.

Leaving any screen after confirmation to go back, including Esc at the first password field, clears the approval;
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
| Engine codes | The engine's reasons pass through unchanged (see [`installation-engine.md`](installation-engine.md#reasons)): `target_disk_in_use`, `password_unavailable`, `engine_asset_mismatch`, `engine_interrupted`, `postcondition_failed` (one per failed check), and `stage_failed` with the failing operation. |
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
| `0` | `installed` | The user confirmed, entered the password, the final revalidation passed, every plan operation and base postcondition passed, and configure returned `0` (see [`installation-engine.md`](installation-engine.md#exit-statuses)). |
| `4` | `not_verified` | The engine completed every operation but at least one postcondition failed (reason `postcondition_failed`, one per failed check). The disk is written and unmounted and the records are retained; the installation is not reported as successful. |
| `4` | `not_configured` | Base installation and verification passed but configure returned `2`–`6`, including interruption. Normal cleanup unmounts the target; recovery is `sudo mirroros-configure` on the installed system, never a live retry. |
| `3` | `cancelled` | The user chose Cancel, answered No, pressed Esc at an authorization prompt, pressed Ctrl+C during the interactive phase, cancelled a failed preparation, or typed a device name that does not match (reason `confirmation_mismatch`). |
| `2` | `invalidated` | A machine, profile, disk, layout, eligibility, policy, configuration asset, or plan change was detected before review, after confirmation, or in the engine's final block before the first destructive operation. The reason is one of the invalidation codes above. |
| `2` | `blocked` | The run cannot reach review for an input reason: invalid facts, an explicit-assertion rejection, an ambiguous profile match, no eligible disk, missing detected memory (`memory_unavailable`, repeat discovery), an unrecoverable discovery result, a plan of a different code identity (`engine_version_mismatch`), or an engine pre-check that stops before any destructive operation (`live_keyring_not_ready`, `password_unavailable`, `target_disk_in_use`). |
| `5` | `failed` | An external tool failed unexpectedly, including an engine operation or a postconditions checker that returned no valid result; the disk may be partially modified. |
| `6` | `failed` | Damaged checkout or embedded code, a damaged configuration asset or prebuilt package, or Gum that is missing or not qualified. |
| `128+n` | `failed` | A signal arrived during the engine outside configure; reason `engine_interrupted`, after cleanup. |
| `128+n` | none | Termination by a signal outside the interactive phase and the engine phase, and every signal other than SIGINT. |

Exit `0` is used only for `installed`, and exit `4` only for `not_verified` or `not_configured`. Arguments or terminal errors, and a concurrent run
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
group and waits for cleanup. Outside configure it ends `failed` with `engine_interrupted` and `128+n`;
during configure it preserves `not_configured`/`4` with the configure outcome in the engine record.

Esc differs by prompt. In configuration steps and the review it goes back without applying an incomplete
answer; leaving the pager returns to the review. In the first password field it returns to the review, discards any
entered value, and clears the approval. In the repetition field it discards both values and restarts at the first
password field within the same stage, retaining the bound approval; final revalidation remains mandatory. At the authorization prompts (the final
No and the device-name input) Esc cancels, as do a No answer and a name mismatch.

## Password hand-over

The assistant owns the whole interaction. In order:

1. The user reviews the plan and completes the bound confirmation.
2. The assistant requests the single `account_password` twice with `gum input --password` (`Password>` and
   `Confirm>`). The screen keeps the context of D10 and D12: one password for the user, and root either locked
   or sharing the same password, as the plan says. The only rules are a non-empty value and a matching pair; a
   blank or mismatched pair shows its message (D11) and asks both fields again, with no attempt limit and no
   strength policy. Esc in `Confirm>` discards both values and restarts at `Password>` without leaving the stage
   or clearing the bound approval. Esc in `Password>` returns to the review and clears the approval.
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

After the engine ends, D18, D19, D20, or D22 offers its corresponding menu. Restarting or powering
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
| `format_version` | New writers emit `7`; readers also accept `6`. |
| `run_id` | Run identifier. |
| `timestamp` | RFC 3339 start time. |
| `entry` | `guided` or `plan_file`. |
| `machine` | The observed machine projection as in the plan's `target.machine`, including `memory_total_bytes`; omitted when discovery was not reached. |
| `profile` | `status` and, only for a match, `profile_id`; omitted when discovery was not reached. |
| `gum_version` | Output of `gum --version`; omitted when Gum was not found. |
| `stages` | The stages reached, once each in canonical flow order, from `preparation`, `discovery_initial`, `plan`, `review`, `confirmation`, `password`, `discovery_final`, and `engine`. Actual timing visit order is independent, including early validation with `--plan`. |
| `timing` | Version `7` only: `total` measurement and `intervals` list, described below. Required for new run records; absent in legacy version `6`. |
| `digests` | Plan digests in order of generation, one per `plans/NN/`. |
| `final_digest` | The digest of the plan shown last; omitted when no plan exists. |
| `exit_status` | The exit status of the run. |
| `outcome` | `installed`, `not_verified`, `not_configured`, `cancelled`, `invalidated`, `blocked`, or `failed`. |
| `reasons` | List of structured reasons; may be empty. |

### Guided timing

`timing.total` is a measurement object: either `{"status":"available","duration_ms":120}` or
`{"status":"unavailable","reason":"clock_unreadable"}`. Available values are non-negative safe integers in
milliseconds, multiples of 10. Unavailable measurements omit `duration_ms` (never `null` or a placeholder zero).
The fixed safe reasons are `clock_unreadable`, `clock_malformed`, `clock_regressed`, and `duration_overflow`.
`not_sampled` is reserved for record-builder callers that supplied no samples; it is not a clock fallback.
Readers reject incompatible combinations and unknown timing fields.

`timing.intervals` contains one entry per reached stage: `id`, `classification`, and `measurement` with the
same shape as `total`. Classification is `interactive` for `review`, `confirmation`, and `password`; `mixed`
for `preparation`; and `automated` for `discovery_initial`, `plan`, `discovery_final`, and `engine`. No entry or
duration is created for unstarted work. Interactive measurements include reading and answering; classification
describes an interval, not exact human-time subtraction from mixed work or the total.

The shared Bash helper `operations/lib/timing.sh` reads the first `/proc/uptime` value without an external
process per sample or any wall-clock fallback. Effective resolution is 10 ms, not 1 ms. UTC timestamps remain
chronological metadata. Unreadable, malformed, or regressing readings make affected measurements unavailable;
clock input is never copied into reasons. A failed visit invalidates the accumulated measurement even if later
visits can be sampled.

The total begins at `flow_main` entry, before run initialization, and ends at outcome finalization, sampled
before the final record write. It excludes live boot, record serialization, and the final outcome menu.
Welcome, configuration screens, start-of-run cleanup, and orchestration overhead remain in the total; they are
not inferred as named-stage time. Each actual preparation, review, confirmation, or password visit is timed
and accumulated, including Back and handled cancellation. Discovery retries measure actual child intervals,
not the intervening recovery menu. Plan timing includes existing-plan validation and each real generation;
plan-failure recovery prompts remain outside that automated interval. Final discovery includes safety and
digest revalidation. The guided engine interval includes engine-result processing; the engine owns its own
nested timings. The existing success-duration line remains unchanged; no timing table or live step times are
added. Timings survive handled terminal paths only where existing evidence can be written: hard kills and
unwritable output gain no persistence guarantee. Timing availability never changes lifecycle outcomes.

### `approval-record.json`

A non-authorizing record: no stage reads it as permission, and a later run never accepts it in place of a fresh
confirmation.

| Field | Description |
| --- | --- |
| `format_version` | New writers emit `7`; readers also accept `6`. |
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
[`prototypes/frontend/guided-installer/`](../prototypes/frontend/guided-installer/README.md). Its screen order,
navigation, and content remain the reference, with the visual baseline and welcome explicitly replaced
under [ADR 0018](../docs/adr/0018-native-live-display-and-installer-presentation.md). Only the differences
below and the ADR 0018 presentation amendment are intended. Any other visual, wording, workflow, or widget difference needs the maintainer's approval
first. The wording shown is the proposed production text; every item awaits approval at plan 02-07, Task 4, except D15, which was approved at plan 02-08, Task 1, with the acceptance of [ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md). The rewording of D7 and D10 to D14 and the new items D16 to D19 are proposed by plan 02-09 and await approval at its Task 2; their fidelity is confirmed at its attended review. The rewording of D18 and D19 and the new items D20 and D21 are proposed by plan 02-11 and await approval at its Task 2; their fidelity is confirmed at its attended review. Plan 02-16 updates D17/D18, extends D19 wrapping, and adds D22/D23 for installer-integrated configure; its graphical and console observations remain subject to the blocking human checkpoint.

| # | Reference | Production | Why |
| --- | --- | --- | --- |
| D1 | "Choose installation target" screen: manual selection of a machine profile. | Removed. Replaced at the same position by a "Machine check" screen showing the recognized or unqualified result with Continue and Cancel (see [Machine check](#machine-check)). | DEC-003, DEC-021: profiles are identified internally. |
| D2 | Synthetic discovery facts; the disk screen says "Example discovery facts, not the current disk state." | Current validated discovery. The line becomes "Disks detected on this machine just now." The other disk lines, the label format, and the single-disk behavior are unchanged. | Replace synthetic facts with real ones. |
| D3 | Live connectivity: one route and HTTPS probe, then "Preparing installation" / "Checking internet connection...". | The coordinated check of [Flow](#flow) step 3. When it passes there is no screen. Adds the gray line "Checking system clock..." during the check. | DEC-010: bounded clock readiness inside preparation. |
| D4 | None. | A clock failure screen titled "Waiting for the system clock": "Accurate time is needed to verify secure connections and package signatures." and "Automatic time synchronization is enabled. Make sure the network works, then retry." with Retry clock check and Cancel. | DEC-010: help, retry, or cancellation. |
| D5 | None. | A failure screen for a failed phase: two top blank lines, the symbol only when the complete inline diagnostic or post-inspection summary and its controls fit (and never below 32 rows), separate red blocks "Phase: …", "Cause: …", "Next: …", wrapped within the 80-column form or available narrower width. A recoverable discovery failure retains Retry / Back / Cancel with Retry selected; a rejected plan combination retains Back / Cancel with Back selected. Selectors use the shared accent-only style and native help; terminal failures gain no retry or menu. | DEC-015. |
| D6 | Review row "Target: <profile>". | Row "Machine": "Recognized (<profile id>)" or "Unqualified (experimental)". A row "Plan" shows the plan reference. Other rows, including "Locales" and "Internet", are unchanged. | DEC-003, DEC-011, DEC-013. |
| D7 | Review footer: "Review only: this does not approve a plan or authorize disk changes." / "Next: simulated confirmation, then password explanation; no installation runs." / "A real flow needs bound plan/disk confirmation, then passwords, before execution." | The first line is kept. The others become "Next: confirm the disk to erase, then set the password. Installation starts after that." The third line is removed. | Remove simulation claims. |
| D8 | Review menu: "Continue to confirmation preview" / "Back". | "Continue to confirmation" / "Inspect complete plan" / "Back". "Inspect complete plan" opens `gum pager`. | DEC-011, DEC-012. |
| D9 | Title "Confirmation preview - simulation only"; "SIMULATION ONLY …" warning; menu "Simulate confirmation" / "Back" / "Cancel preview" selecting Back. | Title "Confirm installation". Shows the disk label, path, "Disk ID", and the layout, "Plan reference: <ref>", and the red line "This will erase all existing content on this disk." An unqualified machine adds the yellow line "Experimental: this machine matches no known profile." Then `gum confirm` ("Erase <path> and apply plan <ref>?", "Yes, erase" / "No", No focused), then `gum input` with the header "Type the device name (<name>) to confirm." and the prompt "Device name> ". There is no Back at this prompt. | DEC-013: real authorization. |
| D10 | Title "Password requirements - preview only"; "PREVIEW ONLY - do not enter a real password here." | Title "Password". The preview-only first line is removed. The line "A real flow asks for one password for $username, with repetition." becomes "One password is used for $username." The sudo and root lines are unchanged. | DEC-004, DEC-018. |
| D11 | Password screen header "No password collection in this prototype"; menu "Finish preview" / "Back". | Two inputs, "Password> " and "Confirm> " (`gum input --password`), and no menu. A blank value shows "Password can't be blank" and a mismatch shows "Passwords didn't match"; both fields are asked again, with no attempt limit and no strength policy. Esc in Confirm discards both values and restarts Password within the stage; Esc in Password returns to the review and clears the approval; Ctrl+C cancels. | Truthful wording; repetition-field Back navigation explicitly approved during password review. |
| D12 | Root screen: "The intended flow asks for one password, with repetition, after plan approval." / "This preview does not collect passwords or change accounts." | "One password is asked, with repetition, after you approve the plan." The preview-only closing line is removed. When password login is enabled, a gray line is added: "Sharing the password does not give root an independent recovery credential." | DEC-004, DEC-005. |
| D13 | Ending: "Presentation demo finished. No installation or disk operation executed." / "Synthetic example facts were used. No credentials or evidence were saved." | Replaced by the engine-phase screens D17 to D19. The run directory is named on the failure screen, and no approval is saved or can authorize a later run. | Truthful engine-unavailable ending. |
| D14 | Screen titles list includes "Choose installation target", "Confirmation preview - simulation only", and "Password requirements - preview only". | "Choose installation target" is replaced by "Machine check" (D1); the other two are replaced as in D9 and D10; a titled screen is added for the clock failure (D4). The remaining titles are unchanged, except the title of the stage changed by D15. Titled screens are added for the keyring wait (D16), the progress (D17), the success (D18), the failure (D19), and the unverified installation (D20). | Consequence of D1, D4, D9, D10, D15. |
| D15 | "Choose swapfile size" screen at the position after storage layout: gray lines "The swapfile is used for swap and hibernation." / "The default does not guarantee hibernation for every workload.", the range line, and the "Swapfile size (MiB)> " input. Review row "Swapfile": "<n> MiB". | The stage is titled "Choose hibernation" and is shown at the same position. A `gum choose` with the header "Hibernation" offers "Enabled" and "Disabled", with the current choice selected (Enabled initially) and the gray lines "Hibernation lets the machine power off and resume where it left off." / "Enabled keeps a swapfile on disk; it also serves as fallback swap when zram is full." Only when Enabled, the sizing screen titled "Choose swapfile size" follows, in the reference's style, with the gray lines "The swapfile holds the hibernation image and also serves as fallback swap after zram." / "The default does not guarantee hibernation for every workload.", the range line stating the RAM-derived minimum and maximum, and the unchanged input; it shows no warning. Back from the sizing returns to the hibernation choice. Disabling removes the explicit size and re-enabling proposes the RAM-derived default again. The review row "Swapfile" becomes "Hibernation": "Enabled (swapfile <n> MiB)", or "Disabled (no swapfile)" with the gray line "Hibernation is disabled: no swapfile will be created."; when the size is below detected memory, the persistent yellow line "Below detected memory: hibernation may be unavailable under large memory workloads. It depends on used memory and free swapfile space." appears under the rows. No additional confirmation dialog, and no claim that the default guarantees a successful resume. | DEC-013, DEC-014, DEC-028; [ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md): hibernation is optional and the swapfile size is RAM-derived. |
| D16 | None. | Drawn only while the package keyring is not ready. While waiting: a screen titled "Preparing the package keyring" with the gray line "Waiting for the package keyring to be initialized...". When the bound of 600 seconds expires or the service fails: a screen titled "Package keyring not ready" with "Package signatures cannot be verified until the keyring is ready." and "Wait a moment, then retry.", with Retry keyring check and Cancel. No screen is drawn when the keyring is already ready. | DEC-012, DEC-020: visible wait during live preparation, before any confirmation or password. |
| D17 | None. | Engine progress screen: the logo, the title "Installing MirrorOS", a centered 34-column progress bar (narrowed only when the terminal is narrower), and a secondary-gray line with the current position and description. The composition is centered vertically and horizontally; completed blocks use the principal foreground and remaining blocks secondary gray. The symbol is omitted below 32 rows. Status lines wrap without truncation. At a subsequent state redraw, only the dynamic area is repainted unless geometry or rendered height changed. For `N` plan operations the total is `N+1`, reserving the final unit for configure; base postconditions add no unit. During package installation a second dimmed line shows "Packages installed: <count>"; the count never moves the bar. During configure the main line is "[N+1/N+1] Configure the graphical environment." with numeric positions, and the second line is "Configure step: <k>/<total> <step>" when a marker is available, with no package count. The bar reaches the end only after configure succeeds; no time-based curve or tips. Every fixed engine-phase line fits 80 columns including its prefix; operation descriptions are at most 72 characters, and every configured step path must fit its complete prefixed line. Tests enforce both limits. | DEC-008: progress must be backed by completed work; Story 4.2 DEC-026, DEC-032. |
| D18 | None. | Success screen: the symbol and "Installed MirrorOS in <duration>" in a vertically and horizontally centered composition, omitting the symbol below 32 rows. The redundant configuration-success explanation is removed. A vertical menu "Restart now" / "Return to shell" uses the shared accent-only selector and native help, both aligned to the title's left margin, with Restart now selected. There is no animated effect. The machine restarts only when "Restart now" is chosen. | DEC-007, DEC-008. |
| D19 | None. | Failure screen for an engine failure or interruption: a two-line top margin, a space-conditional symbol and adaptive diagnostic inspection as described below, the red title "MirrorOS installation stopped", "Failed operation: <id>", "Exit status: <status>", the red line "The disk was partially modified and installation did not complete." (or "The disk was not modified." when no destructive operation had started), the last 15 lines of `engine.log`, "Run directory: <path>", and a separated shared accent-only menu "View full log" (`gum pager` with a slot-4 border) / "Return to shell" (selected) / "Restart" / "Power off", with native help. It offers no log upload, no media diagnosis, and no automatic action. A stop before the first destructive operation (`blocked` or `invalidated`) uses the D5 screen instead. Every line of this screen, including each of the 15 log lines, is wrapped at word boundaries within the 80-column form or available narrower width, preserving complete text and continuation alignment. D20, D22, engine no-valid-record reporting, and other failed-phase diagnostics now use the same form-width wrapping under their separate batch approval. | DEC-006, DEC-008; DEC-014 of Story 2.6. |
| D20 | None. | `not_verified` screen, for the outcome `not_verified`: two top blank lines, a space-conditional symbol and adaptive diagnostic inspection as described below, the red title "MirrorOS installation could not be verified", the red line "Installation finished, but the installed system failed verification. Do not rely on it.", one block per failed check with "Failed check: <id>" and its non-secret `detail` (expected and observed values), the gray line "The disk was modified. The full result is in the run directory.", "Run directory: <path>", and a separated shared accent-only menu "View full log" (`gum pager` with a slot-4 border) / "Return to shell" (selected) / "Restart" / "Power off", with native help. No automatic action and no retry. The restart is never the default. Blank lines separate the warning and each failed-check block. Every line wraps within the 80-column form or available narrower width, as in D19. | DEC-008, DEC-014 of Story 2.6. |
| D21 | Review rows end with "Internet"; the hardware appears only in the full plan as `not_evaluated`. | Review rows "Graphics", "CPU microcode", "Battery", and "Virtualization" are added after the "Machine" row, each showing the rule outcome in one line (for example "Kernel driver, nothing additional", "Installs amd-ucode", "Battery detected", or "Virtual machine"). Every warning of the plan, including the hardware warnings of the plan contract, appears as a persistent yellow line under the rows, like the swapfile warning of D15. The complete plan (D8) shows each outcome with its fact, detected value, and explanation, and the rule packages with their provenance. Nothing here is editable or blocks continuing. | FR18, FR33–FR35 of Story 2.6: hardware-derived choices are explained before approval. |
| D22 | None. | For `not_configured`/`4`: two top blank lines, a space-conditional symbol and adaptive diagnostic inspection as described below, the red line "Base system installed and verified; environment configuration failed at step <step>." (unknown when no step is available), the next action "Boot the installed system, log in at the console, and run sudo mirroros-configure.", and "Run directory: <path>". The menu is "View configure log" / "Restart" / "Return to shell" / "Power off", with "Return to shell" selected. The shared accent-only selector retains native help. The slot-4-border pager shows only the configure portion of `engine.log`. Blank lines separate the failure, recovery action, run directory, and menu. Lines wrap at word boundaries like D20. No retry from the live medium and no automatic action; leaving for the shell returns `4`. | Story 4.2 DEC-027, DEC-028, DEC-032. |
| D23 | No configure announcement under the review rows. | Adds the fixed dimmed line "After the base system is verified, the graphical environment is configured." under the review rows in both review presentations, before confirmation. It fits 80 columns and does not add an editable choice or a plan operation. | Story 4.2 DEC-031. |

### ADR 0018 presentation amendment

[ADR 0018](../docs/adr/0018-native-live-display-and-installer-presentation.md) replaces the previous
ADR 0017 mode preference: the single normal live entry preserves the firmware/kernel display choice
without a MirrorOS display request. The duplicate native-display entry is removed from each loader.

The shared installer uses `symbol.txt`, centered on the screen independently of an 80-column form,
and the ADR's minimal palette, accent-only Gum selection without inverse video, and native Gum help.
`COLORTERM=yes` preserves the distinction between help keys and descriptions. The previous `banner.txt`
is retained unchanged for the existing graphical-wordmark contract; no installed presentation asset changes.

The welcome title remains "Welcome to MirrorOS". Its body is "Let's set up your machine.", a blank line,
"Installation keyboard: <label>", and the gray explanation "Used only during installation." A blank line
precedes the choices "Continue", "Change keyboard layout", and "Change text size". Continue keeps the
existing preparation flow; keyboard changes remain live-only and retain their existing selector and effects.

"Change text size" opens "Installation text size", with the gray lines "Original restores the font selected
at startup." and "Original x2 doubles the saved font, preserving every glyph.", then a blank line and
"Original" / "Original x2", selecting the current value. Esc returns to welcome unchanged. Both sizes
load the exact saved font and mapping; x2 always doubles that saved original. A private temporary file
is captured on the current real VT at startup and restored on exit before temporary-file cleanup.
Capture/load errors stop the flow; restoration errors report a reboot recovery action. Pseudo-terminals
cannot change a VT font. The welcome and size selector omit the symbol below 32 rows. This does not
establish fit, pagination, or warning wrapping for other screens, which remain subject to individual review.
No text-size value enters the plan, approval, installed system, or retained evidence.

The individually reviewed "Connect to the internet" screen uses the welcome's two-line symbol gap
and omits the symbol below 32 rows. It keeps the secondary text "Internet access is needed to prepare
and install MirrorOS." and "This connection is for the live environment only.", followed by a blank
line and the shared accent-only selector without a generic header. Its options remain "Ethernet",
"Wi-Fi", and "Cancel", initially selecting Ethernet, with native Gum help. Esc, Ctrl+C, cancellation,
and preparation checks are unchanged. The individually reviewed "Connect with Ethernet" screen uses
the same heading gap and short-console symbol omission. Its cable instruction uses secondary gray;
a blank line separates instructions from a red retry error, when present, and another precedes the
shared selector. Retry connection check and Back retain their behavior. The individually reviewed
"Connect with Wi-Fi" screen uses the same heading gap, short-console symbol omission, secondary-gray
instructions, and separated error and selector blocks. Retry connection check, Show connection
instructions, Back, and the unchanged instruction text and pager retain their behavior. The individually
reviewed Wi-Fi instruction pager uses the blue-gray accent (slot 4) for its border without changing its
content or navigation. The individually reviewed "Waiting for the system clock" screen uses the same
heading gap and short-console symbol omission, both explanations in secondary gray, and a blank line
before the shared headerless selector. Retry clock check, Cancel, Esc, Ctrl+C, and the bounded clock
readiness check remain unchanged. The individually reviewed "Preparing the package keyring" and
"Package keyring not ready" screens use the same heading gap and short-console symbol omission.
The waiting status remains secondary gray. The failure explanations use secondary gray with a blank
line before the shared headerless selector; Retry keyring check, Cancel, Esc, and Ctrl+C retain their
behavior. Service checks, the 600-second bound, and signature-verification policy remain unchanged.
The individually reviewed "Machine check" (recognized and unqualified), "Choose installation disk",
and "Choose storage layout" screens use the same heading gap, short-console symbol omission, and
shared headerless selector with a blank line before choices. The machine identity remains principal
foreground; the experimental warning remains yellow and its compatibility disclaimer remains secondary.
Disk instructions, including the entire-disk notice, use secondary gray. Storage layout and recovery
explanations use secondary gray, with a blank line between those blocks. All text, options, selected
values, provider boundaries, existing-plan review jump, Esc/Cancel behavior, and authorization limits
remain unchanged. These approvals do not qualify complete doubled-size usability.

The individually reviewed five-stage batch covers "Choose hibernation", its conditional "Choose swapfile
size" sub-form, "Select your timezone", "Choose system language", "Choose regional formats", and
"Choose installed console keyboard". All six headings use the same symbol gap and short-console
symbol omission. Choices use the shared headerless selector, preserving the existing widgets, options,
current values, and native help. Descriptions and instructions use secondary gray, including the sizing
range and the current meaning of following the system language. Blank lines separate description blocks
and choices. The swapfile remains a `gum input` with its original prompt and value; invalid submissions
retain the entered value and show the unchanged red error after the instructions, separated by blank
lines before the error and input. The RAM-derived bounds, normalization, provider validation, Enabled/
Disabled branching, explicit-size preservation and reset, Back/Esc/Ctrl+C behavior, and installed-versus-live
keyboard distinction remain unchanged. The batch was approved using disposable synthetic data, without
running discovery, planning, credentials, the installation engine, or disk operations. This does not qualify
complete doubled-size usability or the later review and confirmation screens.

The individually reviewed account batch covers "Name your machine", "Let's setup your user account...",
and "Choose root account policy", including the current-password-policy disclaimer. All three headings
use the same symbol gap and short-console symbol omission. Hostname retry errors are separated from
the input by a blank line. Username instructions precede the unchanged red validation error, when
present, with blank lines separating instructions, error, and input. Root explanations use secondary
gray and separated blocks before the shared headerless selector. The shared-password disclaimer remains
conditional on the current password policy. Text, options, current values, provider validation, retry
values, Back/Esc/Ctrl+C, and the password-after-approval boundary remain unchanged. Approval used
synthetic data only, without account changes or password collection; later screens and complete
doubled-size usability remain unqualified.

The individually reviewed "Review your choices" screen omits the symbol at every height to prioritize
review content, retaining the two-line top margin, title, and complete answer rows. It uses separated
secondary-gray explanations and the shared headerless selector, retaining the original options,
current default, and native help, with the conditional adaptive-review option described below. All plan warnings remain yellow and non-blocking. They wrap at word boundaries within
80 columns, or the available width on narrower consoles, with continuation lines aligned to the form;
long words split rather than truncate. The below-memory swapfile warning follows the same rule. Warning
text and conditional disabled-hibernation information are retained. The complete-plan pager uses the
blue-gray border (slot 4) without changing its text, navigation, or status handling. Inspection returns
to review and grants no authorization. Approval covered synthetic no-warning and multiple-warning
presentations. A subsequent individually approved adaptive review measures the rendered body on each
redraw, keeps separate rows when they fit, and otherwise groups Hostname/Username/Root and Timezone/
Language/Locales only if each complete group fits horizontally. Rows and explanations also wrap to the
form width. If grouping is insufficient, the full review opens in the blue-gray-bordered pager, followed
by the safety footer and navigation, including "Inspect review". Leaving or reopening that pager retains
answers and grants nothing; Ctrl+C and unexpected pager failures propagate as before. The rendered body
is a private transient file under the existing run temporary directory, never authorization or retained
evidence. No forced-height override exists in production. Attended synthetic review covered 149x41,
a simulated two-line deficit at original size, and 74x20 with the saved font doubled. Measurement is
recomputed on redraw, not a promise of live reflow while a widget remains open. Arbitrary geometries,
long answer values beyond the tested cases, and complete doubled-size usability of the installer remain
unqualified; no general whole-screen-fit guarantee is made.

The individually approved "Confirm installation" screen uses the reviewed heading gap and omits the
symbol below 32 rows. Disk, Path, Disk ID, New layout, and Plan reference reuse the review's aligned
principal-foreground rows and form-width wrapping. Blank lines separate the rows, complete red erasure
warning, confirmation control, and device-name input. The confirmation control uses the blue-gray
selection accent without inverse video and still focuses No. The device-name input uses a blue-gray
prompt and cursor, secondary placeholder, and principal value. Its exact instruction text is rendered
as a separate secondary-gray block, followed by a blank line and the unchanged Device name prompt,
rather than as Gum's internal input header.
No, Esc, Ctrl+C, and a non-matching name still cancel; there is no Back or second attempt. Provider
boundaries and plan/disk binding remain unchanged. Approval used an isolated synthetic preview without
passwords, real authorization, or disk operations. It does not qualify all long values, the unqualified
variant's fit, or complete doubled-size usability.

The subsequently approved "Password" presentation uses the reviewed heading gap and short-console
symbol omission, secondary-gray account and safety explanations separated by a blank line, and the
unchanged red validation error after those explanations, separated from the input. Both masked fields
use the approved blue-gray prompt/cursor and secondary placeholder style; no extra blank line is added
between Password and Confirm. Esc in Confirm clears both values and the displayed error before restarting
Password; Esc in Password returns to review and clears approval. Non-empty matching values remain the
only validation, without an attempt limit or strength policy. Approval used synthetic masked values only,
without authorization, credential persistence, engine execution, or disk operations. Outcome screens
and complete doubled-size usability remain pending.

The subsequently approved progress composition is informed by the dashboard extracted read-only from
the verified Omarchy 4.0.4 ISO. It centers the MirrorOS symbol, title, 34-column bar, and complete operation
and package/configure details as one block. Completed `█` cells use principal foreground (slot 7), while
remaining `░` cells and status text use secondary gray (slot 8). The symbol is omitted below 32 rows;
status lines wrap rather than truncate. State redraws retain the static symbol when geometry and rendered
height are unchanged; leaving progress restores the cursor and clears the cached layout. Geometry is
measured on state redraw, not continuously while the engine state is unchanged. Progress still counts
completed plan operations plus configure; package counts and elapsed time never advance the bar.
No upstream estimator, supervisor, tips, animation, or installation code is incorporated. The repeating
synthetic preview is not production behavior or installation evidence.

The subsequently approved success screen continues the centered composition with the MirrorOS symbol
and unchanged "Installed MirrorOS in <duration>" title, omitting the symbol below 32 rows. The redundant
"Base system verified and graphical environment configured." explanation is removed from this screen;
the installed outcome still requires both verification and configuration success. The vertical Restart now /
Return to shell menu uses the shared accent-only selector with Restart now selected and native help.
Options and help share the title's left margin, derived from the rendered title rather than a fixed duration.
No animation, automatic restart, or change to outcome handling is added. Approval used a disposable
synthetic success screen whose actions only closed the demo; failure screens and complete doubled-size
usability remain pending.

The subsequently approved engine-failure screen starts at the two-line top margin without the symbol,
leaving room for diagnostics. The red title, principal operation/status, separated red partial-modification
warning, complete last 15 sanitized log lines, secondary run directory, and separated shared selector
retain their text and behavior. Every diagnostic line wraps within the 80-column form or available
narrower width, with aligned continuations and no truncation. Return to shell remains selected. View
full log opens the unchanged log in a slot-4-border pager and returns to the failure screen. Restart and
Power off still require their explicit menu choices; there is no retry or automatic action. At that
checkpoint, the D20 selector and pager remained pending review. Both the partially-modified and no-disk-modification
variants were individually approved using synthetic failures and logs, without disk or power actions.
The no-disk-modification variant retains the principal-foreground "The disk was not modified." line.
The later nine-scenario error batch approves D20 (multiple failed checks), D22 (known and unknown
configure step), missing/invalid engine record reporting, recoverable discovery, rejected plan combinations,
blocked discovery, invalidated approval, and unexpected phase failure. These diagnostics use the two-line
top margin without a symbol, separated complete blocks, and 80-column-form or narrower wrapping.
D20 retains its red warning and all failed checks; D22 retains the installed-system recovery instruction.
Their shared accent-only menus retain options, defaults, native help, explicit power actions, and existing
return behavior; full/configure-only logs use slot-4 pager borders. Recoverable discovery still offers
Retry / Back / Cancel with Retry selected; rejected combinations still offer Back / Cancel with Back
selected. Other phase failures gain neither retry nor menu. Error outcomes render the unchanged
"Evidence: <path>" label in secondary gray, wrapped and aligned to the diagnostic form. Success and
cancellation evidence output are unchanged. Outcome/status normalization, approval invalidation, log
filtering, recovery, and all safety boundaries remain intact. The preview-only navigator, Enter pause,
and synthetic data are not integrated. Approval used only disposable synthetic failures and logs;
long-content fit, arbitrary geometries, and complete doubled-size usability remained pending at that checkpoint.

The later approved adaptive-error review supersedes the unconditional symbol omission of those error
presentations. It covers both engine disk-modification variants, multiple failed postconditions, known/
unknown configure steps, missing/invalid engine records, recoverable discovery, rejected combinations,
blocked discovery, invalidated approval, and unexpected phase failures. On redraw, the complete wrapped
diagnostic is measured with its menu/help or terminal Evidence output. If it fits, it remains inline.
The symbol and its two-line gap appear only at 32 or more rows and only if that entire composition fits;
otherwise the symbol is omitted before resorting to paging. If the diagnostic still needs more height,
the complete body opens in a slot-4-border pager, followed by a compact outcome or phase/next-action
summary. No log-tail line, failed-check detail, cause, or evidence path is removed from inspection.
The summary retains the applicable disk warning, verification warning, or installed-system configure
recovery instruction. It receives its own logo/height budget, including the additional inspection choice:
a paged diagnostic can therefore return to a summary with a symbol when that smaller composition fits.

Existing menu options and defaults are preserved; only paged menu-bearing errors add "Inspect diagnostic"
to reopen the complete body. Inspection does not retry discovery, regenerate a plan, change approval,
or perform a power action. Terminal-only errors gain neither menu nor retry. Their complete cause and
Evidence path remain in the initial inspection, and normal ending output still reports Evidence. Private
render files live only under the existing run temporary directory and are removed by normal cleanup;
they never authorize anything. Final outcome menus and their inspectors remain after record writing.
Leaving or failing an inspector cannot turn an existing terminal or recorded failure into success or
replace its outcome; Ctrl+C in recoverable interactive inspection retains cancellation semantics.
Geometry is measured on redraw, not continuously while a widget is open. Approval used only synthetic
long logs, long paths, and failed checks at original and saved-font-doubled sizes, without installation,
credentials, disk changes, or power actions. Preview navigators, pauses, font controls, and synthetic
fixtures are excluded from production. Arbitrary geometries, unbounded summary text, other screen
families, and complete doubled-size usability of the installer remain unqualified.

A subsequent attended saved-font-doubled review approved the remaining displayed batches without
product changes: unqualified machine, disk and storage; hibernation with conditional sizing, timezone,
language, formats and installed keyboard; hostname, username, root policy and masked password entry;
welcome and preparation; unqualified confirmation and device-name entry; and synthetic progress and
success. Together with the earlier adaptive-review and adaptive-error approvals, this completes the
planned synthetic screen-family review at Original x2 on this live VM. It does not qualify every branch,
unbounded values, arbitrary geometries, live widget reflow, physical hardware, or a rebuilt ISO.
No discovery, real credential, account change, installation engine, disk operation, or power action was
used in these batches. Temporary font controls, navigation, waits and synthetic providers remain outside
production. Earlier pending statements describe their respective checkpoints, not this later approval.

Subsequent visual previews apply the agreed baseline before review: principal titles and options,
secondary descriptions and instructions, red errors, separated content blocks, and shared selectors
without a generic header. Editable-field prompts use the blue-gray interaction accent (slot 4), with a
slot-4 cursor, secondary-gray placeholders (slot 8), and values in the principal foreground. This input
style is individually approved and applied to swapfile size, hostname, and username, retaining their
exact prompts, placeholders, values, validation, and navigation. Apply the same criterion to remaining
editable fields during their individual review, including password and device-name confirmation fields;
this does not approve those screens, alter masking, or weaken authorization. Gum 2.0.2 exposes prompt,
placeholder, and cursor colors, but not an editable-value color flag; no Gum patch or terminal-color
workaround is introduced. This baseline does not approve unreviewed screen content or navigation.

Unchanged and not differences: the VT-only palette boundary, the live-keyboard selector and its effects,
the Wi-Fi instruction text and pager behavior, timezone, installed-keyboard, language and formats
options and behavior, the hostname, username, and root-policy screens, storage choices and behavior,
Back and Esc navigation in configuration steps, and the cancellation message. The initial
console font remains the kernel-selected font unless the operator has changed it before entering the guide.

Complete simultaneous fit within 80x25 is not required, and no colorless variant or dedicated pager feature test
is part of this contract.

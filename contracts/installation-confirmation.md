# Installation confirmation (`operations/install apply`)

`format_version: 1`. Produced by `operations/install apply`, which runs one interactive Gum flow: it
chooses a target, discovers it read-only, generates and lets the user edit an
[installation plan](installation-plan.md), presents a single review dashboard, and requires a target- and
digest-bound confirmation. Confirmation is ephemeral and single-use: it exists only inside one process.
No persisted file authorizes anything. The two JSON documents below are evidence records. Unknown fields
are rejected by `install/confirmation/validate-records.mjs`.

In this version the command always ends at the engine boundary. The installation engine
(`install/engine/apply`) is not part of this version, so a valid approval exits `2` with
`engine_not_available` and nothing is executed. No path exits `0`.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted.

## Command

```text
operations/install apply [--plan <file>] [--output <dir>]
```

| Option | Description |
| --- | --- |
| `--plan <file>` | Review an existing plan instead of generating one. The plan is validated and copied to `plans/01/`; the original is untouched. The target comes from the plan. |
| `--output <dir>` | Run directory. Defaults to `evidence/install/<run-id>/`. |

There is no `--target`: without `--plan`, the target is chosen with `gum choose` from the definitions
under `targets/`. `--yes`, `--non-interactive`, and any unknown option exit `2` before any prompt or
discovery. The flow never branches on whether the target is virtual or physical, never requests a secret
value, and never calls `sudo` or any other elevation.

## Flow

1. **TTY precheck.** Stdin and stdout must be terminals; otherwise exit `2` before anything else. There is
   no environment variable or option that bypasses it.
2. **Gum version check.** The major version of `gum --version` must be `2`. A missing Gum or another
   major version exits `6` with the reason `gum_not_qualified`.
3. **Target choice.** `gum choose` over `targets/*/target.json`; with `--plan` the target is read from the
   plan.
4. **`discovery/initial/`.** `install/discovery/discover --target <id> --output <dir>` as a process.
5. **Plan.** Without `--plan`, `install/plan/plan` generates `plans/01/`. With `--plan`, the file is
   validated (including its digest), copied to `plans/01/`, and compared with the fresh facts (the
   pre-review safety comparison below).
6. **Dashboard and edit loop.** One dashboard rendered with `gum format` and a grayscale glamour style:
   - the plan digest (first 12 hex characters) in the header and the target id;
   - the disk path, model, size, and current layout;
   - every choice with its provenance and source;
   - every destructive operation, marked `DESTRUCTIVE`;
   - each secret requirement by name, channel, and consumer.

   A `gum choose` menu follows: `Cancel` (first, the safe answer), `Edit a choice`, and
   `Continue to confirmation`. An edit changes one editable choice with a per-key widget, regenerates the
   plan through `install/plan/plan` into a new `plans/NN/` with a new digest, and shows the new dashboard.
   `choices.json` accumulates every edit of the run. With `--plan`, the starting choices are the plan
   entries whose source is `choice`. An edit that produces an invalid combination shows the reason's
   `message` and `next_step`, is discarded, and keeps the previous plan.
7. **Confirmation.** `gum confirm` (the `gum choose` variant under `NO_COLOR` or `TERM=dumb`) with focus
   on No, asking to erase the disk and apply the plan by digest prefix. Then the user types the kernel
   device name (the basename of the disk path, for example `vda` or `nvme0n1`) with `gum input`.
8. **`discovery/final/`.** Rediscovery, then the safety comparison and a digest re-check of the plan file
   on disk.
9. **Engine boundary.** An absent `install/engine/apply` is `engine_not_available`.

## Safety projection

The comparison runs twice: before the review is presented and again immediately after confirmation. It
compares the plan with fresh facts over this projection:

| Field | Source |
| --- | --- |
| `target_id` | `target.target_id` of the plan against the facts `source.target_id`. |
| `firmware.boot_mode` | `choices.firmware_mode` of the plan against the facts `firmware`. |
| `firmware.secure_boot` | Not recorded in the plan: the Secure Boot state of the fresh facts is compared with the state in `discovery/initial/`. |
| Disk identity | `path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes` of the selected disk. |
| `eligible` | Must remain `true`. |
| `current_layout` | `partition_table` and, for each partition, `uuid`, `partuuid`, size, `fstype`, `label`, and `mountpoints`. |
| `policy_binding` | `policy_sha256` and `override_sha256`, recomputed from `install/plan/policy.json` and the target override. |

`facts_binding.facts_sha256` is not compared: facts include `source.run_id`, so every rediscovery hashes
differently. Network readiness is not part of the projection.

## Reasons

Every reason uses the architecture's structured error shape: `code`, `stage` (`install`), `operation`
(the flow step that failed), `message`, `next_step`, and `child_exit_status` (only when a child process
exists).

Invalidation reasons carry the `next_step` "Regenerate and review the installation plan."

| Code | Condition |
| --- | --- |
| `target_identity_changed` | `target_id`, firmware mode, Secure Boot state, or the disk identity differs from the plan. |
| `target_layout_changed` | The disk is no longer eligible, or its `current_layout` differs from the plan. |
| `policy_changed` | The recomputed policy or override hash differs from `policy_binding`. |
| `digest_mismatch` | The plan file fails its digest, before review or in the re-check after confirmation. |
| Validator codes | A plan given with `--plan` fails `validate-plan.mjs`; its code passes through (see [`installation-plan.md`](installation-plan.md#validation)). |
| Discovery codes | Fresh facts are invalid or discovery fails; the code passes through (see [`target-facts.md`](target-facts.md)), for example `target_identity_mismatch` or `target_identity_pending_capture`. |

Other reasons:

| Code | Condition |
| --- | --- |
| `confirmation_mismatch` | The typed device name differs from the expected kernel name. There is no second attempt. |
| `engine_not_available` | A valid approval reached the engine boundary. The message states that the installation engine is not part of this version and nothing was executed; the next step states that installation becomes available with the engine story. |
| `gum_not_qualified` | Gum is missing or its major version is not `2`. |
| `device_name_unavailable` | The selected disk has no kernel `path`, so the device name to type cannot be derived. The run is `blocked` before confirmation. |

## Outcomes and exits

`outcome` and `exit_status` together distinguish every path.

| Exit | Outcome | Condition |
| --- | --- | --- |
| `2` | `approved` | The user confirmed, the post-confirmation checks passed, and the engine boundary was reached. Reason `engine_not_available`. |
| `3` | `cancelled` | The user chose Cancel, answered No, pressed Esc at a confirmation prompt, pressed Ctrl+C during the interactive phase, or typed a device name that does not match (reason `confirmation_mismatch`). |
| `2` | `invalidated` | A target, layout, policy, or plan change was detected before review or after confirmation. The reason is one of the invalidation codes above. |
| `2` | `blocked` | The run cannot reach review for an input reason: invalid facts, pending target capture, or an identity mismatch from discovery. |
| `5` | `failed` | An external tool failed unexpectedly. |
| `6` | `failed` | Damaged checkout or embedded code, or Gum that is missing or not qualified. |
| `128+n` | none | Termination by a signal outside the interactive phase, and every signal other than SIGINT. |

Exit `0` is unused in this version. Arguments or TTY errors that stop the run before it starts exit `2`
and report on stderr only: no run directory and no records are written.

### Ctrl+C and Esc

SIGINT, or Gum status `130`, during the interactive review and confirmation phase (the dashboard, the
edit widgets, and both confirmation prompts) maps to exit `3` with outcome `cancelled`. The mapping lives
in the orchestrator; the `confirm_status_map` wrapper still returns `130` unmapped, as
[ADR 0004](../docs/adr/0004-interactive-presentation-with-gum.md) states. The SIGINT trap covers only that
phase: SIGINT during read-only revalidation or rediscovery keeps `130`, and SIGTERM and SIGHUP keep
`128+n`.

Esc inside an edit widget returns to the dashboard unchanged and does not cancel the run. Only `Cancel`,
the final No, Esc at a confirmation prompt, a name mismatch, and Ctrl+C cancel.

## Run directory

Each run writes to `evidence/install/<run-id>/`, or to `--output`, with `0700` directories and `0600`
files:

| Path | Content |
| --- | --- |
| `apply-run.json` | The run record. |
| `approval-record.json` | The non-authorizing evidence record. |
| `discovery/initial/` | Facts for generation, or the pre-review check with `--plan`. |
| `discovery/final/` | The post-confirmation rediscovery. Present only when that step was reached. |
| `plans/01/`, `plans/02/`, … | One directory per generated or regenerated plan: `installation-plan.json`, `installation-plan.txt`, `plan-run.json`, and `choices.json`. |
| `apply.log` | Plain text, no ANSI sequences, no secret. |

`apply-run.json` and `approval-record.json` are always written once the run has started, including on
cancellation and invalidation. Each is written to a temporary file in the same directory, re-read,
validated, and renamed. `choices.json` follows the choices file format of the plan contract and never
holds a secret.

### `apply-run.json`

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `run_id` | Run identifier. |
| `timestamp` | RFC 3339 start time. |
| `target_id` | The chosen or planned target; omitted when none was reached. |
| `gum_version` | Output of `gum --version`; omitted when Gum was not found. |
| `digests` | Plan digests in order of generation, one per `plans/NN/`. |
| `final_digest` | The digest of the plan shown last; omitted when no plan exists. |
| `exit_status` | The exit status of the run. |
| `outcome` | `approved`, `cancelled`, `invalidated`, `blocked`, or `failed`. |
| `reasons` | List of structured reasons; may be empty. |

### `approval-record.json`

A non-authorizing record: no stage reads it as permission, and a later run never accepts it in place of a
fresh confirmation.

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `run_id` | Run identifier, the same as in `apply-run.json`. |
| `timestamp` | RFC 3339 time the record was written. |
| `digest` | The final plan digest; omitted when no plan exists. |
| `target_id` | The target; omitted when none was reached. |
| `disk` | Identity of the selected disk: `path`, `by_id`, `wwn`, `serial`, `model`, and `size_bytes`, as available. |
| `gum_version` | As in `apply-run.json`. |
| `outcome` | As in `apply-run.json`. |
| `reason` | The primary reason's `code`; omitted when none applies. |

Neither document contains a secret value, a hash of one, or a secret-like key; the validator rejects them.

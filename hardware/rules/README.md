# Hardware rules

Rules turn detected hardware facts into visible, rule-derived plan selections. Discovery observes
(`hardware/discovery/`); the rules decide at plan generation; the installation engine only executes the approved
plan and never reads a rule. The plan format that carries the results is defined in
[`contracts/installation-plan.md`](../../contracts/installation-plan.md).

| Rule | Fact | Outcomes | Selects |
| --- | --- | --- | --- |
| `graphics` | `hardware.graphics` | `kernel_driver_only`, `nvidia_nouveau_fallback`, `vendor_not_recognized` | Nothing. Warns for NVIDIA and unrecognized graphics. |
| `cpu-microcode` | `hardware.cpu.vendor` | `amd_microcode`, `intel_microcode`, `vendor_not_recognized` | `amd-ucode` or `intel-ucode`. Warns for an unrecognized vendor. |
| `battery` | `hardware.battery_present` | `battery_present`, `battery_absent`, `not_observed` | Nothing (informational). |
| `virtualization` | `hardware.virtualization` | `virtual_machine`, `physical_machine`, `not_observed` | Nothing (informational). |

## Rule module

Each `<rule>/rule.mjs` is a pure ES module whose default export has one shape:

- `id`: the rule id, equal to its directory name.
- `fact`: the dotted path of the facts' `effective` view that the rule reads.
- `observe(raw)`: the value recorded in the plan for the raw fact value (`unknown` when not observed).
- `evaluate(value)`: `{ outcome, explanation, packages, warnings }`. `packages` are package names and `warnings`
  are `{ code, message, next_step }`.

A rule reads no file, writes nothing, and never reads `install/plan/policy.json`, a target override, or another
rule. It never blocks installation.

## Evaluator

`evaluate-rules.mjs` exports the fixed `RULES` list (the plan's order) and two functions that share one
derivation: `evaluateRules(facts)` for plan generation and `evaluateValues(values)` for the plan validator, which
re-derives the results from the values recorded in the plan. Both accept an alternative `rules` list; adding a
rule module needs no change to portable modules, policy, or other rules.

The decisions behind the rules are in [ADR 0005](../../docs/adr/0005-physical-target-change.md) (no dedicated GPU
drivers) and the Story 2.6 plan.

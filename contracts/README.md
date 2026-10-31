# Contracts

Human-readable format contracts for structured MirrorOS data. A contract here documents a format that
production code already produces and that fixtures and contract tests already enforce. The architecture
reserves final schemas until that evidence exists, so no formal `*.schema.json` files are kept here.

| Contract | Produced by | Enforced by |
| --- | --- | --- |
| [`boot-first.md`](boot-first.md) | `operations/boot-first`, `operations/lib/uefi-boot-entry.sh` | `tests/operations/boot-first.contract.bats`, `tests/operations/uefi-boot-entry.contract.bats` |
| [`target-facts.md`](target-facts.md) | `install/discovery/` | `install/discovery/validate-facts.mjs`, `tests/install/discovery/` |
| [`installation-plan.md`](installation-plan.md) | `install/plan/` | `install/plan/validate-plan.mjs`, `tests/install/plan/` |
| [`installation-confirmation.md`](installation-confirmation.md) | `install/confirmation/` | `install/confirmation/validate-records.mjs`, `tests/install/confirmation/` |
| [`installation-engine.md`](installation-engine.md) | `install/engine/` | `install/engine/load-plan.mjs`, `install/engine/engine-record.mjs`, `tests/install/engine/` |
| [`installation-postconditions.md`](installation-postconditions.md) | `install/postconditions/` | `install/postconditions/evaluate.mjs`, `tests/install/postconditions/` |

Target facts are `format_version` `2`; installation plans are `format_version` `6`, installation policy is
format `4`, and choices files remain format `3`. Installation-confirmation writers produce format `7`
(readers also accept pre-timing `6`); engine run writers produce format `4` (readers also accept pre-timing
`3`), and engine state remains format `3`. The postconditions result remains format `1`. Earlier plans
(`1`–`5`) are rejected with regeneration guidance, never migrated. Supported historical evidence records
remain unchanged and never authorize a run. Each document keeps its own version constant. See
[ADR 0006](../docs/adr/0006-guided-live-installation-boundaries.md),
[ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md),
[ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md), and
[ADR 0009](../docs/adr/0009-storage-option-promotion-and-esp-size.md) for the boundaries they implement.

Contracts are documentation: they are not embedded in the live medium. The validator lives in code.

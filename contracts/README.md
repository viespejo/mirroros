# Contracts

Human-readable format contracts for structured MirrorOS data. A contract here documents a format that
production code already produces and that fixtures and contract tests already enforce. The architecture
reserves final schemas until that evidence exists, so no formal `*.schema.json` files are kept here.

| Contract | Produced by | Enforced by |
| --- | --- | --- |
| [`target-facts.md`](target-facts.md) | `install/discovery/` | `install/discovery/validate-facts.mjs`, `tests/install/discovery/` |
| [`installation-plan.md`](installation-plan.md) | `install/plan/` | `install/plan/validate-plan.mjs`, `tests/install/plan/` |
| [`installation-confirmation.md`](installation-confirmation.md) | `install/confirmation/` | `install/confirmation/validate-records.mjs`, `tests/install/confirmation/` |
| [`installation-engine.md`](installation-engine.md) | `install/engine/` | `install/engine/load-plan.mjs`, `install/engine/engine-record.mjs`, `tests/install/engine/` |

Target facts are `format_version` `2`; installation plans are `format_version` `3`; installation-confirmation
records are `format_version` `4`; the engine's run record and state file are `format_version` `1`; an earlier
version is rejected, never migrated. Each document keeps its own version constant. See
[ADR 0006](../docs/adr/0006-guided-live-installation-boundaries.md),
[ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md),
[ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md), and
[ADR 0009](../docs/adr/0009-storage-option-promotion-and-esp-size.md) for the boundaries they implement.

Contracts are documentation: they are not embedded in the live medium. The validator lives in code.

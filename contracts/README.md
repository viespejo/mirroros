# Contracts

Human-readable format contracts for structured MirrorOS data. A contract here documents a format that
production code already produces and that fixtures and contract tests already enforce. The architecture
reserves final schemas until that evidence exists, so no formal `*.schema.json` files are kept here.

| Contract | Produced by | Enforced by |
| --- | --- | --- |
| [`target-facts.md`](target-facts.md) | `install/discovery/` | `install/discovery/validate-facts.mjs`, `tests/install/discovery/` |
| [`installation-plan.md`](installation-plan.md) | `install/plan/` | `install/plan/validate-plan.mjs`, `tests/install/plan/` |
| [`installation-confirmation.md`](installation-confirmation.md) | `install/confirmation/` | `install/confirmation/validate-records.mjs`, `tests/install/confirmation/` |

Target facts, installation plans, and installation-confirmation records are `format_version` `2`; an earlier
version is rejected, never migrated. Each document keeps its own version constant. See
[ADR 0006](../docs/adr/0006-guided-live-installation-boundaries.md) for the boundaries they implement.

Contracts are documentation: they are not embedded in the live medium. The validator lives in code.

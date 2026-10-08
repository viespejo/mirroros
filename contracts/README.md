# Contracts

Human-readable format contracts for structured MirrorOS data. A contract here documents a format that
production code already produces and that fixtures and contract tests already enforce. The architecture
reserves final schemas until that evidence exists, so no formal `*.schema.json` files are kept here.

| Contract | Produced by | Enforced by |
| --- | --- | --- |
| [`target-facts.md`](target-facts.md) | `install/discovery/` | `install/discovery/validate-facts.mjs`, `tests/install/discovery/` |

Contracts are documentation: they are not embedded in the live medium. The validator lives in code.

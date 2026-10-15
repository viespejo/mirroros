# ADR 0013: Regional Live Mirror Selection

## Identifier and title

- **Identifier:** `0013`
- **Title:** Regional Live Mirror Selection

## Status

`Accepted`

## Date

`2026-10-15`

## Context and question

The live medium keeps the upstream `releng` hook that uncomments every HTTPS server of `pacman-mirrorlist`, and the
package audit removed `reflector`. The live mirrorlist is therefore the complete HTTPS list in file order: the
Worldwide servers first, then every country alphabetically. Pacman only moves to the next server on an error or a
stalled transfer, not on a slow one. The maintainer observed slow and failing installation and configure runs with
this order, and normal runs after manually keeping only the mirrors of the country of installation.

The engine copies the live mirrorlist unchanged into the target and records it (`contracts/installation-engine.md`),
so the installed system and its configure stage inherit the same order. The question is how the guided installer
can use mirrors near the user without a new question, a new package, or a change to the plan.

## Constraints and decision criteria

- No technical question for a user who does not know pacman; no new installer screen.
- No change to the plan format, its digest, the engine contract, or the live package set.
- Deterministic and offline: no ranking, no network probe, no `reflector`.
- Never block an installation; any doubt leaves the live mirrorlist as it is today.
- Respect a mirror chosen explicitly by the user (boot parameter `mirror=` or a manual edit).

## Alternatives considered

- **Manual edit before `mirroros-install`:** works today, but requires pacman knowledge.
- **A fixed MirrorOS mirrorlist in the image:** deterministic, but a personal location baked into the medium and
  prone to becoming stale.
- **A mirror choice in the plan:** reviewable, but changes the plan format, policy, confirmation, and engine.
- **Restoring `reflector`:** measures speed, but is network-dependent, non-deterministic, and reverses the audit.
- **A dedicated installer screen:** an invasive technical question.

## Evidence

- The recorded mirrors of a reference-VM engine run list `fastly`, `geo`, `infania`, `rackspace`, and then the
  countries alphabetically.
- Attended observation by the maintainer in Spain: slow and failing package transfers with the default order;
  normal transfers with the Spanish mirrors. No measurement was recorded.
- Comparing the section names of the official HTTPS mirrorlist (generated 2026-10-15) with `iso3166.tab` shows four
  differing names: Czechia, South Korea, Türkiye, and United Kingdom.

## Decision

After the final revalidation and before invoking the engine, the guided installer derives a country from the plan's
time zone with the system `zone.tab` and rewrites the live `/etc/pacman.d/mirrorlist`: the section of that country
first, then the Worldwide section as a fallback, then every other section with its active servers commented out.
The selection never uncomments a server and keeps every line of the file.

The live mirrorlist is left unchanged, and the run continues, when the time zone maps to no country or no section,
the section has no active server, the file has no country sections (for example after `mirror=`), the file was already
selected, or any read or write fails. The result is written to `install.log`; the engine still records the servers
and the SHA-256 of the mirrorlist it used.

The mirrorlist is recorded, not confirmed: it is not part of the plan or its digest, so changing the live file after
confirmation grants and changes no authorization.

## Consequences and trade-offs

- Installations use mirrors of the user's time-zone country, and the installed system inherits them.
- The proximity is approximate: a time zone is not a location, and nearby countries are not added.
- Section names that differ from `iso3166.tab` need an alias; an unknown difference falls back to today's behavior.
- A cancelled run leaves the live mirrorlist untouched; a run that reached the engine leaves it selected.

## Replacement or reversal boundary

Revisit this decision if pacman gains speed-based failover, if the mirrorlist format changes, if selected mirrors
prove unreliable, or if the plan gains a reviewed mirror choice.

## Required validation

- Unit tests of the time-zone mapping and the selection, including every fallback.
- One attended installation in Spain whose engine record lists the Spanish servers first.

## References

- [`contracts/installation-engine.md`](../../contracts/installation-engine.md) (`install_packages`, `mirrors`)
- [`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md)
- [`docs/procedures/iso-size-and-live-branding.md`](../procedures/iso-size-and-live-branding.md) (`reflector`)
- [ADR 0006](0006-guided-live-installation-boundaries.md), [ADR 0008](0008-installation-engine-execution-boundary.md)

## Superseded by

`None`

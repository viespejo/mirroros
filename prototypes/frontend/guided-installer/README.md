# Guided installer reference

Frozen presentation and workflow reference for the MirrorOS guided live installer
(plan 02-07). It is the visual and behavioral reference for the production assistant,
not a source of authorization, facts, or policy. Production paths never source anything
here; the production assistant is reimplemented under `install/`.
See [`../README.md`](../README.md) and [`../../README.md`](../../README.md) for the
prototype rules. Provenance and attribution: [`UPSTREAM.md`](UPSTREAM.md).

## Active entry point

`guest-demo.sh` is the only active entry point. It is meant to run on a colored virtual
console (`tty`) of an Omarchy 4.0.4 live ISO, as root, with Gum installed. It requires the
ISO's `/root/configurator` and `mirroros-logo.txt` beside the script, and extracts only the
`step()` presentation function from that configurator. It performs no disk access, collects
no secrets, and invokes no engine; finishing it returns the prototype's non-success status 2.

Screen order: welcome and live keyboard, live connectivity, target selection, disk
selection, storage layout, swapfile size, timezone, system language and regional formats,
installed keyboard, hostname, username, root policy, review, confirmation simulation,
password explanation. The `lib/` helpers implement the individual screens.

## Contents

| Path | Purpose |
| --- | --- |
| `guest-demo.sh` | Guide entry point. |
| `lib/` | One helper per screen or concern (sourced by the entry point). |
| `mirroros-logo.txt` | Logo, drawn two-tone by the entry point. |
| `instructions/live-wifi.txt` | Live Wi-Fi instructions shown by the connectivity screen. |
| `fixtures/` | Synthetic discovery facts and a policy snapshot; see `fixtures/README.md`. |
| `tests/` | Six helper tests using plain Bash doubles. |
| `preview-*.sh` | Presentation-only logo color and separator previews. |
| `LICENSE`, `LICENSE-ISO` | Upstream license texts, preserved unchanged. |

## Synthetic-data limitations

- `fixtures/target-facts.json` is synthetic (`source.run_id` is `ux-preview-synthetic`) and
  derived from one historical discovery result. It never authorizes installation.
- `fixtures/installation-policy.json` is a temporary snapshot of `install/plan/policy.json`
  and is not an independent policy.
- Regional formats, the shared account password, and confirmation behavior shown here are
  design explorations; the production contracts supersede them.
- The confirmation screen is a simulation: no plan, digest, or approval exists.

## Maintainer trial statement

The maintainer reported exercising all prototype screens on the Omarchy 4.0.4 ISO and
accepted that experience as the desired prototype. This is an attributed statement of the
reference experience. It is not MirrorOS qualification, and no MirrorOS integration was
exercised by it.

## Reference-only differences from the original working copy

The preserved copy was taken from `tmp/mirroros-ux-demo/omarchy-style/` (ignored local
material that remains unchanged). Behavior is identical except:

- `fixtures/README.md`: the local check commands use paths relative to this directory
  instead of `/tmp/mirroros-ux-demo/omarchy-style/...`.
- Not copied: `demo.sh` and `logo.txt` (an earlier host-side demo using a personal absolute
  path and a superseded logo; the guest entry point does not use them).
- Not copied: the sibling comparison options (`option-*`), `common.sh`, style JSON files,
  `start-comparison-vm.sh`, and the historical handoff; they are unrelated to this reference.

`fixtures/README.md` still mentions `/mnt/uxdemo/...`, the guest share used by the original
comparison VM; it is retained as historical context and is not a supported launcher.

## Local checks

From this directory:

```bash
for test in disk-selection storage-layout swapfile-size localization root-account confirmation-preview; do
  timeout 5s bash "tests/$test.sh" || break
done
```

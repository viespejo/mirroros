# Frontend contract check

Story 2.1, Track 3, executed by plan 02-03 as a single-candidate contract check. It is non-production:
production paths never source anything here. The outcome is recorded in ADR 0004.

## Question

Can [Gum](https://github.com/charmbracelet/gum) be the interactive presentation layer of the first
MirrorOS version without weakening the interaction model, the plan review flow, the *Terminal output*
rules, the normalized exit statuses, or the secret-handling rules of
[`docs/architecture.md`](../../docs/architecture.md)?

Gum only presents and collects input. The plan, its digest, and `install/engine/apply` never depend on it.

## Scenario

- One candidate (Gum, from the official `extra` repository), driven by mock data only. The mock plan has
  a fictitious target, defaults labeled with provenance, destructive operations marked by the text
  `DESTRUCTIVE:`, and a fictitious digest. No real disk or system state is read or changed.
- One host, two surfaces, the full matrix on each: a terminal emulator (`terminal`) and a host virtual
  console with `TERM=linux` (`vt`).
- No VM, no boot harness, no counted runs.

## Contract points

Each point is recorded in `result.json` with one class: `pass`, `pass-with-wrapper`, or `fail`. A wrapper is
reported only when the native Gum behavior measured by the point does not satisfy the contract; every
reported wrapper becomes a mandatory constraint of ADR 0004.

| Point | Mode | Contract |
| --- | --- | --- |
| C1 | Attended, with transcript | Six-step review flow: target summary; defaults with provenance; destructive operations marked by text; complete plan in `gum pager`; cancellation possible; confirmation showing target and digest. |
| C2 | Automated | Yes returns `0`; no or Esc returns `3`; never a default yes. The Ctrl+C status is recorded only. |
| C3 | Automated | Without a TTY (stdin or stdout redirected) the flow fails with `2` without confirming; no non-interactive flag bypasses it. |
| C4 | Automated | A secret read with `gum input --password` is not echoed, is absent from `/proc/<pid>/cmdline` and transcripts, and a planted canary yields zero findings. |
| C5 | Automated | `NO_COLOR=1` emits zero ANSI color sequences; selection and destructive operations stay distinguishable (captured with `script(1)`). |
| C6 | Automated | `TERM=dumb` degrades without loss of meaning, or fails clearly with `2`. |
| C7 | Attended, visual | The `TERM=linux` console renders borders, spinner glyphs, and colors legibly. |
| C8 | Automated | `gum spin` states the stage in text; the child exit status is preserved (failure normalized to `5`, original status recorded); a failure shows stage, reason, and next action. |
| C9 | Automated | The styled header or welcome appears only with an interactive TTY and is absent without a TTY and in the log. |
| C10 | Automated | The persistent log contains no ANSI sequences and no secrets. |

Outcome rule, agreed before the runs: Accepted only if every point passes natively or with a wrapper;
Rejected if any of C1 to C4 fails; a failure limited to C5 to C10 is decided by the maintainer at the
checkpoint, never automatically.

## Running

```bash
prototypes/frontend/run terminal   # in a terminal emulator
prototypes/frontend/run vt         # in a host virtual console (for example Ctrl+Alt+F3)
```

The run is attended: C1 and C7 prompt for a verdict. The other points run in short `script(1)` ptys.
A run on a dirty tree reports `dirty: true` and is a development run, not evidence.

## Layout

- `run`: entry point; sources the installation harness modules (`resources.sh`, `evidence.sh`,
  `secrets.sh`) as they are, with `PROTO_TRACK=frontend`.
- `lib/flow.sh`: the Gum flow under test, with every wrapper as a named `wrapper_*` function.
- `lib/scenario.sh`: scenario entry points run inside the ptys.
- `lib/points.sh`: C1 to C10.
- `lib/common.sh`, `lib/mock.sh`, `lib/result.sh`: pty driver and detectors, mock plan, result writer.

## Evidence

`evidence/prototypes/frontend/contract-check/<run-id>/` (ignored, never committed): `result.json`,
`run-metadata.json`, transcripts, `flow.log`, `canary-search.json`, and `gitleaks-evidence.json`.
Directories are `0700` and files `0600`; only allowlisted files remain; the redacted Gitleaks scan has no
exclusions. The extra `contract-check` path segment comes from the shared `resources.sh`, which always
derives `<track>/<name>/<run-id>`.

## Result matrix

Both evidence runs executed at commit `78af2aefc722ccfe1bf6a13368f701d0d0653957` with `dirty: false`,
Gum `2.0.2 (879f048)`. Earlier runs were development runs or predate fix commits and do not count. Cells
show the class and the short run-id (`a1144b57` for `terminal`, `c810f5e8` for `vt`).

| Point | `terminal` | `vt` |
| --- | --- | --- |
| C1 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C2 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C3 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C4 | pass (`a1144b57`) | pass (`c810f5e8`) |
| C5 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C6 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C7 | pass (`a1144b57`) | pass (`c810f5e8`) |
| C8 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C9 | pass-with-wrapper (`a1144b57`) | pass-with-wrapper (`c810f5e8`) |
| C10 | pass (`a1144b57`) | pass (`c810f5e8`) |

Each surface: 3 `pass`, 7 `pass-with-wrapper`, 0 `fail`. The canary search and the redacted Gitleaks scan
of the evidence passed on both runs. The attended verdicts of C1 and C7 are `pass` on both surfaces.

| Surface | TERM | Run ID |
| --- | --- | --- |
| `terminal` | `xterm-kitty` | `20261007T231607Z-a1144b57-f5b7-4cd7-b10b-403cae6121f3` |
| `vt` | `linux` | `20261007T230932Z-c810f5e8-ec5d-4111-868f-f798a76bc1bc` |

### Required wrappers

Each wrapper is a named `wrapper_*` function in `lib/flow.sh` and becomes a mandatory constraint of
ADR 0004.

| Wrapper | Serves | Why native Gum is not enough |
| --- | --- | --- |
| `tty_precheck` | C1, C3 | Native `gum confirm` without a terminal returns `1`, not `2`, and `gum spin` silently runs the command. |
| `confirm_status_map` | C1, C2 | Native decline and Esc return `1`; the contract requires `3`. |
| `colorless_confirm` | C5, C6 | Native `gum confirm` shows no focus cue under `NO_COLOR` or `TERM=dumb`; the confirmation uses `gum choose` with a text cursor and the safe answer first. |
| `stage_status_normalization` | C8 | `gum spin` preserves the child status (`7`); the flow normalizes it to `5` and records the original. |
| `spin_plain_fallback` | C8 | Without an interactive terminal the stage is announced as plain text and run directly. |
| `tty_gate` | C9 | Native `gum style` prints the header without a terminal. |

### Outcome

By the pre-agreed rule: no point fails on either surface, and every point passes natively or with a
wrapper, so the derived outcome is **Accepted**, bound to the six wrappers above. The maintainer confirms
it at the ADR 0004 checkpoint.

### Evidence limits

- The host console font may differ from the live ISO console font.
- Ctrl+C returns `130` and is not remapped; its mapping is left to Story 2.4 (TODO-002).
- One host and one run per surface.
- Live ISO console validation belongs to the story that adds `gum` to `image/`.

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

Pending: the evidence runs have not been executed yet.

| Point | `terminal` | `vt` |
| --- | --- | --- |
| C1 | pending | pending |
| C2 | pending | pending |
| C3 | pending | pending |
| C4 | pending | pending |
| C5 | pending | pending |
| C6 | pending | pending |
| C7 | pending | pending |
| C8 | pending | pending |
| C9 | pending | pending |
| C10 | pending | pending |

| Surface | Run ID |
| --- | --- |
| `terminal` | pending |
| `vt` | pending |

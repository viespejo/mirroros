# Story 4.2 (part 2) — Configure in the Installer Target Context: Consolidated Plan

Current state of the design for plan 02-16, which completes Story 4.2 by adding the installer target-root context
to `configure`. Each paragraph cites its decisions in the [decision log](story-4-2-target-context_log.md); earlier
decisions refer to the [part 1 log](story-4-2-minimal-graphical-login_log.md).

## Installer hook

The guided installer reaches `configure` through the installation engine rather than through the assistant. Once
`run_postconditions` reports the base installation as `installed`, the engine runs `operations/configure` from its
embedded code as a final phase, while the target is still mounted under `/run/mirroros/target` and the installer
lock is still held, and only then performs its usual cleanup. The engine remains the single owner of the target
mount and cleanup, the base postconditions are always proven before configuration begins, and the flow matches the
`install/engine/apply → operations/configure` chain in the architecture. The cost is a change to the engine
contract, its run record, and its progress state; ADR 0008 is untouched because it governs how the engine is
reached, not its internal phases. What the installer reports when `configure` fails is decided separately
[DEC-025, DEC-001].

## Engine-phase text width

Because 02-16 touches the installer anyway, it also fixes the progress line that overflows the console while
packages are downloaded, and turns the fix into a rule. At least 80 columns are always available, since the guide
is centered on the 80-column logo, so every fixed text shown during the engine phase must fit 80 columns including
its prefix. This covers the progress screen, the success screen, and the new `configure` phase. For operation
descriptions, which follow the `[<n>/<N>] ` prefix, that means at most 72 characters, a limit recorded in the D17
entry of the confirmation contract and enforced by a test. The package-installation description is reduced to
"Install packages.", and the six other descriptions that exceeded the limit are shortened. Because descriptions are
part of the plan and its digest, the plan fixtures and render snapshots are regenerated in the same change
[DEC-026].

A length limit cannot bound dynamic text such as paths and reasons. The failure and unverified screens already
wrap every line, and the one remaining unwrapped engine-phase screen, the failure shown when the engine leaves no
valid record, is wrapped the same way. The other phases are unchanged [DEC-026].

## Outcome when configure fails

A `configure` failure after the base postconditions pass leaves a verified base system that boots to a text console
but has no graphical environment, so the installer must neither call it ready nor call it a failed installation.
The engine reports a new outcome, `not_configured`, with exit status 4 like `not_verified`, since both mean that
the run finished without a ready system; the assistant tells them apart by the outcome string. Every non-zero
`configure` outcome maps to it, and the engine record keeps the `configure` outcome, the failed step, and the path
of the `configure` evidence inside the target. An interruption during the `configure` phase is treated the same way
rather than as an engine interruption, because the usual "retry with a new plan" advice would be false: in that
phase the engine waits for `configure` to end and records its outcome 3 [DEC-027, DEC-025, DEC-001].

The assistant shows a new screen, D22, stating that the base system is installed and verified and that environment
configuration failed at a named step, with the next action of booting the installed system and running `configure`
there, and a menu to view the `configure` log, restart, return to the shell, or power off. It offers no retry from
the live medium, which would need a remount outside the engine; recovery is always a rerun on the installed system
[DEC-027, DEC-025].

## Code delivery

The `configure` code travels with the installer. `operations/configure` and `capabilities/` join the embedded paths
of the live medium, so they share the installer's source capture, dirty check, and `identity.json`, and the engine
runs `configure` from that embedded copy with `--target-root`, entering the target through `arch-chroot` from the
helpers. Before it invokes `configure`, the engine copies to the target only what `configure` needs, the entry
point, the lifecycle discovery helper, `capabilities/`, and `identity.json`, to the same `/usr/local/lib/mirroros/`
path, owned by root, and adds the launcher `/usr/local/bin/mirroros-configure`. Copying first means the recovery
command named by the D22 screen exists even when `configure` fails [DEC-028, DEC-027, DEC-014].

When no `.git` is present, `configure` takes its code identity from `identity.json` instead of recording it as
unavailable, so evidence on the installed system names the exact commit. The copy is a snapshot of the installed
version, meant only for reruns without a clone: development keeps running `sudo operations/configure` from a
checkout, and the copy is never synchronized or updated automatically. A pacman package and a clone on the target
were rejected as unnecessary weight and as a breach of DEC-014 respectively [DEC-028, DEC-014].

## Target branch in the helpers

In the target context two systems coexist. The `configure` orchestrator runs on the live medium from the embedded
code: it reads the `packages` files, validates, takes the lock, writes evidence, and orders the steps. The installed
system is mounted at `/run/mirroros/target` and is entered only through `arch-chroot`. The helpers follow that split
through a single wrapper, `cfg_exec`, which runs a command directly in the running context and through
`arch-chroot` on `CONFIGURE_ROOT` in the target context. Everything that depends on the target's package database,
users, or systemd goes through it, including the read-only validation queries, so validation never consults the
live medium's packages or accounts by mistake. User files are written through `runuser` inside the target, so `HOME`
comes from the target's `passwd`. System files, links, the lock, and evidence keep working on `cfg_path` paths from
the live medium, as they already do, and no `apply` script changes [DEC-029, DEC-008, DEC-007].

Package transactions in the target run with `SNAP_PAC_SKIP=y`, as the engine's own transactions do after Snapper is
configured, so the installation does not accumulate snap-pac snapshots; on a running system snap-pac acts normally.
Validation in the target context checks `arch-chroot` and `flock` on the live medium and the base tools inside the
target. The lock file lands in the target's on-disk `/run`, which a tmpfs hides at boot, as already decided. One
helper is corrected: the display-manager check reads the unresolved link and compares its base name, because fully
resolving an absolute link from the live medium would point outside the target [DEC-029, DEC-016].

## The --target-root option

The installer context becomes a public, documented option: `operations/configure --target-root <dir> --user <name>`,
run as root, with the existing `--refresh` and `--output`. Before any mutation it requires an absolute, existing
mount point other than `/`, and a non-root user that exists in the target's `passwd`. `--user` is mandatory here,
because `SUDO_USER` means nothing when the engine runs as root on the live medium. Evidence stays on the configured
system under the target's `/var/log/mirroros/configure/<run-id>/`, the engine records that path rather than passing
`--output`, and the run record states the target context. The engine calls it with the mounted target and the
planned user, with no standard input, and appends its output to `engine.log` [DEC-030, DEC-015, DEC-027, DEC-008].

The test-only `MIRROROS_CONFIGURE_ROOT` stays limited to the running context, and combining it with `--target-root`
is a usage error. Target-context tests rely on doubles for `arch-chroot` and `mountpoint` over a temporary root.
The help and the procedure describe the option as the installer context. A root user on the live medium may use it
by hand against a target they mounted, but the assistant never offers that path; the recovery it advertises remains
`sudo mirroros-configure` on the installed system [DEC-030, DEC-027, DEC-028].

## Configure is an engine phase, not a plan operation

`configure` is not an operation of the installation plan but a fixed engine phase that follows the base
postconditions. Making it a plan operation would have forced the postconditions checker to be split, or to check
the base only after configuration, and would have changed the plan schema and everything built on it. What the
phase runs is still bound to the approval: the plan binds the code identity, and `capabilities/` is embedded under
that same identity. To keep the mutation visible before confirmation, the plan review gains one fixed line, within
80 columns, stating that the graphical environment is configured after the base system is verified; its wording is
a new item of the confirmation contract [DEC-031, DEC-025, DEC-028, DEC-026].

## Progress and success screens

The progress screen treats the `configure` phase as one final unit after the plan operations, so the bar reaches
the end only when `configure` succeeds. During the phase the main line reads "Configure the graphical
environment." with the final position, and a second line names the current step with its position, for example
`Configure step: 4/5 desktop/compositor/providers/hyprland`. To feed it, `configure` adds the position to its
existing step marker, and the engine, which already appends the `configure` output to `engine.log`, reads that
output line by line and publishes the current step in two new optional fields of its progress state. No package
count is shown in this phase. The success screen now states that the base system was verified and the graphical
environment configured. The 80-column rule also covers step names, which a test checks against every entry of
`configure-steps` [DEC-032, DEC-026, DEC-031].

## Qualification

The reference VM does not change. The common contract asks that a clean installation plus `configure` succeed in
the reference VM without manual steps, and `qualify-install` already proves this once the engine runs `configure`
inside the installation: every installing case now expects `installed` with a `configure` outcome of 0 in the
engine record. No display device, screen capture, or automated graphical check is added, because the human
checkpoint already exercises the graphical path and automating it again would only cost resources. The one forced
adjustment is that the existing disk-boot login proof moves from tty1 to tty2, since SDDM takes over tty1. Whether
SDDM manages to start on the reference VM's standard VGA does not matter to that proof [DEC-033, DEC-025, DEC-010].

The graphical path, from greeter password to Hyprland, foot, and tmux, together with a rerun through
`sudo mirroros-configure` that changes nothing, is verified by hand in the laboratory VM with `--gl`. That VM is now
installed from the new ISO with no manual code delivery. This also corrects a 02-15 finding: the laboratory VM did
need `--gl`, and without it Hyprland falls back to CPU rendering [DEC-033].

The four installing cases of `qualify-install` now include `configure` and expect its outcome 0 in the engine
record; the cases that stop before or at package installation are unchanged. The plan checkpoint runs the
`default` case as mandatory and the others as the test procedure usually requires. No VM case forces a `configure`
failure, because that would depend on cutting the network at a precise moment; the `not_configured` path is
covered by engine and assistant tests with doubles instead. The 45-minute installation deadline is kept: the
qualification evidence records the real duration, and if a run exceeds it the task stops so that a new value is
chosen from that measurement rather than guessed [DEC-034, DEC-033, DEC-027].

## Greeter keyboard layout

The greeter's keyboard selector displayed `??zz` in 02-15, and nobody checked whether the greeter really applies the
system layout, because that guest used `us`, which a misconfigured greeter would also have produced. The human
checkpoint therefore installs the laboratory VM with the `es` console keymap and a password containing a key whose
position differs between `us` and `es`, and confirms that the password typed in `es` logs in. If it does, the label
is documented as a cosmetic upstream issue (SDDM #2149) in the Hyprland provider notes and nothing changes. If it
does not, it is a defect in the greeter configuration that must be fixed under the Hyprland provider before Story
4.2 can close [DEC-035].

## Closing the 02-15 findings

Package metadata settles the font question: the provisional Nerd Font provides only `ttf-font-nerd`, while `sddm`
depends on `ttf-font`, which `noto-fonts` provides, so the explicit `noto-fonts` declaration is required rather than
precautionary and `capabilities/README.md` cites that evidence. `qt6-wayland` stays out because the graphical path
worked without it, and it is reconsidered only if the clean-install checkpoint shows otherwise. Whether
`localectl set-x11-keymap` writes `XKBLAYOUT` matters only for later layout changes, because the installer writes
`KEYMAP`, which the keyboard module already uses as fallback. The checkpoint records it as a one-command,
non-gating observation and the keyboard notes document the result; none of the three findings changes code
[DEC-036, DEC-035].

## Documentation and registration

Story 4.2 is registered when the 02-16 SUMMARY declares it complete; `docs/epics.md` carries no status and, like
the ADRs, does not change. Documentation moves with the behavior. The engine contract describes the `configure`
phase, the code copy, the `not_configured` outcome, interruption handling, and the new record and state fields. The
confirmation contract gains the width rule, the `configure` progress lines, the new success screen, the D22 screen,
the plan-review line, and the wrapped engine-phase failure. The engine README, the install, configure, build, and
test procedures, `capabilities/README.md`, and the README's `configure` row follow suit. `docs/architecture.md`
changes only in its sentence about the embedded live code. Help texts change with their code, and this interview's
artifacts are committed unchanged [DEC-037, DEC-025, DEC-026, DEC-027, DEC-028, DEC-030, DEC-033, DEC-035,
DEC-036].

## Commits

Nothing is committed while tasks run. Once the human checkpoint is approved, the plan ends by proposing two
commits for the user's explicit confirmation: first the console-width fix with its regenerated fixtures, so it can
be reverted on its own, then the installer integration of `configure` together with this interview's artifacts.
Each commit is preceded by a clean Gitleaks scan and `git diff --check`, and excludes generated output and local
workflow files [DEC-038, DEC-026].

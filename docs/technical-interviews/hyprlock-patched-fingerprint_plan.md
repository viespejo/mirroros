# Screen lock fingerprint with a patched hyprlock — Consolidated Plan

## Background

Canceled plan 02-38 tried hyprlock's native fprintd fingerprint support and stopped because, in hyprlock `0.9.7`, the
password PAM conversation starts when the lock appears; a fingerprint unlock aborts it on exit and `pam_faillock`
records a failure (hyprwm/hyprlock#1074, #1100). A small patch tested on the T14s on 2026-11-16 removes the defect by
starting PAM only after the first submitted input when native fingerprint is enabled, and also fixes the lost reader
after a quick relock and the stale fingerprint prompt once fingerprint is disabled. MirrorOS does not use PAM modules
that prompt before the password, so the deferred start costs nothing here.

## Delivery

The patched locker ships as the local package `hyprlock-mirroros`, which provides and conflicts with `hyprlock` and
installs the same files (`/usr/bin/hyprlock`, `/etc/pam.d/hyprlock`), so the lock launcher, hypridle and the shell
menu keep working without links. It is built by `cfg_local_package_ensure` from a reviewed recipe derived from Arch
`hyprlock 0.9.7-2` plus the MirrorOS patch, with provenance recorded in `sources.md`; `pacman -Syu` never replaces it,
and makepkg's soname dependencies make pacman refuse an incompatible library upgrade rather than break the lock. Arch
updates must be folded into the recipe by hand until upstream fixes the defect. Build dependencies are declared as
packages because makepkg runs without `-s` [DEC-001]. The official `hyprlock` entry leaves the lock step's package
list [TODO-001], the recipe names `etc/pam.d/hyprlock` explicitly instead of deriving it from `$pkgname`
[TODO-002], and replacing an already installed official package is handled as described next
[RISK-001].

Fresh installations never hold the official package, because only `desktop/lock` installs it; already configured
machines are migrated automatically by a new shared helper in `capabilities/lib/packages.sh` (working name
`cfg_local_package_replace`), using documented pacman options only. It builds `hyprlock-mirroros` first and changes
nothing if the build fails; it stops with exit 4, untouched, when `/etc/pam.d/hyprlock` differs from the packaged
content; it then removes the official package with `pacman -Rdd` and installs the built one, reinstalling the official
`hyprlock` and failing if that install does not succeed. The locker binary is absent for one or two seconds during a
user-started configure run; the helper is covered by the mechanism contract tests [DEC-002, RISK-001].

## Patch set

The recipe applies four separate, numbered patches kept next to it (for example `capabilities/desktop/lock/hyprlock/`)
so each can be reviewed, upstreamed or dropped on its own. 0001 starts PAM only after the first submitted input, and
only when `auth:fingerprint:enabled` is set, so without native fingerprint hyprlock behaves exactly as upstream and no
new configuration option exists. 0002 releases the reader as soon as a fingerprint matches, which is what fixed the
quick relock on the T14s. 0003 retries `Claim` on `AlreadyInUse` every 250 ms for up to 5 s as a safety net. 0004
clears `$FPRINTPROMPT` when fingerprint is disabled so no stale state remains on screen [DEC-003].

Patch 0001 is a deliberate MirrorOS divergence: upstream starts PAM when the lock appears on purpose (#1003) to serve
PAM chains that prompt before the password, such as `pam_fprintd` or OTP, which MirrorOS does not use; it is not an
upstream PR candidate and stays in the recipe for as long as MirrorOS ships native lock fingerprint. Patches 0002–0004
are candidates for upstream contribution. hyprlock is BSD-3-Clause; the patches carry no MirrorOS license header, and
the base version, related upstream issues and license are recorded in `sources.md` [DEC-003].

## Presentation

The lock keeps one password field over the background with its static `Enter Password` placeholder, and gains one
line below it showing a fingerprint glyph followed by hyprlock's fingerprint prompt: "Use your fingerprint or
password" when ready, "Reading fingerprint…" while a finger is on the reader, and hyprlock's own retry and no-match
messages. The label runs a minimal MirrorOS script, `/usr/share/mirroros/lock/fingerprint-prompt`, delivered like
`lock-screen` (system file, root:root 0755); it receives only the prompt text, never credentials, performs no D-Bus
query and prints nothing for an empty prompt. Because the patched hyprlock leaves `$FPRINTPROMPT` empty without a
reader, without enrolled prints and once fingerprint is disabled, the line appears exactly when fingerprint can be
used [DEC-004, DEC-003].

`fail_text` combines `$PAMFAIL$FPRINTFAIL`, so a wrong fingerprint shows its error inside the field as a wrong password
does. The line uses the theme's foreground color, 14 pt text and an absolute, slightly larger glyph size, since
hyprgraphics cancels relative Pango sizes; its offset and sizes follow the focused monitor's scale through the geometry
`lock-screen` already generates for the field. This widget is the only change to ADR 0021's single-field lock, recorded
as an amendment in the new ADR [DEC-004].

## Activation

Native fingerprint is enabled statically in the managed `hyprlock.conf` on every target, without any lock-time probe.
On machines without a reader or without enrolled prints the fingerprint line stays empty and hyprlock only logs that
no fprintd device exists; with patch 0001 PAM starts at the first submitted password everywhere, as in hyprlock
`0.9.5`, so a faillock lockout message appears on submission rather than when the lock appears. A blocking gate in the
reference VM (no reader) and on the T14s without enrolled prints requires the lock to look and behave as today with no
perceptible added delay; a failure stops the plan at a checkpoint where a lock-time reader probe is decided [DEC-005].

## Suspend and resume

No suspend/resume mitigation ships. Omarchy's fprintd restart hook solves a wedged claim in a `pam_fprintd` lock
that retries PAM sessions in a loop; hyprlock instead keeps its claim across sleep and only restarts verification on
resume, so restarting fprintd would drop that claim and likely remove fingerprint after every resume. The T14s
campaign runs five suspend → resume → fingerprint unlock cycles started by the maintainer on the laptop, never through
remote `sudo`, checking that fingerprint responds, faillock is unchanged and the journal shows no `Claim` or
`VerifyStart` errors. A failure stops the plan at a checkpoint to decide a hyprlock patch 0005 that re-claims the
reader after resume, not the Omarchy hook [DEC-006].

## Reader contention

fprintd serves one client at a time, so a polkit or `sudo` fingerprint prompt that is pending when the lock starts,
or a polkit helper still holding the reader for up to 30 s after Escape (plan 02-37's L-1), denies hyprlock the
reader. Patch 0003 therefore retries `Claim` for about 35 s with backoff growing from 250 ms to 2 s, which covers the
post-Escape hold and dialogs closed shortly after locking; the password always remains available. The limitation is
documented next to L-1 in `docs/procedures/hardware.md` [DEC-007].

A pending privileged prompt hidden under the lock is a real risk: a touch meant to unlock would authorize that request
instead [RISK-002]. The plan does not change the polkit agent, which ADR 0030 keeps isolated and which could not cover
`sudo` in a terminal anyway. The T14s campaign measures both contention cases, requiring that the password always
unlocks and recording when fingerprint becomes available and what a touch authorizes; a checkpoint then decides
whether cancelling pending agent requests on lock is needed, here or in a separate plan [DEC-007, RISK-002].

## Governance

A single ADR 0031, "Patched hyprlock with native fingerprint for the screen lock", extends ADR 0030, which had left
lock fingerprint out of scope. It records two bounded exceptions: MirrorOS patches inside the authentication provider
(an exception to ADR 0012, limited to patches 0001–0004 with no new credential handling, no fake PAM success, no
faillock reset and each patch removable on its own), and fingerprint verification by fprintd outside PAM while the
password keeps the packaged `hyprlock` PAM service. It amends ADR 0021 for the fingerprint line and its script, fixes
the `hyprlock-mirroros` delivery and automatic replacement, and is reconsidered when upstream fixes #1074, a patch no
longer applies to a new release, a blocking gate fails or more owned code is proposed for the lock [DEC-008].

The first task drafts the ADR with its normative companions: a `docs/architecture.md` bullet after the ADR 0030
fingerprint line, the `docs/mvp-scope.md` fingerprint and screen-lock rows with the pending lock-fingerprint item
removed, and the ADR index. Following the faster pattern of earlier plans, the maintainer accepts it at a checkpoint
immediately after drafting; later gate failures go to their predefined checkpoints and amend the ADR if needed
[DEC-008].

## Workflow and gates

Work happens directly in the `main` working tree with targeted tests only. The laboratory needs a clean checkout for
`operations/configure`, so a single temporary ref, `refs/mirroros-candidates/02-39`, travels as a bundle and is
regenerated in place after fixes; it is deleted at adoption once the maintainer confirms. Adoption produces two
unpushed commits: `docs(adr)` with ADR 0031, the architecture, scope and index updates and these interview artifacts,
and `feat(lock)` with the recipe, patches, replacement helper, prompt script, configuration, tests, sources,
hardware procedure and T14s README [DEC-009].

The blocking gates cover only what packaging and configure add to the T14s prototype. In the reference VM, without a
reader, configure replaces the official package and exits 0, a rerun changes nothing, PAM hashes stay identical, and
the lock looks and behaves as today without delay; the edited-PAM refusal is left to contract tests. On the T14s the
quick test is withdrawn first, then configure replaces the package and reruns cleanly, and one maintainer session
covers fingerprint unlock with an unchanged tally and a quick relock, wrong and correct passwords, fingerprint
exhaustion with the line disappearing, the no-prints case with a re-enrollment, five resume cycles, both contention
cases and a polkit/sudo regression check. Visual review happens on the T14s at scale 1.6, with other scales covered by
a contract test of the generated geometry [DEC-009, DEC-005, DEC-006, DEC-007].

## Ownership and maintenance

`desktop/lock` relies on `system/fingerprint` for `fprintd` and `libfprint` instead of declaring them again, keeping
one owner per package; its `sources.md` records the dependency and a contract test pins `system/fingerprint` before
`desktop/lock` in `capabilities/configure-steps` [DEC-010]. Since Arch updates no longer reach `hyprlock-mirroros`
automatically, `docs/procedures/hardware.md` documents the manual recipe update: bump `pkgver` and the checksum,
confirm that the patches still apply and rerun the minimal gates [DEC-010, DEC-001]. Offering patches 0002–0004
upstream and a check that warns when Arch is ahead of the recipe are follow-ups recorded in the plan SUMMARY, outside
this plan [DEC-010].

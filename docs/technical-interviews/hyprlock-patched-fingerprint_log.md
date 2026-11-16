# Screen lock fingerprint with a patched hyprlock — Decision Log

Interview for the plan that adds fingerprint authentication to the screen lock through a MirrorOS-patched hyprlock.
It follows canceled plan 02-38 (native hyprlock fingerprint), which stopped because successful fingerprint unlocks in
hyprlock `0.9.7` left `pam_faillock` failures (upstream issues hyprwm/hyprlock#1074 and #1100, eager PAM start from
#1003). Its archived interview (`evidence/lock/lab-02-38/canceled-project-docs/`) is historical context only; its
decisions are reconsidered here explicitly, not inherited.

Laboratory basis (2026-11-16, T14s, ignored `evidence/lock/quick-fprint-patch/`): a patch against hyprlock `0.9.7`
(Arch `0.9.7-2` source, SHA-256 verified) was built in the reference VM and run unpackaged on the T14s. It defers PAM
until the first submitted input when native fingerprint is enabled, releases the reader on a fingerprint match, retries
`Claim` on `AlreadyInUse` for up to 5 s, and clears `$FPRINTPROMPT` when fingerprint is disabled. Observed: fingerprint
unlocks left no faillock record and no `conversation failed`; wrong passwords counted and a correct password cleared
the tally; relock after a fingerprint unlock claimed the reader at once; wrong fingerprints showed the error in the
field. The PAM-first conversation that #1003 enables (modules prompting before the password) is not used by MirrorOS.

## DEC-001
- **Question**: How is the patched hyprlock delivered: same package name `hyprlock` with a local pkgrel, an own
  package name that provides and conflicts with `hyprlock`, or a binary outside pacman?
- **Context/Nuances**: `cfg_local_package_ensure` (used by `strata-bin` and `sesh`) builds a reviewed in-repository
  PKGBUILD as the selected user with `makepkg` (without `-s`) and installs the result as root. Same name with
  `pkgrel=2.1` is silently replaced by `pacman -Syu` on the next Arch release, dropping the patch and restoring the
  faillock defect, unless `IgnorePkg` is managed. A direct binary conflicts with the architecture's package trust rule
  (explicit rationale, not tracked by pacman). An own name is never replaced by `-Syu` (no `replaces`), but Arch
  updates also stop arriving until the recipe is bumped; makepkg's automatic soname dependencies
  (`libhyprutils.so=13` etc.) make pacman refuse an ABI-breaking library upgrade instead of leaving a locker that
  does not start. Package-name consumers were checked: `lock-screen`, hypridle's `pidof hyprlock` and the shell menu's
  `command -v hyprlock` use the binary, which keeps the path `/usr/bin/hyprlock`; no symbolic link is needed.
- **User Response**: Yes (option b).
- **Decision**: The patched hyprlock is a local package `hyprlock-mirroros` with `provides=(hyprlock)` and
  `conflicts=(hyprlock)`, built through `cfg_local_package_ensure` from a reviewed recipe derived from Arch
  `hyprlock 0.9.7-2` plus the MirrorOS patch as an additional source, with provenance in the governing `sources.md`.
  The build dependencies (`cmake`, `hyprwayland-scanner`) are declared as packages because makepkg runs without `-s`.
  The recipe is maintained manually until upstream fixes the defect.
- **Status**: Accepted

## TODO-001
- Remove `hyprlock extra` from `capabilities/desktop/lock/packages`; otherwise configure installs the official
  package, which conflicts with `hyprlock-mirroros`.

## TODO-002
- The Arch recipe uses `$pkgname` in `backup=("etc/pam.d/$pkgname")` and the license directory; the derived recipe
  must name `etc/pam.d/hyprlock` explicitly so the packaged PAM service path and its backup handling are unchanged.

## RISK-001
- Replacing an installed official `hyprlock`: with `conflicts`, `pacman -U --noconfirm` answers the default "N" to
  removing the conflicting package and fails. The replacement needs an explicit, reviewed step (to be decided).

## DEC-002
- **Question**: How does configure replace an installed official `hyprlock` with `hyprlock-mirroros` (RISK-001)?
- **Context/Nuances**: Neither the image nor the installer preinstalls `hyprlock`; only `desktop/lock` installs it,
  so fresh installations never meet the conflict, only already configured machines (reference VM, T14s). Options:
  stop with exit 4 and a documented manual command (a manual step per machine for a state MirrorOS itself created);
  one atomic `pacman -U --ask=4` transaction (`--ask` is undocumented in pacman 7.0); or an automatic two-step
  replacement using documented options only, leaving `/usr/bin/hyprlock` absent for one or two seconds during a
  user-started configure run.
- **User Response**: Yes (option c).
- **Decision**: A new shared helper in `capabilities/lib/packages.sh` (working name `cfg_local_package_replace`)
  performs the replacement with documented pacman options only: (1) build the local package first, changing nothing
  if the build fails; (2) require `/etc/pam.d/hyprlock` to match the packaged content (`pacman -Qkk hyprlock`),
  otherwise exit 4 without changes so a locally edited file is never overwritten silently; (3)
  `pacman -Rdd --noconfirm hyprlock` followed by `pacman -U --noconfirm` of the built package; (4) if the install
  fails, reinstall the official `hyprlock` and fail. Covered by the mechanism contract tests.
- **Status**: Accepted

## RISK-001 — resolved
- Resolved by DEC-002.

## DEC-003
- **Question**: Which changes does the patch set contain, how is deferred PAM start activated, and how are the
  patches organized?
- **Context/Nuances**: The tested patch has four changes: (1) deferred PAM start until the first submitted input
  (fixes #1074/#1100); (2) release the reader on a fingerprint match (this fixed the quick relock in the T14s test);
  (3) retry `Claim` on `AlreadyInUse` every 250 ms for up to 5 s (a safety net, not exercised in the test);
  (4) clear `$FPRINTPROMPT` when fingerprint is disabled. Activation options for (1): only with
  `auth:fingerprint:enabled`, always, or a new option. hyprlock is BSD-3-Clause (`Copyright (c) 2024, Hypr
  Development`). The maintainer noted that (1) is unlikely to be accepted upstream: starting PAM when the lock
  appears is a deliberate upstream design (#1003) that serves PAM chains prompting before the password
  (`pam_fprintd`, OTP), which MirrorOS does not use.
- **User Response**: Yes; patch 1 does not look like an upstream PR candidate.
- **Decision**: The patch set contains the four tested changes. Deferred PAM start is active only when
  `auth:fingerprint:enabled` is set; without it hyprlock behaves as upstream and no configuration option is added.
  The changes ship as four separate numbered patch files (`0001`–`0004`) next to the recipe (for example
  `capabilities/desktop/lock/hyprlock/`), so each can be reviewed, upstreamed or dropped independently. The patches
  carry no MirrorOS license header; base version, related upstream issues and the BSD-3-Clause license are recorded
  in `sources.md`. Patch 0001 is a MirrorOS-maintained divergence, not an upstream PR candidate; patches 0002–0004 are
  candidates for upstream contribution.
- **Status**: Accepted

## DEC-004
- **Question**: How is fingerprint availability presented on the lock within ADR 0021 (one password field over the
  background)?
- **Context/Nuances**: A line below the field is a new widget, so the new ADR amends ADR 0021 on that point. Option
  (a), as validated on the T14s: a label `cmd[update:0] /usr/share/mirroros/lock/fingerprint-prompt "$FPRINTPROMPT"`
  running a MirrorOS script that prints the glyph and the message when the message is non-empty; the glyph appears in
  every fingerprint state, at the cost of hyprlock running owned code through `sh -c` on each state change (the script
  receives only the prompt text, never credentials). Option (b): the glyph inside `ready_message`/`present_message`
  and a plain `$FPRINTPROMPT` label; no owned code, but hyprlock's hard-coded states (retry, no match) appear
  without the glyph. With patch 0004 and an unpatched no-reader/no-prints path, `$FPRINTPROMPT` is empty without a
  reader, without enrolled prints and once fingerprint is disabled, so no D-Bus probe is needed. hyprgraphics `0.6.0`
  inserts `pango_attr_scale_new(1)` over the whole text, which cancels relative Pango sizes (`larger`, `x-large`);
  only an absolute `size` enlarges the glyph.
- **User Response**: (a).
- **Decision**: A label below the field shows `<fingerprint glyph>  <message>` through a minimal MirrorOS script,
  `/usr/share/mirroros/lock/fingerprint-prompt` (no D-Bus, prints nothing for an empty argument), delivered like
  `lock-screen` with `cfg_system_file`, root:root 0755. `ready_message = Use your fingerprint or password`,
  `present_message = Reading fingerprint…` (English only). The field keeps the static `Enter Password` placeholder,
  and `fail_text` becomes `<i>$PAMFAIL$FPRINTFAIL</i>` so a wrong fingerprint shows its error in the field. The label
  uses the theme's `$foreground` with 14 pt text and an absolute, slightly larger glyph size; its position and sizes
  follow the focused monitor's scale through `lock-screen`'s generated geometry, like the field (DEC-012 of the lock
  geometry work). The new ADR amends ADR 0021 for this one widget.
- **Status**: Accepted

## DEC-005
- **Question**: Is native lock fingerprint enabled statically on every target, or decided at lock time by
  `lock-screen` from a reader probe?
- **Context/Nuances**: Plan 02-38's reference-VM gate (no reader) showed only a log line
  `fprint: couldn't connect to Fprint service (NoSuchDevice)`, an unchanged placeholder and no perceptible delay. A
  cold fprintd D-Bus activation measured ~65 ms in the VM and ~470–500 ms on the T14s with a reader; in the
  2026-11-16 T14s runs the session was already locked before hyprlock claimed the reader. With patch 0001, every
  target starts PAM only at the first submitted password (hyprlock `0.9.5` behavior); the only visible difference is
  that a faillock lockout message appears on submission rather than when the lock appears. A lock-time USB probe
  (~6 ms on the T14s) would avoid fprintd activation on machines without a reader, but adds a probe to the lock path
  and misses non-USB readers.
- **User Response**: Yes (option a with the blocking gate).
- **Decision**: `auth { fingerprint:enabled = true }` is static in the managed `hyprlock.conf` on every target; no
  lock-time probe is added. Blocking gate: in the reference VM (no reader) and on the T14s without enrolled prints,
  the lock looks and behaves as today (no fingerprint line, password unlock and wrong-password message unchanged)
  with no perceptible added delay. If the gate fails, the plan stops at a checkpoint where the lock-time probe
  alternative is decided, not improvised.
- **Status**: Accepted

## DEC-006
- **Question**: Does the plan ship a suspend/resume mitigation for fprintd, such as Omarchy's resume hook, or decide
  from evidence?
- **Context/Nuances**: The lock starts before sleep, so hyprlock holds the reader when the system suspends. Omarchy
  `7075b61` (commit `879d6583d`) ships `/usr/lib/systemd/system-sleep/fprintd-resume`
  (`systemctl --no-block try-restart fprintd.service` on `post`) and `fprintd.service.d/10-stop-timeout.conf`
  (`TimeoutStopSec=3s`) for fprintd issue #173: a verify open across suspend fails with "Cannot run while
  suspended", the claim stays wedged, and Omarchy's `pam_fprintd`-based lock keeps retrying PAM sessions so fprintd
  never reaches its 30 s idle exit. hyprlock uses fprintd over D-Bus without a retry loop: on `PrepareForSleep(false)`
  it calls `VerifyStart` on the reader it already claimed, without a new `Claim`. Restarting fprintd after resume
  would drop that claim, `VerifyStart` would fail with "Device was not claimed", and hyprlock `0.9.7` does not
  recover, so the hook would likely remove fingerprint after every resume, besides adding owned code that restarts a
  system service affecting polkit and sudo. Plan 02-38 recorded at least one successful fingerprint unlock after a
  resume on the T14s (`manual-runs/20261116-044620-resume-01`), but its campaign was incomplete and confounded by
  remote `sudo`.
- **User Response**: Yes (option a, with a hyprlock patch as the failure route).
- **Decision**: No suspend/resume mitigation is shipped and Omarchy's hook and drop-in are not adopted. The T14s
  campaign includes five suspend → resume → fingerprint unlock cycles started by the maintainer on the laptop (lid or
  session menu), never through remote `sudo`, so the faillock tally is not cleared between measurements. Each cycle
  records whether fingerprint responds after resume, that faillock is unchanged, and that the journal shows no
  `Claim`/`VerifyStart` errors. If any cycle fails, the plan stops at a checkpoint to decide a hyprlock patch 0005
  (for example, re-claim the reader when `VerifyStart` fails after resume), not the Omarchy hook.
- **Status**: Accepted

## DEC-007
- **Question**: How does the plan handle reader contention with a pending polkit or `sudo` fingerprint prompt when
  the lock starts?
- **Context/Nuances**: fprintd allows one claimant. Case (i): a polkit dialog or a `sudo` in a terminal is waiting
  for a finger when the lock starts (for example on idle). Case (ii): Escape on a polkit dialog, then a lock within
  30 s, while `polkit-agent-helper-1` still holds the reader (plan 02-37 limitation L-1). In both, hyprlock's `Claim`
  gets `AlreadyInUse`; with patch 0003 retrying for only 5 s, that lock stays without fingerprint while the password
  still works. In case (i), touching the reader to unlock authorizes the hidden pending polkit/`sudo` request instead
  of unlocking; this already exists today but becomes far more likely once touching the reader is the habitual
  unlock gesture. Having the polkit agent cancel pending requests on lock would cross ADR 0030's agent isolation and
  would not cover `sudo` in a terminal.
- **User Response**: Yes (option c).
- **Decision**: Patch 0003's retry window grows to about 35 s with increasing backoff (250 ms up to 2 s), covering
  the 30 s `pam_fprintd` hold of case (ii) and a dialog closed shortly after locking; only constants change, no new
  code path. The limitation and the hidden-request risk are documented in `docs/procedures/hardware.md`
  (`## Fingerprint`) next to L-1. The T14s campaign covers (i) a pending polkit dialog, then lock, then a touch, and
  (ii) Escape on a polkit dialog, then lock within 30 s; blocking criterion: the password always unlocks; recorded:
  whether and when lock fingerprint becomes available, and what a touch authorizes in case (i). The result is
  reviewed at a checkpoint that decides whether agent cancellation on lock is needed, in this plan or a separate one.
- **Status**: Accepted

## RISK-002
- With a polkit or `sudo` fingerprint prompt pending under the lock, a touch meant to unlock authorizes that hidden
  request instead. Measured on the T14s (DEC-007) before deciding any agent change; not mitigated by this plan unless
  the checkpoint decides so.

## DEC-008
- **Question**: What does the new ADR cover, and how is it accepted?
- **Context/Nuances**: Number 0031 is free (the rejected 02-38 draft left no trace). A MirrorOS-patched hyprlock puts
  owned code in the authentication provider, a stronger exception to ADR 0012 than plan 02-38 recorded; native
  fingerprint is verified by fprintd outside PAM (`docs/architecture.md` line 310); ADR 0030 left lock fingerprint
  out of scope as a reopening trigger; ADR 0021 defines a single-field lock; `docs/mvp-scope.md` rows 59 ("not for
  the screen lock") and 68 and the pending item at line 215 are affected. The assistant proposed the 02-37/02-38
  pattern (Proposed, text review, Accepted only after laboratory gates). The maintainer preferred the faster pattern
  of earlier plans, since most behavior is already tested and approved on the T14s.
- **User Response**: One ADR, accepted at a checkpoint right after it is drafted; less ceremony.
- **Decision**: A single ADR 0031 ("Patched hyprlock with native fingerprint for the screen lock") extends ADR 0030;
  records the ADR 0012 exception (MirrorOS patches 0001–0004 in the authentication provider, bounded: no new
  credential handling, no fake PAM success, no faillock reset, each patch removable on its own) and the exception to
  "PAM owns authentication" (fprintd verifies the fingerprint outside PAM; the password keeps the packaged `hyprlock`
  PAM service); amends ADR 0021 for the fingerprint line and the `fingerprint-prompt` script; fixes the delivery
  (`hyprlock-mirroros` local package, automatic replacement of the official package); and lists reconsideration
  triggers (upstream fixes #1074, a patch stops applying to a new release, a blocking gate fails, more owned code in
  the lock is proposed). The first task drafts it together with the `docs/architecture.md` bullet after line 311,
  the `docs/mvp-scope.md` updates (rows 59 and 68, pending item removed) and the ADR index; the maintainer accepts it
  at a checkpoint immediately after drafting. A later blocking gate failure is handled at its predefined checkpoint
  (DEC-005, DEC-006, DEC-007), amending the ADR if needed.
- **Status**: Accepted

## DEC-009
- **Question**: What is the delivery workflow and the minimal blocking gate set?
- **Context/Nuances**: The maintainer asked for less ceremony; most behavior was already exercised on the T14s with
  the unpackaged patched binary. The laboratory runs `operations/configure` from a clean git checkout, so a candidate
  snapshot is still needed. Only what the real package and configure delivery add remains untested.
- **User Response**: Yes, as proposed.
- **Decision**: Work happens in the `main` working tree with targeted tests only. One temporary candidate ref,
  `refs/mirroros-candidates/02-39`, is shipped to the laboratory as a bundle and regenerated in place after fixes
  (no `-a/-b/-c` series); it is deleted at adoption with the maintainer's confirmation. Two commits land on `main`,
  not pushed: `docs(adr)` (ADR 0031, `docs/architecture.md`, `docs/mvp-scope.md`, ADR index, these interview
  artifacts) and `feat(lock)` (recipe, patches, helper, script, configuration, tests, `sources.md`,
  `docs/procedures/hardware.md`, T14s README). Blocking gates:
  - **VM (no reader):** configure replaces the official `hyprlock` with exit 0; a rerun is unchanged; PAM hashes are
    unchanged; the lock looks as today with no fingerprint line and no perceptible delay; the password unlocks and a
    wrong password shows its message. The edited `/etc/pam.d/hyprlock` exit 4 case is covered by contract tests, not
    in the laboratory.
  - **T14s:** first withdraw the quick test (restore `hypridle.conf` and `hyprlock.conf`, remove
    `quick-fprint-test/`), then configure with the replacement and a rerun. One maintainer session then covers:
    (1) fingerprint unlock with faillock unchanged and a relock within 1–2 s; (2) a wrong password counts and the
    correct one clears the tally; (3) wrong fingerprints until fingerprint is disabled, the line disappears, password
    unlocks; (4) without enrolled prints (delete with `fingerprint-setup`, lock, re-enroll) the lock looks as before
    (DEC-005); (5) five resume cycles (DEC-006); (6) both contention cases (DEC-007); (7) polkit and `sudo`
    fingerprint regression.
  - **Visual:** on the T14s at scale 1.6 only; other scales are covered by a contract test of the geometry generated
    by `lock-screen`.
- **Status**: Accepted

## DEC-010
- **Question**: Closing items: fprintd ownership for the lock, upstream contribution of patches 0002–0004, and
  recipe maintenance.
- **Context/Nuances**: `system/fingerprint` installs `fprintd` and `libfprint` on every target and already precedes
  `desktop/lock` in `capabilities/configure-steps`; declaring fprintd in both steps would create two owners of one
  package. Opening upstream pull requests needs the maintainer's GitHub account and does not gate delivery. Arch
  updates no longer reach `hyprlock-mirroros` automatically (DEC-001).
- **User Response**: Yes, all three.
- **Decision**: (1) `desktop/lock` depends on `system/fingerprint` and does not redeclare fprintd; `sources.md`
  documents the dependency and a contract test pins `system/fingerprint` before `desktop/lock` in
  `capabilities/configure-steps`. (2) Upstream contribution of patches 0002–0004 is out of scope and recorded as a
  follow-up in the plan SUMMARY. (3) No recipe-update automation in this plan: `docs/procedures/hardware.md`
  documents the manual update (bump `pkgver` and checksum, verify the patches apply, rerun the minimal gates); a
  check warning that Arch is ahead is a separate follow-up.
- **Status**: Accepted

## TODO-002 — resolved in the recipe task
- The derived recipe names `etc/pam.d/hyprlock` and the license directory explicitly (DEC-001); verified by a
  contract test on the recipe.

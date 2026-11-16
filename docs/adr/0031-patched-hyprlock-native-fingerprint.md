# ADR 0031: Patched hyprlock with native fingerprint for the screen lock

## Identifier and title

- **Identifier:** `0031`
- **Title:** Patched hyprlock with native fingerprint for the screen lock

## Status

`Accepted`

The maintainer accepted this ADR on 2026-11-16 at the plan 02-39 checkpoint immediately after the normative document
review (DEC-008). At the Task 8 DEC-007 checkpoint on the same date, the maintainer explicitly authorized extending
this accepted ADR to patch 0005 and package `0.9.7-2.2` after the cross-client match finding below. Acceptance of the
architecture decision and its amendment does not establish that the package and laboratory gates have passed;
residual contention-risk acceptance remains conditional on the corrected candidate's attended tests.

## Date

`2026-11-16`

## Context and question

[ADR 0030](0030-shell-hosted-polkit-agent-and-fingerprint.md) enabled fingerprint authentication in `polkit-1` and
`sudo`, left the screen lock unchanged and made lock fingerprint a reconsideration trigger. The lock remains hyprlock,
not project-owned QML, with the presentation bounded by [ADR 0021](0021-neutral-greeter-and-themed-lock.md).

Canceled plan 02-38 found that hyprlock `0.9.7` starts its password PAM conversation when the lock appears. A native
fingerprint unlock aborts that conversation on exit and leaves a `pam_faillock` failure, even though authentication
succeeded (upstream issues #1074 and #1100). Eager PAM startup is intentional in #1003: it supports PAM modules that
prompt before the password. MirrorOS uses no such modules in the packaged `hyprlock` PAM service.

On 2026-11-16, an unpackaged patched build on the T14s deferred PAM until submitted input, released the reader on a
match, retried a busy reader and cleared disabled fingerprint prompts. Fingerprint unlocks left no faillock record;
wrong passwords counted, a correct password cleared the tally, quick relocking retained fingerprint, and wrong
fingerprints showed their error in the field. Packaging, migration, no-reader/no-prints behavior, resume and contention
still require the plan 02-39 gates.

The question is whether MirrorOS may maintain bounded patches inside the lock's authentication provider and use
fprintd outside PAM for fingerprints, while preserving the password PAM path and the existing lock presentation.

## Constraints and decision criteria

- Keep `/usr/bin/hyprlock` and the packaged `/etc/pam.d/hyprlock` service; no PAM stack content changes.
- No new credential handling, fake PAM success, automatic faillock reset or credential logging.
- Password authentication remains available independently of reader availability and contention.
- Without a reader or enrolled prints, the lock must look and behave as before, with no perceptible added delay.
- Keep the owned patch set small, independently removable and attributable; no MirrorOS license headers on patches
  or the derived recipe. Record provenance and the upstream BSD-3-Clause license in the governing `sources.md`.
- Use documented pacman options only, build without automatic dependency installation, and refuse modified PAM files.
- Real lock and suspend actions are maintainer-started; laboratory sudo runs only in an attended tmux window, with no
  remote sudo between faillock baseline and measurement.

## Alternatives considered

1. **Keep password-only locking.** No provider patches or authentication exception, but leaves the proven fingerprint
   path unavailable at the lock.
2. **Enable unmodified hyprlock native fingerprint.** Small configuration change, rejected because successful unlocks
   leave faillock failures (#1074, #1100).
3. **Add fingerprint to the lock's PAM stack.** Changes the password path and PAM stacks, outside this decision's scope.
4. **Ship a patched binary outside pacman or retain the official package name.** An unmanaged binary loses package
   traceability; the official name would let a later Arch upgrade silently replace the fixes unless updates were pinned.
5. **Local `hyprlock-mirroros` package with five patches (selected, amended at DEC-007).** Preserves the binary and PAM paths and prevents
   silent replacement, at the cost of manual recipe maintenance and a bounded owned authentication-provider surface.
6. **Lock-time reader probe or proactive fprintd resume restart.** Adds lock-path code or disrupts the native client's
   reader claim. Neither ships; evidence-driven failure checkpoints govern any reconsideration.

## Evidence

- [Interview decision log](../technical-interviews/hyprlock-patched-fingerprint_log.md), DEC-001–DEC-010, and
  [consolidated interview plan](../technical-interviews/hyprlock-patched-fingerprint_plan.md).
- Local ignored prototype artifacts under `evidence/lock/quick-fprint-patch/`: Arch `hyprlock 0.9.7-2` recipe,
  verified source tarball, pristine and patched trees, patch and tested binary. Source SHA-256:
  `01145790570ffabd31e9b528c517bdccae76f36e72d733f00c2696d9c3bf2c88`; tested binary SHA-256:
  `19a0020c7cc01299a2dffb360d276772d57450de1e55d1df4479eac093f5f796`.
- Historical ignored `evidence/lock/lab-02-38/`: no-reader observations, fprintd discovery timings, faillock diagnosis
  and the remote-sudo measurement confounder. The canceled plan's decisions are not inherited.
- The prototype's busy-reader retry was 20 × 250 ms; the approximately 35-second backoff in this decision is the
  DEC-007 extension, not a result already demonstrated by that prototype.

## Decision

**Authentication and delivery.** Extend ADR 0030 to use hyprlock's native fprintd D-Bus client for fingerprint
verification in parallel with the password field. Ship `hyprlock-mirroros 0.9.7-2.2`, derived from Arch
`hyprlock 0.9.7-2` with five separate patches (the first four were tested as `0.9.7-2.1`):

- **0001 — defer PAM start until input:** start PAM only after the first submitted input when
  `auth:fingerprint:enabled` is set. With native fingerprint disabled, preserve upstream behavior. This is a deliberate
  divergence from #1003, not an upstream contribution candidate, because MirrorOS does not need pre-password prompts.
- **0002 — release on match:** release the reader as soon as a fingerprint matches so a quick relock can claim it.
- **0003 — retry a busy claim:** retry `net.reactivated.Fprint.Error.AlreadyInUse` for about 35 seconds, with backoff
  from 250 ms doubling to a 2-second ceiling; do not retry while fading out or terminating.
- **0004 — clear disabled prompts:** clear `$FPRINTPROMPT` after too many failures, unknown errors, disconnects and
  failed verification restarts.
- **0005 — ignore unowned verification signals:** accept fingerprint status and presentation only while this client
  owns the reader and has initiated its own verification. Track claim ownership separately from a pending claim;
  invalidate verification before stop/release and reject obsolete asynchronous replies. A busy reader leaves the
  fingerprint line empty; the existing bounded retry can restore it only after an own claim and verification.

The package provides and conflicts with `hyprlock`, keeps `/usr/bin/hyprlock` and the byte-identical packaged
`/etc/pam.d/hyprlock`, lists the latter in `backup`, retains the Arch dependency declarations and generated soname
dependencies, and names `/usr/share/licenses/hyprlock-mirroros/` explicitly. It does not use `replaces`.

Configure uses a shared `cfg_local_package_replace` helper: an already-current local package is unchanged; otherwise
build first as the selected user with `makepkg` without `-s`. If the official package is installed, require its
protected PAM file to match packaged content through `pacman -Qkk`; a local modification stops configure with exit 4
without system changes. Remove the official package with `pacman -Rdd --noconfirm`, then install the local artifact
with `pacman -U --needed --noconfirm`. A failed install attempts to reinstall official `hyprlock` and fails configure.
A fresh target installs the local package directly. No undocumented `--ask` option is used.

`desktop/lock` relies on the preceding `system/fingerprint` step for `fprintd` and `libfprint`, rather than declaring
those packages twice. The lock step declares its build dependencies and records recipe and patch provenance in
`capabilities/desktop/lock/sources.md`.

**Bounded exceptions.** This ADR extends ADR 0030 and grants an exception to
[ADR 0012](0012-owned-quickshell-desktop-shell.md)'s prohibition on owned authentication surfaces, limited to patches
0001–0005 inside the provider: no new credential handling, no fake PAM success, no faillock reset, and each patch
removable independently. It also grants an exception to "PAM owns authentication": fprintd verifies fingerprints
outside PAM; passwords still use the packaged `hyprlock` PAM service. The lock is never project-owned QML. Other
ADR 0012 and ADR 0030 boundaries, including polkit-agent isolation, remain unchanged.

**Activation and presentation.** Enable native fingerprint statically on every target, without a lock-time probe.
Use `ready_message = Use your fingerprint or password` and `present_message = Reading fingerprint…`. Keep the static
`Enter Password` placeholder and set `fail_text = <i>$PAMFAIL$FPRINTFAIL</i>`.

Amend ADR 0021 only for one label below the password field. It runs
`cmd[update:0] /usr/share/mirroros/lock/fingerprint-prompt "$FPRINTPROMPT"`; the minimal owned script prints nothing for
an empty argument, otherwise a Nerd Font fingerprint glyph (U+F0237) followed by two spaces and the prompt. It receives
no credentials, makes no D-Bus query and starts no other process. Configure delivers it as root:root 0755. The label
uses the theme foreground, 14 pt text and an absolute larger glyph size (18 pt at the base scale): hyprgraphics
`0.6.0` cancels relative Pango sizes. Sizes and position follow the focused monitor's scale through `lock-screen`'s
generated geometry. Missing geometry or theme data must never prevent locking. Other ADR 0021 decisions stay in force.

**Out of scope:** SDDM fingerprint, PAM stack changes, polkit-agent changes, fprintd unit/drop-in changes, Omarchy's
resume hook or stop-timeout drop-in, upstream pull requests and recipe-update automation. No resume mitigation ships.

## Consequences and trade-offs

- Fingerprint-only unlocks avoid starting a password PAM conversation; password failure accounting remains intact.
- With static fingerprint enablement, PAM starts on password submission even without a reader. A faillock lockout
  message therefore appears on submission, not when the lock appears, as with hyprlock `0.9.5`.
- Arch updates do not automatically reach `hyprlock-mirroros`. The maintainer must update the recipe and checksum,
  review patch applicability and rerun the minimal gates. Soname dependencies can block incompatible library upgrades.
- The two-step replacement briefly removes the locker binary during a user-started configure run. Rollback is a
  recovery attempt, not an atomic transaction; a failed recovery needs explicit operator intervention.
- fprintd allows one claimant. A pending polkit/sudo request or the post-Escape helper hold (up to 30 seconds, L-1)
  can deny the lock fingerprint access; the retry window helps only when that claimant releases the reader.
- **RISK-002:** a touch intended to unlock may authorize a pending polkit/sudo request hidden under the lock instead.
  This is not mitigated by the retry. Password unlock must remain available, and the contention checkpoint decides
  whether agent cancellation is needed here or in a separate plan; it would not cover terminal sudo requests.
- No fprintd restart hook is adopted: restarting fprintd would discard hyprlock's claim and can break verification
  after resume. Five attended resume cycles are required before adoption.
- Patches 0002–0005 are upstream contribution candidates; patch 0001 remains a deliberate local divergence.

## DEC-007 amendment: cross-client signals and bounded contention policy

The first T14s contention run with `0.9.7-2.1` found more than RISK-002: hyprlock repeatedly failed Claim with
`AlreadyInUse`, then handled `verify-match` and unlocked at the same second that polkit authorized `pkexec true`.
Its VerifyStop and Release failed because another client owned the device. Evidence is retained under ignored
`evidence/lock/lab-02-39/t14s/step-6-pending-*.log`. The upstream `0.9.7` source archive, verified against the
recorded SHA-256, confirms that authentic fprintd signals were handled without checking claim/verification ownership.
The existing sender check is necessary but does not distinguish another client's legitimate authentication.

The maintainer considered exclusive fingerprint use by the locker. fprintd's documented API and upstream `v1.94.5`
`src/device.c` (T14s package `fprintd 1.94.5-2`) offer no priority Claim or cross-client VerifyStop/Release. Global
exclusivity would require broader arbitration and is not adopted. No fprintd, PAM or polkit-agent changes are authorized.

Instead, patch 0005 implements the bounded policy above. While another client owns the reader, the locker offers
password only and ignores that client's result and finger-present signals. A touch can still authorize the hidden
request (RISK-002), but must not also unlock the session. The maintainer's acceptance of that residual limitation is
conditional on attended tests of both contention cases, password fallback and later own-reader recovery. The first
run is a blocking finding, not a passed gate. Rebuild and rerun the affected VM and T14s gates before adoption.

The isolated `fingerprint-state.bats` suite compiles the patched provider with test-only D-Bus doubles. It exercises
busy-reader signals, own verification, early results, obsolete replies, retries, exhaustion, sleep and termination;
it is not hardware qualification.

## Replacement or reversal boundary

Reconsider this decision if upstream fixes #1074, any patch no longer applies to a new release, a blocking gate fails,
or more owned code is proposed for the lock. A no-reader/no-prints failure stops at the DEC-005 checkpoint to decide
whether a lock-time probe is warranted. A resume failure stops at DEC-006 to decide a bounded hyprlock patch 0005,
not a service restart hook (patch number 0005 is now assigned to the DEC-007 signal fix). The DEC-007 contention
checkpoint keeps pending-request cancellation outside this delivery, subject to the conditional residual-risk review
above. Amend this ADR if another checkpoint changes its bounds; do not silently expand the patch set.

## Required validation

Before acceptance: maintainer review of this Proposed ADR, the architecture bullet, scope rows and ADR index at the
checkpoint immediately after drafting (DEC-008). The following gates remain required after acceptance and before
plan 02-39 adoption:

- Reference-VM package build: five cleanly applying patches, correct provides/conflicts, soname dependencies, PAM
  backup path, binary and explicit license path.
- Mechanism contracts: unchanged current package, fresh install, replacement, build failure without system writes,
  modified protected file refusal (exit 4), and official-package recovery attempt after installation failure.
- Lock/theme contracts, prompt-script cases, scaled geometry at 1, 1.25 and 1.6, shell syntax and relative links.
- Isolated provider-state tests with the verified source archive and g++; no skipped ownership-state tests for adoption.
- No-reader VM: configure exits 0 twice, second run unchanged, all PAM hashes identical; no fingerprint line or
  perceptible delay, password unlock and wrong-password message confirmed by the maintainer.
- T14s after withdrawing the quick test: configure twice; fingerprint unlock with unchanged faillock and relock
  within 1–2 seconds; wrong password counts and correct password clears; exhausted fingerprint attempts hide the
  line while password works; no prints behaves as before and re-enrollment restores fingerprint.
- Five maintainer-started suspend/resume/fingerprint-unlock cycles with unchanged faillock and no Claim/VerifyStart
  journal errors; both contention cases with password unlock, availability timing and what a touch authorizes recorded;
  while another client owns the reader, no fingerprint line or unlock from its match; after release, only own
  verification may restore fingerprint presentation and unlocking;
  polkit and sudo fingerprint regressions; visual approval at scale 1.6.
- Ignored evidence under `evidence/lock/lab-02-39/{vm,t14s}/`, maintainer checkpoint decisions and final impact analysis.

After adoption: review each recipe update against these minimal gates. Track upstream contributions for 0002–0005,
an Arch-ahead warning check and any contention-checkpoint follow-up separately.

## References

- [ADR 0012](0012-owned-quickshell-desktop-shell.md)
- [ADR 0021](0021-neutral-greeter-and-themed-lock.md)
- [ADR 0030](0030-shell-hosted-polkit-agent-and-fingerprint.md)
- [Architecture](../architecture.md)
- [MVP scope](../mvp-scope.md)
- [Interview log](../technical-interviews/hyprlock-patched-fingerprint_log.md)
- [Interview plan](../technical-interviews/hyprlock-patched-fingerprint_plan.md)
- [Lock sources](../../capabilities/desktop/lock/sources.md)
- [Hardware procedure](../procedures/hardware.md#fingerprint)
- [hyprlock issue #1074](https://github.com/hyprwm/hyprlock/issues/1074)
- [hyprlock issue #1100](https://github.com/hyprwm/hyprlock/issues/1100)
- [hyprlock PR #1003](https://github.com/hyprwm/hyprlock/pull/1003)
- [fprintd device API](https://fprint.freedesktop.org/fprintd-dev/Device.html)
- [fprintd v1.94.5 device implementation](https://gitlab.freedesktop.org/libfprint/fprintd/-/blob/v1.94.5/src/device.c)

## Superseded by

`None`

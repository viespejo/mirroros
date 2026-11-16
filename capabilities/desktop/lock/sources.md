# Lock and idle sources and ownership

## Providers

hypridle comes from the Arch `extra` repository. hyprlock was selected for Story 4.3 after the guest prototype
(DEC-019), and now ships as the local `hyprlock-mirroros` package under
[ADR 0031](../../../docs/adr/0031-patched-hyprlock-native-fingerprint.md). It renders the lock surface
(`ext-session-lock-v1`), uses native fprintd outside PAM for fingerprints and keeps the byte-identical packaged
`/etc/pam.d/hyprlock` service for passwords; hypridle owns idle detection, logind Lock/sleep requests and idle
inhibition, and honours Wayland idle inhibitors. The shell's runtime-only Stay Awake indicator (plan 02-31) is one
more idle-inhibit client: while it is on, a native idle inhibitor suspends only the idle lock; lock before sleep, on
lid close and through `loginctl lock-session` is unchanged, and the shell never becomes the idle manager. MirrorOS
code never handles credentials and the desktop shell has no lock or PAM code
([ADR 0012](../../../docs/adr/0012-owned-quickshell-desktop-shell.md), bounded provider-patch exception in ADR 0031).
hypridle remains rolling; hyprlock is maintained manually as described below.

### Patched hyprlock provenance

- Base: upstream hyprlock `0.9.7`, derived from the
  [Arch `0.9.7-2` recipe](https://gitlab.archlinux.org/archlinux/packaging/packages/hyprlock/-/blob/0.9.7-2/PKGBUILD),
  not from the development host. Recipe and reference-VM build evidence are recorded under ignored
  `evidence/lock/lab-02-39/`.
- Source: `https://github.com/hyprwm/hyprlock/archive/v0.9.7/hyprlock-0.9.7.tar.gz`, SHA-256
  `01145790570ffabd31e9b528c517bdccae76f36e72d733f00c2696d9c3bf2c88`.
- Owned derivation: [hyprlock/PKGBUILD](hyprlock/PKGBUILD), `hyprlock-mirroros 0.9.7-2.2` (initial four-patch
  candidate `0.9.7-2.1`), provides and
  conflicts with `hyprlock`, retains Arch dependencies and generated soname dependencies, names the PAM backup
  `etc/pam.d/hyprlock` explicitly and installs the upstream BSD-3-Clause license under
  `/usr/share/licenses/hyprlock-mirroros/LICENSE`. No MirrorOS license headers are added to the derivation or patches.
- `0001-pam-defer-start-until-input.patch`: defer PAM until submitted input when native fingerprint is enabled,
  avoiding fingerprint unlock failures in [#1074](https://github.com/hyprwm/hyprlock/issues/1074) and
  [#1100](https://github.com/hyprwm/hyprlock/issues/1100). Deliberate divergence from eager startup in
  [#1003](https://github.com/hyprwm/hyprlock/pull/1003), not an upstream contribution candidate.
- `0002-fprint-release-on-match.patch`: release the reader on a match for quick relocking.
- `0003-fprint-retry-claim-when-in-use.patch`: retry `AlreadyInUse` for about 35 seconds, backing off from 250 ms
  to 2 seconds, except while fading out or terminating.
- `0004-fprint-clear-prompt-when-disabled.patch`: clear the prompt on exhaustion, unknown errors, disconnect and
  failed verification restart.
- `0005-fprint-ignore-unowned-verification-signals.patch`: DEC-007 amendment after the T14s contention finding:
  upstream `0.9.7` accepted another client's authentic fprintd match despite a failed Claim. Track claim ownership
  and own verification, ignore unowned status/presentation signals, and invalidate stale asynchronous replies.
  Evidence: ignored `evidence/lock/lab-02-39/t14s/step-6-pending-*.log`; the original Fingerprint.cpp/.hpp match
  the verified source archive above. Patches 0002–0005 are upstream contribution follow-ups, not merged fixes.
- Contention policy: no fingerprint line while Claim is busy; password remains available. Retry may restore the
  line only after claiming the reader and starting an own verification. This does not prevent a touch authorizing
  a hidden polkit/sudo request (RISK-002); corrected-candidate acceptance remains gated on attended tests.
  Global locker exclusivity was considered but not adopted: the
  [fprintd API](https://fprint.freedesktop.org/fprintd-dev/Device.html) and
  [v1.94.5 source](https://gitlab.freedesktop.org/libfprint/fprintd/-/blob/v1.94.5/src/device.c) bind Stop/Release
  to the claimant and provide no priority Claim. T14s read-only package inspection: `fprintd 1.94.5-2`,
  `libfprint 1.94.100-1`; no daemon changes or restarts were performed for this investigation.
- Provider-state tests: `HYPRLOCK_SOURCE_ARCHIVE=/path/to/hyprlock-0.9.7.tar.gz bats
  tests/capabilities/desktop/lock/fingerprint-state.bats` with g++ available. The test verifies the archive SHA-256,
  applies the five patches with zero fuzz and compiles actual provider methods against isolated test-only D-Bus
  doubles. It treats signals as authentic fprintd broadcasts, not sender spoofing. No test downloads or privilege
  changes; missing source/compiler is a skip, which is not sufficient for adoption.
- [build-hyprlock](build-hyprlock) stages the reviewed recipe and patches in the selected user's cache and runs
  `makepkg` without `-s`. Configure uses `cfg_local_package_replace`: build first, refuse a modified packaged PAM
  file, remove official hyprlock, install the local artifact and attempt official-package recovery on failure.
  The official-package check requires the exact returned package name: reference-VM pacman
  `7.1.0.r9.g54d9411-3` resolves `pacman -Q hyprlock` to installed `hyprlock-mirroros` through `provides`.
  Checking only query success incorrectly attempts to remove the absent official package during local upgrades.
  The failed 2.2 configure log is retained under ignored
  `evidence/lock/lab-02-39/patch-0005/vm/configure-failure.log`; the mechanism contract reproduces this resolution.
- `desktop/lock` relies on [system/fingerprint](../../system/fingerprint/sources.md) for `fprintd` and `libfprint`;
  that step precedes it in [configure-steps](../../configure-steps). Only `cmake` and `hyprwayland-scanner` build
  dependencies are added here, alongside hypridle.
- Arch updates do not automatically replace this package. Follow the
  [manual recipe update procedure](../../../docs/procedures/hardware.md#fingerprint): update version and source
  checksum, review each patch and rerun the package, configuration and hardware gates.

## Ownership and lifecycle (DEC-023)

| Item | Location | Owner |
|---|---|---|
| Idle and lock requests | `~/.config/hypr/hypridle.conf` | Managed user file (`hypridle.conf`) |
| Lock surface | `~/.config/hypr/hyprlock.conf` | Managed user file (`hyprlock.conf`) |
| Lock colors | `~/.local/state/mirroros/current/theme/hyprlock.conf` | Selected theme ([theme sources](../../visual/theme/sources.md)) |
| Fingerprint prompt renderer | `/usr/share/mirroros/lock/fingerprint-prompt` | MirrorOS, system file, root:root 0755 |
| Lock field and fingerprint geometry | `~/.cache/mirroros/lock/geometry.conf` | Generated by `lock-screen` on every lock |
| Service | packaged `/usr/lib/systemd/user/hypridle.service` | Package |
| MirrorOS addition | `/etc/systemd/user/hypridle.service.d/10-mirroros.conf` | MirrorOS, tracked delivery |
| Enablement | `~/.config/systemd/user/graphical-session.target.wants/hypridle.service` | Selected user only |

Both native files use hypridle's and hyprlock's default paths, so no environment variable or argument is needed.
Unmarked files and links stay user-owned. The drop-in only removes a stale while-away lock marker before hypridle
starts and asks a running shell to reread it; the packaged command, restart policy and dependencies are unchanged.
hyprlock runs as a child of hypridle's `lock_cmd`, never of the shell, so stopping or restarting the shell leaves the
lock in place. Configure never starts, restarts or reloads hypridle.

## Configuration choices

- Lock after 300 seconds idle and before sleep; every lock path reaches `lock_cmd`.
- `lock_cmd` runs `/usr/share/mirroros/lock/lock-screen` only when no hyprlock exists. It selects layout index 0
  before starting hyprlock (decision J(a)) and, once hyprlock exits after unlocking, restores the layout that was
  active before locking (plan 02-20). A layout that cannot be read or switched never prevents locking.
  Behavior reference only: Omarchy `bin/omarchy-system-lock` at `7075b61c6aaa5d8589f6e816867508fc96dc49d9` (MIT)
  also selects the first layout when locking; no Omarchy file or script is copied or executed. Since plan 02-20
  index 0 is the configured layout ([ADR 0015](../../../docs/adr/0015-greeter-keyboard-layout-switching.md)), and
  `SUPER+I` / `SUPER+SHIFT+I` do not work at the lock screen. In the plan 02-20 VM (packaged hyprlock), hyprlock
  follows only the first layout change after locking; later changes switch the compositor layout but not the lock
  screen's indicator. Keeping the active layout when locking and switching while locked were therefore rejected,
  so the lock always uses the configured layout. Known cosmetic limitation: when another layout is active, the
  shell bar briefly shows the configured layout before the lock surface covers it.
- Before switching the layout, `lock-screen` reads the focused monitor's scale (the first monitor when none is
  focused) from `hyprctl monitors -j` and atomically replaces `~/.cache/mirroros/lock/geometry.conf` with
  `$field_size` and `$field_border` for a 378x57 logical-pixel field and a 3 logical-pixel border, plus fingerprint
  text size, absolute glyph size and vertical offset, rounded to
  physical pixels (DEC-012 of the greeter and lock interview log). hyprlock `0.9.6` lays out widgets in the lock
  surface's physical pixels and derives the text size from the field height, so no hyprlock value follows the
  Hyprland scale by itself. When the scale cannot be read or is invalid, the file is removed and the fallbacks
  apply; a failure here never prevents locking.
- `on_lock_cmd` / `on_unlock_cmd` maintain `$XDG_RUNTIME_DIR/mirroros-shell-locked` and call the shell's
  `notifications lockChanged` IPC function for the while-away count (DEC-021/022; gate passed in plan 02-19
  Task 1). The marker carries no notification content.
- No screensaver, DPMS, backlight or automatic suspend policy.
- `hyprlock.conf` is an original MirrorOS layout under
  [ADR 0021](../../../docs/adr/0021-neutral-greeter-and-themed-lock.md): one password field over the selected
  background (`~/.local/state/mirroros/current/background`, ADR 0020), amended by ADR 0031 for one fingerprint
  line below the field, with `blur_passes = 3`, `blur_size = 8` and
  `brightness = 0.9`, or the theme background color when the image is missing; no clock, keyboard layout,
  screenshot, window or notification content. The field size and border are `$field_size` and `$field_border`,
  sourced after the theme from `lock-screen`'s geometry file; their fallbacks are `31.5%, 8.4%` of the output and
  5 pixels, the values accepted at 1920x1080 and scale 1.6. The field has an accent border, no rounding, the theme background at 80% and an `Enter Password` placeholder at 60%
  opacity. A failure shows `<i>$PAMFAIL$FPRINTFAIL</i>` (including faillock's remaining time and fingerprint
  errors) for five seconds (`general:fail_timeout = 5000`); the faillock policy is unchanged.
- Native fingerprint is statically enabled on every target, without a reader probe. The ready message is
  `Use your fingerprint or password`; the present message is `Reading fingerprint…`. The prompt renderer prints
  nothing for an empty `$FPRINTPROMPT` and otherwise prints the UTF-8 U+F0237 glyph, two spaces and the prompt.
  It uses Bash builtins only, with no D-Bus query or child process, and receives no credentials. Its optional second
  argument is `$fprint_glyph_size`, an absolute Pango size generated by `lock-screen`: hyprgraphics `0.6.0` resets
  relative sizes with `pango_attr_scale_new(1)`. Text is 14 logical points, the glyph 18 logical points (1024 Pango
  units per physical point), and the centered line is offset by -62.5 logical pixels (-100 physical at scale 1.6).
  All three values follow the focused monitor's scale; fallbacks are 22 points, 29491 Pango units and -100 pixels.
  The label uses the theme foreground. Empty prompts after reader absence, no prints or disabled verification hide
  the line; a busy reader also leaves the line empty, with status and presentation from other clients ignored.
  VM and hardware gates must confirm those cases on the amended candidate. No suspend/resume mitigation ships.
- Colors are the variables `$background`, `$field`, `$foreground`, `$accent` and `$failure`. The managed file
  defines neutral literal fallbacks (the greeter's colors), then sources the selected theme's `hyprlock.conf`
  through the `current/theme` link, as Foot does. A missing theme file is logged by hyprlock and the fallbacks
  remain. The link is user-controlled and hyprlock configuration can run commands through labels, so the lock
  trusts the selected theme like the user-writable lock file itself. Both paths use the default XDG state directory
  (`~/.local/state`), not a custom `XDG_STATE_HOME`.
- The previously shipped layout carried the managed header, so configure replaces it; a personal (unmarked) or
  linked `hyprlock.conf` stays user-owned and keeps its own layout.
- Behavior reference only: Omarchy `4.0.6-1` (inspected read-only on the reference VM) locks with one field over a
  blurred background; no Omarchy file, value set or asset is copied.

## Open limits

- The packaged unit's exact contents are verified on an installed system (plan 02-19 Task 3), not assumed here.
- If hypridle itself fails while locked, its service stop also ends the hyprlock child (default kill mode);
  Hyprland then shows its lockdead screen. Recovery (`misc:allow_session_lock_restore`) is untested.
- Multi-output lock, idle inhibition by applications and lock after resume remain unqualified. With outputs at
  different scales, the focused output's scale sizes the field on all of them; a scale change while locked applies
  at the next lock. The background `blur_size` stays in physical pixels.
- The ADR 0021 behavior (theme sourcing through `~` and the link, missing theme file, missing background, blur,
  percentage sizes and the failure display) was first observed with temporary configurations on hyprlock `0.9.6`;
  the delivered file and the scale-following geometry are VM-qualified on the existing reference installation
  ([record](../../../docs/procedures/greeter-plymouth.md#adr-0021-greeter-and-lock)), not on a clean installation
  or physical hardware.

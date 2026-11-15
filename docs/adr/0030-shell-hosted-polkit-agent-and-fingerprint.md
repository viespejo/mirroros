# ADR 0030: Shell-Hosted Polkit Agent and Fingerprint

## Identifier and title

- **Identifier:** `0030`
- **Title:** Shell-Hosted Polkit Agent and Fingerprint

## Status

`Accepted`

Drafted by plan 02-37 (Story 4.5 polkit agent, option A). The maintainer accepted it on 2026-11-15 at the plan
02-37 adoption checkpoint, after every blocking laboratory gate passed on the final candidate `a7068c6` (DEC-002,
DEC-015): G1, cancel 126, fingerprint with password fallback in `polkit-1` and `sudo`, the closed lid, and no added
delay without enrollment.

## Date

`2026-11-15`

## Context and question

Story 4.5 leaves the polkit authentication agent open in [`docs/mvp-scope.md`](../mvp-scope.md). Without an agent,
session-menu actions answered with `challenge` by logind and graphical privileged requests (`pkexec`, Strata
`admin://`) fail.

Plan 02-36 evaluated option B, the packaged `hyprpolkitagent` themed through hyprtoolkit, and stopped at the gate:

- **G1 failed** by maintainer verdict in the reference VM at scales 1.6 and 1.25. Text ellipsized with the shell
  font, the `*` mask, no in-progress state, a fixed error color, a cramped fixed layout, a trembling button row and
  verbose journal output are fixed upstream behavior (findings F1–F7, F9).
- **Cancel returned 127 instead of 126** in the VM and on the T14s, because the agent answers a user cancel as a
  failed authentication (F8). It fails closed but is intrinsic to the agent.
- **G2 on the T14s** (Synaptics `06cb:00bd`) showed that fingerprint success and password fallback depend on PAM,
  not on the agent. That evidence covers only a temporary `/etc/pam.d/polkit-1` with `auth sufficient
  pam_fprintd.so` and no clamshell gate; `sudo`, hyprlock and the closed lid were not exercised.

Two accepted rules stand in the way of the maintainer's chosen option A:

- [ADR 0012](0012-owned-quickshell-desktop-shell.md) and [ADR 0025](0025-shell-panels.md), the frozen principle of
  `docs/mvp-scope.md` and the QML clause of [`docs/architecture.md`](../architecture.md): authentication, including
  the polkit agent, is never project-owned QML.
- ADR 0012's constraint that authentication surfaces must not be project-owned code, and the architecture's
  "Linux accounts and PAM own user authentication": fingerprint enablement places MirrorOS-owned code and managed
  files in PAM stacks.

The question is: may the owned shell host a polkit agent UI adapted from Omarchy, and may configure enable
fingerprint authentication in the `polkit-1` and `sudo` PAM stacks, and within which bounds?

## Constraints and decision criteria

- PAM remains the authenticator: the agent only relays prompts between `polkit-agent-helper-1` and the user.
- No credential or flow data (message, prompt, response) is stored or logged; no shell interpolation (`bash -c`).
- The agent is isolated from other shell components; no shared service or property exposes it.
- The screen lock (hyprlock, [ADR 0021](0021-neutral-greeter-and-themed-lock.md)) and the SDDM greeter stay
  unchanged.
- Configure is the single declarative owner of system files: no user command writes `/etc`, and a locally edited
  file is never overwritten silently.
- Machines without a reader or without enrolled prints must behave exactly as before, with no perceptible delay.
- Stay close to Omarchy `7075b61` so the adaptation stays reviewable; record provenance and license.
- Sustainability for a single maintainer: the smallest owned surface in PAM, removable without other changes.

## Alternatives considered

1. **Option A, shell-hosted QML agent adapted from Omarchy, with gated fingerprint (selected).** Uses the native
   `Quickshell.Services.Polkit` agent, follows the selected theme through the shell's color model and returns 126 on
   cancel. Costs two accepted exceptions and couples privilege prompts to shell uptime.
2. **Option B, hyprpolkitagent themed through hyprtoolkit.** Packaged and not project-owned, but failed G1 and
   returns 127 on cancel (plan 02-36).
3. **Option C, a packaged neutral agent such as polkit-gnome.** Needs no exception and would inherit the MirrorOS
   GTK theme, but was not chosen by the maintainer (DEC-001) and is not evaluated.
4. **Agent only, without fingerprint.** Smaller exception, but leaves the reader that G2 proved usable idle and the
   agent's fingerprint mode as dead code.
5. **Hardware-conditioned fingerprint packages, or Omarchy's on-demand setup command writing PAM.** Introduces a new
   configure pattern reading live `/sys` in target context, or a second owner of `/etc/pam.d`.
6. **Line editing of the vendor `sudo` stack (`sed`, as Omarchy does).** Silent on local edits and not reviewable as a
   managed file.

## Evidence

- [Story 4.5 polkit agent interview log](../technical-interviews/story-4-5-polkit-agent_log.md), including its
  "Execution findings" section (G1 F1–F9, cancel 127, T14s G2).
- [Story 4.5 polkit QML agent interview log](../technical-interviews/story-4-5-polkit-qml-agent_log.md),
  DEC-001 to DEC-017.
- Local ignored records `evidence/polkit/lab-02-36/checkpoint.md` and `evidence/polkit/lab-02-36/t14s/g2.md`
  (package delta `fprintd`, `libfprint`, `libgusb`).
- Omarchy `7075b61c6aaa5d8589f6e816867508fc96dc49d9`: `shell/plugins/polkit/{PolkitAgent.qml,PolkitModel.js}`,
  `shell/Commons/Color.qml` (`polkit` section), `bin/omarchy-hw-laptop-closed`, `bin/omarchy-hw-fingerprint`,
  `bin/omarchy-setup-security-fingerprint`, `install/user/first-run/setup-fingerprint.hook`.

Plan 02-37 laboratory evidence for option A, local and ignored under `evidence/polkit/lab-02-37/`:

- `checkpoint.md` (reference VM, 2026-11-14/15, SHA256
  `f58f1915883a999697b3b6537dfc65f8e638352f2d7b7fe35384c2c8fae9a153`): the competing-agent exit 4 and unchanged
  reruns, `polkit-check`, G3 (`pkexec true` correct 0, wrong then correct 0, Escape 126), no delay without a reader,
  Strata `admin:///etc`, a shell restart ending a pending request without granting it, and the maintainer's G1
  approval at scales 1.6 and 1.25. A live session-menu `challenge` was not reproducible (logind answers `yes` in the
  active session); it rests on the `check-menu.sh` fixture.
- `t14s/g2.md` (T14s Gen 1, Synaptics `06cb:00bd`, 2026-11-15, SHA256
  `1652403a69a9457a21beb8d4823a7bc8e2714c770f25a8a22ef63aa1d1bd1b55`): password-only before enrollment, the
  invitation and menu row, fingerprint with password fallback and cancel in both stacks, the closed lid with an
  external monitor going straight to the password, and deletion back to password-only.
- Checksum lists `SHA256SUMS` (SHA256 `865be63f941c70e3ed6c927ac3da78fb4aa0724daf8be83d70451f7a951917ad`) and
  `t14s/SHA256SUMS` (SHA256 `2d2784d0828086681588f5272b6c9f5eccc496e2f626be130255954694a61af9`).

Defects found in the laboratory were fixed within the plan and recorded in the
[plan 02-37 execution findings](../technical-interviews/story-4-5-polkit-qml-agent_log.md#execution-findings--2026-11-15-plan-02-37).

## Decision

**Agent.** The polkit authentication agent UI is QML hosted in the owned Quickshell shell, adapted from Omarchy
`7075b61` over the native `Quickshell.Services.Polkit` agent registered at `/org/mirroros/PolkitAgent`:

- It is instantiated directly in `shell.qml` as an isolated sibling; no reference is passed to it or taken from it,
  and no other shell component can read its state.
- It stores and logs no flow data (message, prompt or response); only a warning when registration fails is logged.
- It runs no `bash -c`. Its only process is `/usr/share/mirroros/hardware/lid-closed` with fixed argv, used as a
  presentation hint; it reads `/etc/pam.d/polkit-1` read-only to detect `pam_fprintd`.
- Cancel uses `cancelAuthenticationRequest()` so the caller receives 126.
- It follows the selected theme through a `polkit` section of the shell's color model and English strings only.
- hyprlock and its PAM service are unchanged.

**Fingerprint.** A `system/fingerprint` configure step enables fingerprint authentication in two PAM stacks:

- `fprintd` and `libfprint` from Arch `extra` are installed unconditionally (no `libfprint-git`, no hardware
  condition). Without enrolled prints `pam_fprintd` is unavailable and authentication falls through to the password.
- `/etc/pam.d/polkit-1` and `/etc/pam.d/sudo` are complete managed files. Each has, immediately before
  `auth sufficient pam_fprintd.so`, the clamshell gate
  `auth [success=1 default=ignore] pam_exec.so quiet /usr/share/mirroros/hardware/lid-closed`, followed by the
  vendor `system-auth` includes. `sudo` is replaced only when it holds the exact packaged content; any other content
  stops configure with exit 4 and is never overwritten.
- `lid-closed` is the only MirrorOS-owned code in PAM. Its contract: read-only, writes nothing and starts nothing,
  reads the ACPI lid state and otherwise asks logind for `LidClosed` with a bounded 2-second timeout, and is
  delivered at the literal path above as root:root 0755. Exit 0 means closed; any error counts as an open lid.
- Enrollment is user-run through the owned `fingerprint-setup` command in a terminal. It enrolls, verifies,
  re-enrolls or deletes the current user's prints through fprintd and polkit, and never runs `pacman`, `sudo` or
  `systemctl` or writes `/etc`.
- A session-menu row (Setup › Security › Fingerprint) is shown only when a USB sysfs reader probe detects a reader.
  A oneshot user unit sends one invitation notification per user when a reader is present and no prints exist.

**Out of scope:** fingerprint for hyprlock (recorded as pending), SDDM fingerprint, keyring changes, a generic
first-run framework or welcome application, `libfprint-git`, platform (non-USB) readers, and any polkit rule or
action change.

This ADR partially amends ADR 0012 and ADR 0025 for the polkit agent and PAM fingerprint only; their remaining rules,
including that the screen lock is never project-owned QML, stay in force. It does not rewrite them.

## Consequences and trade-offs

- **Shell-uptime coupling:** without a running shell there is no agent and privileged graphical requests fail closed;
  a shell restart ends a pending request without granting it.
- **Owned code in PAM:** a defect in `lid-closed` cannot grant access; a failing probe is ignored
  (`default=ignore`) and PAM continues to `pam_fprintd`, then the password.
- **Managed `sudo` stack:** a later `sudo` package change to `/etc/pam.d/sudo` arrives as `.pacnew` and must be
  reviewed; the recorded packaged hash then needs updating.
- Every installation carries `fprintd` and `libfprint` (about 3.5 MiB with `libgusb`), used or not.
- The agent is adapted, not copied byte-identically, and needs review on upstream changes.
- Fingerprint is not available at the screen lock until a later decision.
- After a cancelled prompt, `polkit-agent-helper-1` keeps the reader claimed until the 30-second `pam_fprintd`
  timeout, so authentications in that window fall back to the password (accepted upstream behavior, fail-safe).

## Replacement or reversal boundary

Reconsider through a new ADR if a blocking plan 02-37 gate fails (G1, cancel 126, fingerprint with password fallback
in either stack, closed lid, or added delay without enrollment), if fingerprint is proposed for hyprlock or SDDM, if
the agent needs any process beyond `lid-closed` or any shared state, or if more MirrorOS-owned code is proposed in
PAM. Removing fingerprint does not require removing the agent.

## Required validation

Before acceptance (plan 02-37):

- Contract and unit tests for the step, the scripts, the agent model, the single-owner check and the menu rows.
- Reference VM: the competing-agent exit 4 and rerun, `polkit-check`, `pkexec` correct, wrong-then-correct and
  cancel (0, 0, 126), no delay without a reader in `pkexec` and `sudo`, Strata `admin:///etc`, a session-menu
  `challenge`, shell restart with a pending request, and the maintainer's written G1 verdict.
- T14s MirrorOS partition: password-only before enrollment, the one-time invitation and menu row, fingerprint with
  password fallback and cancel in `pkexec` and `sudo`, closed lid with an external monitor, and deletion back to
  password-only.

After acceptance: review `.pacnew` for `/etc/pam.d/sudo` after `sudo` updates.

## References

- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [ADR 0021: Neutral Greeter and Themed Lock](0021-neutral-greeter-and-themed-lock.md)
- [ADR 0023: Recognized Unqualified Targets and Target Hibernate Mode](0023-recognized-unqualified-targets-and-target-hibernate-mode.md)
- [ADR 0025: Shell Panels](0025-shell-panels.md)
- [Story 4.5 polkit agent interview log](../technical-interviews/story-4-5-polkit-agent_log.md)
- [Story 4.5 polkit QML agent interview log](../technical-interviews/story-4-5-polkit-qml-agent_log.md)
- [MVP scope and change control](../mvp-scope.md)
- [Architecture](../architecture.md)

## Superseded by

`None`

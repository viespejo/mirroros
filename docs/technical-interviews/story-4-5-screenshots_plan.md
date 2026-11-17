# Story 4.5 Area 4 — Screenshots: Consolidated Plan

Execution amendment DEC-016 explicitly permits the two-file Save As portal patch after the isolated prototype.
The maintainer approved the final reference-VM checkpoint on 2026-11-17 after confirming the postdeployment
visual check. The accepted delivery is Omasnap 1.26.2-4.2 with immediate menu dispatch and the provider-owned
exact menu namespace no-animation rule; see the closure findings in the decision log.

## Scope

Plan 02-40 delivers the screenshot core of Story 4.5. Omasnap is built from a reviewed local recipe and placed under
the Hyprland compositor provider, behind a neutral MirrorOS command. It provides region, window, full-screen and
scroll capture with save and copy, annotation with secure redaction, and Omasnap's built-in English OCR, which comes
with the provider because `tesseract` is a hard dependency. The work is validated in a single laboratory
campaign [DEC-001].

The hyprpicker colour picker and the zbar QR reader are deferred to a separate plan (02-41). That plan must choose
how QR obtains a region image without entering clipboard history. Screen recording stays outside Story 4.5
[DEC-001, TODO-001].

## Capability placement

Screenshots follow the architecture's capability tree. A new neutral capability, `capabilities/desktop/screenshot/`
(`desktop.screenshot`), owns the neutral command and the capability contract (modes, exit codes and output
location), together with its `sources.md` and its own configure step. Nothing in it names Omasnap or Hyprland
[DEC-002].

Because Omasnap hard-depends on Hyprland, its implementation stays beneath the compositor provider boundary
required by ADR 0011, in `capabilities/desktop/compositor/providers/hyprland/omasnap/`. That directory holds the
reviewed PKGBUILD and its user-run build script on the Strata pattern, the user `omasnap.conf`, the layer rule and
the bindings. A future provider can implement the same neutral command, for example with grim + slurp, without
redesigning the capability [DEC-002].

## Neutral command

Bindings and the shell call one owned command,
`/usr/share/mirroros/screenshot/screenshot [smart|region|window|full|scroll] [--edit]`, with smart selection as the default.
OCR and annotation remain in-editor actions, not modes. The optional `--edit` requests annotation before any output;
the backend translates it to `--editor overlay` [DEC-013]. The command validates its argument, invokes and waits for the backend
that the active compositor provider installs at `/usr/share/mirroros/compositor/screenshot-backend` [DEC-011]. The Hyprland
backend is a thin wrapper that maps the neutral modes onto Omasnap's `windows`, `fullscreen` and `--scroll`
[DEC-002, DEC-003].

The exit codes follow Omasnap's own: 0 for success, a silent cancel or a dismissal by a second key press, 1 for a
capture failure and 2 for a usage error. To meet the story's actionable-error criterion, a missing backend
notifies the user to rerun `mirroros-configure`, and a failed capture notifies with a pointer to the journal.
Cancelling never notifies [DEC-003].

## Omasnap recipe and supply chain

Omasnap is built from a MirrorOS-derived copy of Omarchy's own recipe (`omacom/omarchy-pkgs` `pkgbuilds/omasnap`
1.26.2-4). It is pinned to `v1.26.2` (`6150151`) from the GitHub tag archive, whose reference SHA-256 is verified
again on download. The package keeps the name `omasnap` and uses `pkgrel=4.2`. The recipe is x86_64 only and omits
`check()` with its `clang` checkdepend because upstream CI runs the unmodified smoke suite [DEC-004]. DEC-016
explicitly amends the original no-patches decision: an inline prepare() diff removes DontUseNativeDialog and forces
xdgdesktopportal instead of generic in main.cpp. Save As can then use the configured Strata portal from all launch
paths, without a desktop override or wrapper-only flag. Declare xdg-desktop-portal directly; the VM's qt6-base owns
the Qt portal plugin. Prototype success does not replace final-package cancellation, focus, save/overwrite and
launch-path retests.

Following the hyprlock and Strata precedents, the runtime and build dependencies are declared in the Hyprland
provider's `packages`. A user-run `build-omasnap` script builds into `~/.cache/mirroros/omasnap`, and configure
installs the result. Because upstream moves fast, each update is an explicit recipe change with a reason, a diff
review and a rerun of the theme contract test, recorded in `sources.md` [DEC-004].

## Recent captures stay in RAM

Omasnap keeps a shelf of the last five captures, including the unredacted source image, and by default writes it
to `~/.local/state/omasnap/recent`. A secret redacted in the editor would therefore persist on disk. The packaged
desktop entry, a terminal and Open With all launch Omasnap directly, so a wrapper alone cannot cover them. The
Hyprland provider instead installs a managed one-line `environment.d` file that sets
`OMASNAP_RECENT_DIR=${XDG_RUNTIME_DIR}/omasnap/recent`, and `screenshot-backend` exports the same value as a
fallback. The shelf then works for the session and vanishes at logout, on every launch path [DEC-005].

A `.desktop` override was rejected: it drifts from the packaged file, it complicates the neutral command with file
arguments, and it leaves terminals uncovered. This plan introduces the first `environment.d` use in the
repository. The laboratory confirms the variable's expansion and inheritance with a new user manager: graphical logout alone
can retain the old manager while SSH/other sessions remain. A coordinated reboot established the fresh manager in
the reference VM. Recipe updates re-check that upstream has not renamed the variable [DEC-004, DEC-005, DEC-016].

## Output naming and metadata

Saved captures land in Omasnap's default `~/Pictures/Screenshots`, resolved through the xdg-user-dirs already
declared by `desktop/files`, and are saved automatically as well as copied. Omasnap's default name appends the slug
of the captured application, which can leak what was on screen. Omasnap reads only a per-user INI file, so the
Hyprland provider delivers a managed `omasnap.conf`, on the `xdph.conf` pattern, that sets only
`[output] filename = screenshot-{date}_{time}`. Its MirrorOS marker is an INI `;` comment. A copy without the marker
is the user's and is preserved, and the procedure warns that such a copy may bring the slug back [DEC-006].

Patching the default pattern remains rejected; DEC-016's approved patch covers Save As portal integration only. The PNG itself
carries only Omasnap's logical-size text field, with no EXIF, and the laboratory verifies this on real output
[DEC-006].

The default fast path saves and copies before showing its preview. Redacting through that preview later does not
remove the original file or history entry. For sensitive captures, the procedure directs users to `--edit` or the
`Screenshot with annotation` menu action, redact before output, and explicitly save or copy afterward. RAM-only
recent documents do not protect an original already exported through the fast path [DEC-013].

## Capture feedback

Success is confirmed only by Omasnap's own floating preview, which offers pin, edit, copy and drag-out. MirrorOS adds
neither `--notify` nor an `omarchy-notification-send` shim, so that the product does not depend on an
Omarchy-named command. Failures remain the neutral command's job [DEC-003, DEC-007]. The laboratory judges whether
the preview is enough: visibility, and Edit and drag into Strata and Chromium. Existing previews and pins can appear
in subsequent captures, as upstream documents; no patch excludes them. The procedure explains that users must close
or move them, or wait for an unpinned preview to expire, when they would cover the intended capture. The laboratory
verifies this behavior rather than requiring automatic exclusion [DEC-007, DEC-012]. A shortfall in success feedback
is escalated as a new decision rather than patched with a shim in this plan [DEC-007].

## Clipboard history

Captures reach the plan 02-38 RAM history through the existing `image/png` watcher, and OCR text through the text
watcher. No second store and no change to Area 3 are introduced. A full-HD capture fits comfortably under the
5,000,000-byte per-entry cap. Larger 4K or scroll captures are dropped from history with a type-and-size journal
entry, but remain on the clipboard and in `~/Pictures/Screenshots` [DEC-008].

Omasnap cannot mark a capture as sensitive, and the history pause remains deferred, so the procedure documents
manual deletion from the picker as the mitigation. The laboratory checks a capture in the picker and the oversized
drop [DEC-008].

## Shortcuts and capture menu

`PRINT` and `SUPER+CTRL+ALT+C` start the neutral command in smart mode, and a second press dismisses the overlay.
They are delivered by a new `screenshot-bindings.lua` in the Hyprland provider through `MirrorOSKeys`. Per-mode
keys are unnecessary, because smart selection covers region, window and monitor, and `S` switches to scroll
[DEC-009].

Following Omarchy, `SUPER+CTRL+C` opens a Capture submenu in the existing MirrorOS session menu: `trigger`,
`trigger.capture` (searchable as `capture` or `screenshot`) and `trigger.capture.screenshot`. The submenu uses a
new closed action, `screenshot:capture`, that runs the neutral command as a fixed argv. Because these are rows in a
surface ADR 0012 already admits, no ADR is needed. Their provenance is recorded in the shell `UPSTREAM.md`
[DEC-009].

`SUPER+PRINT` and `SUPER+CTRL+PRINT`, together with the Color and QR menu rows, are reserved for plan 02-41, and
recording stays out. A second Capture menu row, `Screenshot with annotation`, calls the neutral command with
`--edit`, without adding a shortcut [DEC-013]. Capture alone has a screen-clamped wider card. Its actions close the
menu and immediately launch fixed argv; the maintainer withdrew the experimental unmap wait and 100 ms delay
recorded during DEC-016 execution. A subsequent viewer-keyboard trial reproduced the fading menu in the selector
and exported PNG. The maintainer approved Omarchy's exact menu namespace no-animation policy after one repeated
Screenshot selector/export check passed; repeated reliability and annotation were not separately retested.
The provider owns that `^mirroros-menu$` rule with `no_anim=true` and `animation="none"`, without global changes.
Candidate lab-d subsequently installed this rule, passed a configuration reload and an unchanged 26/26 configure
rerun, and the maintainer confirmed the final visual check succeeded before approving closure. The report does
not enumerate repeated trials or a new per-action test matrix.
The provider adds Omasnap's recommended layer rule without `no_screen_share`, which would
black out scroll captures [DEC-009, TODO-001].

## Shared theme bridge and contract

Both theme consumers ensure the bridge independently. Extract the existing bridge logic from `desktop/files/prepare-strata` into a shared script owned by `visual/theme`, provisionally `omarchy-bridge apply|check --session|--default`, invoked through `cfg_user_script` by both `desktop/files` and the Hyprland provider. An absent bridge is created atomically, an identical bridge is unchanged, and conflicting state is preserved while the consumer fails. Keep the existing session/default state resolution. Strata preparation retains only its first-launch marker; update its affected tests while preserving behavior. Inspect script delivery before implementing the cross-capability call [DEC-010].

This avoids both duplicated bridge logic and a dependency on Strata remaining installed. Omasnap reuses the existing bridge's `colors.toml` and `shell.toml`. A new `tests/capabilities/desktop/hyprland/omasnap-theme-contract.test.mjs` pins the bridge path and the keys read by Omasnap v1.26.2, requiring either a declared theme value or a documented fallback. Do not add `[controls]` to `shell.toml`; review the Osaka Jade chrome visually in the laboratory and rerun the contract on recipe updates [DEC-004, DEC-010].

## Backend supervision correction

The neutral command must remain alive while the backend runs: it invokes the backend without `exec`, waits for its result and preserves exit codes 0, 1 and 2. It adds no notification for success or cancellation, notifies capture failure and leaves usage errors as usage errors. Backend diagnostics go to the journal, making the failure notification's troubleshooting reference actionable. The provider backend may still `exec` Omasnap after preparing its environment. This corrects the neutral-command execution mechanism in DEC-003 without changing its public interface [DEC-003, DEC-011].

## Reference VM campaign and access

Validate in one reference-VM campaign, with deployment authorization requested at execution time and a blocking
human checkpoint. Exercise initial configure and idempotent rerun, then a fresh session for environment.d;
region/window/monitor/scroll capture, cancellation and second-press dismissal; shortcuts and both Capture menu
actions; preview, editing, pins and Osaka Jade chrome; synthetic redaction before export with --edit, inspecting
both file and clipboard; English OCR, clipboard history and an oversized scroll-capture drop; slug-free names,
metadata and RAM recent documents from menu, terminal and Open With; and actionable failures with journal
diagnostics. Run only affected automated tests. Evidence is synthetic and non-sensitive, under ignored
`evidence/screenshots/lab-02-40/` with SHA256SUMS. Explicitly record VM limitations rather than claiming T14s,
fractional-scale or multi-monitor qualification [DEC-014].

Use local workflow guidance `.agents/lab-access.md` for access. The VM connection is
`ssh -i ~/.ssh/id_ed25519 viespejo@127.0.0.1 -p 2222`. Operations needing SSH and sudo run in a new window in the
current tmux session, where the maintainer enters the sudo password. Monitor the operation and confirm the window
closes automatically when it finishes. Never place credentials in artifacts or evidence [DEC-014].

## Delivery and closure

Deliver via temporary `refs/mirroros-candidates/02-40-lab-*` refs. Return failures to the owning task and rerun only
the affected checks. After the blocking laboratory approval, commit by concern using a temporary index, update
scope/procedure/attribution/provenance with the changes they govern, remove the candidate refs and write
`.agents/plans/02-40-story-4-5-screenshots-SUMMARY.md`. Never commit `.agents/`, evidence, generated outputs, secrets
or personal configuration. Test execution and live verification are strictly limited to specifically affected
checks, not complete suites. Formal frontmatter dependencies remain `[]`; previous plans are context only [DEC-015].

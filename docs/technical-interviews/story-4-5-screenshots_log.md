# Story 4.5 Area 4 — Screenshots: Decision Log

Input: `.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (local; Area 4 — Screenshots and capture
extras). Plans 02-35 (portals and files) and 02-38 (clipboard and history) are prior work.

## DEC-001
- **Question**: Should Area 4 be one plan, or should the screenshot core be split from the capture extras?
- **Context/Nuances**: OCR is built into Omasnap, and `tesseract` and `tesseract-data-eng` are hard dependencies of
  the reference PKGBUILD (`omacom/omarchy-pkgs` `pkgbuilds/omasnap`, 1.26.2-4). A region-based QR reader needs a
  region selector that hands the image over without the clipboard: either `slurp` + `grim`, or
  `omasnap --copy` followed by `wl-paste`, which would put the capture into clipboard history. hyprpicker and zbar
  QR are small scope changes that can be validated independently.
- **User Response**: Agreed to split.
- **Decision**: Plan 02-40 covers the screenshot core only: Omasnap from a reviewed local recipe under the Hyprland
  compositor provider, a neutral MirrorOS command, region, window, full-screen and scroll capture with save and
  copy, annotation with redaction, and built-in English OCR, validated in one laboratory campaign. The hyprpicker
  colour picker and zbar QR move to a later plan (02-41). Screen recording remains out of Story 4.5.
- **Status**: Accepted

## TODO-001
- **Item**: Plan 02-41 for the hyprpicker colour picker and zbar QR after 02-40. It must decide the region selector
  for QR (`slurp` + `grim` versus a clipboard round trip). It also binds the reserved `SUPER+PRINT` and
  `SUPER+CTRL+PRINT` and adds the Color and QR rows to the Capture menu (DEC-009).
- **Status**: Pending

## DEC-002
- **Question**: Where do the screenshot capability, the neutral command and the Omasnap implementation live?
- **Context/Nuances**: `docs/architecture.md` lists `capabilities/desktop/screenshot/` and the `desktop.screenshot`
  identifier. Omasnap hard-depends on `hyprland` (`hyprctl` discovery and `depends`), and ADR 0011 requires
  Hyprland-specific packages and configuration to stay beneath `desktop/compositor/providers/hyprland/`. The
  alternative of placing everything, the command included, inside the provider has fewer parts but departs from
  the architecture's tree and from the neutral indirection idea (#125).
- **User Response**: Accepted the recommendation.
- **Decision**: A new neutral capability `capabilities/desktop/screenshot/` owns the neutral command, the capability
  contract (modes, exit codes, output location), `sources.md` and its own configure step, and names neither Omasnap
  nor Hyprland. The Omasnap implementation lives in `capabilities/desktop/compositor/providers/hyprland/omasnap/`:
  the derived PKGBUILD and its build script (following the `build-strata` pattern), the user `omasnap.conf`, the
  layer rule and the bindings. A replacement compositor provider would implement the same command, for example with
  grim + slurp, without changing `desktop/screenshot`.
- **Status**: Accepted

## DEC-003
- **Question**: What are the neutral command's name, interface, provider dispatch and exit codes?
- **Context/Nuances**: Owned commands are installed at `/usr/share/mirroros/<capability>/<command>`, off PATH, and
  are called by absolute path (`clipboard-history`, `reminder`); usage errors exit 2. Omasnap accepts `smart`,
  `region`, `windows`, `fullscreen` and `--scroll`, exits 0 on success or when a second press dismisses the overlay,
  1 on capture, image or lock failure, and 2 on usage errors. OCR and annotation are in-editor actions (`E`/`A` in
  the picker, `O` in the editor).
- **User Response**: Accepted the recommendation.
- **Decision**: The neutral command is `/usr/share/mirroros/screenshot/screenshot [smart|region|window|full|scroll]`,
  with `smart` as the default. It validates the mode and execs the provider-owned backend at the fixed path
  `/usr/share/mirroros/compositor/screenshot-backend <mode>`. The Hyprland backend is a thin wrapper over
  `omasnap`, mapping `window` to `windows`, `full` to `fullscreen` and `scroll` to `--scroll`. OCR and annotation
  are not command modes. Exit codes: 0 for success, silent cancel or dismissal; 1 for a capture failure; 2 for a
  usage error. A missing backend produces an actionable notification (rerun `mirroros-configure`) and exit 1. A
  backend exit 1 produces a failure notification that points to the journal. A cancel is not notified.
- **Status**: Accepted

## DEC-004
- **Question**: How is the Omasnap recipe derived, pinned, built and updated?
- **Context/Nuances**: The reference recipe is `omacom/omarchy-pkgs` `pkgbuilds/omasnap` 1.26.2-4 (source: the
  GitHub tag archive, SHA-256 `e173edd4f2e797273c967513f24c360b6f00733792b9708757a82c39fbc43bf9`; `check()` runs the
  ctest smoke suite offscreen and requires `clang` as a checkdepend). The latest release is `v1.26.2`, commit
  `6150151846b0ddc2ca8e6b107324de8b0c7240ae`. The hyprlock precedent builds with `makepkg` without `-s` and declares
  the makedepends in the capability's `packages`. Upstream is fast-moving (27 tags in three months).
- **User Response**: Accepted the recommendation.
- **Decision**: Derive the recipe from the reference 1.26.2-4 and pin `v1.26.2` (`6150151`), using the tag archive
  with the reference SHA-256, which is verified again on download. Keep `pkgname=omasnap` (unpatched) with
  `pkgrel=4.1`. Changes documented in the header: x86_64 only, and `check()` with its `clang` checkdepend removed
  (upstream CI runs the suite in `test.yml`). The runtime depends and the makedepends (`cmake`, `ninja`, `pkgconf`,
  `wayland-protocols`) are declared in the Hyprland provider's `packages`. A user-run `build-omasnap` (the
  `build-strata` pattern) builds into `~/.cache/mirroros/omasnap`, and configure installs the package. Updates are
  explicit recipe changes with a reason (#129): each new tag requires a diff review and a rerun of the theme
  contract test, and is recorded in `sources.md` as for Strata.
- **Status**: Accepted

## DEC-005
- **Question**: Where does Omasnap keep its recent-captures shelf, and how is that enforced on every launch path?
- **Context/Nuances**: Omasnap stores the last five captures, including the original source image and the operation
  log, under `$OMASNAP_RECENT_DIR`, or `$XDG_STATE_HOME/omasnap/recent` when the variable is unset
  (`src/recent-snaps.cpp:75`). A capture redacted in the editor therefore keeps its unredacted source on disk, which
  conflicts with the story's no-secret-bearing-output criterion and with Area 3's runtime-only line. The packaged
  `omasnap.desktop` (`Name=Screenshot`, `Exec=omasnap %f`) bypasses any wrapper from the launcher, from Open With
  and from a terminal. Options weighed:
  - A `.desktop` override in `/usr/local/share/applications` (or a `sed` on `Exec` in the recipe's `package()`). It
    drifts from the package file, needs a comparison test, forces the wrapper to accept file paths, and does not
    cover terminals.
  - A one-line `environment.d` file, which covers every path launched by the session.
- **User Response**: Accepted the `environment.d` approach after the maintenance explanation.
- **Decision**: The Hyprland provider installs a managed `environment.d` file setting
  `OMASNAP_RECENT_DIR=${XDG_RUNTIME_DIR}/omasnap/recent`, so the shelf lives in RAM for the session on every launch
  path. The `screenshot-backend` wrapper also exports the same variable as a fallback. There is no `.desktop`
  override and no Exec rewrite. This is the repository's first `environment.d` use. The laboratory must confirm
  that `${XDG_RUNTIME_DIR}` is expanded and that uwsm-launched applications, the launcher entry and a terminal
  inherit the variable. A rename of the variable upstream is caught by the DEC-004 diff review.
- **Status**: Accepted

## DEC-006
- **Question**: How does the saved filename avoid the application slug, and who owns `omasnap.conf`?
- **Context/Nuances**: The default pattern `screenshot-{date}_{time}-{app}` appends the slug of the captured window's
  class (#117, #128), which can reveal what was on screen. Omasnap only reads
  `$XDG_CONFIG_HOME/omasnap/omasnap.conf` (INI through `QSettings`; `src/output-config.cpp`). It never writes the
  file and has no system path or environment variable for the pattern. The default directory,
  `PicturesLocation/Screenshots`, resolves through xdg-user-dirs, which `desktop/files` declares (plan 02-35). PNG
  output carries only a logical-size text field, with no EXIF. The rejected alternative is a recipe patch of the
  default pattern, which breaks DEC-004's unpatched recipe and must be rebased on every update.
- **User Response**: Accepted the recommendation.
- **Decision**: The Hyprland provider delivers a managed `omasnap.conf` with `cfg_user_file`, following the
  `xdph.conf` pattern: a copy without the MirrorOS marker is user-owned and preserved. It sets only
  `[output] filename = screenshot-{date}_{time}` and carries the marker in an INI `;` comment, whose validity is
  covered by a test. `directory`, `autosave` and every other key keep Omasnap's defaults (autosave on, into
  `~/Pictures/Screenshots`). The procedure warns that a user-owned copy may reintroduce the slug. The laboratory
  checks the saved PNG's metadata (#117).
- **Status**: Accepted

## DEC-007
- **Question**: How is a successful capture confirmed: Omasnap's own preview, or a notification shim (#127)?
- **Context/Nuances**: Omasnap shows a 7-second floating preview without taking focus, with Pin, Edit, Copy, file
  drag and Close on hover. Notifications are sent only with `--notify` and only through `omarchy-notification-send`
  with `--action`. When that command is absent, no notification is sent and the output is unaffected. Failures are
  already notified by the neutral command (DEC-003). A shim would mimic an Omarchy-namespaced command.
- **User Response**: Accepted the recommendation.
- **Decision**: Omasnap's own preview is the only success confirmation. There is no `--notify` and no
  `omarchy-notification-send` shim. The laboratory reviews whether the preview is sufficient on the VM: it appears,
  it is excluded from the next capture unless pinned, and Edit and dragging into Strata or Chromium work. If it
  proves insufficient, the gap is raised as a new decision; the plan contains no shim.
- **Status**: Accepted

## DEC-008
- **Question**: How do captures interact with the Area 3 clipboard history (#118)?
- **Context/Nuances**: Omasnap copies PNG output through `wl-copy`. The plan 02-38 `image/png` watcher stores it in
  the RAM history with a 5,000,000-byte per-entry cap; a photographic 1920x1080 PNG measured 2,293,215 bytes in the
  02-38 laboratory. 4K or tall scroll captures may exceed the cap: they are then dropped from history with a
  type-and-size-only journal entry, but remain on the clipboard and on disk. OCR text enters the text history.
  Omasnap cannot mark its copies as sensitive, and the history pause is deferred (02-38 DEC-007).
- **User Response**: Accepted the recommendation.
- **Decision**: No change to Area 3 or to Omasnap: captures enter the history as they are, with no second store.
  The procedure documents two limits: oversized captures are dropped from history but kept on file and on the
  clipboard, and there is no exclusion of sensitive captures until the deferred pause exists, with deleting the
  entry from the picker as the mitigation. The laboratory verifies that a capture appears in the `SUPER+CTRL+V`
  picker and pastes, and that a scroll capture over the cap yields only the type-and-size journal entry.
- **Status**: Accepted

## DEC-009
- **Question**: Which shortcuts, menu entries and layer rules does the screenshot core bind, and is there a capture
  menu?
- **Context/Nuances**: Omarchy (`520c3ed96`, `default/hypr/bindings/utilities.lua`) binds:
  - `PRINT` and `SUPER+CTRL+ALT+C` to a screenshot;
  - `SUPER+CTRL+C` to its Capture menu (`trigger.capture` in `omarchy-menu.jsonc`, with Screenshot, Screenrecord,
    Text, QR Code and Color rows);
  - `SUPER+PRINT` to the colour picker and `SUPER+CTRL+PRINT` to OCR;
  - `ALT+PRINT` to recording.

  The MirrorOS session menu (`menu/MirrorMenu.js`) is an existing ADR 0012 surface derived from the same file, with
  approved rows and a closed action table. A Capture submenu therefore adds rows, not a surface. Omasnap's smart
  mode already chooses region, window or monitor, and `S` switches to scroll. Omasnap's OCR has no standalone CLI.
  Upstream warns against `no_screen_share` on the Omasnap layer.
- **User Response**: Asked why there was no menu. After the explanation, chose to add the menu now (option a)
  rather than defer it to 02-41.
- **Decision**: A new provider file `screenshot-bindings.lua`, registered through `MirrorOSKeys` (ids fixed during
  execution), binds:
  - `PRINT` and `SUPER+CTRL+ALT+C` to the neutral `screenshot` (smart), where a second press dismisses;
  - `SUPER+CTRL+C` to open the menu at `trigger.capture`, through the existing menu IPC, resolved during execution.

  `MirrorMenu.js` gains the rows `trigger`, `trigger.capture` (Omarchy aliases `capture` and `screenshot`) and
  `trigger.capture.screenshot`, with the closed action `screenshot:capture`, which `Menu.qml` maps to a fixed argv
  of the neutral command. These rows are recorded in the shell `UPSTREAM.md` against Omarchy `520c3ed96`. This is a
  row extension of an existing surface, with no new ADR. There are no per-mode keys. `SUPER+PRINT` (Color) and
  `SUPER+CTRL+PRINT` (QR or OCR) are recorded as reserved and unbound for 02-41, as are the Color and QR menu rows.
  Recording rows and keys are out. The layer rule matches `namespace ^omasnap$` with `no_anim` and
  `animation = none`, and without `no_screen_share`.
- **Status**: Accepted

## DEC-010
- **Question**: Should the Omasnap preparation ensure the theme bridge itself rather than rely on Strata?
- **Context/Nuances**: The bridge currently lives in `desktop/files/prepare-strata`, mixed with Strata's first-launch marker. It atomically creates an absent bridge, accepts an identical bridge unchanged, and preserves conflicting state while failing with exit 4. Duplicating this logic risks divergence. Moving bridge creation solely into the first configure step would make a conflict block unrelated consumers earlier than today.
- **User Response**: Requested that the new consumer also ensure the bridge; accepted extraction into a shared script owned by `visual/theme`.
- **Decision**: Extract the existing bridge logic into a shared script owned by `visual/theme`, provisionally `omarchy-bridge apply|check --session|--default`. Both `desktop/files` and the Hyprland provider invoke it through `cfg_user_script`. Each consumer ensures the bridge: create when absent, continue unchanged when identical, preserve and fail on conflict. `prepare-strata` retains only Strata's first-launch marker. Preserve session/default state resolution, atomic creation and existing conflict behavior. Inspect `cfg_user_script` delivery before implementing cross-capability invocation. Update the affected Strata tests without changing its behavior. Add the Omasnap theme-contract test for the bridge path and the pinned upstream keys, documenting fallback values for missing optional keys such as `controls.*`; do not add `[controls]` to the theme. Review Omasnap's Osaka Jade chrome in the laboratory. This replaces the proposed, unaccepted soft dependency on Strata.
- **Status**: Accepted

## DEC-011
- **Question**: How can the neutral command report backend failures if DEC-003 makes it exec the backend?
- **Context/Nuances**: Bash exec replaces the caller, leaving no neutral command to inspect the backend's exit status and send the promised failure notification. Waiting for the backend instead retains a small Bash process but preserves the interface and normal user experience. Pointing users to the journal is only actionable if backend diagnostics actually reach it, including launches from a terminal.
- **User Response**: Requested an explanation of exec versus waiting, then explicitly approved the correction.
- **Decision**: Amend DEC-003: the neutral command invokes the backend without exec, waits for it and preserves exit codes 0, 1 and 2. Success or cancellation (0) adds no notification; failure (1) produces the agreed actionable notification; usage errors (2) remain usage errors. Send backend diagnostics to the journal so the failure notification's reference is valid. The provider backend may still exec Omasnap after translating modes and preparing its environment. This supersedes only DEC-003's neutral-command exec mechanism, not its interface, mode mapping or missing-backend behavior.
- **Status**: Accepted

## DEC-012
- **Question**: Should the plan accept that existing Omasnap previews and pins can appear in subsequent captures?
- **Context/Nuances**: DEC-007 incorrectly required the laboratory to check that an unpinned preview was excluded from subsequent captures. Omasnap v1.26.2's README explicitly states that both existing previews and pins are ordinary compositor windows and remain visible in later captures. Capturing before mapping the selection overlay does not exclude those existing windows.
- **User Response**: Explicitly approved the correction and direct artifact registration.
- **Decision**: Accept upstream behavior without patches. Keep the native preview as success confirmation. Document that users must close or move previews and pins, or wait for an unpinned preview to expire, before taking another capture if they would cover the intended content. The laboratory verifies this actual behavior instead of requiring automatic exclusion. This supersedes DEC-007's preview-exclusion expectation only.
- **Status**: Accepted

## DEC-013
- **Question**: How can a user redact sensitive content before the original is saved or copied?
- **Context/Nuances**: The default capture flow saves and copies before displaying the preview. Editing and redacting afterward does not undo the original file or clipboard-history entry. RAM-only recent documents do not prevent this exposure. Omasnap supports `--editor overlay`, which opens annotation before output and waits for an explicit Copy or Save action.
- **User Response**: Explicitly approved the interface and menu extension and direct artifact registration.
- **Decision**: Keep the fast default flow, and extend the neutral interface to `screenshot [smart|region|window|full|scroll] --edit`, with the mode still defaulting to smart. The Hyprland backend translates `--edit` to `--editor overlay`. Add a Capture menu row labelled `Screenshot with annotation`, without a new shortcut. Document that normal captures save and copy immediately, while sensitive captures should use `--edit`, redact first and then explicitly save or copy. This extends DEC-003's interface and DEC-009's menu; it does not change the fast-path defaults or claim to remove earlier copies.
- **Status**: Accepted

## DEC-014
- **Question**: What is the laboratory scope and how is VM access handled?
- **Context/Nuances**: The reference VM can validate the desktop flow but does not imply T14s qualification, fractional-scale qualification or multi-monitor coverage. `.agents/lab-access.md` is local workflow guidance for access, not a product artifact. It specifies the VM SSH identity and endpoint and attended sudo through a tmux window.
- **User Response**: Approved the proposed campaign and requested inclusion of the connection and SSH/sudo authorization-window information from `.agents/lab-access.md`.
- **Decision**: Run one campaign on the reference VM, requesting deployment authorization at execution time and ending with a blocking human checkpoint. Cover initial and repeated configure; a fresh session for environment.d; region, window, monitor and scroll captures; cancellation and second-press dismissal; shortcuts and both Capture menu actions; preview, editor, pins and Osaka Jade theme; synthetic redaction before export through --edit with file and clipboard inspection; English OCR; clipboard history and a scroll capture exceeding 5,000,000 bytes; slug-free filenames and metadata; RAM recent documents through menu, terminal and Open With; actionable errors and journal diagnostics. Run only affected automated tests. Keep synthetic, non-sensitive evidence in ignored `evidence/screenshots/lab-02-40/` with SHA256SUMS. Do not claim T14s, fractional-scale or multi-monitor qualification when the VM cannot provide it; record limitations explicitly. Follow `.agents/lab-access.md`: connect with `ssh -i ~/.ssh/id_ed25519 viespejo@127.0.0.1 -p 2222`; when SSH and sudo are needed, open a window in the current tmux session for the user to enter the sudo password, monitor the operation and confirm automatic window closure on completion. Never record credentials in evidence or source artifacts.
- **Status**: Accepted

## DEC-015
- **Question**: How is the candidate delivered, tested, committed and closed?
- **Context/Nuances**: Follow plan 02-38's delivery pattern. The selected formal dependencies are none; earlier plans provide context, not implicit dependency edges. The user explicitly restricts tests and live checks to those affected by the changes, excluding complete suites.
- **User Response**: Approved delivery and closure, reiterated affected-only testing with no full suites, and requested direct materialization. Final plan materialization remains subject to the planning workflow's draft approval gate.
- **Decision**: Use temporary candidate refs `refs/mirroros-candidates/02-40-lab-*`. Return failures to their owning tasks and rerun only affected checks. After laboratory approval, commit by concern with a temporary index as in 02-38; update scope, procedure, attribution and provenance together with their governing changes. Remove candidate refs and write `.agents/plans/02-40-story-4-5-screenshots-SUMMARY.md`. Do not commit `.agents/`, evidence, generated outputs, secrets or personal configuration. Run only specifically affected tests and live checks, never complete test suites. Plan frontmatter uses `dependencies: []`.

### DEC-016 — Adopt the reviewed Save As portal patch after the isolated prototype

- **Question**: Should Save As use Strata without desktop-entry overrides or a wrapper that misses direct launches?
- **Evidence**: The maintainer authorized an isolated Omasnap 1.26.2 experiment, then confirmed the complete Strata
  Save As cycle worked without perceptible delay. The prototype removed `DontUseNativeDialog` and launched with
  `-platformtheme xdgdesktopportal`; removing the dialog option alone is insufficient because main.cpp forces generic.
- **Decision**: The maintainer explicitly authorized product adoption and then extending the patch to main.cpp so
  every launch path selects xdgdesktopportal. This narrowly supersedes DEC-004's unpatched-source requirement and
  the execution plan's no-source-patches boundary for these two changes only. Keep pkgname omasnap, bump pkgrel to
  4.2, embed the strict patch in the self-contained reviewed recipe, declare the portal frontend dependency and
  record Qt plugin ownership from the VM. Do not alter the neutral interface, add desktop overrides, shadow the
  executable, change global Qt/portal settings or change normal autosave/copy defaults. A/E remains available in
  the selector for opt-in annotation. The final package requires focused contracts and attended Save As retests
  across launcher, terminal, Open With and the neutral flow; prototype success is not final-package acceptance.
- **Related execution findings**: Correct Capture's truncated annotation row and wait for menu unmap/presentation
  before capture. A new graphical session can retain an old user manager while other sessions exist; document the
  fresh-manager requirement observed in the laboratory. Maintainer authorized synchronizing already-committed main
  weather files during the next deployment, without weather source changes or unrelated weather checks. Final
  checkpoint approval and delivery closure remain pending.
- **Execution amendment**: The maintainer subsequently requested removal of the experimental backing-window wait,
  pending-capture state and 100 ms delay from the product. Restore immediate fixed-argv dispatch after closing the
  menu; retain compositor animations and the wider Capture card. Automated screenshots did not establish a cause
  or a verified fix for the frozen-background menu finding. Deployment and live reproduction remain pending.
- **Menu finding resolution**: A subsequent SUPER+CTRL+C then Enter trial through the existing SPICE viewer,
  without menu IPC or compositor key dispatch, reproduced the partially faded menu in both the selector background
  and exported PNG. Earlier keyboard attempts had been confounded by an active session lock. The maintainer
  authorized a VM-file-only exact `^mirroros-menu$` rule with `no_anim=true` and `animation="none"`, matching
  Omarchy `520c3ed969d30b58defe03eb19d603f32b4cb002`, `default/hypr/apps/omarchy-shell.lua`. After a configuration
  reload, one repeated Screenshot selector/export check had no menu residual. The maintainer approved product
  adoption and removal of the temporary VM file. Keep immediate dispatch, no timer, no global animation change
  and no `no_screen_share`. This bounded check does not establish repeated reliability or separately retest
  annotation. Overall checkpoint and delivery closure remain separate.
- **Status**: Accepted

## Execution closure — 2026-11-17

- **Approval**: After candidate lab-d deployment, the maintainer confirmed the final visual check succeeded
  ("ya lo comprobé...todo bien!"), explicitly approved the campaign checkpoint ("approved"), and authorized
  checksum consolidation, concern-separated commits, candidate-ref cleanup and the execution summary.
- **Final candidate**: `3971bf5871790b8ed8fdd57badef7f6b83f56615` (lab-d), with Omasnap `1.26.2-4.2`.
  All 874 installed capability-source paths matched the candidate; published screenshot bindings matched the
  accepted source. Configure succeeded twice, with the second run 26/26 unchanged. The config-only Hyprland
  reload succeeded without configuration errors or a shell restart. The guarded temporary personal menu-rule
  file was removed; the product rule now survives reload without that override.
- **Final behavior**: Keep normal upstream autosave/copy, opt-in pre-output annotation, immediate fixed-argv menu
  dispatch and the screen-clamped wider Capture card. Only the exact `mirroros-menu` and `omasnap` layers disable
  animations. No delayed launch, global animation suppression, desktop override or clipboard-store change.
- **Observed campaign**: Shortcuts/menu, cancellation/dismissal, normal smart save/copy, explicit region/window/full
  with `--edit`, scroll, English OCR/history, preview/editor/pin/drag and Osaka Jade chrome were confirmed.
  Independent probes found no premature file/clipboard export at editor-open; the redacted exported file and
  clipboard were identical. The measured scroll PNG was 10,183,785 bytes, usable on file/current clipboard but
  absent from history, with type-and-size-only diagnostics. PNG inspection found only logical-size text metadata
  and date/time-only filenames. Runtime recent documents and absence of a new default disk store were observed
  through wrapper, launcher, terminal and Open With after a fresh user manager.
- **Save As evidence**: The maintainer reported the full isolated Strata chooser cycle and later broad success
  with the final package. These reports and the final visual confirmation do not enumerate every launch-path,
  cancellation, focus or overwrite combination; do not invent a per-path matrix or performance measurement.
- **Failure scope**: Missing-backend recovery and journal guidance were observed and injections restored. The
  real backend failure exercised a runtime precondition, not an Omasnap image-acquisition failure.
- **Verification deviation**: One Node test-name-filter attempt hit a custom runner that ran all 16 checks in
  that file, all passing; subsequent Capture runs used its actual custom filter. No repository-wide suite ran.
  Accidental menu/test edits during an earlier misunderstanding were precisely reverted before deployment;
  later no-delay and menu-rule product corrections were separately authorized and accepted.
- **Evidence**: The allowlisted synthetic campaign artifacts are checksummed in ignored
  `evidence/screenshots/lab-02-40/SHA256SUMS`; excluded exploratory/invalid/masked captures and candidate bundles
  are not delivery evidence. The execution SUMMARY records final commit identities and checksum verification.
- **Limits and follow-up**: Reference VM only, not T14s, fractional-scale or multi-monitor qualification. The
  existing experimental lab clipboard service was left untouched; no isolation claim. Explicit normal modes
  without `--edit` were not separately repeated. Recent RAM storage is not secure erasure and exported originals
  remain on disk. Plan 02-41 retains Color/QR and reserved keys; recording and history pause remain deferred.

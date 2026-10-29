# Wallpaper selection research

This record supports [ADR 0020](../adr/0020-wallpaper-selection.md). It records investigation and prototype observations, not an accepted architecture or product qualification.

## Omarchy alignment checkpoint

The maintainer approved the complete point-by-point alignment proposal after rejecting unnecessary independent
complexity. This checkpoint supersedes the earlier per-output animation, JSON-persistence, rollback/fallback,
status IPC and separate-background-publication descriptions below; those sections retain historical evidence,
not the current implementation contract. The current interface is documented in
[desktop-shell.md](../procedures/desktop-shell.md#wallpaper-interface-deployment-validation-pending).

- The six unchanged PNGs now live under `capabilities/visual/theme/default/backgrounds/`, with numeric prefixes;
  delivery is inside `/usr/share/mirroros/themes/default/backgrounds/`, not a separate background tree. Theme
  configure initializes `current/background` to the approved logo image (`2-mirroros-jade.png`) only when absent
  and preserves existing paths.
- Selection is the shell-managed `current/background` symlink, resolved at startup and on refresh. The adapted
  setter accepts any existing file, runs plain `ln -nsf` before display and preserves a non-symlink selection path.
  JSON state, generation/all-output save barrier, timers, rollback and automatic fallback are removed. Old JSON
  files are not read, migrated or deleted. A corrupt existing file can be persisted; runtime keeps the previous
  image, while startup with that selection leaves an empty background. Concurrent writes are not guarded.
- `Wallpaper.qml` reuses the original shared reveal state and first-ready-output start. `ScreenMoveRemap.qml` is
  copied unchanged and registered for both bar and background. It was not initially registered in `Ui/qmldir`;
  the isolated guest load caught this and a regression now covers registration.
- The catalog resolves theme directories before listing, derives the personal folder's theme name from the
  `current/theme` target and uses `sort -z`. Every next request rescans all entries. The picker deduplicates by
  basename, first sorted path wins, as Omarchy; next deliberately does not. The inherited individual-image-link
  identity limitation remains. Empty next scans notify through the shell for two seconds.
- The integrated picker remains an approved adaptation: internal signals/argv replace external scripts,
  selection/done files and encoded IPC rows. It now loads thumbnails generated with Omarchy's libvips options,
  size/mtime index, per-thumbnail locks, stale-partial cleanup and parallel fan-out. Internal pairs are NUL records;
  TSV index path keys are base64 so tabs/newlines remain opaque. External row/preload caches and generic selector
  modes are omitted; each opening rescans and revalidates the thumbnail index. `libvips` is declared from extra.
- Style > Background, Install > Style > Background and Super+Ctrl+Space retain upstream ids, labels, icons and
  aliases. The chord explicitly supersedes the earlier Story 4.3 exclusion. Install creates the per-theme personal
  folder and opens Nautilus; the new desktop/files capability declares only Nautilus, with no optional extras or
  preferences. Actual dependency effects on audio/battery widgets remain unqualified.

Additional installed reference identities, not assigned the older shell Git pin:

| Reference | SHA-256 |
|---|---|
| `/usr/bin/omarchy-menu-images` | `9d113b2138c49a944fe4e25f5b062d875d8ef4aaa5e00e59cc9282229d8e2093` |
| `bin/omarchy-theme-bg-set` | `afee8d3bdd15917a2553c4f7a542de507f3f1b6e63eb92d38b5b1efe952209a0` |
| `bin/omarchy-theme-bg-install` | `f23306136f240f330db1d477eaedbc378a67ba98ee2f7dda665fe78bf41a2ba5` |
| `shell/Ui/ScreenMoveRemap.qml` | `ae09782672877502015e517c6f58565cf79b82e0aa1dc56ee5655989863ad8a7` |
| `default/omarchy/omarchy-menu.jsonc` | `8c791cfc457d6c50b90a6636a6f28c9415a2fa6e4edf84826906457b75649689` |
| `default/hypr/bindings/utilities.lua` | `60b4ad67084d71222f04b118d6b5df0da7bc7b48169655674b84ae6d2f36b5ff` |

The final non-theme-management differences are bounded integration/ownership adaptations: non-symlink conflict
preservation (requirement); argument-array execution (architecture requirement); integrated signals and no
external selector protocol (approved design choice); directory resolution and derived theme name (required by the
chosen linked-theme layout); NUL records/base64 index keys (retained filename handling); picker output-removal
cancellation (discretionary safeguard, still needs real-output validation). Native IPC logs asynchronous failures
and rejects overlapping operations as busy rather than queuing them; accepted does not acknowledge save/display.
Screen remapping, reveal, corrupt-image behavior, duplicate policy, thumbnail settings, menus and chord are reused,
not claimed deviations. Product images are original MirrorOS assets, not copied Osaka Jade backgrounds.

The shared reference can keep an incoming frame after a completed reveal if the base-ready event arrives before
`finishingTransition` is set. The headless probe observed this; the test checks completed progress/display instead
of inventing a stricter cleanup guarantee. No adjacent upstream behavior was refactored.

No permanent shell deployment, full configure run or session replacement is authorized by these tests.
The maintainer subsequently authorized installing libvips and Nautilus in the MirrorOS guest and testing them
in isolation; see the real-application checkpoint below. Installed-path loading, actual input/focus, visuals and
real multimonitor connect/disconnect/move remain separate deployment gates. Earlier cache and IPC tests retain
explicit command doubles; their results are not counted as real-application validation.

### Alignment verification

- Host shell Node run: 51 harness passes, 10 dependency-gated skips, no failures. The legacy menu-model script
  contributes one harness pass and reports its own 11 assertions; those are not added again to the harness count.
- Focused host wallpaper/remap, bindings and theme run: 46 passes, two runtime skips, no failures. This overlaps
  the shell run and is not an additional independent total.
- Configure contracts using doubles: 34 Bats cases passed across shell, files and target contracts, including
  fourteen-step convergence/idempotence and preservation of current/background plus obsolete prototype JSON.
  All six runtime-publication contracts also passed (40 Bats cases total in these runs).
- Disposable MirrorOS guest: all 20 wallpaper/remap cases passed, including real native IPC, fresh next scans,
  outside-catalog existing files, missing-file refusal, empty notification, personal-folder creation/Nautilus argv,
  integrated picker methods, cancellation while an opening scan is in flight, closed menu routes, corrupt
  persistence and startup without fallback. Nautilus and
  thumbnail generation are explicit command doubles, not installed-application qualification.
- Private D-Bus/headless Weston exercised the shared reveal and a full-shell load. There was no injected input,
  active-session replacement or real layer-shell/multimonitor qualification. The inherited incoming-frame retention
  described above was observed. Quickshell 0.3.2-1, Weston 15.0.1-3, Qt declarative 6.12.0-2 and guest Node
  v24.22.0; no packages were installed. Final process inspection found only the existing installed shell (PID 593),
  with no test Quickshell or Weston left running.
- Guest qmllint: 62 QML files, 832 reviewed warnings, no new or stale baseline entries after adding exactly two
  reviewed wallpaper diagnostics: PanelWindow creatability metadata (runtime loading succeeds) and the dynamic
  Style.font.title token (present in Style.qml). No diagnostic category was disabled.
- ShellCheck for list-wallpapers, wallpaper-set and wallpaper-thumbnails and git diff --check passed.

### Real-application validation checkpoint

After separate maintainer authorization, libvips 8.18.7-1 and Nautilus 51.1-1 were installed in the MirrorOS
VM through interactive Kitty/SSH and sudo. PipeWire 1:1.6.10-1 and UPower 1.91.5-1 are now present as dependencies;
their effects on the active shell's audio/battery widgets remain unqualified. No full configure run, runtime
publication, installed-shell restart or commit was performed.

`tests/capabilities/desktop/shell/wallpaper-applications.test.mjs` adds dependency-gated real-application probes:

- Real libvips decoded all six product PNGs into JPEG thumbnails with verified 1536x864 dimensions. A second run
  reused the same paths and preserved thumbnail modification times. A corrupt PNG was omitted. These assertions
  supplement, rather than replace, the command-double tests for arguments, invalidation and concurrency.
- Real Nautilus opened an isolated personal-background directory on private D-Bus and headless Weston. Its
  `org.freedesktop.FileManager1.OpenLocations` property contained that directory's file URI. HOME and all XDG
  user directories were temporary. A warning about the missing Mutter-specific Wayland service channel was
  observed; opening succeeded, but portal dialogs were not exercised or qualified.
- The complete guest wallpaper/remap run passed 22 cases with no failures or skips, including the existing native
  IPC and shared-reveal/full-shell-load probes. This is a new run containing the earlier 20 cases plus two real
  application cases, not 22 additional independent cases. Native IPC still uses its explicit application doubles.
- Final process inspection found only the unchanged installed shell, PID 593, with no test Nautilus, Weston or
  Quickshell left running. Only the newly created guest test-copy directory was removed afterwards.

These probes qualify isolated real decoding/cache reuse and file-manager folder opening, not picker input,
focus arbitration, visual appearance, installed paths, real multimonitor/hotplug or active-session integration.

### Installed-session and attended validation checkpoint

The maintainer separately authorized a bounded deployment in the MirrorOS reference VM, with backup and rollback,
followed by a shell restart and attended checks. Only the manifest-managed shell and default-theme trees and the
tracked Hyprland `defaults.lua` and `shell-bindings.lua` were published. Preflight verified intact previous trees
and unchanged supporting loaders, monitor configuration and user entry point. Personal configuration was not
modified. The initial background link was created only because it was absent. No full configure run or commit
was performed.

The shell was stopped before publication to avoid a partial live reload, then Hyprland was reloaded and the shell
started. Installed shell/theme manifests matched the staged source, both Hyprland file hashes matched their
delivery records, and Hyprland reported no configuration errors. The installed shell was active with zero automatic
restarts, exposed the five wallpaper IPC methods, and registered the Background switcher chord. An initial SSH IPC
inspection lacked the session display; it succeeded after supplying the existing Wayland display context.

The maintainer reported that the requested manual checks all appeared OK: visible jade background;
Super+Ctrl+Space opening the picker, arrow navigation and Enter selection; desktop double-left-click opening it,
Escape cancellation; and normal terminal typing afterwards. This is a bounded user-reported input/focus and visual
smoke result on one Virtual-1 output (1920x1080, scale 1.6), not exhaustive focus arbitration or visual qualification.

The current invocation logged a failed PipeWire context connection and a portal app-ID registration warning.
Neither was reported to block the wallpaper checks; their cause and audio/portal effects remain unresolved.
Real multimonitor connect/disconnect/move remains pending.
A subsequent authorized shell-only restart preserved the existing `2-mirroros-jade.png` selection exactly; the
service returned active with zero automatic restarts and wallpaper IPC available. Hyprland reported no
configuration errors. The PipeWire connection error recurred, but the portal registration warning did not appear
in that invocation. The maintainer subsequently confirmed that the logo remained visible after this restart and that the requested
Install > Style > Background action opened Nautilus. No logout or reboot had been tested at that checkpoint. The root-only product backup and rollback script are retained under
`/var/lib/mirroros/wallpaper-backup.*/`; temporary deployment staging is retained until review is complete.
Rollback has been prepared, not exercised. No claim of laptop qualification is made.

### Follow-up audio diagnostic

Read-only inspection after the attended wallpaper checks found `pipewire` installed, but both `pipewire.service`
and `pipewire.socket` inactive and no PipeWire socket in the user's runtime directory. The socket unit was enabled
on disk; the service was disabled, and neither had recent journal entries. `wireplumber`, `pipewire-audio` and
`pipewire-pulse` were absent. No PipeWire/Pulse environment override was found in the shell unit or user manager.
This is consistent with the shell's failed PipeWire context connection and incomplete audio setup, not evidence of
a wallpaper regression. No audio service was started, enabled or configured, and no additional package was
installed by this diagnostic. Complete audio behavior and the effect of starting its services remain unqualified.

### Default-background amendment

After the attended VM smoke check, the maintainer selected the MirrorOS logo background (`mirroros-jade.png`,
delivered as `2-mirroros-jade.png`) as the default instead of the phase-space image. `prepare-current` now
initializes that explicit path only when no selection exists. Numeric filenames and image bytes remain unchanged
to avoid invalidating saved paths in already deployed installations. Unlike the earlier first-sorted-image rule,
the default is therefore independent of catalog order; this is a bounded adaptation for the maintainer's revised
product default, not a change to picker or next ordering. Existing selections are not reset or migrated.
Host verification: all 16 theme Node cases and all eight theme configure Bats cases passed.

### Reboot persistence checkpoint

The maintainer explicitly authorized a reference-VM reboot. The initial noninteractive SSH request was denied
because interactive authentication was required; a Kitty/SSH sudo invocation then performed the reboot.
Read-only post-boot inspection confirmed a changed kernel boot ID, the unchanged `current/background` link to
`2-mirroros-jade.png`, an active installed shell with zero automatic restarts, available wallpaper IPC and no
Hyprland configuration errors. The maintainer confirmed that the logo was still displayed correctly after login.
This qualifies the tested selection's persistence across one real VM reboot, not arbitrary logout/reboot cycles
or laptop behavior.

PipeWire's service and socket were active after boot and the shell's earlier PipeWire connection error did not
recur in the inspected boot log. No audio package or service configuration was added during this follow-up, and
actual sound/input routing remains unqualified. The portal app-ID registration warning recurred; its cause and
portal behavior remain unresolved. Real multimonitor connect/disconnect/move remains pending. Backup and rollback
material are still retained, and no commit or full configure run was performed.

### Portal registration diagnostic

Read-only inspection found xdg-desktop-portal 1.22.1-2 and its GTK backend 1.15.3-2 active, with no unit drop-ins
or user portal-selection files found. The Hyprland backend was not installed; its absence alone does not explain
the registration warning, and this investigation does not select a portal provider. The user manager exported
Hyprland/Wayland session context. Qt package versions were qt6-base 6.12.0-3, qt6-declarative 6.12.0-2 and
qt6-wayland 6.12.0-1.

The [portal Registry contract](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.host.portal.Registry.html)
allows registration only once per D-Bus peer and before other portal calls. The
[Qt 6.12.0 implementation](https://github.com/qt/qtbase/blob/v6.12.0/src/gui/platform/unix/qdesktopunixservices.cpp)
emits the observed warning from its asynchronous registration callback. It attempts initial registration and
watches for portal-service registration; its registered flag is set only after a successful reply. Startup timing
or an earlier portal call is therefore a plausible explanation, not a traced or reproduced root cause in this VM.

A separate read-only D-Bus client successfully read `org.freedesktop.appearance` / `color-scheme` (uint32 0);
Settings version 2 and FileChooser version 4 were exposed. The installed shell remained active with zero automatic
restarts. This establishes basic portal responsiveness, not the shell's own portal connection, successful chooser
dialogs, screen sharing or complete portal integration. No service restart, provider installation, configuration
change or warning suppression was performed. The warning remains an upstream/integration investigation item;
there is no demonstrated wallpaper failure requiring a product-code workaround.

### Final review and available-environment regression checkpoint

The maintainer confirmed that no second monitor is available in this context. Real multimonitor and
connect/disconnect/move validation is therefore **blocked by unavailable hardware**, neither passed nor failed.
This does not waive ADR 0020's output-lifecycle gate or qualify the target laptop. The authorized VM deployment
and its attended acceptance remain explicitly bounded to the single tested output.

Final host regression after the logo-default amendment: 79 Node harness passes, 12 dependency-gated skips,
zero failures across shell, theme and Hyprland-binding tests; all 48 Bats cases passed across files, shell,
runtime publication, theme and target configure contracts. The menu-model script's 11 internal assertions are
not added again to the Node harness total. These runs overlap earlier counts and are not additive. ShellCheck
passed for the file-manager apply script, wallpaper scanner/setter/thumbnail helper and theme initializer;
`git diff --check` passed. The earlier guest run remains 22 passes with no skips; no new guest runtime run was
claimed for this final host checkpoint.

Review did not identify an additional required change to the wallpaper pipeline. The tested single-output
scope includes real libvips caching, isolated Nautilus opening, installed-path publication, attended picker
input/cancellation and keyboard return, the attended Install action, and visual logo persistence after a shell
restart and one VM reboot. Separate Style menu-route confirmation was not individually reported. Exhaustive
overlay focus arbitration, multi-output lifecycle, portal dialogs, audio routing and rollback execution are not
qualified. The portal-registration warning remains under investigation without a demonstrated wallpaper failure.

No further deployment, package installation, full configure run, commit, or deletion of backup/personal material
was performed during this final review. Source changes remain uncommitted among other desktop/theme work;
backup and temporary deployment staging are retained for review and possible rollback.

## Reference and candidates

The inspected Omarchy reference uses a Quickshell background plugin, one background-layer panel per screen, an image picker, personal selection, IPC and a next-image command. The surface ignores window exclusion, requests no keyboard focus and waits for the incoming image to be ready. The next command enumerates personal and theme directories, sorts them and wraps. Its theme switching is outside the MirrorOS proposal. These source observations do not establish hotplug or failure behavior; copied material requires attribution review.

- The [swaybg manual](https://man.archlinux.org/man/swaybg.1.en) describes a separate Wayland background process, per-output selection and fill. It does not document a visual selector or animated changes.
- [hyprpaper](https://wiki.hypr.land/hypr-ecosystem/user/hyprpaper/) documents IPC and fallback monitor configuration. The [Arch package record](https://archlinux.org/packages/extra/x86_64/hyprpaper/) observed version 0.8.4-9, BSD-3-Clause. A selector and interaction require additional integration.
- The [swww repository](https://github.com/LGFae/swww) says the project was renamed `awww` and moved to Codeberg. The [Arch package record](https://archlinux.org/packages/extra/x86_64/awww/) observed 0.12.1-1, GPL-3.0-only, providing and replacing `swww`. Its [image manual](https://man.archlinux.org/man/awww-img.1.en) documents a separate daemon, transitions, crop, output selection and per-output cache. A selector and background gesture require additional integration.

Package records are observations, not installed or pinned versions. On the development host, no Quickshell, swaybg, hyprpaper, swww, awww, Weston or Cage executable and no Wayland display were available. Read-only VM checks found Quickshell `0.3.2-1` in MirrorOS and `0.3.2.r7.g2b4501a-1` in Omarchy; none of the other named tools was found on PATH or in the queried package database. This is not evidence of repository availability or comparative behavior.

## Comparison checkpoint

`Not tested` is neither a pass nor a failure. Documented behavior is not a practical test.

| Scenario | Owned Quickshell prototype | swaybg | hyprpaper | awww |
|---|---|---|---|---|
| Initial display and fill | One active-session output displayed with aspect-preserving crop | Fill and output selection documented; not tested | Monitor configuration documented; not tested | Crop and output selection documented; not tested |
| Output addition and removal | Not tested | Not tested | Not tested | Not tested |
| Changes and transitions | Two distinct images and rapid valid/missing/valid requests completed on one output | Animated changes not documented in reviewed manual; not tested | IPC documented; transitions not tested | Transitions documented; not tested |
| Invalid or removed image | Missing request rejected; removal of displayed image not tested | Not tested | Not tested | Not tested |
| Restart and selection recovery | Not implemented | Not tested | Not tested | Cache documented; recovery not tested |
| Input focus and exclusion | Requests no keyboard focus and ignores exclusion; interaction not tested | Not tested | Not tested | Not tested |
| Selector, next action and gesture | Not implemented | Additional integration required; not tested | Additional integration required; not tested | Additional integration required; not tested |
| Lifecycle and maintenance | Existing shell process; new owned surface, state and selector code; test-child cleanup verified | Separate process and selector integration | Separate process, Hyprland association and selector integration | Separate daemon and selector integration |

This checkpoint does not establish NFR37 compliance or a winner by measurement. The maintainer selected the Quickshell direction; comparisons supply evidence for review, not another product-choice request.

## Reference implementation details

Read-only inspection of the Omarchy VM found package `omarchy 4.0.6-1`. Local reference copies match the installed files by SHA-256; this does not establish a Git revision for the package:

- `/usr/share/omarchy/shell/plugins/background/Background.qml`: `6135a06b4c17c9a5a251053c294a657ecd80eb3a339f6eea146455b3925fd65b`. It uses per-screen background panels, separate displayed/old/incoming images, readiness before a 420 ms `InOutCubic` reveal, and an expanding slanted mask. Double left-click opens the selector; double right-click invokes theme switching, which MirrorOS excludes. The shared reveal begins when a panel becomes ready; the reference does not prove an all-output readiness barrier or invalid-image recovery.
- `/usr/share/omarchy/shell/plugins/image-picker/ImagePicker.qml`: `9799f9cb52ffc4bd6d3089a50b73386b017e1c726b786e193e12d83561385ca8`. The picker uses an overlay and exclusive keyboard focus while open, a large selected preview, skewed narrow neighboring slices, dimming, keyboard navigation and mouse selection. It defers showing the carousel until layout settles. Its external-process selection protocol is not automatically a MirrorOS requirement.
- `/usr/share/omarchy/shell/plugins/image-picker/ImagePickerModel.js`: `2eecf32b70811d0a39981e351ebe9843384aaf97b43dad1216651d2535a9a5da`. Its newline/tab rows and basename deduplication have different filename and duplicate semantics from the MirrorOS catalog experiment; do not silently claim parity.
- `omarchy-theme-bg-next` enumerates both directories with `find -L`, NUL-delimits and sorts paths, then wraps. `omarchy-theme-bg-set` resolves a file, force-replaces the current background symlink and invokes shell IPC. MirrorOS must preserve unknown personal files and links, so blindly copying the force-replacement behavior would violate its ownership contract. The reference picker also constructs shell command strings; MirrorOS must use bounded argument arrays instead.

The first MirrorOS `Wallpaper.qml` only loaded a single image. It now adapts the reference slanted-mask reveal, 420 ms cubic animation and double-left-click signal. Loading and animation are per output; the previous base stays while an incoming image loads, and a five-second load timeout or image error rejects the incoming request. The incoming layer remains until the replacement base is ready. Theme synchronization, the right-click theme gesture and the separate old-frame override were omitted. The selector signal now opens `WallpaperPicker.qml`, adapted from the installed reference. `WallpaperActions.qml` supplies a generation-tagged requested path through native IPC, and `WallpaperLibrary.qml` scans separate product and personal directories. `WallpaperState.qml` now restores and saves private JSON state only after confirmation from all current output instances. Product image publication is not implemented yet.

`tests/capabilities/desktop/shell/wallpaper-runtime.test.mjs` creates two distinct PNG fixtures and a missing path in a disposable directory. The first offscreen attempt failed because this Quickshell has no offscreen `PanelWindow` backend. The revised test passed in the MirrorOS guest using a private D-Bus session and headless Weston: it observed initial display, replacement, rejection of a missing file and subsequent recovery. This is image/lifecycle evidence, not layer-shell placement, visual mask correctness, mouse interaction, rapid replacement or multi-monitor qualification. Weston is a test dependency only. A malformed cleanup command in the first remote invocation left a temporary source directory; the subsequent invocation explicitly removed it and used a cleanup function.

## Prototype observations

An authorized temporary Quickshell prototype ran independently of the installed shell in the MirrorOS guest. Qt reported the approved 2560×1440 image ready; Hyprland placed its namespace at background layer level 0 on `Virtual-1`, below the existing bar at level 2. The maintainer confirmed its appearance. One probe initially left its Quickshell child running after its wrapper stopped. The child was identified and stopped, the layer disappeared, and the installed shell remained active. A later direct-PID cleanup test also removed the temporary layer. These are single-output observations, not proof of focus, selection, recovery or deployment readiness.

A separate non-product transition prototype used PID-addressed Quickshell IPC and waited for image readiness before fading. A change between distinct images completed. A rapid valid/missing/valid sequence rejected the missing image and completed the final request. The process and layer were removed and the installed shell remained active. Persistence, selector behavior, all race timings and multiple outputs remain untested.

The ignored plan `tmp/mirroros-fixed-theme-plan.md` records additional local experiments, including isolated catalog and transition-state tests, unsuccessful isolated layer-shell attempts and temporary testing packages. It is working material, not a durable source or product implementation.

## Product interface checkpoint

The current source exposes `wallpaper` IPC actions `open`, `close`, `next`, `set`, `refresh` and `status`, without a new default key chord. The picker retains the reference skewed carousel and keyboard/mouse handlers, but replaces its external-file protocol with signals. The read-only catalog uses `/usr/share/mirroros/backgrounds` and `$XDG_CONFIG_HOME/mirroros/backgrounds`; it preserves equal basenames and transports NUL records instead of newline/tab rows. The installed `omarchy-theme-bg-next` reference matches the working copy at SHA-256 `3dbef062b7bde6322f428969bde9eb76fe436e3ab969ca0bc1ca7c46d5835241`.

All 17 focused wallpaper tests passed together in a disposable MirrorOS guest tree. These include native IPC with a real catalog reader and a fake picker, opaque filenames including newline and shell syntax, scan conflicts, and a separate headless Weston test using the real picker and surface. The latter invokes picker methods to open, navigate, select and close, including an empty catalog; it does not inject actual keyboard or mouse events. Process and temporary-directory checks found no matching test leftovers; the installed shell remained active. No installation or active-session replacement occurred.

The host passed 15 logic/contract tests and skipped the two dependency-gated runtime tests. Bash syntax, ShellCheck and parsing of the picker/library passed; host `qmlformat` rejects the typed IPC functions, while guest Quickshell loaded and exercised them. Installed-path integration, focus arbitration with other overlays, visual mask/carousel appearance, actual input, hotplug and multi-monitor recovery remain unqualified.

## Persistence checkpoint

The newer focused run passed all 28 wallpaper tests in the disposable MirrorOS guest. Host checks passed 20 cases and skipped eight dependency-gated runtime cases; 13 runtime-publication/configure contracts also passed, now including synthetic wallpaper-state preservation. Bash syntax and ShellCheck passed for the state and scan helpers.

The real QML state service passed absent-state/no-startup-write, valid restoration, latest-save coalescing, malformed JSON, symlink preservation and a changed-on-disk save refusal. Helper tests also cover hardlinks, unsafe ancestors and concurrent writers sharing one baseline. A headless Weston test connected the real surface, actions and state: missing-image rejection did not save the failed path, rapid valid/missing/valid replacement retained the final request, and another process restored the saved image without changing the state file's modification time. A further restart with a saved missing image displayed a fallback while preserving the missing-image state bytes and modification time. A temporary full-shell startup also loaded successfully, using isolated configuration and state directories. No matching Quickshell/Weston test processes remained and the installed shell stayed active. A pre-existing `/tmp/mirroros-wallpaper-preview` directory was left untouched. None of these tests replaces visual, actual-input or real multi-output qualification.

The new state is version-1 JSON under the private wallpaper state directory, not Omarchy's force-replaced selection link. Saves follow generation-aware confirmation, use an exact-read baseline and cooperating-writer lock, and replace the file atomically. These are conflict/preservation measures, not a sandbox against hostile same-UID activity, a complete check/rename race defense or a power-loss guarantee. Startup recovery can show a fallback but never rewrites the saved selection. Product asset publication and its rights review remain open.

## Asset provenance checkpoint

The approved phase-space generator was recovered from the project session. An ignored working copy with only its output path changed reproduced the approved PNG byte for byte using Python 3.13.1 and Pillow 11.1.0. The PNG SHA-256 is `f1fde4145b25d4b91196cb87077fa20c1bdc530d6bb0c06ba82e9f5bd12a3494`; the modified-path script SHA-256 is `b94a1e615fcb6bc2202bbc4916731a2bd4eae160eeeb9f33a1f6a1a179d82e2e`. It describes an unforced damped Duffing system integrated with RK4, seeded initial conditions and composited jade trajectories. A mathematical description alone does not reproduce Pillow rasterization, compositing or PNG encoding. The ignored copies are not durable assets, and project-owned Python is not admitted by the architecture.

The selected working set also includes an approved minimal symbol image and four images supplied by the maintainer, who reports generating the latter with OpenAI Image (`gtp-6`, as reported). Exact model identification, applicable terms, inputs and third-party rights remain unverified. Review provenance, licenses and distribution rights before publication.

Each of the four supplied PNGs contains one embedded C2PA manifest (`caBX` chunk, specification 2.2.0, `c2pa-rs` 0.79.2) and no textual metadata. A read-only string inspection found claim generator `OpenAI Media Service API`, software agent `ChatGPT` version `gpt-image`, IPTC digital source type `trainedAlgorithmicMedia`, `c2pa.created` actions dated 2026-10-29 between 01:08 and 01:44 UTC, a `c2pa.converted` action, an unbound watermark assertion and a signing chain naming `OpenAI OpCo, LLC`. No ingredient, placed, opened or edited assertion was found. The signatures and data-hash bindings were not cryptographically validated because no C2PA validator was available; this supports, but does not prove, the reported origin and absence of uploaded input images. Any byte change, including lossless PNG recompression, would invalidate the data-hash binding, so the working copies were not optimized. Personal images are user data and must remain separate from managed assets.

## Publication checkpoint

The maintainer confirmed that the Emerald prompt requested only the Osaka Jade style, without supplied images, accepted their distribution under the project license and accepted committing the six PNGs (about 11 MB) as authoritative source assets with documented methods instead of project-owned Python. For comparison, Omarchy 4.0.6's installed Osaka Jade background directory occupies about 15 MB including its intro assets. The maintainer regards the images as part of the default theme: they live in `capabilities/visual/theme/backgrounds/` and the theme step publishes them, while the shell only displays and selects them. They are delivered as a separate `/usr/share/mirroros/backgrounds` tree so the existing catalog path is kept and a changed image cannot block theme updates. The [theme sources](../../capabilities/visual/theme/sources.md#backgrounds) record digests, methods, C2PA observations and delivery.

The theme step publishes the backgrounds with its existing publisher after the theme tree. On the host, four new theme configure contracts (running and target publication, idempotence, restoration of an absent tree, conflicts for modified, added, removed or linked images and an untrusted product parent) and three source tests passed, as did the existing theme and terminal contracts and the full target contract including thirteen-step convergence. No guest deployment, installed-path shell load or visual review of the published images occurred.

## Remaining comparison protocol

Record tool versions, setup, results and untested scenarios for initial display and fill, output addition and removal, changes and transitions, invalid or removed images, restart and recovery, focus and exclusion, selector and next-image integration, and process/dependency and maintenance costs. Use disposable sessions and obtain the necessary authorization for VM session changes or package installation. Offscreen and logic tests do not establish Wayland output or visual behavior.

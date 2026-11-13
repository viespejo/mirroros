# Story 4.5 — Portals and file manager: decision log

Technical interview for the first Story 4.5 plan. Primary input: the brainstorming session
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 1 — Portals and file manager), whose In/Out
boundary rows are maintainer decisions; its interview handoff items are treated as open questions here.

## DEC-001
- **Question**: How should Story 4.5 be cut into plans?
- **Context/Nuances**: Story 4.5 spans heterogeneous areas (portals, polkit agent, clipboard and history,
  screenshots, file manager, browser). Story 4.4 was delivered as several plans. Each area is being explored in a
  separate brainstorming session backed by a markdown file; the portals area is closed and ready for planning.
- **User Response**: Treat each area as a separate plan within the same story, starting with portals.
- **Decision**: Story 4.5 is delivered as one plan per area. The first plan covers portals with suggested numbering
  02-35. Each area's brainstorming document is the primary source for its interview. Remaining plans are numbered
  as their brainstorming closes; inter-plan dependencies are not assumed from order.
- **Status**: Accepted

## DEC-002
- **Question**: Does the portals plan also include the file manager change (Strata), or is it split into its own plan?
- **Context/Nuances**: The brainstorming area is "Portals and file manager". Portals are configuration plus official
  packages; the file manager is a MirrorOS-derived Strata PKGBUILD (Rust, Sesh pattern) with supply-chain review,
  FileManager1/MIME ownership, Nautilus removal, shell folder opening and a theme bridge. Splitting would isolate
  the Strata build risk from the DEC-030 closure.
- **User Response**: A single plan, so that all laboratory tests are shared.
- **Decision**: Plan 02-35 covers the whole area: the portal stack, Secret through gnome-keyring unlocked by PAM, the
  Settings dark answer, the official share picker, environment and service-ownership postconditions, the DEC-030
  closure, and Strata as file manager (FileManager1, `inode/directory`, Nautilus removal, explicit `xdg-user-dirs`,
  shell folder opening without naming the binary).
- **Status**: Accepted

## DEC-003
- **Question**: Which backend serves the FileChooser portal interface: `-gtk` or Strata (brainstorm #52)?
- **Context/Nuances**: Omarchy after v4.5.0 (`origin/quattro` @ `2d33fd5`) keeps `default=hyprland;gtk` with
  Folio only as `inode/directory` handler; Folio's own plan (`plans/folio.md` @ `ac9d14f`) leaves a Folio chooser
  as an open question. Strata (`b978134`, `docs/portal-file-chooser.md`) offers a FileChooser with the file
  manager's views, sidebar and previews, keyboard-first navigation and a 10xer keymap, on-demand D-Bus activation
  (exits after about two minutes idle) and a runtime-only Hyprland centering rule registered over IPC. Costs: file
  open dialogs accept `http(s)` URLs and download to `/tmp/strata-download-*` (kept up to a day, optional sandboxed
  PNG conversion); local locations only; `strata;gtk` falls back only when Strata's metadata is absent, with no
  live failover; `strata --install-portal` and the first-launch offer rewrite the user's `portals.conf`; a young,
  fast-moving project whose failure affects file selection in every application. Strata's `package.nix` keeps
  the FileChooser and FileManager1 integrations as separate opt-in file sets.
- **User Response**: C — evaluate Strata in the laboratory and decide with evidence.
- **Decision**: The plan evaluates `FileChooser=strata;gtk` in the laboratory and selects with evidence between
  `gtk` only and `strata;gtk`; any failed check yields `gtk` only. The recipe packages Strata's portal integration
  separately from FileManager1. `portals.conf` is owned by configure; `strata --install-portal` is never used and
  the first-launch offer is suppressed. Reverting is two package files and one `portals.conf` line.
- **Follow-ups**: Define evaluation criteria (open/save from the browser, multiple/folder/filter requests,
  keyboard-only use, coexistence with Meet sharing and FileManager1); decide whether URL download is acceptable or
  blocks `strata;gtk`; record the outcome in `docs/mvp-scope.md` and the capability's `sources.md`.
- **Status**: Accepted

## DEC-004
- **Question**: Does Strata's FileChooser URL download block the `strata;gtk` outcome?
- **Context/Nuances**: At `b978134` the download cannot be disabled: no Cargo feature (only `rar`, `qa`,
  `invariant-checks`), environment variable or preference; it lives in `src/ui/chooser/download.rs`. It runs only
  when the user pastes an `http(s)` URL into the Name field of an open request and confirms; never in save or
  folder requests. Credentials and automatic redirects are rejected; files go to a user-only temporary folder swept
  after a day; image conversion runs in the bubblewrap sandbox; everything runs with the user's privileges.
  Alternatives were a recipe patch (recurring maintenance on a fast-moving project), blocking `strata;gtk`, or an
  upstream switch request.
- **User Response**: A — accept it as is.
- **Decision**: URL download is accepted as a user-initiated capability and does not block `strata;gtk`. It is
  documented in the file manager's `sources.md` and the procedure; no recipe patch and no upstream dependency.
- **Status**: Accepted

## DEC-005
- **Question**: Which browser exercises the portal checks of this plan while the browser provider (Chrome vs
  Chromium) is still owned by a later Story 4.5 area plan?
- **Context/Nuances**: FileChooser open/save, Meet window/screen sharing (#55, #56) and browser keyring storage
  (#57) need a portal-aware browser. Selecting the browser now would break the per-area cut of DEC-001; validating
  without any browser would leave the attended sharing and dialog checks to a later plan.
- **User Response**: Recommendation accepted.
- **Decision**: Automated postconditions use dedicated clients without a browser (`gdbus` introspection and calls,
  Strata's `scripts/portal-test.py` against the installed backend, a portal capture request). Attended checks use
  official `extra/chromium` installed only as authorized laboratory drift: not declared by configure and removed
  when the campaign closes. The browser plan reruns browser-dependent checks with the selected provider. The Google
  account used for Meet is external state, never recorded, logged or committed.
- **Status**: Accepted

## DEC-006
- **Question**: Which criteria select between `strata;gtk` and `gtk` only (DEC-003)?
- **Context/Nuances**: DEC-003 requires an evidence-based outcome with `gtk` only on any failure; DEC-005 provides
  dedicated clients for automated checks and laboratory Chromium for attended ones. Visual appearance belongs to
  Story 4.8, and URL download is already accepted by DEC-004.
- **User Response**: Accepted as proposed.
- **Decision**: `strata;gtk` is selected only if every criterion passes; any failure yields `gtk` only.
  1. Activation and routing: the frontend resolves FileChooser to Strata, `gdbus` reports `version` 4, and removing
     `strata.portal` makes the frontend fall back to `gtk` without other reconfiguration.
  2. Dedicated client (`portal-test.py`): single, multiple, folder, filter, save and save-files requests return
     the correct paths; cancellation returns `1`.
  3. Chromium (attended): open file, multiple upload, "Save as" download and folder selection work, and the
     chooser appears floating over its parent window.
  4. Keyboard only: open, navigate, filter, rename, create folder, accept and cancel without a pointer in all three
     views.
  5. Coexistence: Meet sharing (xdph) and FileManager1 folder opening keep working with Strata as chooser, and the
     chooser leaves no process after its idle timeout.
  6. Quiet: no new portal diagnostics in the session journal or the shell quiet-log suites.
  Visual appearance and theme are not criteria (Story 4.8); URL download is exercised once for documentation only.
- **Status**: Accepted

## DEC-007
- **Question**: How does Strata show the MirrorOS theme permanently in this plan (brainstorm #51)?
- **Context/Nuances**: The maintainer rejected a temporary bundled theme. MirrorOS already publishes its palette
  (`visual/theme/default/colors.toml`, Osaka Jade adapted from Omarchy) with the Quattro keys Strata maps.
  Strata (`b978134`) follows an external theme only through the fixed path `$HOME/.local/state/omarchy/current/`
  (`src/ui/theme/omarchy_state.rs`, ignores `XDG_STATE_HOME`), requiring `theme.name` (also the key of its
  remembered variant) and `theme/colors.toml`; it watches them live and follows them by default on first launch.
  The alternative was a MirrorOS-generated custom theme in `~/.config/strata/themes/` with a palette converter and
  an initialize-only `theme = "mirroros"` write into Strata's user-owned `settings.toml`, which Story 4.8 would
  have to regenerate on theme changes.
- **User Response**: A — bridge to Strata's Quattro contract.
- **Decision**: Configure creates, initialize-only, a minimal `~/.local/state/omarchy/current/` containing only a
  `theme` link to the resolved MirrorOS theme directory (honoring MirrorOS's `XDG_STATE_HOME` resolution) and a
  `theme.name` entry. `visual/theme` publishes `theme.name` with the theme, so Story 4.8 theme selection changes
  both together and Strata follows live. An existing `omarchy/` state is never replaced and is reported as a
  conflict. No palette converter and no write to Strata's `settings.toml`. The bridge is documented in the file
  manager's `sources.md` against the verified Strata revision, and a test checks the contract (paths and keys read
  by `omarchy_state.rs`) whenever the recipe revision changes.
- **Risks**: An `omarchy` namespace in user state that future Omarchy-aware tools could interpret; dependency on a
  contract Strata does not declare stable, whose change silently falls back to Tokyo Night; `visual/theme`
  contract grows by `theme.name`.
- **Status**: Accepted

## DEC-008
- **Question**: Is Strata delivered from a source build (brainstorm #50) or from the upstream release binary?
- **Context/Nuances**: At `b978134` two build-time switches differ. `STRATA_UPDATER` is enabled in releases: the
  automatic check runs at each start and every 24 hours (on by default, user-switchable); with the
  `install-source.toml` marker shipped by the first-party `packaging/aur/strata-bin` recipe Strata never replaces
  the pacman-owned binary and only offers an AUR-helper update. `STRATA_INTEGRATIONS` is `runtime` in releases:
  the first-launch offer and "Complete setup" can write user-level portal metadata, `portals.conf`, FileManager1
  and `inode/directory` overrides that take precedence over configure-owned files. Omarchy shortcut writing is
  gated on the `omarchy` command or `/usr/share/omarchy/version`, not on the DEC-007 bridge. Releases bundle UnRAR
  (`LicenseRef-UnRAR`). Official `strata-bin`/`strata-rc-bin` are not yet published on the AUR, and AUR updates
  are never automatic in MirrorOS (Story 4.7 review). A source build removes both switches and rar but costs a
  Rust build of about 450 crates per version, also inside the target during installation.
- **User Response**: Accepted the recommendation of the binary recipe as the most flexible option for MirrorOS.
- **Decision**: Strata is delivered by a MirrorOS recipe derived from the first-party `packaging/aur/strata-bin`
  PKGBUILD (Sesh pattern): a pinned stable release tag with its `sha256`, `gh attestation` verification, `!strip`,
  and the `install-source.toml` marker. UnRAR is accepted and its license recorded. The package installs the portal
  (DEC-003) and FileManager1 integration files. The first-launch integration offer is suppressed initialize-only. A
  running-context postcondition reports user-level FileChooser or FileManager1 overrides. Strata's update check is
  accepted as a notice only and documented in `sources.md`. This supersedes the brainstorm's source-build choice
  (#50); switching back to a source build changes only the recipe.
- **Follow-ups**: During implementation verify the latest stable tag, its release assets, `.sha256` and
  attestation, and which integration files the release archive ships.
- **Status**: Accepted

## DEC-009
- **Question**: How is the overlap between the xdph Screenshot portal interface and direct capture tools divided
  (handoff item 3)?
- **Context/Nuances**: `xdg-desktop-portal-hyprland` implements `Screenshot` and `ScreenCast`, used by sandboxed or
  portal-aware applications. User-initiated captures through shortcuts belong to the separate Story 4.5
  screenshots area plan and typically use `grim`/`slurp` directly.
- **User Response**: Accepted.
- **Decision**: This plan delivers and verifies the `Screenshot`/`ScreenCast` portal interfaces as part of the
  stack: a postcondition checks that the frontend routes them to `hyprland`, and the attended Meet sharing check
  exercises `ScreenCast`. It selects no capture tool, binds no capture shortcut and does not test user captures;
  the screenshots plan decides whether its tool uses the portal or captures directly.
- **Status**: Accepted

## DEC-010
- **Question**: How is the dark Settings portal answer delivered, and how far does it reach (brainstorm #60,
  handoff item 4)?
- **Context/Nuances**: With `default=hyprland;gtk`, `org.freedesktop.appearance color-scheme` is served by `-gtk`,
  which reads GSettings `org.gnome.desktop.interface color-scheme` from dconf. Chrome/Chromium, `-gtk` dialogs and
  GTK4/libadwaita applications read it; Strata only in "Follow system" mode, which DEC-007 does not use. GTK3
  (`gtk-application-prefer-dark-theme`) and Qt applications do not read the portal. A user-level `gsettings`
  write needs the session bus or direct dconf writes, is fragile in target context and overwrites user state.
- **User Response**: Accepted.
- **Decision**: Configure delivers a system dconf default: `/etc/dconf/profile/user` and a MirrorOS file under
  `/etc/dconf/db/local.d/` setting `color-scheme='prefer-dark'`, compiled with `dconf update` through `cfg_exec`
  without context branching. User state is not touched and a user value takes precedence. Postconditions: the
  portal answers `1` (dark) in running context; the declared dconf database exists in target context. GTK3 and Qt
  dark preferences are out of scope and belong to Story 4.8, which also derives the value from the theme `mode`;
  light GTK3/Qt surfaces seen in the laboratory are recorded as Story 4.8 findings, not fixed here.
- **Status**: Accepted

## DEC-011
- **Question**: How is the keyring (Secret, brainstorm #57/#58) delivered?
- **Context/Nuances**: Verified read-only in the laboratory VM (Arch, `127.0.0.1:2222`): `/etc/pam.d/sddm` from
  `sddm 0.21.0-7` already contains `-auth optional pam_gnome_keyring.so`, `-password optional pam_gnome_keyring.so
  use_authtok` and `-session optional pam_gnome_keyring.so auto_start`, so installing `extra/gnome-keyring`
  (`1:51.1-1`, depends on `dconf`) enables login unlock without a MirrorOS PAM change. Installed today:
  `xdg-desktop-portal 1.22.1`, `-gtk 1.15.3` (via Nautilus) and `libsecret`; `xdg-desktop-portal-hyprland`
  (`extra`, `1.5.0`) and `gnome-keyring` are absent. Chrome/Chromium use `org.freedesktop.secrets` directly through
  libsecret; sandboxed applications use the `Secret` portal.
- **User Response**: Accepted.
- **Decision**: `gnome-keyring` is declared by the neutral portal capability and relies on the packaged SDDM PAM
  integration, with no MirrorOS PAM drop-in or edit; a missing integration would be a finding routed through
  review. Portal preferences set `org.freedesktop.impl.portal.Secret=gnome-keyring`. Running postconditions:
  `org.freedesktop.secrets` is owned by `gnome-keyring-daemon` and the `login` collection is unlocked after login.
  Target postconditions: the package is present and the packaged `pam_gnome_keyring` lines exist (read-only).
  Attended check: laboratory Chromium stores a test password without an unlock prompt and keeps it across logout
  and login; the entry is deleted afterwards and no value is recorded. Out of scope: `gcr-ssh-agent`, KeePassXC
  and cloud password managers. Documented: `passwd` does not re-encrypt the keyring (#58) with its recovery
  procedure; the keyring is runtime state outside the repository (#6); hyprlock does not lock the keyring.
- **Status**: Accepted

## DEC-012
- **Question**: Which capability owns each piece, and where do portal preferences live?
- **Context/Nuances**: The frontend searches `~/.config`, `/etc/xdg`, then `/usr/share`, trying
  `<desktop>-portals.conf` and `portals.conf`; the first file found wins entirely, without merging. The `hyprland`
  package ships `/usr/share/xdg-desktop-portal/hyprland-portals.conf` with `default=hyprland;gtk`.
  `allow_token_by_default` is off by default and `hyprland-share-picker` ships inside
  `xdg-desktop-portal-hyprland`, so no `xdph.conf` is needed. A generic `/etc/xdg` `portals.conf` would still have
  to name `hyprland` in `default=` and its resolution with xdp 1.22 is unverified.
- **User Response**: Accepted.
- **Decision**: `desktop/compositor/providers/hyprland` owns `xdg-desktop-portal-hyprland` and
  `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` (`default=hyprland;gtk`, `FileChooser` per the DEC-003
  outcome, `Secret=gnome-keyring`). A new neutral `desktop/portal` capability owns `xdg-desktop-portal`, `-gtk`,
  `gnome-keyring`, the DEC-010 dconf default, and the service-ownership and environment postconditions.
  `desktop/files` keeps the file manager: the Strata recipe with its portal and FileManager1 integrations,
  `inode/directory`, the DEC-007 theme bridge, Nautilus removal and `xdg-user-dirs`. No `xdph.conf`. A test checks
  that the provider file matches the neutral declarations and the DEC-003 outcome. In `configure-steps`,
  `desktop/portal` precedes `desktop/files`; the Hyprland provider keeps its position.
- **Status**: Accepted

## DEC-013
- **Question**: How is Nautilus retired?
- **Context/Nuances**: In the laboratory VM `nautilus 51.1` is explicitly installed and pulls `gvfs`, `localsearch`,
  `tinysparql`, `xdg-user-dirs-gtk` and others; `inode/directory` resolves to `org.gnome.Nautilus.desktop`; no
  `~/.config/mimeapps.list` exists; `xdg-user-dirs` is only a dependency of `xdg-user-dirs-gtk`. Configure has no
  package-removal helper (`cfg_packages_ensure`/`cfg_packages_present` only). Fresh installations no longer receive
  Nautilus once `desktop/files` stops declaring it; only already-configured systems (laboratory VM, T14s) are
  affected. Nautilus also registers `org.freedesktop.FileManager1`, creating two owners (#16) if it stays. An
  automatic retirement helper would add a new class of mutation for a one-time transition on two systems.
- **User Response**: Accepted.
- **Decision**: No automatic uninstallation. `desktop/files` stops declaring Nautilus and declares `xdg-user-dirs`
  explicitly (#23). An ownership postcondition fails when FileManager1 or `inode/directory` has two owners,
  identifying both and the action (`sudo pacman -Rns nautilus`); this slice is the first consumer of the Epic 4
  common-contract clause for detecting two owners of the same package, file or service. The one-time migration is
  documented in the procedure. Keeping Nautilus installed as a non-default is rejected because it keeps a second
  FileManager1 owner.
- **Status**: Accepted

## DEC-014
- **Question**: Where is the `inode/directory` association to Strata declared?
- **Context/Nuances**: No `mimeapps.list` exists today; Nautilus wins only as the sole advertiser of
  `inode/directory`. A system `/etc/xdg/mimeapps.list` is a single shared file: the browser plan will add
  `x-scheme-handler/http(s)` and `text/html`, and the brainstorm's leftovers area holds other MIME defaults. A
  desktop-specific `hyprland-mimeapps.list` couples defaults to the provider without need; writing the user's
  `~/.config/mimeapps.list` overwrites user state.
- **User Response**: Accepted.
- **Decision**: `/etc/xdg/mimeapps.list` is owned by the neutral `desktop/portal` capability as the desktop's
  default application associations, so later plans add their lines to a single owner. In this plan it contains only
  `inode/directory=io.github.lgse.Strata.desktop`. This refines DEC-012: `desktop/files` delivers Strata and its
  desktop entry, while `desktop/portal` owns the association file. Postconditions: `xdg-mime query default
  inode/directory` returns Strata in running context; the file is declared in target context. A user
  `mimeapps.list` pointing elsewhere is a user choice reported as a notice, not a failure; the DEC-013 two-owner
  failure applies only to package-created conflicts such as Nautilus.
- **Status**: Accepted

## DEC-015
- **Question**: Which keyboard paths open the file manager?
- **Context/Nuances**: Story 4.5 requires a documented keyboard path; Story 4.3 reserved the file-manager key.
  Omarchy (v4.5.0 and `origin/quattro`) binds `SUPER+SHIFT+F` to the file manager and `SUPER+ALT+SHIFT+F` to the
  file manager in the focused terminal's working directory. Both chords are free in MirrorOS; nearby `SUPER+F`
  (fullscreen) and `SUPER+ALT+F` (full width) are taken.
- **User Response**: Accepted, and the working-directory variant is included in this plan.
- **Decision**: The Hyprland provider binds `SUPER+SHIFT+F` (`files.open`, `uwsm app -- strata`) and
  `SUPER+ALT+SHIFT+F` (file manager in the focused terminal's working directory), both registered in the binding
  registry and shown by keyboard help. The working-directory resolution mechanism is decided separately. The
  reserved-and-unbound list in the provider `UPSTREAM.md` moves the file-manager key to bound; browser, editor,
  clipboard and capture keys stay reserved.
- **Status**: Accepted

## DEC-016
- **Question**: How is the focused terminal's working directory resolved for `SUPER+ALT+SHIFT+F`?
- **Context/Nuances**: Omarchy (`origin/quattro`) runs `uwsm-app -- folio "$(omarchy-cmd-terminal-cwd)"`; the
  helper takes the active window PID from `hyprctl activewindow`, picks its newest child and returns that child's
  `cwd` only if it is a session-leading shell on a pty listed in `/etc/shells`, else `$HOME`. It has no tmux
  support: under MirrorOS's Foot+tmux path (`SUPER+ALT+RETURN`) the child is the tmux client, so the result would
  always be `$HOME`.
- **User Response**: Accepted.
- **Decision**: `desktop/files` delivers an owned `files-cwd` command under `/usr/share/mirroros/files/`, adapted
  from Omarchy's algorithm (MIT, attributed in `sources.md`) with a tmux case: when the focused terminal's child is
  a tmux client, it asks tmux for the active pane's `#{pane_current_path}` of that client, identified by its tty
  (`tmux display-message -c <tty> -p`); otherwise it applies Omarchy's shell rule; any other case (another
  application, Strata, a missing directory) yields `$HOME`. It launches `uwsm app -- strata <dir>` with fixed argv.
  Automated tests use a fake process tree (shell, tmux, other application, deleted directory); the attended
  laboratory check covers Foot with zsh and Foot with tmux in two panes. Kitty support and using Strata's own
  `cwd` when Strata is focused are out of scope.
- **Status**: Accepted

## DEC-017
- **Question**: How does the shell open folders without naming the file manager binary (brainstorm #21)?
- **Context/Nuances**: `capabilities/desktop/shell/services/WallpaperActions.qml:105` runs `["nautilus", <dir>]`;
  the dependency-gated `wallpaper-applications.test.mjs` verifies real folder opening through Nautilus's D-Bus
  `OpenLocations` property. The network panel already uses `xdg-open` for the captive portal. A
  `FileManager1.ShowFolders` call would depend on the service owner instead of the MIME association.
- **User Response**: Accepted.
- **Decision**: The shell's Install > Style > Background action opens the folder with `xdg-open <dir>` and fixed
  argv, resolved through the DEC-014 `inode/directory` association and honoring user choice. The shell
  `UPSTREAM.md` and `sources.md` stop naming Nautilus. The dependency-gated test is adapted to a temporary
  `mimeapps.list` and a fake desktop entry, checking that the shell delegates to `xdg-open` and the folder reaches
  the associated handler, without requiring Nautilus. Real opening in Strata is an attended laboratory check.
- **Status**: Accepted

## DEC-018
- **Question**: What does closing DEC-030 mean in this plan?
- **Context/Nuances**: DEC-030 (Story 4.3) is a documentary exception, not a code exemption: `check-launcher.sh`
  already states that portal warnings are no longer exempted. It is described in `docs/procedures/desktop-shell.md`
  ("Open failures and limits") and `docs/mvp-scope.md` and covers three absent-provider categories: PipeWire,
  UPower and portal. Story 4.4 delivered PipeWire and UPower without updating the exception text. A portal app-ID
  registration warning was observed during the wallpaper laboratory work. `no-omarchy-coupling.test.mjs` scans the
  shell and `system/*` commands only, not `desktop/files`, so the DEC-007 bridge does not collide with it; the
  bridge is documented as a deliberate exception in `sources.md`.
- **User Response**: Accepted.
- **Decision**: With the portal stack delivered, the laboratory reruns the shell quiet-log suites (`check-*.sh`)
  and the production journal check (`mirroros-shell.service` and portal services during session start). A clean
  portal category is removed from the exception in the procedure and `docs/mvp-scope.md`. Persistent portal
  diagnostics are never suppressed or waived: they are diagnosed, fixed when caused by this plan's stack, or
  recorded with evidence as harmless upstream noise, in which case the exception stays open, narrowed to that
  specific diagnostic by explicit maintainer decision. PipeWire and UPower observations from the same campaign are
  recorded as clean or persistent so the DEC-030 text reflects actual state, without presuming Story 4.4 closure.
- **Status**: Accepted

## DEC-019
- **Question**: Where do session-dependent checks live, given that configure never starts or restarts session
  services?
- **Context/Nuances**: In the laboratory uwsm already exports `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland`,
  `XDG_SESSION_TYPE`, `DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` to the user manager; the frontend and `-gtk` run
  as D-Bus-activated user units, so MirrorOS needs no environment propagation of its own. DEC-010, DEC-011,
  DEC-012 and DEC-014 placed effective checks (dark answer, secrets owner and unlocked `login` collection, routing)
  as running-context configure postconditions, but a running frontend keeps its old configuration until the next
  login, the keyring unlocks only at SDDM login, and configure may run from a TTY without a session; a first run
  on a live session would fail them.
- **User Response**: Accepted.
- **Decision**: Amends DEC-010, DEC-011, DEC-012 and DEC-014. Configure postconditions in both contexts check only
  declared state: packages, `hyprland-portals.conf`, `mimeapps.list`, the compiled dconf database (readable with
  `dconf` without a bus), `.portal` and D-Bus `.service` files, the packaged PAM lines, the theme bridge and the
  static two-owner rule (FileManager1 service files and desktop declarations). In running context they add
  session-independent checks such as `xdg-mime query default inode/directory` as the user. Effective session
  checks move to an owned read-only `portal-check` command in `desktop/portal`, documented in the procedure and run
  after a new login: activation environment in `systemctl --user show-environment`, owner and routed backend of
  FileChooser, Screenshot, ScreenCast, Settings and Secret, the dark portal answer, the unlocked keyring, the
  FileManager1 owner, and DEC-008 user overrides as notices. The laboratory campaign uses it as its automated
  check and Epic 5 independent verification may reuse it. Configure reports that portal changes take effect at the
  next login, as it already does for audio and the power watcher.
- **Status**: Accepted

## DEC-020
- **Question**: Which window rules apply to portal dialogs?
- **Context/Nuances**: Omarchy floats every portal window (`default/hypr/apps/system.lua`). DEC-006 criterion 3
  requires the chooser to float over its parent. Modal dialogs with a parent usually float in Hyprland, but
  `hyprland-share-picker` and `-gtk` dialogs without a Wayland parent can tile. Strata registers a runtime centering
  rule for its chooser but does not force floating.
- **User Response**: Accepted.
- **Decision**: The Hyprland provider declares native `float` and `center` rules for the portal dialog classes
  `xdg-desktop-portal-gtk`, `hyprland-share-picker` and `io.github.lgse.Strata.FileChooser`, with exact classes
  confirmed in the laboratory through `hyprctl clients` and Omarchy (MIT) as attributed reference. The regular
  Strata file manager window gets no rule.
- **Status**: Accepted

## DEC-021
- **Question**: How are tasks ordered and where are the checkpoints?
- **Context/Nuances**: The Strata recipe risk and the FileChooser evaluation must not block the portal stack or
  the DEC-030 closure. Recent plans (02-34) end with a commit-by-concern task run after the laboratory checkpoint
  is approved, with tests on each committed tree and cleanup of `refs/mirroros-candidates/*` laboratory refs.
- **User Response**: Accepted, with an explicit commit task.
- **Decision**: Task order:
  1. Portal stack: `desktop/portal` (packages, dconf, `mimeapps.list`, `portal-check`), the Hyprland provider
     (`xdg-desktop-portal-hyprland`, `hyprland-portals.conf` starting at `FileChooser=gtk`, window rules),
     `configure-steps` order, tests and contracts.
  2. File manager: Strata binary recipe (tag, `sha256`, attestation verified) with packaged FileManager1 and portal
     integration, first-launch offer suppression, `theme.name` in `visual/theme` and the theme bridge,
     `xdg-user-dirs`, Nautilus removed from declarations with the two-owner rule, `files-cwd` and both chords.
  3. Shell: folder opening through `xdg-open` and the adapted wallpaper test.
  4. Laboratory phase A (`gtk`), with maintainer authorization before VM deployment and before installing
     laboratory Chromium: deployment, new login and `portal-check`, one-time Nautilus migration, keyring, Meet,
     FileManager1, `files-cwd`, window rules, quiet-log suites and journal (DEC-030).
  5. Phase B: switch to `strata;gtk`, apply the DEC-006 criteria, decide, and fix the final value in
     `hyprland-portals.conf` with its consistency test; a `gtk` outcome removes the two portal integration files
     from the recipe.
  6. Documentation: `docs/mvp-scope.md` (portals, Strata, DEC-030 text), procedures (`configure.md`,
     `desktop-shell.md`, a portals and file manager section), `capabilities/README.md`, `sources.md`/`UPSTREAM.md`,
     and removal of laboratory Chromium.
  7. Commits by concern, only after the laboratory checkpoint is approved: show the commit list with files first,
     split shared files by hunk, run the suites on each committed tree, never commit `.agents/` or generated
     outputs, no push or amend, and delete laboratory candidate refs after explicit confirmation.
- **Status**: Accepted

## DEC-022
- **Question**: Does this plan require an ADR?
- **Context/Nuances**: `docs/adr/README.md` requires an ADR for a critical technology or architecture selection, a
  design-changing prototype outcome, or an architecture exception. Portal, keyring and FileChooser choices select
  providers left open for Story 4.5, a reviewed update under `docs/mvp-scope.md` change control; Strata replacing
  Nautilus is a reviewed provider update owned by Story 4.5 (brainstorm). The binary recipe fits
  `docs/architecture.md` (reviewed PKGBUILD, unprivileged build, provenance and license recording) with the Sesh
  precedent; UnRAR is covered by license recording, with no project policy against non-free licenses. ADR 0012
  forbids depending on the Omarchy package or shell, not sharing a state path. `desktop/portal` already appears in
  the architecture tree. The two-owner rule applies the Epic 4 common contract.
- **User Response**: Accepted.
- **Decision**: No ADR. Provenance is recorded in `sources.md`/`UPSTREAM.md` and `docs/mvp-scope.md`; ADRs and
  `docs/architecture.md` are unchanged. A design-changing finding (for example, a needed PAM edit) is routed through
  review, not resolved inside the plan.
- **Status**: Accepted

## Execution findings — 2026-11-12/13 (plan 02-35)

These findings supplement, and do not rewrite, DEC-001 to DEC-022. Records:
`evidence/portals/lab-02-35/checkpoint.md` (ignored).

- Strata recipe (DEC-008): stable `v1.2.1`, tag commit `491e6ba9`, build commit `fb7eb0c4`, asset SHA-256 and SLSA
  attestation verified on the host; `strata-bin 1.2.1-1.1`. The first-launch offer is suppressed by
  `strata --dismiss-portal-prompt`, which at this tag only writes `portal-opt-in-v1` without initializing GTK, so the
  marker fallback was not needed.
- Phase A (`gtk`) was approved on candidate `2c56a10` (earlier `d5a12ba`, `edaad28`). Configure failed on the two
  FileManager1 owners as designed (DEC-013); detail is only in `configure.log`, the terminal shows the generic
  postcondition message. `sudo pacman -Rns nautilus` removed 91 packages, including `xdg-user-dirs` (reinstalled),
  `ffmpeg` and `localsearch`; the remedy stays `-Rns` by maintainer decision and the procedure documents these
  removals. `portal-check` exited 0 after a new login; keyring, Meet sharing, file manager chords, keyboard help and
  the shell background action passed.
- Amendments: D1a delivers the user `~/.config/hypr/xdph.conf` with `allow_token_by_default = true` (Omarchy's file
  without its custom picker), because Chromium otherwise showed the picker twice; this amends DEC-012 and AC-4. D2a
  adds `grim`, required by the Screenshot backend. D3 sizes `xdg-desktop-portal-gtk` windows 875×600 (Omarchy),
  because the GTK chooser exceeded the 1536×864 logical screen; this amends DEC-020. Portal dialogs are centered on
  the monitor, not over their parent; the maintainer accepted it as Omarchy-equivalent (DEC-006 criterion 3 and AC-9
  wording).
- Window classes confirmed: `xdg-desktop-portal-gtk`, `hyprland-share-picker`, `io.github.lgse.Strata.FileChooser`
  (phase B); the Strata main window `io.github.lgse.Strata` stays tiled.
- DEC-018/DEC-030: the PipeWire and UPower categories are dropped on observation (provider suites pass; no Story 4.4
  closure). The exception is narrowed by maintainer decision to the pre-existing shell host-portal app-ID
  registration and frontend RealtimeKit diagnostics, the GTK chooser `tracker3` warning caused by removing
  `localsearch` with Nautilus, and the Strata chooser diagnostics accepted below. gnome-keyring
  `discover_other_daemon` is benign.
- FileChooser (DEC-003, DEC-006): phase B passed criteria 1–5; criterion 6 failed under its literal reading (sporadic
  GTK4 `gdk_frame_timings_presented`/`gtk_svg_advance` warnings, Strata tracing `WARN` lines for unreadable or deleted
  directories, a `strata@` activation unit `status=1/FAILURE` when the session ends inside the idle window). The
  maintainer selected `strata;gtk` anyway, an explicit deviation from "any failure yields `gtk`"; the portal files
  stay in the recipe. URL download: one `GET`, a 0700 directory and 0600 file under `/tmp/strata-download-*`, kept
  after the chooser closes.
- Findings without change: dbus-broker warns that `io.github.lgse.Strata.FileManager1.service` is not named after its
  D-Bus name; workspace sharing and region selection fail in the VM and `hyprland-share-picker` 1.5.0 crashed twice
  (upstream); GTK3/Qt light surfaces and text size at scale 1.25 go to Story 4.8 (DEC-010); the
  `check-selector-replacement` fixture lacks a theme selection link (pre-existing); the quiet suites leaked orphan
  `inotifywait` processes in phase A.

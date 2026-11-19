# Story 4.5 Area 6 — Browser: Decision Log

Technical interview for the Story 4.5 browser plan. Primary input: the brainstorming session
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 6 — Browser), whose decided rows and In/Out
boundary are maintainer decisions and whose interview handoff items are treated as open questions here. Related
context: plan 02-35 DEC-005 (laboratory Chromium, browser-dependent checks rerun by the browser plan) and DEC-014
(single `/etc/xdg/mimeapps.list` owned by `desktop/portal`).

## DEC-001
- **Question**: What does the next Story 4.5 plan cover, and how is the Chrome supply-chain ADR sequenced?
- **Context/Nuances**: Areas 1–4 are implemented (02-35, 02-36/02-37, 02-38, 02-40, 02-41); 02-42 is independent.
  The brainstorming prioritized Viewers/MIME (Area 7) before the browser and required a Chrome ADR first, because
  Google publishes no pacman repository and Chrome's cadence conflicts with "pin and update only with a reason" and
  Story 4.7's review. Precedents: an immediate acceptance checkpoint right after drafting, before implementation
  (02-04 ADR 0005, 02-27 ADR 0026, 02-28 ADR 0028, 02-32 ADR 0029), versus acceptance at the final adoption
  checkpoint when the ADR depends on laboratory gates (02-37 ADR 0030, 02-38 ADR 0031). The Chrome ADR sets
  governance rules that the recipe and configure depend on, matching the first pattern.
- **User Response**: Approved.
- **Decision**: Plan 02-43 is the browser plan, with no dependencies. Task 1 drafts ADR 0032 (Chrome supply chain
  and update flow) as Proposed with any normative amendments and commits the interview record. Task 2 is a blocking
  `checkpoint:decision` (accept or revise), as in 02-32; the recipe, configure and laboratory work start only after
  acceptance. Viewers/MIME (Area 7) remains a later, independent plan; Chrome downloads without an associated viewer
  are recorded as a finding, not a blocker.
- **Status**: Accepted

## DEC-002
- **Question**: Where does Chrome's version live, and how does an installed device receive updates?
- **Context/Nuances**: Google publishes a signed apt channel: `InRelease` (signed by Google's Linux signing key)
  lists the SHA256 of `Packages`, which gives the stable version and the `.deb` SHA256 (verified 2026-11-19:
  `google-chrome-stable` 158.0.8127.36-1). AUR `google-chrome` only pins a sha512 inside its PKGBUILD. Installed
  systems run configure from a root-owned snapshot in `/usr/local/lib/mirroros/` that is never synchronized with the
  repository (`docs/procedures/configure.md`), official packages are unpinned under Story 4.7, and existing local
  recipes (Strata, Sesh, Omasnap) pin version and hash in the repository and are updated manually. Pinning Chrome in
  the repository would either make a self-updating device diverge from the product (and risk a downgrade on the
  next configure) or delay security fixes until the maintainer publishes each release. The maintainer asked for a
  startup hook that checks and offers the update through a notification, like the fingerprint invitation
  (`mirroros-fingerprint-invite.service`: oneshot user unit in `graphical-session.target`, bounded wait for the
  notification server, `notify-send --wait` with an action that opens `foot -e <setup>`).
- **User Response**: Approved.
- **Decision**: The repository's Chrome recipe pins neither version nor hash; it pins only the fingerprint of
  Google's signing key and the packaging structure. Version and `.deb` hash are resolved on the device at each build
  from `InRelease`/`Packages` verified against that fingerprint, and the applied values are recorded as provenance
  in the device's evidence, so the product never becomes outdated when a device updates. ADR 0032 records the
  exception: trust comes from Google's key rather than a per-release reviewed hash, and structural recipe changes
  still require normal review. The update path follows the fingerprint-invitation pattern: a oneshot user hook in
  `graphical-session.target` verifies the signed metadata and, when a newer stable version exists, offers it through
  an actionable notification; the privileged installation is always authorized by the user. Rejected: pinning in
  the repository (delayed security fixes) and unattended privileged updates at boot.
- **Status**: Accepted

## TODO-001
- **Item**: Detail the update hook and command: check frequency and per-version marker, bounded network wait,
  notification urgency and sender (02-42 shared sender), whether `chrome-update` is an owned command or a configure
  sub-step, key provenance and rotation, and the boundary with Story 4.7.
- **Status**: Resolved by DEC-003 to DEC-008

## DEC-003
- **Question**: What is Chrome's trust anchor, and how is signing-subkey rotation handled?
- **Context/Nuances**: Verified 2026-11-19: Google's primary key `EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796`
  (RSA 4096, created 2016, no expiry) is published as "Active (Primary)" on `google.com/linuxrepositories`
  (`4CCA…5991` is obsolete). Signing subkeys rotate roughly yearly with three-year validity (2023→2026, 2024→2027,
  2025→2028, 2026-03→2029); today's `InRelease` is signed by subkey `0E22 5917 4146 70F4 442C 250D FD53 3C07 C264
  648F` and verifies with `gpg`. Pinning the whole key file would require a repository change per new subkey and
  leave devices, which run a non-synchronized configure snapshot, unable to verify once Google signs with a subkey
  their snapshot lacks. TLS-only trust was rejected because it gives no origin guarantee beyond the transport.
- **User Response**: Approved.
- **Decision**: The repository and ADR 0032 pin only the primary key fingerprint. Each verification fetches
  `linux_signing_key.pub` into a temporary keyring and accepts it only if its primary matches the pinned
  fingerprint; signatures are accepted only from subkeys bound by that primary, so yearly subkey rotation needs no
  repository or device change, the key's download location is irrelevant to trust, and published revocations are
  honored. A mismatched or changed primary fails closed: no update is offered, the user is told the trust anchor is
  invalid, and a reviewed ADR change is required.
- **Status**: Accepted

## DEC-004
- **Question**: Who installs Chrome and who updates it: configure, an owned command, or both?
- **Context/Nuances**: Configure installs only missing packages and never upgrades installed ones; `--refresh` only
  permits `-Syu` in the first missing-package transaction (`docs/procedures/configure.md`). Local recipes go through
  `cfg_local_package_ensure` (user build, privileged `pacman -U`, build only when the installed version differs).
  Configure has no single-step mode and runs every `CFG_STEPS` entry. `docs/architecture.md` already lists
  `capabilities/desktop/browser/`. Running `sudo mirroros-configure` from the notification would run every step for
  one package and break configure's missing-only semantics.
- **User Response**: Approved.
- **Decision**: The configure step `desktop/browser` installs Chrome only when missing, using the latest verified
  stable version, and never upgrades an installed Chrome, matching official-package semantics. An owned
  `chrome-update` command delivered by `desktop/browser` (for example under `/usr/share/mirroros/browser/`)
  verifies the metadata, compares versions, builds unprivileged as the user and requests `sudo` only for
  `pacman -U`; the notification action runs it in a terminal and it can also be run manually. One shared helper
  implements verification (primary key → `InRelease` → `Packages` → `.deb` hash) and the build for configure, the
  hook and `chrome-update`, so the trust chain has a single implementation. Provenance (version, hash, `InRelease`
  date, signing subkey) is recorded in configure evidence and in a `chrome-update` record.
- **Status**: Accepted

## DEC-005
- **Question**: When does the update check run?
- **Context/Nuances**: The fingerprint invitation runs only at graphical login, which suits a one-time invitation.
  Chrome ships security fixes almost weekly and laptops often suspend and resume for days or weeks without logging
  out, so a login-only check could stay silent for long periods. The shared 02-42 sender
  (`mirroros-notification-send`) has no actions or wait mode (`docs/procedures/desktop-shell.md`), so an actionable
  offer uses `notify-send --wait -A …` directly, like the fingerprint invitation; the shell invokes a live
  `default` action on card click. Urgency and sender are decided separately.
- **User Response**: Approved.
- **Decision**: The check is a oneshot user unit (`mirroros-chrome-update-check.service`) started at graphical login
  through `WantedBy=graphical-session.target`, plus a user timer with `OnCalendar=daily` and `Persistent=true` that
  reruns it daily and catches up after a suspended or missed slot. Nothing stays resident; each run makes small
  HTTPS requests (`InRelease`, `Packages`, the key) and exits. Rejected: login only (weeks without notice in long
  sessions) and timer only (no immediate notice at the start of the day).
- **Status**: Accepted

## DEC-006
- **Question**: What urgency does the update offer use, and how often is it repeated?
- **Context/Nuances**: A `normal` notification expires, and `notify-send --wait` cannot tell an unseen expiry from a
  dismissal, so a per-version marker could swallow an offer nobody saw. `critical` stays until the user acts (the
  fingerprint invitation uses it for that reason) and bypasses Do Not Disturb in the shell. Chrome publishes new
  stable versions almost weekly. Repeating the same offer at every login and daily run would contradict the Story
  4.3 quiet rule.
- **User Response**: Approved.
- **Decision**: The offer is a `critical` notification ("Chrome <version> available") whose `default` action,
  labelled "Update", opens `foot -e chrome-update` on card click. A marker
  `${XDG_STATE_HOME:-~/.local/state}/mirroros/chrome-update-offered` stores the offered version; while that version is
  still the latest, no further offer is sent at login or by the timer, even after a dismissal. A newer stable
  version produces a new offer, and an offer already on screen is not duplicated by a later run because the marker
  exists. Rejected: `normal` urgency repeated at every run, and `critical` repeated at every run.
- **Status**: Accepted

## DEC-007
- **Question**: How do the update check and `chrome-update` behave on failure?
- **Context/Nuances**: Three failure classes: transient (no network, `dl.google.com` unreachable, no notification
  server within the bounded wait), integrity (primary fingerprint mismatch, invalid or expired `InRelease`
  signature, `Packages` hash mismatch) and application (build failure, `pacman -U` failure, cancelled `sudo`).
  DEC-003 already requires integrity failures to fail closed and tell the user. Treating every failure silently
  would hide an attack or a key change indefinitely.
- **User Response**: Approved.
- **Decision**: Transient failures use bounded waits (network through `nm-online -q -t 30` or an equivalent;
  notification server 30 s, as the fingerprint invitation), then exit silently with success, leave the marker
  untouched so the next login or timer run retries, and log only to the unit's journal. Integrity failures fail
  closed and visibly: no offer is made, a non-actionable notice is sent through the shared 02-42 sender pointing to
  `journalctl --user -u mirroros-chrome-update-check`, a separate marker suppresses repeats until the cause changes,
  and the unit exits with failure so it appears in `systemctl --user --failed`. Application failures surface in the
  visible `chrome-update` terminal with a next step and a common-contract outcome code; the installed Chrome is left
  intact because `pacman -U` is atomic, the offered-version marker is kept, and the procedure documents rerunning
  `chrome-update` manually. Rejected: silent handling of integrity failures.
- **Status**: Accepted

## DEC-008
- **Question**: Which story owns Chrome's update flow, and how does it relate to Story 4.7?
- **Context/Nuances**: Story 4.7 requires reviewed, unprivileged AUR builds, keeps Chaotic-AUR and unapproved
  third-party repositories disabled, and forbids version pins beyond what an accepted ADR requires. Chrome's flow is
  MirrorOS's first post-installation update path and lands before Story 4.7. Transferring ownership later would add
  a future dependency and invite redesign; recording the relation only in the ADR would hide it from Story 4.7
  readers.
- **User Response**: Approved.
- **Decision**: Story 4.5 owns Chrome's update flow end to end under ADR 0032, and Story 4.7 inherits it as an
  already governed exception. ADR 0032 states that Google's apt channel is not an enabled pacman repository (no
  `pacman.conf` entry, no key in pacman's keyring) but a verified source for a local build, so Story 4.7's
  third-party repository rule holds unchanged, and that the recipe needs review only for structural changes (DEC-002),
  consistent with "not pinned beyond what an accepted ADR requires". Task 1 amends `docs/epics.md` minimally with a
  Story 4.7 note that Chrome's update path is governed by ADR 0032; the general `yay` flow and AUR review stay with
  Story 4.7.
- **Status**: Accepted

## DEC-009
- **Question**: What does the managed Chrome policy contain, and are Omarchy's extensions and theme color included?
- **Context/Nuances**: Omarchy `origin/quattro` @ `2eb7eb3` ships `/etc/opt/chrome/policies/managed/omarchy.json`
  (`DefaultBrowserSettingEnabled`, `MetricsReportingEnabled`, `PrivacySandboxPromptEnabled`,
  `PrivacySandboxAdTopicsEnabled`, `PrivacySandboxSiteEnabledAdsEnabled`, `PrivacySandboxAdMeasurementEnabled`,
  `PromotionalTabsEnabled`, all `false`), hardens the policy directories (`root:root 0755`, non-root entries purged),
  force-installs three own MV3 extensions (Copy URL and Download Video through native messaging hosts that run
  `wl-copy` and yt-dlp, and WhatsApp Slim as a content script) and writes a theme `color.json`
  (`BrowserThemeColor`, `BrowserColorScheme: device`) through a NOPASSWD sudoers rule. Branded Chrome dropped
  `--load-extension` in Chrome 137 (Chromium PSA, April 2025), so extensions on Chrome need `ExtensionSettings`
  `force_installed` with signed `.crx` files whose IDs derive from a private signing key (either Omarchy's prebuilt
  binaries or a MirrorOS key, which is secret material); force-installed extensions cannot be disabled; Omarchy
  writes native host manifests into `~/.config/google-chrome/NativeMessagingHosts/`, against the brainstorm boundary
  that configure never touches the profile, and the brainstorm leaves extension selection external. Any managed
  policy makes Chrome show "Managed by your organization". The MirrorOS theme publishes no `chromium.theme`; its
  `background` is `#111c18`. Plan 02-35 DEC-006 had left application appearance to Story 4.8.
- **User Response**: Option A for the policy and extensions, but color/theme is handled in this plan, not deferred.
- **Decision**: `desktop/browser` delivers `/etc/opt/chrome/policies/managed/mirroros.json` with Omarchy's seven keys,
  attributed under MIT, with `root:root 0755` policy directories checked by configure; `PasswordManagerEnabled`
  stays at its default. Extensions are out, as the brainstorm boundary states: no third-party `.crx`, no signing
  key, no native messaging hosts, no yt-dlp, and the profile is never touched; Copy URL or Download Video would be a
  separate scope change. Chrome's theme color is in this plan; its mechanism is decided next. The "Managed by your
  organization" indicator is accepted.
- **Status**: Accepted

## DEC-010
- **Question**: How does Chrome receive the MirrorOS theme color?
- **Context/Nuances**: Each MirrorOS theme publishes one file per consumer under `/usr/share/mirroros/themes/<slug>/`
  (GTK CSS, `foot.ini`, `hyprland.lua`, `hyprlock.conf`, `shell.toml`, `theme.name`), tested for consistency with
  `colors.toml`, and `capabilities/visual/theme/sources.md` requires every future theme to publish them. Selection
  is per user through `~/.local/state/mirroros/current/theme`, validated by `resolve-current` and
  `check-trusted-path`; only `default` exists, and Story 4.8 adds theme selection. Without touching the profile,
  Chrome's only route is the machine-wide, root-owned managed policy, which is why Omarchy uses a NOPASSWD sudoers
  rule for `omarchy-theme-set-browser-policy` (six hex digits) and then runs `--refresh-platform-policy`. Omarchy's
  `chromium.theme` holds the theme background as `r,g,b` (template `{{ background_rgb }}`).
- **User Response**: Approved.
- **Decision**: Every theme publishes `chromium.theme` in Omarchy's `r,g,b` background format (`17,28,24`, i.e.
  `#111c18`, for `default`), with a consistency test against `colors.toml` and an addition to the "every future theme
  must publish" rule. Configure writes `/etc/opt/chrome/policies/managed/color.json` (`BrowserThemeColor` from that
  file, `BrowserColorScheme: device`), `root:root 0644`, from the configured user's resolved theme
  (`resolve-current` with `check-trusted-path`) in both contexts, and checks it. A root-owned helper
  `browser-theme-color`, without free-form arguments, reads that resolved theme, rewrites `color.json` atomically and,
  when Chrome is running, runs `google-chrome-stable --refresh-platform-policy` as the user; configure uses it and
  Story 4.8 will invoke it on theme change. No NOPASSWD sudoers or pkexec grant is added now: it stays a documented
  contract for Story 4.8 until a theme selector without a terminal exists. Rejected: adding the sudoers rule now
  (an unused privileged grant) and a fixed static `color.json` (breaks the theme-consumer pattern).
- **Status**: Accepted

## DEC-011
- **Question**: Which Chrome flags are applied, and where?
- **Context/Nuances**: Chromium selects its password store from `XDG_CURRENT_DESKTOP`; on Hyprland it fails the portal
  attempt and falls back to `basic`, i.e. unencrypted plain text (Chromium `docs/linux/password_storage.md`; Omarchy
  PR #6065 "Pin browser password store to gnome-libsecret", observed on Hyprland). The 02-35 attended check (a
  disposable password filled after logout and login without an unlock prompt) also passes with the plain-text
  store, so the sentence in `docs/procedures/portals-and-files.md` that Chromium-family browsers use
  `org.freedesktop.secrets` directly was probably never verified. Since Chrome 140 `--ozone-platform-hint` defaults
  to `auto` (crrev.com/c/6775426) and Chrome 141+ uses Wayland in a Wayland session. The AUR launcher
  `/usr/bin/google-chrome-stable` reads `~/.config/chrome-flags.conf` and execs `/opt/google/chrome/google-chrome`;
  Omarchy copies its flags into that user file.
- **User Response**: Approved.
- **Decision**: The recipe's launcher, derived from the AUR one, always passes `--password-store=gnome-libsecret`
  before the user's flags, so every launch path (key binding, `xdg-open`, desktop entry) is covered without
  depending on a user-deletable file; it still reads `~/.config/chrome-flags.conf`, which MirrorOS never creates. No
  Ozone flag (Chrome 158 selects Wayland itself), no `--no-default-browser-check` (covered by policy) and no
  `--no-first-run` (fresh profile; first-run is external state). The laboratory verifies Wayland in `chrome://gpu`,
  `Local State` `os_crypt` showing libsecret rather than `basic` (read-only, laboratory only), and a disposable
  password present in the `login` collection through `secret-tool search` without recording any value; this plan
  corrects the 02-35 procedure sentence with that evidence. Rejected: Omarchy-style initialize-only user flags file
  (silent plain-text fallback if removed, and writes to `$HOME`) and forcing `--ozone-platform=wayland` (redundant and
  removes the X11 fallback).
- **Status**: Accepted

## DEC-012
- **Question**: Which key paths open the browser, and how is it launched?
- **Context/Nuances**: The Hyprland provider's `UPSTREAM.md` lists the Story 4.5 browser keys as reserved and
  unbound; `SUPER+SHIFT+B`, `SUPER+SHIFT+RETURN` and `SUPER+SHIFT+ALT+B` are free in MirrorOS. Omarchy
  `origin/quattro` binds `SUPER+SHIFT+RETURN` and `SUPER+SHIFT+B` to "Browser" and `SUPER+SHIFT+ALT+B` to "Browser
  (private)" through `omarchy-launch-browser`, which launches the `xdg-settings` default browser rather than naming
  Chrome. MirrorOS's file manager key names its binary (`uwsm app -- strata`, 02-35), while the shell opens folders
  neutrally through `xdg-open` (02-35 DEC-017). The brainstorm boundary had left private-window binding variants out.
- **User Response**: Approved, and asked to include the private window as well.
- **Decision**: `SUPER+SHIFT+B` and `SUPER+SHIFT+RETURN` open the browser and `SUPER+SHIFT+ALT+B` opens a private
  window, all registered by the Hyprland provider so keyboard help lists them, with `UPSTREAM.md` moving them from
  reserved to bound. An owned `browser-open` command in `desktop/browser` queries the default handler of
  `x-scheme-handler/https` (`xdg-mime query default`) and launches it through `uwsm app -- <desktop-id>` with fixed
  argv, so a user's own default browser is respected; with no handler it sends a notice with the next step. Including
  the private window changes the brainstorm boundary, which is recorded in `docs/mvp-scope.md` with this plan.
  Rejected: launching `google-chrome-stable` directly (ignores the user's choice) and binding only `SUPER+SHIFT+B`.
- **Status**: Accepted

## TODO-002
- **Item**: Decide how `browser-open --private` passes the private-window flag for the resolved handler and what
  happens for an unknown handler.
- **Status**: Resolved by DEC-013

## DEC-013
- **Question**: How does `browser-open --private` open a private window for the resolved default browser?
- **Context/Nuances**: `uwsm app -- entry.desktop[:action]` launches a desktop entry action (uwsm README). Chrome,
  Chromium and Firefox entries declare `new-private-window` (Chrome verified: `Actions=new-window;new-private-window;`).
  Omarchy's `omarchy-launch-browser` instead maps flags by binary name or by running `--help` (which starts the whole
  browser to detect Firefox). Launching Chrome by name would break DEC-012's neutrality.
- **User Response**: Approved.
- **Decision**: `browser-open --private` resolves the default desktop ID as in normal mode and, when the entry
  declares the `new-private-window` action, runs `uwsm app -- <id>:new-private-window`; the browser's own entry
  supplies its private flag, so MirrorOS keeps no flag table and never probes the binary. An entry without that
  action gets a notice ("The default browser offers no private window") instead of a normal window, since opening a
  non-private window on a private request would mislead. Tests cover entries with the action, without it and no
  handler using fake desktop entries; the laboratory exercises Chrome. Rejected: an Omarchy-style flag table and a
  Chrome-only `--incognito` launch.
- **Status**: Accepted

## DEC-014
- **Question**: Which browser associations go into `/etc/xdg/mimeapps.list`, and who owns them?
- **Context/Nuances**: Plan 02-35 DEC-014 makes `desktop/portal` the single owner of `/etc/xdg/mimeapps.list`, which
  later plans extend rather than duplicate; `mimeapps.list` has no drop-in mechanism. Chrome's desktop entry declares
  web types (`text/html`, `application/xhtml+xml`, `x-scheme-handler/http`, `x-scheme-handler/https`) plus
  `application/pdf`, `image/{gif,jpeg,png,webp}` and XML/RSS types. Omarchy only runs `xdg-settings set
  default-web-browser`. `xdg-open` falls back to any application declaring a type, so until Area 7 (imv, Papers, mpv;
  `mailto` still undecided) PDFs and images opened from Strata or downloads will open in Chrome anyway.
- **User Response**: Approved.
- **Decision**: The single `desktop/portal` `mimeapps.list` gains `x-scheme-handler/http`, `x-scheme-handler/https`,
  `text/html` and `application/xhtml+xml` → `google-chrome.desktop`, which is also what `browser-open` (DEC-012)
  resolves. PDF, images and `mailto` stay with Area 7; the interim fallback to Chrome is documented in the procedure,
  and Area 7's explicit associations will take precedence without touching Chrome. A consistency test ties the
  associated desktop ID to the entry the recipe installs, so a provider replacement changes those four lines and the
  test. Configure checks the effective value as the user (`xdg-mime query default x-scheme-handler/https`); a user's
  own different choice is a notice, not a failure, as in 02-35. Rejected: explicitly associating PDF and images with
  Chrome (Area 7 would undo it) and a browser-owned association file (would duplicate the single owner).
- **Status**: Accepted

## DEC-015
- **Question**: Is Chrome installed during the guided installation (target context) as well as on the running system?
- **Context/Nuances**: Story 4.2 requires every configure step to work in running and target contexts (`--target-root`,
  `arch-chroot`, unprivileged builds through `runuser`); Story 4.8 forbids a hidden second installation after first
  boot and requires an unavailable capability not to be represented as ready. Chrome means about 150 MB of `.deb`,
  extraction and repackaging (about 400 MB unpacked) and zstd compression. Configure records per-step timing in
  `configure-run.tsv`, retained by the guided installation; no time budget is defined. `build-strata` uses makepkg
  defaults, including compression.
- **User Response**: Approved.
- **Decision**: `desktop/browser` installs Chrome in both contexts through the same helper. In the guided
  installation it downloads and verifies the chain (key → `InRelease` → `Packages` → `.deb`), builds as the user
  inside the target like Strata, and installs with `SNAP_PAC_SKIP=y pacman -U`; the check unit and timer are enabled
  but not started, as other units in that context. A verification or network failure during installation fails the
  step with a next step under the common contract, so a system without its browser is never reported ready. The
  laboratory measures the impact in `configure-run.tsv`; only a significant cost triggers an optimization, first
  candidate `PKGEXT='.pkg.tar'` for this recipe only, recorded as a finding. Rejected: running context only (a hidden
  second installation against Story 4.8) and a non-blocking install-time failure (a declared capability missing on a
  system presented as ready).
- **Status**: Accepted

## DEC-016
- **Question**: What does the laboratory campaign cover, and where does it run?
- **Context/Nuances**: Laboratory Chromium is still on the reference VM as approved drift (02-35 kept it, 02-38
  retained it "until future browser work" with a browser-area follow-up). Browser-dependent checks from 02-35
  (FileChooser, Meet sharing, keyring), 02-38 (clipboard, password-manager copy entering history) and 02-40 (drag into
  a browser) await the selected provider. DEC-015 needs target-context evidence. Production code will have no way to
  override the pinned fingerprint.
- **User Response**: Approved.
- **Decision**: The campaign runs on the reference VM in phases, without a T14s step. Phase 0, authorized by the
  maintainer before deployment, removes laboratory Chromium and closes the 02-38 follow-up. Phase 1 (running context,
  `sudo mirroros-configure`) checks attended: recorded provenance; `chrome://policy` showing `mirroros.json` and
  `color.json`; the theme color and dark mode; Wayland in `chrome://gpu`; libsecret in `os_crypt` and a disposable
  password in `login` through `secret-tool` without recording values; the three keys with incognito on the private
  key; Strata FileChooser (open, multiple, Save as, folder); Meet window and screen sharing; clipboard round trips and
  the password-manager copy against history; an Omasnap drag into Chrome; `xdg-open https://…` and the interim PDF
  fallback; a fresh profile without an account not failing configure; and the update path with a laboratory-only
  build labelled with a lower version (single offer, action opens `chrome-update`, upgrade completes, marker suppresses
  repeats, silence without network). Integrity failures are covered by Bats fixtures, not on the VM. Phase 2 runs a
  clean guided installation on the VM for the target context: Chrome present at first boot, unit and timer enabled,
  step time measured in `configure-run.tsv`. No T14s step is required; Meet camera and microphone remain daily use.
  The Google account is external state, never recorded or committed. Rejected: running context only (DEC-015
  unverified).
- **Status**: Accepted

## DEC-017
- **Question**: What package name does the recipe use, and how does the browser reach the T14s?
- **Context/Nuances**: Earlier plans deployed T14s candidates as checksummed Git bundles extracted into a working
  checkout and applied with `sudo operations/configure` in running context, never from the installed
  `/usr/local/lib/mirroros/` snapshot, which stays at its installation version; the update hook, timer,
  `chrome-update` and helper live under `/usr/share/mirroros/browser/` (DEC-004) and do not depend on that snapshot.
  The T14s has Chromium installed. A user profile under `~/.config/google-chrome` is external state and is reused
  as is; Chrome never reads Chromium's `~/.config/chromium` profile.
- **User Response**: Approved option A, and asked that the optional T14s deployment mirror the VM phases without any
  later validation.
- **Decision**: The recipe uses `pkgname=google-chrome` with `conflicts=('google-chrome')`, so an AUR `google-chrome`
  is replaced cleanly by `pacman -U` and configure reports the replacement; a user-installed Chromium is not a package
  conflict and is left alone by configure, with the system association deciding the default. The plan adds an
  optional, supervised T14s deployment that is not an acceptance gate: phase 0 removes Chromium with the
  maintainer's authorization, and phase 1 applies the candidate through bundle → working checkout →
  `sudo operations/configure`. No attended validation follows it, and the guided-installation phase does not apply
  because the T14s is not reinstalled. Rejected: `pkgname=mirroros-google-chrome` (manual AUR removal, ecosystem
  divergence) and leaving the T14s out of the plan.
- **Status**: Accepted

## RISK-001
- **Item**: Chromium on the VM and the T14s most likely stored passwords in the plain-text `basic` store under
  `~/.config/chromium` (DEC-011). Removing the package leaves that profile on disk, and Chrome neither reads nor
  migrates it. Handling of the leftover profile is not yet decided.
- **Status**: Resolved by DEC-018

## DEC-018
- **Question**: How is Chromium's leftover profile handled on the VM and the T14s (RISK-001)?
- **Context/Nuances**: `pacman -Rns chromium` leaves `~/.config/chromium`, whose passwords are most likely in the
  plain-text `basic` store (DEC-011); the mode can be read from `Local State` `os_crypt` without reading values.
  Chrome on Linux does not import from a Chromium profile, and Chromium lost Google sync in 2021, so the T14s
  passwords saved in Chromium exist only there. The only migration path is a CSV export from Chromium's
  `chrome://password-manager` imported into Chrome; the CSV is plain text too.
- **User Response**: Approved.
- **Decision**: The profile is external state, so nothing is automated. On the VM, phase 0 records only the
  `os_crypt` mode, without values, as evidence for the 02-35 correction, then deletes the disposable laboratory profile
  with the package. On the T14s, neither configure nor the plan touches `~/.config/chromium`; the browser procedure
  documents how to check the store mode without reading values, the optional migration (export the CSV into a `0700`
  directory, import it into Chrome, remove the CSV with `shred`) and the advice to delete the Chromium profile
  afterwards. The maintainer runs it when he decides, outside any evidence. Rejected: a supervised migration step in
  the plan (contradicts DEC-017 and the external-state boundary) and removing the package without documenting the
  profile (plain-text passwords forgotten on disk).
- **Status**: Accepted

## DEC-019
- **Question**: How is the Chrome recipe derived from the AUR `google-chrome` PKGBUILD?
- **Context/Nuances**: AUR `google-chrome` (158.0.8127.36) extracts `data.tar.xz`, installs icons and the EULA,
  fixes the desktop entry (`StartupWMClass`, removes `ftp`), removes the Debian apt cron job, ships a launcher reading
  `~/.config/chrome-flags.conf`, depends on `alsa-lib gtk3 libcups libxss libxtst nss ttf-liberation xdg-utils`, and
  pins `sha512sums` for `x86_64` and `aarch64`. The Strata recipe header cites its upstream origin and lists changes.
- **User Response**: Approved.
- **Decision**: The recipe lives at `capabilities/desktop/browser/google-chrome/PKGBUILD`; its header cites the
  exact AUR repository commit it derives from and lists the changes: `x86_64` only; `pkgver` and the hash become
  placeholders filled by the helper with verified values (DEC-002), using `sha256sums` because `Packages` publishes
  SHA256, which `makepkg` independently rechecks on download; the MirrorOS launcher passing
  `--password-store=gnome-libsecret` before reading `chrome-flags.conf` (DEC-011); and a `.1` `pkgrel` suffix as other
  recipes. `package()`, dependencies and `optdepends` (including `pipewire` for screen sharing), the desktop-entry fix
  and the cron removal stay as upstream. `eula_text.html` is versioned with its checksum as a local source;
  `sources.md` records that Chrome is proprietary, MirrorOS redistributes no binaries, and the user downloads from
  Google and builds locally. `extra/chromium` is recorded as the alternative provider in `docs/mvp-scope.md` and the
  ADR (no sync, no Endpoint Verification); replacing it changes only the recipe, the associations and the desktop ID.
  Rejected: the AUR PKGBUILD nearly unchanged with a launcher patch (keeps `aarch64`, a pinned sha512 and a format
  that resists version injection).
- **Status**: Accepted

## DEC-020
- **Question**: Is the browser area one plan or two?
- **Context/Nuances**: The planning format recommends 2–3 tasks per plan and a split above three. The agreed design
  needs about five tasks: ADR 0032 draft with amendments and the interview record; the ADR acceptance checkpoint
  (DEC-001); the supply chain (verification and build helper, recipe, `desktop/browser` installation in both
  contexts, hook, timer, `chrome-update`) with Bats and fixtures; the integration (policy, `color.json` with
  `chromium.theme` and `browser-theme-color`, launcher and flags, `browser-open` and keys, associations,
  documentation) with tests; and the VM campaign, optional T14s deployment and commits. The project has repeatedly
  used larger plans (02-37 ten tasks, 02-32 six) and 02-35 DEC-002 kept one plan so one laboratory campaign served
  both halves. A split would mean two VM campaigns and Chrome installed without integration in between.
- **User Response**: Approved.
- **Decision**: One plan, 02-43, with five tasks: (1) ADR 0032 draft and interview record, (2) blocking ADR
  acceptance checkpoint, (3) supply chain with tests, (4) integration and documentation with tests, (5) VM campaign,
  optional T14s deployment and commits by concern. Tests live in the same task as the behavior they verify.
  Rejected: splitting into a supply-chain plan and a dependent integration plan.
- **Status**: Accepted

# Story 4.5 — Browser: consolidated plan

## Scope and sequencing

Story 4.5 continues one plan per area. This interview covers Area 6 (Browser) of the brainstorming session
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md`, whose boundary rows are taken as given and whose
handoff items are resolved below. The plan is suggested as 02-43 and has no plan dependencies; Viewers/MIME
(Area 7) stays a later, independent plan, so a Chrome download that finds no associated viewer is recorded as a
finding rather than blocking this plan [DEC-001].

Governance comes first. Because Google publishes no pacman repository and Chrome's release cadence conflicts with
the pinned-recipe rule and Story 4.7's review, the plan opens by drafting ADR 0032 on Chrome's supply chain and
update flow as Proposed, together with any normative amendments and the interview record. A blocking acceptance
checkpoint follows immediately, as in plan 02-32, and no recipe, configure or laboratory work begins until the ADR
is accepted; acceptance is not deferred to the adoption checkpoint, because the ADR fixes rules the implementation
builds on rather than an outcome the laboratory must prove [DEC-001].

## Supply chain and update path

Chrome is treated like an official package with a different root of trust. Google's signed apt channel provides a
verifiable chain from its Linux signing key through `InRelease` and `Packages` to the version and SHA256 of the
`.deb`, so the repository's recipe pins only that key's fingerprint and the packaging structure, never a version or
hash. Each build on the device resolves the current stable version and hash from the verified metadata and records
them as provenance in the device's evidence. This keeps the product correct while devices update: the configure
snapshot in `/usr/local/lib/mirroros/` is never rewritten, a later configure cannot downgrade Chrome, and security
fixes do not wait for a repository release. ADR 0032 states the exception explicitly: trust comes from Google's key
rather than a per-release reviewed hash, while structural changes to the recipe still go through normal review.
Pinning the version in the repository was rejected because it delays security fixes [DEC-002].

Updates are offered, never imposed. Following the fingerprint invitation, a oneshot user hook in
`graphical-session.target` verifies the signed metadata at login and, when a newer stable version exists, sends an
actionable notification whose action opens a terminal running the update, where the user authorizes the privileged
installation; with nothing to offer it stays quiet. Unattended privileged updates at boot were rejected. The hook's
frequency, per-version marker, network wait, urgency and sender, the shape of the update command, key provenance
and rotation, and the boundary with Story 4.7 are settled in the sections below [DEC-002, TODO-001].

## Trust anchor

The only pinned trust material is the fingerprint of Google's primary Linux package signing key,
`EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796`. Each verification fetches Google's public key into a temporary
keyring, accepts it only when its primary matches that fingerprint, and accepts signatures only from subkeys the
primary certifies. Google's yearly subkey rotation therefore reaches every device without a repository change or a
refreshed configure snapshot, where the key is downloaded from does not affect trust, and published revocations are
honored. Should the primary change or fail to match, verification fails closed: no update is offered, the user is
told the trust anchor is invalid, and only a reviewed change to ADR 0032 restores the channel. Pinning the full key
file was rejected for its yearly repository churn and stale device snapshots, and TLS-only trust for lacking an
origin guarantee independent of transport [DEC-003].

## Installation and update commands

Installation and updates are separate entry points over one core. The `desktop/browser` configure step, already
foreseen in the architecture tree, installs Chrome only when it is missing, taking the latest verified stable
version, and never upgrades an installed Chrome, so configure keeps the missing-only semantics it applies to official
packages and a rerun never triggers a large download or rebuild unasked. Upgrades go through an owned
`chrome-update` command delivered by the same capability: it verifies the metadata, compares versions, builds as the
user without privileges and asks for `sudo` only for `pacman -U`. The login hook's notification action runs it in a
terminal, and the user may also run it directly. Configure, the hook and `chrome-update` share a single helper for
the trust chain (primary key, `InRelease`, `Packages`, `.deb` hash) and the build, and each installation records its
version, hash, `InRelease` date and signing subkey as provenance, in configure evidence or in a `chrome-update`
record. Driving updates through `sudo mirroros-configure` was rejected because it runs every step for one package
and would break configure's missing-only semantics [DEC-004].

## Update check trigger

The check runs at login and once a day. A oneshot user unit, `mirroros-chrome-update-check.service`, is wanted by
`graphical-session.target` like the fingerprint invitation, and a daily user timer with `Persistent=true` reruns it
so that a laptop suspended across the scheduled slot catches up on resume. Nothing stays resident: each run fetches
the key and the small signed metadata files, decides and exits. A login-only check was rejected because long
suspended sessions could go weeks without a security notice, and a timer-only check because it loses the immediate
notice at the start of the day [DEC-005].

## Update notification

The offer is a `critical` notification announcing the new Chrome version, so it stays on screen until the user acts,
as the fingerprint invitation does; clicking it runs its `default` "Update" action, which opens `chrome-update` in
Foot. It is sent once per version: a marker under the MirrorOS state directory stores the offered version and
suppresses repeats at login and from the timer while that version is still the latest, including after a dismissal,
and also prevents a later run from stacking a second card. A newer stable version, typically within days, produces
a fresh offer. Repeating the offer at every run was rejected as contrary to the quiet rule, and `normal` urgency
because an expired, unseen card cannot be told apart from a dismissal [DEC-006].

## Failure handling

Failures are handled by class. Transient ones, such as no network, an unreachable `dl.google.com` or no notification
server within the bounded wait, end silently and successfully after bounded waits like the fingerprint invitation's,
leaving the marker untouched so the next login or daily run retries; only the unit journal records them. Integrity
failures, meaning a primary fingerprint mismatch, an invalid or expired `InRelease` signature or a `Packages` hash
mismatch, fail closed and visibly: no offer is made, a non-actionable notice through the shared notification sender
points to the unit's journal, a separate marker keeps that notice from repeating until the cause changes, and the
unit fails so it is listed by `systemctl --user --failed`. Failures while applying an update appear in the
`chrome-update` terminal with a next step and a common-contract outcome; the installed Chrome is untouched because
the package transaction is atomic, the offered version is not re-announced, and the procedure explains how to rerun
`chrome-update`. Silent handling of integrity failures was rejected because it would hide an attack or a key change
indefinitely [DEC-007, DEC-003].

## Ownership against Story 4.7

Story 4.5 owns Chrome's update flow end to end under ADR 0032, and Story 4.7 inherits it as an exception that is
already governed. The ADR makes clear that Google's apt channel is never an enabled pacman repository, with no
`pacman.conf` entry and no key in pacman's keyring, but only a verified source for a local build, so Story 4.7's rule
keeping unapproved third-party repositories disabled holds as written, and its rule against pins beyond what an
accepted ADR requires matches the unpinned recipe. The only normative amendment outside the ADR is a short note in
Story 4.7 of `docs/epics.md` pointing to ADR 0032, written with the ADR draft; the general `yay` flow and AUR review
remain Story 4.7's. Deferring ownership to Story 4.7 was rejected as a future dependency that invites redesign
[DEC-008].

## Managed policy and extensions

The browser capability delivers a machine-wide managed policy, `mirroros.json` under
`/etc/opt/chrome/policies/managed/`, taken from Omarchy with attribution: it turns off Chrome's default-browser
prompt, since the system association file decides the default browser, along with metrics reporting, the Privacy
Sandbox prompts and settings, and promotional tabs. None of these touch accounts, sync or passwords, and the password
manager keeps its default so passwords stored in Chrome keep working over the PAM-unlocked keyring. Configure checks
that the policy directories are root-owned with mode `0755`. The "Managed by your organization" indicator that any
managed policy brings is accepted [DEC-009].

Omarchy's extensions stay out, as the brainstorm boundary places extension selection outside the system. Branded
Chrome ignores `--load-extension` since Chrome 137, so shipping them would mean force-installing signed `.crx`
files, either Omarchy's prebuilt binaries or ones signed with a MirrorOS private key that would be secret material,
plus native messaging hosts written into the user's Chrome profile and a new yt-dlp dependency. Adding Copy URL or
Download Video later is a separate scope change. Chrome's theme color, by contrast, is handled in this plan rather
than deferred to Story 4.8 [DEC-009].

## Theme color

Chrome becomes a regular theme consumer. Every theme publishes a `chromium.theme` file holding its background as
`r,g,b`, in Omarchy's format, so the default theme publishes `17,28,24`; a test keeps it consistent with
`colors.toml`, and the visual theme's rule on files every future theme must publish gains this entry. Because Chrome
can only be themed without touching its profile through the machine-wide managed policy, configure writes a
root-owned `color.json` beside `mirroros.json` with the theme color and a color scheme that follows the device,
which the portal already answers as dark. The color comes from the configured user's selected theme, resolved and
path-checked as every other consumer does, in both configure contexts, and configure checks the result [DEC-010].

The write itself lives in a root-owned helper, `browser-theme-color`, that accepts no free-form arguments: it reads
the resolved theme, replaces `color.json` atomically and asks a running Chrome to reload its policy. Configure uses it
today, and Story 4.8's theme selection will call it on every theme change. The passwordless grant that a menu-driven
switch needs is deliberately not added yet and is documented as Story 4.8's contract, since no selector without a
terminal exists to use it; a fixed color file was rejected because it would break the theme-consumer pattern and be
redone in Story 4.8 [DEC-010].

## Launcher flags and password storage

Without a flag, Chrome on Hyprland stores passwords in plain text: it picks its store from the desktop name, does
not recognize Hyprland, and falls back to the unencrypted `basic` store, as Chromium documents and Omarchy observed.
The recipe's launcher, derived from the AUR one, therefore always passes `--password-store=gnome-libsecret` ahead of
any user flags, so the PAM-unlocked keyring protects saved passwords whatever the launch path and no deletable user
file can silently undo it. The launcher still honors a user's own `~/.config/chrome-flags.conf`, which MirrorOS never
creates. No Ozone flag is set because Chrome has chosen Wayland by itself since release 141, keeping its X11
fallback, and default-browser and first-run switches are left out because the policy and the fresh, external
profile already cover them [DEC-011].

The laboratory confirms Wayland in `chrome://gpu`, reads the profile's `os_crypt` entry to see libsecret rather than
`basic`, and finds a disposable password in the `login` collection through `secret-tool` without recording any value.
That evidence also corrects the portals procedure, whose claim that Chromium-family browsers use the secret service
directly was likely never verified: the 02-35 check would have passed with plain-text storage too [DEC-011].

## Key paths and launching

The browser opens with `SUPER+SHIFT+B` or `SUPER+SHIFT+RETURN`, and `SUPER+SHIFT+ALT+B` opens a private window,
following Omarchy's chords. The Hyprland provider registers all three so keyboard help lists them, and its reserved
key record moves them to bound. Including the private window widens the brainstorm boundary, which had left private
variants out, and the scope change is recorded in `docs/mvp-scope.md` [DEC-012].

The keys do not name Chrome. They run an owned `browser-open` command that asks the system which desktop entry
handles `https` links and launches that entry through uwsm with fixed arguments, so a user who picks another browser
in their own associations gets it from the same keys, in the same spirit as the shell's folder opening through
`xdg-open`. With no handler registered it sends a notice naming the next step. Launching Chrome by name was rejected
because it would ignore the user's choice. How the private flag reaches the resolved browser is settled below
[DEC-012, TODO-002].

The private window comes from the browser's own desktop entry. `browser-open --private` resolves the same default
entry and, when it declares the standard `new-private-window` action, launches that action through uwsm, so each
browser supplies its own private flag and MirrorOS neither keeps a flag table nor runs the browser to identify it. A
default browser without that action gets a notice rather than an ordinary window, because silently opening a
non-private window on a private request would mislead. Fake desktop entries drive the automated cases, and Chrome is
exercised in the laboratory [DEC-013].

## Default associations

The browser joins the single system association file that `desktop/portal` owns since plan 02-35, adding only the
web types: `http` and `https` links, HTML and XHTML, all mapped to Chrome's desktop entry. That is exactly what
`browser-open` resolves. PDF, image and `mailto` handling stays with Area 7; until it lands, `xdg-open` falls back to
Chrome for PDFs and images because Chrome's entry declares them, and the procedure documents that interim behavior,
which Area 7's explicit associations will override without touching the browser. A test keeps the associated
desktop ID in step with the entry the recipe installs, so replacing the provider changes four lines and that test.
Configure checks the effective `https` handler as the user and reports a user's own different choice as a notice
rather than a failure, as plan 02-35 does for folders [DEC-014].

## Installation-time delivery

Chrome is part of the installed system from the first boot. The `desktop/browser` step runs in both configure
contexts through the same verification and build helper: during the guided installation it verifies the signed chain,
builds the package as the user inside the target as Strata does, and installs it without installation-time snapshots,
while the update check unit and timer are enabled without being started. A network or verification failure at that
point fails the step with a next step, so the installer never reports a ready system that lacks its browser.
Deferring the browser to a post-login configure run was rejected as the hidden second installation Story 4.8
forbids, and a non-blocking failure because it would present a missing declared capability as ready. The cost of the
large download and repackaging is measured in the laboratory through configure's timing record, and only a
significant cost leads to an optimization, the first candidate being an uncompressed package for this recipe alone
[DEC-015].

## Laboratory campaign

The campaign runs on the reference VM. It opens, with the maintainer's authorization, by removing the laboratory
Chromium that earlier Story 4.5 plans kept, which also closes plan 02-38's browser follow-up and keeps profiles,
policies and password stores from mixing. The running-system phase then exercises everything attended: provenance
and the two policy files in `chrome://policy`, the theme color and dark mode, Wayland, libsecret storage proven with a
disposable password that is never recorded, the three keys including incognito, and the browser-dependent checks
earlier plans left for the selected provider, namely Strata's FileChooser, Meet window and screen sharing, clipboard
round trips including the password-manager copy against history, and dragging an Omasnap capture into Chrome. It
also covers link and interim PDF opening, a fresh profile without an account that leaves configure successful, and
the update path through a laboratory-only build labelled with a lower version, which must produce a single offer,
upgrade through `chrome-update`, stay quiet on repeat and stay silent without network. Integrity failures are proven
by automated fixtures rather than on the VM, since production code offers no way to swap the pinned fingerprint
[DEC-016].

A clean guided installation on the VM closes the campaign for the target context: Chrome must be present at first
boot with its check unit and timer enabled, and the step's cost is read from configure's timing record [DEC-015,
DEC-016]. No T14s step is required because nothing in this plan is hardware-specific; Meet's camera and microphone
remain daily use. The Google account used for Meet stays external state that is never recorded or committed
[DEC-016].

## Package identity and T14s deployment

The recipe keeps the ecosystem's package name, `google-chrome`, and declares a conflict with it, so an AUR build is
replaced cleanly by the local one and configure reports the replacement. A Chromium the user installed is not a
package conflict and configure leaves it alone; the system association decides which browser is the default. A
separate MirrorOS package name was rejected because it forces a manual AUR removal and diverges from the ecosystem
[DEC-017].

The T14s needs no reinstallation. An optional, supervised deployment mirrors the VM's first two phases without being
an acceptance gate: with the maintainer's authorization Chromium is removed, then the candidate reaches the laptop as
a checksummed bundle in a working checkout and is applied by running configure there, as earlier plans did. No
attended validation follows, and the guided-installation phase does not apply. The installed configure snapshot on
the laptop is not refreshed by this, which does not matter for Chrome because its update hook, timer and commands are
delivered outside that snapshot. Chromium's leftover profile, whose saved passwords were most likely kept in plain
text, is handled below [DEC-017, RISK-001].

Chromium's leftover profile is treated as the external state it is. On the VM the disposable laboratory profile is
deleted with the package, after recording only its password-store mode as evidence for the 02-35 correction. On the
T14s nothing touches it; instead the browser procedure explains how to check the store mode without reading any
value, how to migrate passwords through a CSV export kept in a private directory and shredded after importing it into
Chrome, and why the Chromium profile should then be deleted, leaving the timing to the maintainer and outside any
evidence. Automating that migration was rejected as contrary to the external-state boundary and to the unvalidated
T14s deployment, and silently leaving the profile as plain-text passwords forgotten on disk [DEC-018].

## Recipe derivation

The recipe is a minimal, traceable derivation of the AUR `google-chrome` PKGBUILD, kept under the browser
capability with a header that cites the exact AUR commit and lists every change, as Strata's recipe does. It builds
for `x86_64` only; its version and hash are placeholders the shared helper fills with verified values, using SHA256
because that is what Google's package index publishes, while makepkg rechecks the download on its own; it installs
the MirrorOS launcher with the password-store flag; and its release carries the usual MirrorOS suffix. Packaging,
dependencies, the desktop-entry fix and the removal of Debian's apt cron job stay as upstream, and `pipewire` remains
the optional dependency screen sharing relies on. Google's EULA is versioned as a checksummed local source, and the
provenance record states that Chrome is proprietary, that MirrorOS redistributes no binary and that each device
downloads from Google and builds locally. Chromium from the official repositories is recorded as the alternative
provider, without sync or Endpoint Verification, and switching to it would touch only the recipe, the associations
and the desktop ID. Reusing the AUR PKGBUILD almost unchanged was rejected because it keeps a second architecture, a
pinned hash and a layout that resists version injection [DEC-019].

## Plan shape

The area stays a single plan, 02-43, despite exceeding the usual three tasks, following the project's precedent and
plan 02-35's reasoning that one laboratory campaign should serve every half of an area. It runs in five steps: the
ADR draft with its amendments and the interview record; the blocking acceptance checkpoint; the supply chain, meaning
the verification and build helper, the recipe, installation in both contexts, the update hook, timer and command,
with their tests; the integration, meaning policy, theme color, launcher, keys, associations and documentation, with
their tests; and finally the VM campaign, the optional T14s deployment and commits by concern. Splitting into a
supply-chain plan and a dependent integration plan was rejected because it doubles the VM campaigns and leaves Chrome
installed but unintegrated in between [DEC-020].

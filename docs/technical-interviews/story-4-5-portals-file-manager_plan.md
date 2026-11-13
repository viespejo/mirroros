# Story 4.5 — Portals and file manager: consolidated plan

## Scope and source

Story 4.5 is delivered as one plan per area, each driven by its own closed brainstorming session; this interview
covers the first area, and its plan is suggested as 02-35 [DEC-001]. The source of the area's in/out boundary is
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 1), whose decided rows are taken as given and
whose interview handoff items are resolved below.

A single plan covers both portals and the file manager, so that one laboratory campaign exercises the attended
checks that cross both halves (FileChooser dialogs, Meet sharing, FileManager1 activation, keyring unlock). The
trade-off accepted is a larger plan in which the Strata recipe risk shares a delivery with the DEC-030 closure
[DEC-002].

The plan includes the portal stack (frontend, the Hyprland backend under the compositor provider, the GTK backend
and `portals.conf` in a neutral `desktop/portal` capability), Secret through gnome-keyring unlocked at SDDM login,
the fixed dark Settings answer, the official xdph share picker with `allow_token_by_default` off, environment
propagation and service ownership as configure postconditions, and the closure of the DEC-030 portal exception. On
the file-manager side it includes Strata from a MirrorOS-derived recipe as file manager, FileManager1 and
`inode/directory` owner, the removal of Nautilus, an explicit `xdg-user-dirs` declaration, and shell folder opening
without naming a binary [DEC-002].

## FileChooser layer

The FileChooser backend is selected by evidence within this plan. Omarchy keeps `-gtk` for dialogs even after
adopting Folio, but Strata's chooser offers the file manager's views and keyboard-first navigation, so the
laboratory campaign evaluates `FileChooser=strata;gtk` against `gtk` only, and any failed check yields `gtk` only.
The Strata recipe packages the portal integration separately from FileManager1, mirroring the opt-in file sets of
upstream `package.nix`; configure owns `portals.conf`, `strata --install-portal` is never used and the
first-launch offer is suppressed, so reverting costs two package files and one configuration line. The evaluation
weighs Strata's local-only scope and the absence of live failover, and records the outcome in `docs/mvp-scope.md`
and `sources.md` [DEC-003].

`strata;gtk` is selected only when every criterion passes: the frontend routes FileChooser to Strata at version 4
and falls back to `gtk` when Strata's metadata is removed; the dedicated client's single, multiple, folder,
filter, save and save-files requests return correct paths and cancellation; attended Chromium open, multiple
upload, "Save as" and folder selection work with the chooser floating over its parent; the chooser is fully usable
without a pointer in all three views; Meet sharing and FileManager1 keep working alongside it and no chooser process
outlives its idle timeout; and no new portal diagnostics appear in the session journal or the shell quiet-log
suites. Appearance is left to Story 4.8, and URL download is exercised once only to document it [DEC-006].

Strata's URL download in open dialogs cannot be disabled at the evaluated revision, but it is accepted as a
user-initiated capability: it requires an explicit paste and confirmation, rejects credentials and redirects, keeps
files user-only and short-lived, and adds no privilege or resident service. It does not block `strata;gtk` and is
documented in the file manager's `sources.md` and the procedure, without a recipe patch [DEC-004].

## Strata theme

Strata shows the MirrorOS theme permanently from this plan onward, not a temporary bundled theme. Because the
MirrorOS palette already uses the Quattro keys Strata maps, configure bridges it through Strata's fixed
`$HOME/.local/state/omarchy/current/` contract: an initialize-only directory holding only a `theme` link to the
resolved MirrorOS theme and a `theme.name` entry that `visual/theme` now publishes with the theme. Strata follows
it live and by default, so Story 4.8 theme selection reaches Strata without further work, and neither a palette
converter nor a write to Strata's own `settings.toml` is needed. An existing `omarchy/` state is reported as a
conflict, never replaced. The accepted risks are an `omarchy` namespace in user state and reliance on a contract
Strata does not declare stable, so the bridge is documented against the verified recipe revision and a contract
test runs whenever that revision changes [DEC-007].

## Capture boundary

The portal's `Screenshot` and `ScreenCast` interfaces are part of this plan's stack: their routing to `hyprland` is
a postcondition and the attended Meet check exercises `ScreenCast`. Capture tooling, capture shortcuts and user
capture tests belong to the later screenshots plan, which decides whether its tool goes through the portal
[DEC-009].

## Appearance answer

The Settings portal answers dark through a system dconf default rather than user state: configure declares the
`user` dconf profile and a MirrorOS `local.d` entry with `color-scheme='prefer-dark'`, compiled through `cfg_exec`
in either context, so a user's own choice still wins. Configure checks the declared and compiled database, and the
portal's effective dark answer is checked after a new login [DEC-010, DEC-019]. The preference reaches Chromium-family browsers, `-gtk` dialogs
and GTK4 applications; GTK3 and Qt dark settings, and deriving the value from the theme `mode`, are left to Story
4.8, with any light surface observed in the laboratory recorded as a finding for it [DEC-010].

## Keyring

Secrets are stored by gnome-keyring, unlocked with the login password at SDDM login. The laboratory showed that the
packaged SDDM PAM service already carries optional `pam_gnome_keyring` lines, so the neutral portal capability only
declares `gnome-keyring` and MirrorOS never edits PAM; a missing integration would be a reviewed finding. Portal
preferences route `Secret` to gnome-keyring, while Chromium-family browsers reach `org.freedesktop.secrets`
directly. Configure checks the package and, read-only, the packaged PAM lines; the service owner and the unlocked
`login` collection are session checks after a new login [DEC-019]. The attended check stores and recalls a
disposable browser password across a new login without recording any value. The SSH agent, KeePassXC and cloud
password managers stay out, and the procedure documents that `passwd` does not re-encrypt the keyring, that the
keyring is runtime state outside the repository and that the screen lock does not lock it [DEC-011].

## Capability ownership

Portal preferences are desktop-specific, because the frontend takes the first matching `<desktop>-portals.conf`
whole and the `hyprland` package already ships one. The Hyprland provider therefore owns
`xdg-desktop-portal-hyprland` and an `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` that restates
`default=hyprland;gtk` and adds the FileChooser outcome and `Secret=gnome-keyring`, so a different compositor would
write its own file without redesigning the rest. A new neutral `desktop/portal` capability owns the frontend, the
GTK backend, gnome-keyring, the dconf appearance default and the session verification command, and runs before
`desktop/files`. The existing `desktop/files` capability owns Strata and everything around the file
manager: its recipe and integrations, `inode/directory`, the theme bridge, Nautilus removal and `xdg-user-dirs`.
No `xdph.conf` is delivered, since the token default is already off and the share picker ships with xdph, and a
test keeps the provider file consistent with the neutral declarations and the FileChooser outcome [DEC-012].

Default application associations have a single owner: `desktop/portal` delivers `/etc/xdg/mimeapps.list`, which
in this plan maps only `inode/directory` to Strata's desktop entry and which the browser and leftovers plans will
extend rather than duplicate. `desktop/files` therefore delivers Strata and its desktop entry but not the
association file. Configure checks the declared file and, in running context, queries the effective default as the
user, which needs no session. A user's own `mimeapps.list` choice is reported as a notice, while only package-created conflicts such as
Nautilus fail as two owners [DEC-014].

The Hyprland provider also declares native floating and centering rules for portal dialogs (the GTK backend, the
xdph share picker and Strata's chooser), following Omarchy's choice to float every portal window; exact window
classes are confirmed in the laboratory, and the ordinary Strata window keeps default tiling [DEC-020].

## Task order and checkpoints

Work proceeds so that the Strata risk never blocks the portal stack: the portal capability and provider files come
first with `FileChooser=gtk` as the safe starting point, then the Strata delivery and its surroundings, then the
shell's folder opening. A first laboratory phase, authorized by the maintainer before VM deployment and before
laboratory Chromium, validates everything with `gtk`, including the Nautilus migration and the DEC-030 rerun; a
second phase switches to `strata;gtk`, applies the evaluation criteria and fixes the final value, removing Strata's
portal files from the recipe if `gtk` wins. Documentation follows, and a final task commits by concern only after
the laboratory checkpoint is approved, testing each committed tree, never committing `.agents/` or generated
outputs, and removing laboratory candidate refs after confirmation [DEC-021].

## Laboratory campaign

Automated postconditions run without a browser, through dedicated clients: `gdbus` introspection and calls against
the portal frontend and backends, Strata's `scripts/portal-test.py` against the installed backend, and a portal
capture request. Attended dialog, sharing and keyring checks use official `extra/chromium` as authorized laboratory
drift only; configure does not declare it, it is removed when the campaign closes, and the later browser plan
reruns the browser-dependent checks with the selected provider. The Google account used for Meet remains external
state that is never recorded or committed [DEC-005].

## Strata delivery

Strata is packaged from its release binary rather than built from source, replacing the brainstorm's source-build
choice. A MirrorOS recipe derived from Strata's own `packaging/aur/strata-bin` PKGBUILD pins a stable release tag
by checksum and attestation, keeps the binary unstripped and installs the `install-source.toml` marker, so updates
remain cheap, reviewable recipe changes and installation in either context avoids a Rust build. The accepted cost
is that the updater and runtime-integration code remain in the binary: the update check is only a notice because
the marker prevents self-replacement, the first-launch integration offer is suppressed initialize-only, the package
itself ships the portal and FileManager1 files, and a running-context postcondition reports any user-level
FileChooser or FileManager1 override. Bundled UnRAR is accepted with its license recorded. Returning to a source
build would change only the recipe. The latest stable tag, its assets, checksum, attestation and shipped
integration files are verified during implementation [DEC-008].

## Nautilus retirement

Configure gains no uninstall capability: `desktop/files` simply stops declaring Nautilus and declares
`xdg-user-dirs` itself, so fresh installations never receive Nautilus. On already-configured systems an ownership
postcondition fails while FileManager1 or `inode/directory` has two owners, naming both and the one-time
`sudo pacman -Rns nautilus` action documented in the procedure. This slice thereby becomes the first consumer of
the Epic 4 common-contract clause on detecting two owners of the same package, file or service [DEC-013].

## Keyboard paths

The file manager opens with `SUPER+SHIFT+F`, and `SUPER+ALT+SHIFT+F` opens it in the focused terminal's working
directory, following Omarchy's chords. Both are registered by the Hyprland provider so keyboard help lists them,
and the provider's reserved-key record marks the file-manager key as bound while the browser, editor, clipboard and
capture keys remain reserved for their own plans [DEC-015].

The working directory comes from an owned `files-cwd` command delivered by `desktop/files`. It adapts Omarchy's
terminal-cwd algorithm, which only recognizes a shell directly under the terminal, and adds the tmux case that
MirrorOS's Foot+tmux path needs: when the terminal's child is a tmux client, the active pane's current path is
asked from tmux for that client's tty. Anything else falls back to `$HOME`, and Strata is launched through uwsm
with fixed argv. A fake process tree drives the automated tests and the laboratory covers Foot with zsh and with a
two-pane tmux session; kitty and Strata-as-source are left out [DEC-016].

## Shell folder opening

The shell no longer names a file manager: its background-folder action opens the folder through `xdg-open` with
fixed argv, so the system association, or the user's own, decides the handler. Its provenance records stop
mentioning Nautilus, and the dependency-gated wallpaper test checks delegation to the associated handler with a
temporary association and a fake desktop entry instead of requiring Nautilus, while opening in Strata is confirmed
in the laboratory [DEC-017].

## DEC-030 closure

Closing the Story 4.3 portal exception is evidence-driven. Once the portal stack is delivered, the laboratory
reruns the shell quiet-log suites and the production journal check; a clean portal category leaves the exception
in the desktop-shell procedure and the MVP scope. Remaining portal diagnostics are never suppressed: they are fixed
when this plan causes them, or recorded with evidence as upstream noise, which keeps the exception open but narrowed
to that diagnostic by explicit maintainer decision. The same campaign records the observed PipeWire and UPower
state so the exception text matches reality without presuming Story 4.4's closure [DEC-018].

## Verification split

Configure verifies declared state only, because it never starts or restarts session services and a running
frontend keeps its old configuration until the next login. Its postconditions cover packages, the provider portal
preferences, the association file, the compiled dconf database, portal and D-Bus service files, the packaged PAM
lines, the theme bridge and the static two-owner rule, plus session-independent queries in running context; it
reports that portal changes apply at the next login. Effective behavior is checked by an owned read-only
`portal-check` command in `desktop/portal`, run after a new login: the uwsm-exported activation environment (MirrorOS
adds no propagation of its own), the owner and routed backend of FileChooser, Screenshot, ScreenCast, Settings and
Secret, the dark answer, the unlocked keyring, the FileManager1 owner and user overrides as notices. The laboratory
campaign runs it as its automated check, and Epic 5 verification may reuse it [DEC-019].

## Decision record

No ADR is required: the provider choices are reviewed updates owned by Story 4.5, the binary recipe follows the
architecture's reviewed-PKGBUILD rule and the Sesh precedent, the theme bridge shares a state path without
depending on Omarchy, and `desktop/portal` already appears in the architecture tree. Provenance lives in the
capabilities' `sources.md`/`UPSTREAM.md` and `docs/mvp-scope.md`, ADRs and `docs/architecture.md` stay unchanged,
and any design-changing finding goes through review instead of being resolved inside the plan [DEC-022].

## Execution notes (2026-11-12/13)

This section supplements the narrative above; the execution findings in the
[interview log](story-4-5-portals-file-manager_log.md#execution-findings--2026-11-1213-plan-02-35) hold the details.
Both laboratory phases were approved on the reference VM. Four outcomes differ from the expectations above. The
FileChooser is `strata;gtk` although the quiet criterion failed under its literal reading: the maintainer accepted
the Strata chooser's sporadic diagnostics as an explicit deviation from DEC-006. The share picker's restore token is
checked by default through a user `xdph.conf`, and `grim` backs the Screenshot portal, amending DEC-012. The GTK
chooser gets Omarchy's 875×600 floating size, and portal dialogs center on the monitor rather than over their
parent. DEC-030 is narrowed, not closed, to named portal diagnostics, with the PipeWire and UPower categories dropped
on observation.

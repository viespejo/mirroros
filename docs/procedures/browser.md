# Browser

## Installation and daily use

[ADR 0032](../adr/0032-chrome-supply-chain-and-update-flow.md) governs the Story 4.5 Google Chrome provider.
Configure builds the verified stable package locally as the selected user and installs it only when missing or when
replacing a non-MirrorOS `google-chrome` package. An installed MirrorOS package is not upgraded by configure.
Configure records the verified build source in `sources.tsv`. If installation cannot verify the channel, fix the
reported network or integrity issue and rerun configure; do not fall back to an unverified download.
A Google account is optional. Accounts, profiles, user flags and browsing data remain external to MirrorOS.

- `SUPER+SHIFT+B` and `SUPER+SHIFT+RETURN` open the default HTTPS handler.
- `SUPER+SHIFT+ALT+B` opens its `new-private-window` action (Incognito on Chrome). If no handler or action is
  available, the launcher shows a notice rather than substituting Chrome or silently opening a normal window.
- `/etc/xdg/mimeapps.list` sets Chrome as the system default for HTTP, HTTPS, HTML and XHTML. A personal default
  takes precedence; configure reports a different effective choice without changing it. To inspect the choice,
  run `xdg-mime query default x-scheme-handler/https` in the graphical session.
- Until Area 7 provides dedicated PDF and image handlers, opening a PDF or a supported image from downloads or
  Strata can fall back to Chrome when no other default is set. MirrorOS adds no PDF, image or mailto associations.

## Updates

The user service checks at graphical login and its persistent user timer checks daily. A verified version newer
than the installed one generates a critical notification with an **Update** action. This opens Foot and runs
`/usr/share/mirroros/browser/chrome-update`; to retry or check manually, run that command as your normal user.
It verifies the channel again, compares versions and builds without privilege. It uses sudo only for the final
`pacman -U` transaction. A failed verification or build does not replace the installed package; follow the next
step printed by the command. Successful updates append the version, package hash, signed release date and signing
subkey under `${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/chrome-update/`.

Under the same `mirroros` state directory, `chrome-update-offered` remembers the offered version so it is not
reoffered each day. A temporary network or notification-server failure presents no update and does not change the
offer marker. On integrity failure the unit fails and the shared sender issues a non-actionable notice;
`chrome-update-integrity-notified` suppresses repeats for the same cause and is cleared after a verified check.
Review the failure with `journalctl --user -u mirroros-chrome-update-check` and resolve it before trying again.

## Policy, theme and password storage

`chrome://policy` shows platform policies from `/etc/opt/chrome/policies/managed/`: `mirroros.json` disables
Chrome's default-browser setting and metrics reporting; `color.json` sets `BrowserThemeColor`. These policies
can cause Chrome to show **Managed by your organization**. They do not disable the password manager, install
extensions or force dark mode.

`/etc/opt/chrome/policies/recommended/mirroros.json` restores the previous session, recommends Google as the
search engine, shows the Home button without setting its destination, and disables background mode after the
last browser window closes. These are defaults, not locks: settings chosen by the user take precedence.
Restoring the session can affect session-only cookies and clearing data on exit.

`managed/mirroros.json` also blocks Google sync for apps, extensions, browser preferences, and themes
across all Chrome profiles on the machine, including at first sign-in. It does not remove local data or
prevent local customization. Bookmarks, history, and the other supported types are not blocked by this
policy; users can manage them under **Settings → You and Google**.
`recommended/mirroros.json` also recommends **Standard protection** for Safe Browsing. Users can override
it under **Settings → Privacy and security → Security**. Use **Reload policies** in `chrome://policy` to check
that Chrome has picked up the two policies.

Configure migrates the unmodified standalone T14s trial policies (`managed/local-sync-types.json` and
`recommended/local-safe-browsing.json`) into the corresponding `mirroros.json` files. If a trial file has
been customized, Configure reports the conflict and leaves that file in place for review.

MirrorOS launch paths use `/usr/bin/google-chrome-stable`, which supplies `--password-store=gnome-libsecret`
before any flags from `${XDG_CONFIG_HOME:-$HOME/.config}/chrome-flags.conf`. Leave that option unmodified to use
the `login` keyring unlocked by the [packaged SDDM PAM integration](portals-and-files.md#keyring). Configure manages
neither the flags file nor the Chrome profile. No password values or secret-tool output belong in evidence.

For Story 4.8, after changing the theme selection, invoke `/usr/share/mirroros/browser/browser-theme-color --user <login>`
through a separately reviewed sudo or pkexec integration. Derive `<login>` from `SUDO_USER` for sudo, or resolve
`PKEXEC_UID` to its account for pkexec; do not accept an arbitrary session-supplied login. No authorization grant
is shipped here. The helper resolves and validates the product theme's `chromium.theme` (`R,G,B`), then replaces
the system-wide `color.json` atomically. If Chrome is running for that user, it asks the user session to refresh
platform policy. Because this is a system policy, the last applied color applies across users.

## Optional migration from Chromium

Do not copy the Chromium profile to Chrome. To check the old store mode, inspect only the `os_crypt` mode metadata
in the old profile's `Local State` and record only the backend classification, if present (for example, `basic` or
`gnome-libsecret`), never preference values or login database contents. If the available metadata is inconclusive,
record the mode as unknown rather than opening the credential database. Nothing is migrated automatically.

If locally saved passwords must be retained, close other readers of the export, create a private directory with
mode `0700` on a trusted local volume, export from Chromium's `chrome://password-manager` into that directory,
then import the CSV into Chrome and confirm it works. The CSV is plaintext: do not sync, back up, log or share it.
Remove it immediately with `shred -u -- <csv>`; shredding is not a guarantee on SSDs, copy-on-write filesystems or
snapshots. Only once satisfied with the migration should you explicitly delete the old Chromium profile; that
also removes any remaining local browser state. Keep the profile if not ready to discard it.

## Reference VM results

- Running-system configure installed verified Chrome `158.0.8127.36-1.1`. The maintainer confirmed the three
  shortcuts, Wayland, Strata Open and Save as, and Meet window and entire-screen sharing. Workspace sharing
  did not work; the cause was not established. Multiple upload and folder selection were not repeated in
  Chrome. Clipboard, Omasnap drag-and-drop, the HTTPS and PDF fallback paths, and the fresh-profile case
  were not verified in this campaign.
- The running browser used `gnome-libsecret`, and the unlocked `login` collection contained a Chrome Safe
  Storage item. A fresh disposable password write was not tested. The removed laboratory Chromium profile's
  backend could not be established from the available metadata.
- Chrome accepted `BrowserThemeColor` and the two retained managed keys on the reference VM. After the policy
  revision, the maintainer confirmed that `BackgroundModeEnabled` appeared as a recommended, editable setting;
  live behavior and overrides for the other recommended defaults were not established.
- A laboratory package with a lower release label triggered a critical update offer. Clicking the card opened
  Foot and the attended update restored the verified package and recorded its provenance. A check after updating
  made no further offer; live deduplication with the lower release still installed was not tested. The installed
  check exited successfully without an offer or marker changes in an isolated network namespace. The separate
  shell button change was not verified visually.
- A clean guided installation from the explicitly approved dirty-tree ISO completed target configure with
  Chrome present and both user units enabled. `desktop/browser` took 65.86 seconds out of 738.37 seconds for
  configure. This measured the whole step, not compression alone; no package compression change was made.

## Optional T14s deployment

With maintainer authorization, remove the Chromium package but leave its profile untouched. Deliver the reviewed
candidate as a checksummed Git bundle, verify its checksum, check out the candidate in a working checkout, and
run `sudo operations/configure` there. Do not modify the installed configure snapshot. The reference VM and clean
guided installation own the validation campaign; no additional T14s validation is part of this plan.

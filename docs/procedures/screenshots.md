# Screenshots

Story 4.5 screenshot core (plan 02-40) and capture extras (plan 02-41). Automated contracts do not establish live
qualification; the capture extras require an authorized reference-VM campaign and explicit maintainer approval.

## Capture

```bash
/usr/share/mirroros/screenshot/screenshot [smart|region|window|full|scroll] [--edit]
```

Omitting the mode selects smart. One mode and one `--edit` are accepted, in either order. Unknown, repeated or
excess arguments return 2. The command waits for the active compositor backend: 0 means success, cancellation or
second-press dismissal; 1 means capture failure; 2 means usage error. Success and cancellation add no notification.

- PRINT or SUPER+CTRL+ALT+C opens smart capture; pressing again dismisses a running overlay.
- SUPER+CTRL+C opens Capture in the existing session menu. Trigger → Capture contains **Screenshot**,
  **Screenshot with annotation**, **Text**, **QR Code** and **Color**, in that order. The aliases `capture`
  and `screenshot` resolve to the submenu. Capture has a wider,
  screen-clamped card; its actions close the menu and immediately dispatch fixed argv. The Hyprland provider
  disables animations only for `mirroros-menu`, following Omarchy, so a closing-menu fade does not enter the capture.
  There is no capture timer or global animation change.
- Smart selection covers regions, windows and monitors; `S` switches to scroll. The explicit command modes allow
  region, window, full-screen and scrolling capture without additional shortcuts. Scroll selects a region and
  direction, stitches the scrolled content, then allows annotation. In the selector, `A` or `E` toggles annotation
  before output; the guide shows whether it is enabled. Defaults remain automatic save/copy without annotation.
- SUPER+PRINT opens Color and SUPER+CTRL+PRINT starts direct OCR. QR Code has no dedicated shortcut. Recording is excluded.

Normal capture uses upstream autosave and copy defaults: a flattened PNG in the XDG Pictures directory's
`Screenshots` child (normally `~/Pictures/Screenshots`), plus the current clipboard. The managed filename is
`screenshot-{date}_{time}`, without an application slug. It does not override the directory or autosave behavior.
A successful capture shows Omasnap's own floating preview for about seven seconds, not an added notification.
Hover for Edit, Copy, Pin, drag-out and Close. Pin keeps a reference visible; drag into Strata or an available
browser. Existing previews and pins **can appear in subsequent captures**: close or move them, or wait for an
unpinned preview to expire. Expiry does not remove the saved file.

The editor provides annotations, redaction and built-in English OCR (`O` in the editor). OCR text enters the
existing text clipboard history when copied. The direct OCR language settings below do not change Omasnap.

## Color, direct OCR and QR Code

- **Color** opens the picker and copies the selected color value. A second invocation dismisses the active
  picker. MirrorOS retains Omarchy's `pkill hyprpicker || hyprpicker -a` toggle. Because direct OCR and QR also
  use `hyprpicker` to freeze the screen during selection, Color can stop that process; the resulting selection
  and output behavior has not been verified on the reference VM.
- **Text** runs direct OCR on a selected region without opening Omasnap or saving an image. Paste the result
  from the ordinary clipboard; it can also appear in the existing text clipboard history.
- **QR Code** decodes only QR codes in the selected region and copies the result as sensitive. It is pasteable
  but excluded from MirrorOS clipboard history. MirrorOS does not save the image or open the decoded result.
  Cancellation is silent; a region without a QR code produces a content-free notification. Neither case
  replaces the current clipboard.

Existing Text, QR Code and Color notifications use the same icons as the Capture menu and never include the
captured result. Color remains silent on success.

The commands `/usr/share/mirroros/screenshot/{color,ocr,qr}` take no arguments. Rerun `mirroros-configure` if a
backend is missing or after changing the installed language or regional formats. Configure reads `/etc/locale.conf`
(not the session locale or keyboard layout), ensures the English model, and adds Spanish when the installed
language or installer-managed formats are Spanish. The managed default is `eng` or `eng+spa`, respectively.
Override it for one direct OCR invocation using already installed Tesseract models, for example:

```bash
MIRROROS_OCR_LANGS=spa /usr/share/mirroros/screenshot/ocr
```

## Sensitive annotation: redact before output

Use `screenshot --edit` or **Screenshot with annotation**. The provider requests `--editor overlay`: annotate and
redact the synthetic sensitive region first, then explicitly Save or Copy. Inspect both the exported PNG and the
clipboard before sharing. This flow must not export prematurely; its live validation is part of the checkpoint.

**Normal capture saves and copies before preview. Editing afterward does not erase earlier originals**, including
files or history entries. RAM-only working documents do not undo an automatic export. Manual cleanup must include
original exported files and unwanted clipboard-history entries. Omasnap cannot mark a capture as sensitive, and
there is no history-pause feature in this delivery. Deleting a history entry does not clear the current clipboard,
remove exported files, undo external pastes or guarantee forensic erasure.

## Recent documents and history

Omasnap retains original source images and operation logs for its recent-document shelf. Configure installs
`/etc/environment.d/60-mirroros-omasnap.conf` with
`OMASNAP_RECENT_DIR=${XDG_RUNTIME_DIR}/omasnap/recent`; the backend exports the runtime path as a fallback.
Start a **fresh graphical session with a new user manager** after first delivery. Graphical logout alone may keep
the old manager alive while SSH or other sessions remain, so it may not load the new environment.d file. A
coordinated reboot establishes a fresh manager; save work before rebooting. Check `systemctl --user show-environment`
for the expanded runtime value before capturing. Wrapper, launcher, terminal and Open With must inherit it,
avoiding the default persistent `~/.local/state/omasnap/recent`. No desktop entry or MIME override
is used. Existing persistent recent documents are not migrated or deleted; inspect and remove unwanted old
material manually. A user environment override can defeat the direct-launch setting.

Runtime documents disappear with the user runtime directory, which can outlive a graphical logout when other
sessions remain; exported captures intentionally remain on disk.
RAM-backed storage is not a no-swap or secure-erasure guarantee; see the [clipboard privacy caveats](clipboard.md).

PNG copies use the existing RAM clipboard history unchanged. Its per-entry cap is **5,000,000 bytes**: an oversized
scroll/4K PNG is excluded from history with type-and-size-only journal diagnostics, but its saved file and current
clipboard remain usable. Normal PNGs appear in SUPER+CTRL+V and can be copied/pasted; OCR uses the text watcher.
Delete sensitive entries from the picker and separately handle current clipboard and files as needed.

## Ownership and recovery

Apps lists the application as **Omasnap**, using a Name patch to the packaged `omasnap.desktop`.
Desktop-entry Keywords retain searches for `screenshot`, `capture` and `screen capture`.
Its desktop id, icon, launch command and MIME associations stay upstream-owned; Capture's descriptive action
labels and the neutral screenshot command are unchanged.

Configure builds `omasnap 1.26.2-4.4` unprivileged from the reviewed local recipe, caches the result under
`${XDG_CACHE_HOME:-$HOME/.cache}/mirroros/omasnap`, then installs it with privileges. An unchanged recipe version
and managed state should produce an unchanged rerun. It does not enable Omarchy repositories.

The explicitly approved local patch allows the native Save As chooser and selects Qt's `xdgdesktopportal` theme
inside Omasnap. Save As therefore uses the configured FileChooser portal (Strata in MirrorOS) across command,
shortcut, menu, launcher, direct terminal and Open With paths, not an in-process GTK chooser. No desktop-entry
override or session-wide Qt theme is installed. Explicit Qt platform-theme arguments can override this choice.
The two-file patch and its update/retest obligations are recorded in provider sources; final-package live
validation remains part of the checkpoint.

`~/.config/omasnap/omasnap.conf` is delivered through `cfg_user_file`, with a semicolon MirrorOS marker. An unmarked
file or link is user-owned and preserved; user overrides can reintroduce application slugs or change autosave.
Inspect those overrides if output differs. The provider independently ensures the shared theme bridge; conflicting
Omarchy state is preserved and fails configure, with an instruction to move it aside. Strata is not a prerequisite.

A missing backend reports that you should rerun `mirroros-configure`. For capture failures, inspect backend
diagnostics with `journalctl --user -t mirroros-screenshot` (or the matching journal view available to the session).
Never place capture contents or sensitive application metadata in troubleshooting evidence. Restore any temporary
missing-backend/capture-failure injection before continuing.

## Focused reference-VM checkpoint

Deployment requires separate authorization. Use disposable synthetic content only and test:

1. Configure, unchanged rerun, then fresh login with a new user manager. Check expanded recent directory through wrapper, launcher,
   terminal and Open With; inspect source/log placement and absence of new persistent default recent documents.
2. Smart/region/window/full/scroll, silent cancel, second-press dismissal, both shortcuts, menu route and actions.
3. Redact before Save/Copy through --edit; inspect file and clipboard for redaction and lack of premature export.
4. Osaka Jade chrome, preview expiry, Edit, Copy, pins, drag to Strata/an authorized available browser, and actual
   preview/pin visibility in later captures. Insufficient preview feedback needs a new decision, not a shim.
5. English OCR, normal PNG history/paste, and a scroll PNG over the cap: no history entry, type/size-only drop log,
   usable file/current clipboard. Do not change existing watchers or install browser drift without approval.
6. Save As uses Strata across launch paths: successful PNG export, overwrite, cancel, focus restoration and no
   perceptible regression in the attended flow; no security claim from a chooser change.
7. Filename without application slug, PNG metadata using an available parser, no secret-bearing application info;
   controlled capture and missing-backend failures with actionable notifications/journal diagnostics, then restore.

Retain only synthetic non-sensitive evidence in ignored `evidence/screenshots/lab-02-40/`, with `SHA256SUMS` verified
by `sha256sum -c SHA256SUMS`. Record limitations: this does not qualify T14s, fractional scaling or multiple monitors.
Only affected contracts and live checks are allowed, never complete suites. Delivery commits and candidate-ref
cleanup follow explicit checkpoint approval. Recipe/source/theme-update requirements and exact provenance are in
[provider sources](../../capabilities/desktop/compositor/providers/hyprland/omasnap/sources.md).

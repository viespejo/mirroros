# Screenshot command source and ownership

The MirrorOS-owned `screenshot` command is installed off PATH at
`/usr/share/mirroros/screenshot/screenshot`. It accepts one optional mode (`smart`, `region`, `window`, `full`,
`scroll`) and one optional `--edit`, in either order. The default mode is `smart`; repeated, unknown or excess
arguments return 2 without dispatch. Annotation is requested before output through `--edit`.

The active compositor provider owns `/usr/share/mirroros/compositor/screenshot-backend`. The neutral command
waits for that backend, preserving 0 (success, cancellation or overlay dismissal), 1 (capture failure) and 2
(usage error); other backend failures are reported as 1. Backend stdout/stderr diagnostics go to
`systemd-cat --identifier=mirroros-screenshot`. The pipeline's backend status is collected separately so logger
failure does not replace it. The backend contract is diagnostic text only, never image bytes or capture contents.
No arguments, image data or session environment are added to logs. Troubleshoot with
`journalctl --user -t mirroros-screenshot`. Journal delivery failures also report on stderr.

Only failures notify through `notify-send`. Missing backends advise rerunning `mirroros-configure`; capture
failures point to the journal. Notification delivery failure cannot mask the capture status. Output location,
autosave, clipboard export and rendering are provider responsibilities, not implemented here. Configure delivers
the command as a tracked file: conflicts are preserved and fail rather than overwritten. It starts no capture.

## Direct runtime dependencies

Package identity/version observations below come from the current Arch repository JSON endpoints, queried for
plan 02-40, not from the development host. These are provenance observations, not version pins; configure records
resolved installed versions in `packages.tsv`.

| Declaration | Purpose | Observed version | Source |
|---|---|---|---|
| `core/bash` | Bash interpreter, arrays and pipeline statuses | `5.3.20-1` | <https://archlinux.org/packages/core/x86_64/bash/json/> |
| `core/systemd` | `systemd-cat` journal diagnostics | `262.2-1` | <https://archlinux.org/packages/core/x86_64/systemd/json/> |
| `extra/libnotify` | `notify-send` actionable failure notifications | `0.8.9-1` | <https://archlinux.org/packages/extra/x86_64/libnotify/json/> |

Tests in `tests/capabilities/desktop/screenshot/` use a disposable dispatch double and journal/notification doubles;
they require neither a provider installation nor a graphical session. Live journal delivery remains a laboratory
check. Governing decisions: Story 4.5 screenshots DEC-002, DEC-003, DEC-011 and DEC-013.

## Direct capture extras (plan 02-41)

The MirrorOS-owned `color`, `ocr` and `qr` commands accept no arguments and dispatch to their fixed compositor
backend paths. They return 0 for completion or cancellation, 2 for misuse and 1 for any dispatch or capture
failure. They do not relay backend output. The Hyprland backends send only controlled diagnostics to
`mirroros-screenshot`; see the [provider record](../compositor/providers/hyprland/UPSTREAM.md#direct-capture-extras-plan-02-41).

Configure always selects English OCR data and adds Spanish only for `es_ES.UTF-8` in the installed `LANG` or
an installer-managed format category (`LC_TIME`, `LC_NUMERIC`, `LC_MONETARY`, `LC_MEASUREMENT`). A single
preflight selection drives resolution, the partial-upgrade guard, installation and package postconditions.
The provider persists `eng` or `eng+spa` in `ocr-languages`. Direct OCR uses it unless `MIRROROS_OCR_LANGS`
is set explicitly. Removing the Spanish locale selection does not uninstall an existing model.

Plan 02-41 observations from official Arch package JSON endpoints (not pins). Configure records the resolved or
installed package versions in `packages.tsv`.

| Declaration | Purpose | Observed version | Source |
|---|---|---|---|
| `extra/hyprpicker` | Color picker and OCR/QR freeze overlay | `0.4.8-1` | <https://archlinux.org/packages/extra/x86_64/hyprpicker/json/> |
| `extra/slurp` | Interactive region selection | `1.5.0-2` | <https://archlinux.org/packages/extra/x86_64/slurp/json/> |
| `extra/zbar` | QR-only decoding via `zbarimg` | `0.23.95-3` | <https://archlinux.org/packages/extra/x86_64/zbar/json/> |
| `extra/grim` | Stream the selected image | `1.5.0-2` | <https://archlinux.org/packages/extra/x86_64/grim/json/> |
| `extra/tesseract` | Direct OCR | `5.5.4-1` | <https://archlinux.org/packages/extra/x86_64/tesseract/json/> |
| `extra/tesseract-data-eng` | Required English model | `2:4.1.0-5` | <https://archlinux.org/packages/extra/any/tesseract-data-eng/json/> |
| `extra/tesseract-data-spa` | Conditional Spanish model | `2:4.1.0-5` | <https://archlinux.org/packages/extra/any/tesseract-data-spa/json/> |
| `extra/wl-clipboard` | Clipboard delivery, including sensitive QR copies | `1:2.3.0-1` | <https://archlinux.org/packages/extra/x86_64/wl-clipboard/json/> |
| `core/procps-ng` (base) | `pkill` for the Color toggle | `4.0.7-1` | <https://archlinux.org/packages/core/x86_64/procps-ng/json/> |

The commands reuse the existing Bash, systemd and libnotify runtime dependencies.

# Guided installer presentation upstream record

## Origin

- **Upstream project:** `omacom/omarchy-iso` (the Omarchy ISO builder), as shipped in the Omarchy 4.0.4 ISO.
- **Adapted material:** the presentation of the guided live installer's screens: the `step()` screen
  (logo, blank line, title, blank line), the Tokyo Night virtual-console palette, the centering of the logo
  and the guide as one block, the Gum widget color settings, and the wording and widget layout of the
  screens. Sources reviewed: `/root/configurator` and `/root/.automated_script.sh` of the ISO.
- **Reference copy:** the frozen reference at [`prototypes/frontend/guided-installer/`](../../prototypes/frontend/guided-installer/README.md)
  (see its [`UPSTREAM.md`](../../prototypes/frontend/guided-installer/UPSTREAM.md) for the ISO identity,
  hashes, palette, geometry, console font, and Gum version of the tested ISO). It is a visual and behavioral
  reference only.
- **Production implementation:** reimplemented under `install/confirmation/` (`lib/ui.sh`, `lib/live.sh`,
  `lib/screens.sh`, `banner.txt`, `instructions/live-wifi.txt`). Nothing at runtime sources the prototype,
  `/root/configurator`, or any other Omarchy file; no Omarchy file is required on the MirrorOS ISO.
- **Upstream version caveat:** the published upstream source was not extracted from the exact tested ISO.
  Newer upstream behavior must not be substituted silently.

## Licensing

- **License (SPDX):** `MIT`, Copyright (c) 2025 Anton Hvornum, preserved unchanged in
  [`LICENSE-ISO`](LICENSE-ISO).
- **Scope:** the notice accompanies the presentation material adapted from `omacom/omarchy-iso`. Original
  MirrorOS material in this directory remains under `GPL-3.0-only`; incorporation does not relicense the
  upstream material. The `LICENSE` of the Omarchy project itself stays with the reference copy, which is not
  shipped on the ISO.

## Differences from the reference

[ADR 0018](../../docs/adr/0018-native-live-display-and-installer-presentation.md) replaces the inherited
logo, palette, shared-edge centering, and welcome with the approved MirrorOS presentation and a temporary
Original / Original x2 font selector. `symbol.txt` is original MirrorOS material; `banner.txt` remains
unchanged as the historical source of the installed graphical wordmark. The frozen prototype and the
adapted screen-text attribution remain intact. The 720p request of ADR 0017 is removed.
The individually approved "Connect to the internet" screen additionally uses the welcome's symbol gap
and short-console symbol omission, a blank line before the shared selector, and no generic selector header.
Its inherited text, choices, and navigation remain unchanged. The approved Ethernet and Wi-Fi guidance use the
same heading gap and short-console symbol omission, secondary-gray instructions, and blank lines between
instructions, retry errors, and options, with the shared headerless selector. The Wi-Fi instruction text
remains unchanged, and its pager uses the blue-gray border accent with unchanged navigation. The approved
clock guidance uses the same heading gap and short-console symbol omission, secondary-gray explanations,
and a blank line before the shared headerless selector. The approved keyring waiting and failure screens
use the same heading gap and short-console symbol omission. Waiting status and failure explanations use
secondary gray; failure choices follow a blank line and use the shared headerless selector. No inherited
guidance text, navigation, service check, or wait bound is changed.
The approved machine check (recognized and unqualified), disk selection, and storage layout screens use
the same heading gap, short-console symbol omission, and shared headerless selector after a blank line.
Disk instructions and storage recovery explanations use secondary gray, with separated storage text
blocks. The principal machine identity, yellow experimental warning, compatibility disclaimer, all choices,
and navigation remain unchanged. Selection grants no authorization.
The approved hibernation, timezone, language, regional formats, and installed console keyboard batch,
including conditional swapfile sizing, uses the same heading gap and short-console symbol omission.
Selectors use the shared headerless style; instructions and the current follow-language meaning use
secondary gray with separated blocks. Swapfile sizing retains its input and prompt, with the unchanged
red validation error moved after the instructions and separated from the input. Text, options, current
values, RAM-derived bounds, provider validation, size-reset behavior, Back/Esc/Ctrl+C, and the installed
keyboard boundary remain unchanged. Review used synthetic data only and grants no installation authority.
The separately approved swapfile-size, hostname, and username input style uses blue-gray prompts and
cursors, secondary-gray placeholders, and principal-foreground values. Prompts, placeholders, defaults,
validation, and navigation are unchanged. Other editable fields inherit this criterion only during their
individual screen review; password and destructive-confirmation behavior remain unchanged.
The approved hostname, username, and root-policy batch uses the same heading gap and short-console
symbol omission. Hostname retry errors are separated from the input; username errors follow the
instructions with separate blocks. Root explanations use secondary gray and a separated shared
headerless selector, preserving the disclaimer conditional on the current password policy. Text,
options, values, provider validation, navigation, and password-after-approval semantics remain unchanged.
Review used synthetic data only, including both root variants, without account changes or credentials.
The approved review screen omits the symbol at every height while retaining the two-line top margin,
complete answer rows, and safety text. It uses separated secondary explanations and the shared
headerless selector. All yellow warnings, including reduced-swapfile capacity, wrap within the
80-column form or available narrower width, preserving full text and continuation alignment. The
complete-plan pager uses the blue-gray border with unchanged content, navigation, and status handling.
Review used synthetic no-warning and multiple-warning data only. The subsequently approved adaptive
review measures the rendered body and terminal geometry at redraw, keeps separate rows when they fit,
and otherwise groups Hostname/Username/Root and Timezone/Language/Locales independently if each fits
horizontally. Rows and explanations wrap to the form width. When grouping is insufficient, the complete
review opens in the blue-gray-bordered pager before navigation, whose conditional Inspect review option
reopens it. Inspection never authorizes installation. Original-size 149x41, a disposable two-line deficit,
and doubled-font 74x20 were reviewed; no forced-height hook enters production. Arbitrary geometries,
all long answer values, live reflow inside an open widget, and complete installer usability at doubled
size are not qualified. Gum 2.0.2's choose/command.go and choose/choose.go were consulted only to inspect
native menu/help sizing at https://github.com/charmbracelet/gum/tree/v2.0.2/choose; no Go code was copied.
The approved confirmation screen uses the reviewed heading gap and short-console symbol omission,
review-style aligned principal-foreground rows with form-width wrapping, and blank lines between disk
context, the full red erasure warning, the confirmation control, and the device-name input. The control
uses the blue-gray selection accent without inverse video and retains No as its default. The device-name
input uses the approved prompt/cursor accent and secondary placeholder. The unchanged instruction text
is rendered in secondary gray as a separate block with a blank line before the unchanged input prompt,
rather than as Gum's internal header.
No, Esc, Ctrl+C, mismatch cancellation without retry, provider boundaries, and plan/disk binding remain
unchanged. Review used synthetic data only; long values, the unqualified variant's fit, complete doubled
size, and password screens remain unqualified by this approval.
A separately approved password-navigation change makes Esc in Confirm discard both values and restart
Password within the same stage. Esc in Password still returns to review and clears approval; Ctrl+C
still cancels. Bound plan approval and mandatory final revalidation are unchanged. This navigation
approval was separate from the subsequent password-presentation approval.
The approved password presentation uses the reviewed heading gap and short-console symbol omission,
secondary-gray account and safety explanations in separated blocks, and unchanged red validation
errors after those explanations with space before the input. Masked fields retain native help and use
blue-gray prompts/cursors and secondary placeholders, without an extra blank line between the fields.
Esc in Confirm also clears the displayed error. Text, non-empty/matching validation, unlimited attempts,
secret handling, and mandatory final revalidation remain intact. Review used synthetic masked values
only; outcome screens and complete doubled-size usability remain pending.

The subsequently approved progress composition was informed by read-only inspection of
`/usr/local/bin/omarchy-install-dashboard` extracted from the same Omarchy 4.0.4 ISO:

- ISO SHA-256: `ddeded2758c48318d201dfdac905ecb28f570441883f0c052ea3cd5d05acf92d`.
- Dashboard SHA-256: `47d446a7fd27cb74b479e05c9652a9693243416b667a17b990b89b30e1897851`.
- Observed functions: `progress_bar`, `centered_top_row`, `render_static`, `render_dynamic`.

MirrorOS reimplements the centered composition, principal completed blocks, secondary remaining
blocks, and static-symbol/dynamic-content separation. It retains its own symbol and palette, omits the
symbol below 32 rows, wraps full status text, and measures geometry at state redraw. Cursor and cached
layout are reset when leaving progress. The 34-column bar still reflects completed operations plus
configure, not the upstream time estimator or package-based curve. No upstream supervisor, tips,
animation, installation implementation, or power action is imported or executed. Approval used a
repeating synthetic preview; no loop or synthetic provider enters production.

The dashboard's `render_finish` and `reboot_prompt` were subsequently read to compare the success
composition. MirrorOS's separately approved success screen keeps its symbol and duration title centered,
omits the symbol below 32 rows, and removes the redundant configuration-success explanation. Unlike
Omarchy's single reboot button, MirrorOS retains its vertical Restart now / Return to shell selector,
with the approved accent and native help aligned to the title's left margin. No upstream animation,
reboot implementation, or automatic action is incorporated. Outcome gates and duration calculation are
unchanged. Approval used a synthetic demo whose actions only closed it.

The subsequently approved engine-failure presentation omits the symbol, keeps the two-line top margin,
and separates the existing operation/status, red disk warning, complete last 15 sanitized log lines,
secondary run directory, and shared accent-only selector. Diagnostics wrap at the 80-column form or
available narrower width with aligned continuations and no truncation. Return to shell stays selected;
View full log retains its content and return behavior with the slot-4 pager border. No additional external
code, media diagnosis, log upload, retry, or automatic power action is introduced. Both partially-modified
and no-disk-modification variants were individually approved with synthetic failures and logs only,
without disk or power actions; the latter preserves the principal-foreground no-modification statement.
The later approved nine-scenario error batch covers D20 with multiple failed checks, D22 with known
and unknown configure steps, missing/invalid engine records, recoverable discovery, rejected plan
combinations, blocked discovery, invalidated approval, and unexpected phase failure. These screens
adopt compact top spacing without a symbol, separated complete blocks, and form-width wrapping.
Selectors retain options/defaults and native help with the shared accent; full/configure-only log pagers
use slot-4 borders. Error Evidence labels use secondary gray and the form's margin; success/cancellation
evidence output is unchanged. Text, recovery, outcome normalization, invalidation, filtering, and explicit
power semantics remain intact. No additional external code is incorporated. Synthetic data, the preview
navigator, and its Enter pause remain disposable-only. Long-content fit, arbitrary geometries, and
complete doubled-size usability remained pending at that checkpoint.

The later approved adaptive-error presentation is original MirrorOS work using the same Gum widgets;
no additional external code is incorporated. On redraw it measures the complete wrapped diagnostic
with menu/help or terminal Evidence space. Inline content is preserved when it fits. At 32 or more rows,
the symbol and two-line gap are included only if that whole composition fits; otherwise the symbol is
omitted first. If the diagnostic still overflows, its complete transient rendering opens in the slot-4
pager before an outcome or phase/next-action summary. The summary retains disk/verification warnings
and configure recovery instructions. It has an independent symbol budget, including the conditional
Inspect diagnostic choice, so the summary may show the symbol even when the complete diagnostic needed
a pager. Existing options/defaults, full/configure-only log scope, outcomes, cancellation, plan binding,
and explicit power semantics are preserved. Inspection grants nothing, repeats no provider operation,
and cannot replace an existing terminal or recorded failure outcome. Terminal-only errors gain no menu
or retry. Private render files remain under the existing run temporary directory and are cleaned up,
never authorization or retained evidence. Attended approval used synthetic long logs, paths, failed
checks, and known/unknown steps at original and saved-font-doubled sizes. Preview-only controls, pauses,
and fixtures are not incorporated. Arbitrary geometries, unbounded summary text, other screen families,
and whole-installer doubled-size usability remain unqualified.
A subsequent attended Original x2 pass approved the remaining displayed preparation, machine/storage,
hibernation/locale, account/password, confirmation/device-name, progress and success batches without
product changes or additional external material. Together with the earlier adaptive review and error
passes, this completes the planned synthetic screen-family review on this live VM only. It is not
qualification of every branch, unbounded content, arbitrary geometry, hardware or a rebuilt ISO.
Synthetic providers, values, timing, navigation and font controls remain disposable; no real credential,
installation, account change, disk operation or power action was involved. Earlier pending statements
refer to their respective checkpoints.

The intended differences are listed in
[`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md#differences-from-the-reference)
(D1 to D14). The production assistant additionally shows three short gray status lines while a read-only
phase runs, in the style of the reference's "Checking internet connection...": "Checking system clock...",
"Inspecting this machine...", and "Checking the machine and plan again...". It also shows the failed-input
reason of the plan component in red below a hostname the plan component rejects. These are listed for the
maintainer's review.

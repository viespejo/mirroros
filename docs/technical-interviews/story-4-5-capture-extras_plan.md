# Story 4.5 Area 4 — Capture Extras: Consolidated Plan

## Scope

Plan 02-41 completes Area 4 with hyprpicker for Color, zbar for QR, the corresponding Capture menu rows and the reserved SUPER+PRINT and SUPER+CTRL+PRINT shortcuts [DEC-001].

## Shortcuts and direct OCR

Follow Omarchy's shortcut distribution: SUPER+PRINT invokes Color, SUPER+CTRL+PRINT invokes direct OCR, and QR is offered in Capture without a direct shortcut. Plan 02-41 adds an independent direct OCR flow, reusing Omarchy's omarchy-capture-text script as far as possible: freeze with hyprpicker, select with slurp, capture with grim, recognize with tesseract, then copy text and notify success. This flow does not use Omasnap or save a screenshot; the existing OCR inside Omasnap remains available. Clipboard-history policy is not settled by this decision [DEC-002].

## QR capture and sensitive output

Reuse Omarchy's omarchy-capture-qr from reviewed checkout 520c3ed969d30b58defe03eb19d603f32b4cb002 as closely as possible, adapting notification calls and paths to MirrorOS. Freeze the screen with hyprpicker, select a region with slurp and pass grim output directly to zbar without saving the image. Enable only QR recognition. Copy the decoded payload with wl-copy --sensitive, never including its content in notifications or journal output. Cancellation is silent; a region without a recognized QR produces a notification. Preserve cleanup of the freeze process on exit and verify that the existing MirrorOS clipboard history respects the sensitive marker [DEC-003].

## Direct OCR clipboard policy

Preserve Omarchy's ordinary wl-copy behavior for direct OCR: recognized text may enter the existing clipboard history. Unlike QR, direct OCR does not mark its output sensitive. Document this distinction explicitly so users do not mistake direct OCR for a history-excluded path when recognizing sensitive text [DEC-004].

## Ownership and provider boundary

The desktop/screenshot capability owns separate neutral color, ocr and qr commands, leaving the existing screenshot interface unchanged. The Omarchy-derived implementations live beneath desktop/compositor/providers/hyprland because they use hyprpicker. Both shell menu actions and compositor shortcuts invoke the neutral entry points, which delegate to provider implementations. This follows the screenshot indirection established in 02-40 and preserves ADR 0011's replacement boundary, with three small additional delegation entry points. Exact installed paths and backend contracts are not yet settled [DEC-005].

## Color toggle and cross-tool interaction

Preserve Omarchy's Color behavior, pkill hyprpicker || hyprpicker -a, which selects and automatically copies a color or terminates existing hyprpicker processes instead of stacking another picker. Upstream commit 7540bddee1503a79c213bb667cdf749bb55608cd introduced this toggle on 2025-08-04 explicitly to avoid stacking. Do not introduce dedicated process tracking preventively. OCR and QR also use hyprpicker for freezing; invoking Color during either selection may therefore remove its freeze without explicitly cancelling slurp, and a successful pkill prevents Color from opening on that invocation. This is an inferred interaction, not a reproduced defect. Exercise both cross-tool cases in the laboratory and return problematic observations for an explicit adaptation decision rather than silently changing upstream behavior [DEC-006].

## Direct OCR models and language defaults

Always install and enable English for direct OCR. During capability configuration, derive the additional Spanish model requirement from the installed locale configuration: if either the selected system language or regional format is Spanish, install tesseract-data-spa and default to eng+spa; otherwise default to eng. Do not add an installer question or infer OCR languages from keyboard layouts, since the managed desktop already offers both US and ES. Tesseract uses the explicitly selected models together for the same recognition operation, including mixed-language regions; language order may affect results and timing. Allow a later explicit override through MIRROROS_OCR_LANGS. This applies only to the independent direct OCR flow, without automatically changing Omasnap's language selection [DEC-007].

## Capture menu entries

Keep the existing Screenshot and Screenshot with annotation actions. Add Omarchy's Text, QR Code and Color rows to the same Capture submenu. Text invokes direct OCR and Color opens the color picker through the same neutral commands as their shortcuts. QR Code invokes the neutral QR command and has no dedicated shortcut [DEC-008].

## Command and diagnostic contract

Install the no-argument neutral commands at `/usr/share/mirroros/screenshot/{color,ocr,qr}`, delegating through fixed paths to `/usr/share/mirroros/compositor/{color,ocr,qr}-backend`. Return 0 on completion or cancellation, 1 on failure and 2 on incorrect usage. A missing backend tells users to rerun `mirroros-configure`. Unlike the existing screenshot diagnostic pipeline, these commands must not forward raw tool output to the journal. Only controlled MirrorOS diagnostics may be logged, with no recognized OCR text or decoded QR payloads [DEC-009].

## Upstream script structure

Keep OCR and QR as independent provider scripts, as in Omarchy. Retain each script's short freeze, selection and cleanup block rather than extracting a shared region capture helper. This makes both adaptations easier to compare with upstream during updates; revisit extraction only if a concrete maintenance need arises [DEC-010].

## Reference VM verification

Run one reference VM campaign, requesting deployment authorization at execution time and requiring human approval before closure. Use synthetic data and run only affected checks. Verify the new shortcuts and Capture rows, English and Spanish direct OCR based on the installed configuration, sensitive QR pasting without history retention, and Color invocation during OCR and QR selection. Smoke-test both existing Capture actions without repeating the full Omasnap campaign. Do not infer additional hardware qualification from the VM results [DEC-011].

During `mirroros-configure`, read the installed `/etc/locale.conf`, ensure the selected models and persist the corresponding managed default (`eng` or `eng+spa`). Direct OCR reads that default rather than recalculating it at capture time; an explicit `MIRROROS_OCR_LANGS` takes precedence. Rerun configure after changing the system language or regional format so the managed default stays aligned with installed models [DEC-007, DEC-012].

## Candidate delivery and closure

Deploy from a temporary candidate ref after authorization. Keep only synthetic evidence and its checksums. After explicit laboratory approval, commit by concern, remove the candidate ref and write the execution summary. Do not commit `.agents/` or evidence [DEC-013].

Follow `.agents/lab-access.md` for reference VM access: `ssh -i ~/.ssh/id_ed25519 viespejo@127.0.0.1 -p 2222`. For operations requiring SSH and sudo, open a window in the current tmux session so the maintainer can enter the sudo password. Monitor the operation and confirm that the window closes automatically when it finishes. Never record credentials [DEC-013].

## Conditional package preflight

Use the same effective Hyprland package selection for configure preflight and apply. Include `tesseract-data-spa` only when the installed system language or regional format is Spanish; do not add it to unconditional dependencies or install it outside the existing preflight and partial-upgrade guard. Limit the change to this case, preserving existing package-list syntax and behavior for other capabilities [DEC-007, DEC-012, DEC-014].

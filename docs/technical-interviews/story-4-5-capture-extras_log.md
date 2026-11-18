# Story 4.5 Area 4 — Capture Extras: Decision Log

## DEC-001
- **Question**: What does plan 02-41 cover?
- **Context/Nuances**: This is the second plan for Area 4.
- **User Response**: Approved registering only the proposed Decision; other aspects will be discussed separately.
- **Decision**: Plan 02-41 completes Area 4 with hyprpicker for Color, zbar for QR, the corresponding Capture menu rows and the reserved SUPER+PRINT and SUPER+CTRL+PRINT shortcuts.
- **Status**: Accepted

## DEC-002
- **Question**: Should shortcuts follow Omarchy, including its independent direct OCR flow?
- **Context/Nuances**: Omarchy checkout 520c3ed969d30b58defe03eb19d603f32b4cb002 binds SUPER+PRINT to Color and SUPER+CTRL+PRINT to direct OCR; QR is a Capture menu action without a direct shortcut. Its omarchy-capture-text script uses hyprpicker to freeze the screen, slurp to select, grim to capture and tesseract to recognize text, then copies the text and notifies success. It does not use Omasnap or save a screenshot. English is the default, configurable upstream through OMARCHY_OCR_LANGS. Upstream OCR uses ordinary wl-copy, unlike its sensitive QR copy; clipboard-history handling remains undecided here.
- **User Response**: Requested fidelity to Omarchy and SUPER+CTRL+PRINT for OCR, then explicitly confirmed adding the independent OCR flow and this shortcut distribution.
- **Decision**: Plan 02-41 adds the independent direct OCR flow by reusing Omarchy's script as far as possible. SUPER+PRINT invokes Color, SUPER+CTRL+PRINT invokes direct OCR, and QR is available from Capture without its own shortcut. Existing Omasnap OCR remains available. This clarifies DEC-001's reserved shortcuts; it does not assign a shortcut to QR.
- **Status**: Accepted

## DEC-003
- **Question**: Should the QR flow reuse Omarchy's omarchy-capture-qr implementation?
- **Context/Nuances**: The reviewed local Omarchy checkout is 520c3ed969d30b58defe03eb19d603f32b4cb002. Its script freezes with hyprpicker, selects with slurp and pipes grim output to zbarimg with only QR recognition enabled. QR payloads may contain secrets, including 2FA setup URIs. Sensitive clipboard handling must be verified against MirrorOS's existing history implementation rather than assumed.
- **User Response**: Explicitly approved the proposed approach and requested direct registration in both artifacts.
- **Decision**: Reuse omarchy-capture-qr as closely as possible, adapting notification calls and paths to MirrorOS. Freeze with hyprpicker, select with slurp and pass the grim capture to zbar without saving the image. Enable QR recognition only. Copy the decoded result with wl-copy --sensitive; do not include its content in notifications or write it to the journal. Cancel silently, notify when no QR is found and preserve cleanup of the freeze process on exit. Verify that MirrorOS clipboard history respects the sensitive marker.
- **Status**: Accepted

## DEC-004
- **Question**: Should direct OCR use Omarchy's ordinary clipboard copy or mark its output sensitive like QR?
- **Context/Nuances**: Omarchy's omarchy-capture-text uses ordinary wl-copy, whereas omarchy-capture-qr uses wl-copy --sensitive because QR payloads routinely carry credentials. MirrorOS's existing clipboard-history command handles CLIPBOARD_STATE=sensitive by delegating to cliphist without spooling the payload; the end-to-end sensitive-copy path remains a QR verification requirement.
- **User Response**: Explicitly approved preserving ordinary OCR copy and requested direct registration in both artifacts.
- **Decision**: Preserve Omarchy's ordinary clipboard copy for direct OCR. Recognized text may enter the existing clipboard history. Keep the sensitive-copy policy specific to QR and document that direct OCR does not exclude sensitive text from history.
- **Status**: Accepted

## DEC-005
- **Question**: Where should the new commands and their implementations live?
- **Context/Nuances**: Plan 02-40 established a neutral desktop/screenshot command delegating to a compositor-owned backend. ADR 0011 requires Hyprland-specific integration to remain isolated beneath the compositor provider. Reusing scripts that invoke hyprpicker beneath that boundary avoids coupling the shell menu to Hyprland, at the cost of three small delegation entry points.
- **User Response**: Explicitly approved the proposed distribution and requested direct registration in both artifacts.
- **Decision**: Add separate neutral commands named color, ocr and qr under capabilities/desktop/screenshot. Place the Omarchy-derived implementations beneath capabilities/desktop/compositor/providers/hyprland. Menu actions and shortcuts call the neutral commands, which delegate to the provider. Do not change the existing screenshot command interface. Exact installed paths and backend contracts remain to be specified.
- **Status**: Accepted

## DEC-006
- **Question**: Should Color preserve Omarchy's process-wide toggle or introduce dedicated process tracking?
- **Context/Nuances**: Omarchy commit 7540bddee1503a79c213bb667cdf749bb55608cd (2025-08-04), titled "Toggle instead of stack hyprpicker", replaced hyprpicker -a with pkill hyprpicker || hyprpicker -a to cancel an existing picker instead of stacking another. OCR adopted hyprpicker freezing later, in May 2026; QR followed in August 2026. Because pkill targets hyprpicker processes without distinguishing their role, invoking Color during OCR/QR selection may terminate the freeze without explicitly cancelling slurp, and that invocation does not open Color when pkill succeeds. This is a code-derived risk, not a reproduced failure or an upstream-documented rationale for cross-tool cancellation. Dedicated Color process tracking would diverge from upstream and would not alone settle simultaneous-tool behavior.
- **User Response**: Explicitly approved preserving Omarchy's behavior with a laboratory cross-tool check and requested direct registration in both artifacts.
- **Decision**: Preserve Omarchy's Color toggle behavior, pkill hyprpicker || hyprpicker -a: select and automatically copy a color, or cancel an existing hyprpicker instead of opening another. Do not add preventive dedicated process management. Check Color invocation during OCR and QR selection in the laboratory; if the observed interaction is problematic, bring the evidence back for a decision before adapting it.
- **Status**: Accepted

## DEC-007
- **Question**: Should direct OCR models and defaults follow installation language, regional format or keyboard layouts?
- **Context/Nuances**: Installation separately records language, regional format and console keymap. Language and regional categories are written to /etc/locale.conf. The managed desktop declares both us and es layouts, with the configured initial layout first, so the presence of an ES layout alone is not a reliable OCR-language signal. Tesseract accepts multiple recognition languages in one invocation through -l eng+spa; installed models are not automatically selected. Upstream documentation warns that language order can affect output and recognition time: https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html. The Arch extra repository JSON endpoint https://archlinux.org/packages/extra/any/tesseract-data-spa/json/ reports tesseract-data-spa epoch 2, version 4.1.0-5, installed size 18,256,019 bytes; this is a repository observation, not a version pin or development-host package fact.
- **User Response**: Explicitly approved deriving the selection from installed language or regional format rather than keyboard layout, and requested direct registration in both artifacts.
- **Decision**: Always install and enable English for direct OCR. Add the Spanish model when either the selected system language or regional format is Spanish, and use eng+spa as the direct OCR default in that case; otherwise default to eng. Derive this during capability configuration from the installed locale configuration, without adding an installer question. Allow a subsequent explicit override through MIRROROS_OCR_LANGS. Do not derive OCR language from the active or available keyboard layouts. This decision governs the new direct OCR flow only and does not automatically change Omasnap's OCR language selection.
- **Status**: Accepted

## DEC-008
- **Question**: Should the Capture menu also expose direct OCR as Text, as Omarchy does?
- **Context/Nuances**: Omarchy exposes Text, QR Code and Color under Capture. A Text row makes direct OCR discoverable without requiring the shortcut. MirrorOS already has Screenshot and Screenshot with annotation; neither needs to change.
- **User Response**: Explicitly approved the three rows and requested direct registration in both artifacts.
- **Decision**: Keep Screenshot and Screenshot with annotation in Capture, and add Text for direct OCR, QR Code for the QR reader, and Color for the color picker. Text and Color invoke the same neutral commands as their shortcuts; QR Code remains menu-only.
- **Status**: Accepted

## DEC-009
- **Question**: What are the installed paths, exit statuses and diagnostic contract of the neutral commands?
- **Context/Nuances**: The existing screenshot command provides the fixed-path delegation and status convention. Unlike its backend diagnostic stream, third-party output in the new flows may contain recognized text or sensitive QR contents and must not be forwarded wholesale to the journal.
- **User Response**: Explicitly approved the proposed contract and requested direct registration in both artifacts.
- **Decision**: Install the no-argument neutral commands at /usr/share/mirroros/screenshot/{color,ocr,qr}, delegating to the corresponding provider executables at /usr/share/mirroros/compositor/{color,ocr,qr}-backend. Return 0 on completion or cancellation, 1 on failure and 2 on incorrect usage. A missing backend tells the user to rerun mirroros-configure. Journal only controlled MirrorOS diagnostics; never forward tool output automatically or include recognized text or QR payloads.
- **Status**: Accepted

## DEC-010
- **Question**: Should the direct OCR and QR implementations share a region capture helper?
- **Context/Nuances**: Omarchy maintains separate scripts that each freeze the screen, select a region and clean up their freeze process. The duplicated block is short. Preserving that structure makes each adaptation easier to compare with upstream and review during updates.
- **User Response**: Explicitly approved keeping the scripts separate and requested direct registration in both artifacts.
- **Decision**: Keep independent OCR and QR provider scripts in plan 02-41. Do not extract a shared region capture helper. Revisit extraction only if a concrete maintenance need arises.
- **Status**: Accepted

## DEC-011
- **Question**: Should verification follow the 02-40 reference VM campaign and human approval pattern?
- **Context/Nuances**: Plan 02-40 already validated the Omasnap core. A narrow regression check covers the two existing Capture actions without repeating its full campaign. The reference VM does not qualify additional hardware.
- **User Response**: Explicitly approved the proposed verification scope and requested direct registration in both artifacts.
- **Decision**: Run one reference VM campaign with deployment authorization requested at execution time and a blocking human approval before closure. Use synthetic data and run only affected checks. Cover the new shortcuts and Capture rows, English and Spanish direct OCR according to installed configuration, sensitive QR output that pastes but does not enter clipboard history, and Color invocation during OCR and QR selection. Smoke-test both existing Capture actions without repeating the full Omasnap campaign. Do not claim additional hardware qualification.
- **Status**: Accepted

## DEC-012
- **Question**: Should configure persist the direct OCR default rather than deriving it during every capture?
- **Context/Nuances**: Deriving the default at runtime could select spa immediately after a locale change, before the Spanish model is installed. Configure can deliver the model and its matching default together.
- **User Response**: Explicitly approved the configure-time default and requested direct registration in both artifacts.
- **Decision**: Have mirroros-configure read the installed /etc/locale.conf, install the required models and write the managed default (eng or eng+spa). Direct OCR uses that value unless MIRROROS_OCR_LANGS is explicitly set. Apply subsequent language or regional-format changes by rerunning configure, not by recalculating the default during capture. This refines DEC-007.
- **Status**: Accepted

## DEC-013
- **Question**: How will the candidate be deployed, accepted and closed?
- **Context/Nuances**: Plan 02-40 used a temporary candidate ref, synthetic evidence and human approval before delivery. Local workflow instructions in .agents/lab-access.md specify the reference VM SSH command and attended sudo in the current tmux session.
- **User Response**: Explicitly approved the proposed delivery flow, requested direct registration and asked to reference the connection and SSH/sudo procedure in .agents/lab-access.md.
- **Decision**: Deploy from a temporary candidate ref after authorization. Keep only synthetic evidence with checksums. After explicit laboratory approval, commit by concern, remove the candidate ref and write the execution summary. Keep .agents/ and evidence out of commits. Follow .agents/lab-access.md for the reference VM: ssh -i ~/.ssh/id_ed25519 viespejo@127.0.0.1 -p 2222. For operations requiring SSH and sudo, open a window in the current tmux session for the maintainer to enter the sudo password, monitor the operation and confirm that the window closes automatically when it finishes. Never record credentials.
- **Status**: Accepted

## DEC-014
- **Question**: How should conditional Spanish OCR model installation participate in configure package validation?
- **Context/Nuances**: Configure resolves and checks declared packages before running a capability and applies its partial-upgrade guard to missing packages. Adding Spanish to the fixed provider package list would install it unconditionally. Installing it separately in apply would bypass that preflight and guard.
- **User Response**: Explicitly approved the bounded configure change and requested direct registration in both artifacts.
- **Decision**: Preflight and the Hyprland apply step must consume the same effective package selection. Include tesseract-data-spa only when the installed system language or regional format is Spanish. Limit the change to this case; do not change existing package-list syntax or other capability behavior. Preserve package resolution and the partial-upgrade guard. This implements DEC-007 and DEC-012.
- **Status**: Accepted

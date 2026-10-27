# Installer symbol across boot and greeter — Consolidated interview plan

Date: 2026-10-27

## Agreed scope

Adopt the standalone symbol from `install/confirmation/symbol.txt` in the SDDM greeter, the installed-system Plymouth splash, and a new live Plymouth splash. Keep background `#101315` and foreground `#CACCCC`, without additional text. The greeter remains static; the later animation decision supersedes the original static-only constraint for both splashes. Preserve greeter behavior and Esc access to splash diagnostics. [DEC-005] The lock screen and unrelated presentation changes remain outside scope. [DEC-001]

Prepare the normative amendment required by the existing ADR boundaries. Planning does not authorize image builds, VM launches, or installations; runtime qualification must remain distinct from static verification and visual previews. [DEC-001]

## Confirmed implementation context

The current installed graphical asset derives from the historical `install/confirmation/banner.txt`, not the new standalone symbol. Installed SDDM and Plymouth consume the shared graphical asset. The live profile currently has no Plymouth integration. ADR 0018 explicitly leaves graphical surfaces unchanged, and ADR 0014 assigns existing theme integration to configure in installed contexts.

These are inspection findings, not approval of a particular implementation strategy.

## Symbol sizing

Center the symbol without deformation, preserving square visual proportions and the existing graphical bounds of at most 22% of display height and 42% of display width. Apply the same sizing criterion across the greeter and both splashes. Approximate illustrative sizes are 238x238 pixels at 1920x1080 and 176x176 at 1280x800; these examples are not rendered-preview or runtime qualification evidence. [DEC-002]

## Unresolved details

Resolve shared-source and generated-asset delivery, and live boot integration with diagnostic recovery and validation. Investigate code-answerable questions directly; ask only about consequential alternatives. No implementation detail in this section is approved yet.

Animation exploration was resolved by DEC-005 below. Shared-source delivery and real Plymouth lifecycle behavior still require implementation inspection and validation; browser preview approval does not establish these outcomes.

## Final plan state

The maintainer explicitly approved the complete draft for materialization with "yes". The plan is saved at `.agents/plans/02-22-shared-symbol-and-live-splash.md`, with phase metadata `02-new-phase`, plan metadata `22`, date `2026-10-27`, status `pending`, and no dependencies. Materialization is complete; implementation has not started. Builds, VM launches, and installations still require separate authorization.

## Synthetic animation comparison

Before deciding whether to adopt splash animation, compare the static symbol with a single soft fade-in of approximately 400 ms over the same dark background. The candidate has no movement, pulse, or repetition and must not delay boot completion or Esc access to diagnostics. Fast boots may make a fade look like a flash; evaluate that trade-off explicitly. This is synthetic presentation review, not a change to real boot or evidence of Plymouth behavior. Animation adoption remains pending, and the accepted static-only product scope is not superseded. [DEC-003]

Extend the temporary synthetic comparison with a single 400 ms fade-in followed by an ongoing two-second opacity pulse between 75% and 100%. Keep static and single-fade alternatives available, and stop the preview effect with Static or Esc. This initially added an evaluation candidate only; DEC-005 below subsequently approves adoption. [DEC-004]

## Adopted splash animation

Both the installed-system and live splashes will use a single 400 ms fade-in followed by a smooth two-second opacity pulse between 75% and 100%. The greeter remains static. Never delay boot completion or Esc access to diagnostics for an animation cycle. Amend the normative boundaries before product integration. Only DEC-001's splash-animation prohibition is superseded; its remaining scope and safety boundaries are retained. [DEC-005]

The maintainer approved the temporary browser preview, not real Plymouth execution, boot lifecycle behavior, a rebuilt ISO, or physical hardware. Qualify those separately and do not silently substitute a different effect if the Plymouth implementation cannot reproduce the approved behavior. [DEC-005]

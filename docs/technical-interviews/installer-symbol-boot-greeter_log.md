# Installer symbol across boot and greeter — Decision log

Date: 2026-10-27

Persistence was explicitly requested by the maintainer. Ask only consequential unresolved design questions; investigate code-answerable questions without expanding the interview unnecessarily. The final implementation plan has not been approved or materialized.

## DEC-001
- **Question**: Which presentation surfaces should adopt the new installer symbol, and what stays outside scope?
- **Context/Nuances**: The installer uses `install/confirmation/symbol.txt`; the existing graphical wordmark instead derives from the historical banner. Installed Plymouth and SDDM share the graphical wordmark. The live currently has no Plymouth integration. Accepted ADRs require a normative amendment for this extension. Visual consistency does not require changing authentication or installer behavior.
- **User Response**: "si", with a request to keep the interview focused on consequential alternatives; persistence explicitly requested.
- **Decision**: Adopt the installer symbol in the greeter, installed-system splash, and a new live splash. Preserve background `#101315`, foreground `#CACCCC`, a static symbol without additional text, greeter behavior, and Esc access to splash diagnostics. Exclude the lock screen and unrelated redesigns. Prepare the required normative amendment. The plan does not authorize builds, VM launches, or installations.
- **Status**: Accepted

## Open implementation questions

- Symbol proportions and size across graphical surfaces.
- Shared graphical source and generated-asset delivery.
- Live boot integration, diagnostic recovery, and validation.

These questions are not accepted decisions. Resolve code-answerable details by inspection and ask the maintainer only where consequential alternatives remain.

## DEC-002
- **Question**: What size and proportions should the symbol use on the three graphical surfaces?
- **Context/Nuances**: Preserve the current graphical bounds rather than copying console pixel dimensions: at most 22% of display height and 42% of display width, with square visual proportions preserved. The maintainer reviewed illustrative sizes of approximately 238x238 at 1920x1080 and 176x176 at 1280x800. The chat diagram was illustrative, not a scale preview or runtime qualification.
- **User Response**: "si", confirming the size example before asking about animation.
- **Decision**: Keep the current graphical size bounds, center the symbol without deformation, and use the same sizing criterion across the greeter and both splashes.
- **Status**: Accepted

## Animation exploration — not a decision

The maintainer requested evaluation of a single soft fade-in for the splashes. Duration, preview method, adoption, and any amendment to DEC-001's static-only scope remain unapproved. The greeter remains static under the accepted scope. Do not treat exploration as authorization to implement animation.

## DEC-003
- **Question**: Should a synthetic comparison precede any decision to adopt splash animation?
- **Context/Nuances**: Compare the accepted static symbol with a single soft fade-in lasting approximately 400 ms, over the same dark background, with no movement, pulse, or repetition. The candidate must not delay boot completion or Esc access to diagnostics. A fast boot may make a fade appear as a flash. A synthetic preview cannot establish Plymouth behavior or qualify a rebuilt ISO.
- **User Response**: "si", approving the proposed synthetic comparison as the next step.
- **Decision**: Include a synthetic static-versus-fade comparison before deciding whether to adopt animation. Do not change real boot behavior or treat preview approval as animation adoption. The accepted product scope remains static unless explicitly superseded after review.
- **Status**: Accepted

## DEC-004
- **Question**: Should the synthetic preview include an ongoing animation candidate?
- **Context/Nuances**: Repeating a fade from transparent could look like blinking. The proposed alternative is a single 400 ms fade-in followed by a gentle opacity pulse between 75% and 100%, with a two-second cycle. Real boot completion must never wait for animation. The browser preview can stop the effect through Static or Esc; this does not establish real boot integration.
- **User Response**: "ok", approving addition of the candidate to the preview, not adoption in the real splash.
- **Decision**: Add a fade-plus-pulse variant alongside static and single-fade variants in the temporary synthetic preview. Product animation remains unapproved and DEC-001's static-only scope remains in force pending visual review and explicit adoption.
- **Status**: Accepted

## DEC-005
- **Question**: Should both splashes adopt the reviewed fade-plus-pulse animation while the greeter remains static?
- **Context/Nuances**: The maintainer liked the temporary browser preview and explicitly confirmed adoption after the scope was restated. The candidate uses a 400 ms fade-in followed by a two-second opacity pulse between 75% and 100%. Browser approval does not establish Plymouth timing, boot lifecycle, diagnostic behavior, rebuilt-artifact qualification, or physical-hardware support. Existing ADR boundaries must be amended before product integration.
- **User Response**: "yes", explicitly confirming adoption on both splashes with a static greeter.
- **Decision**: Adopt the reviewed fade-plus-pulse presentation on the installed-system and live splashes. Keep the greeter static. Animation must never delay boot completion or Esc access to diagnostics. Supersede only DEC-001's prohibition on splash animation; preserve its other scope and safety boundaries. Prepare the corresponding normative amendment and require real Plymouth validation separately from the synthetic approval.
- **Status**: Accepted

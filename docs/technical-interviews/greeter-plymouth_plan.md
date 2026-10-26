# Greeter and Plymouth — Consolidated Interview Plan

## Agreed intent

The greeter should follow the style and simplicity of the existing hyprlock screen. The requested scope also includes Plymouth showing MirrorOS branding. The maintainer wants a quick, bounded change and requested studying Omarchy before selecting the implementation. Interview persistence is active; these artifacts are not approval to implement or materialize the final plan. [DEC-001]

## Existing implementation and upstream reference

MirrorOS uses SDDM for login and independent hyprlock for locking. The current lock screen has a solid dark background, a large clock, a rectangular password field and a keyboard-layout indicator. Omarchy revision `1801adc1983b06f6ab218f8060e430cb3477d8d0` uses a small SDDM QML theme with a centered logo and password field, last-user selection and uwsm session preference. Its Plymouth theme includes a centered logo, a password dialogue and mixed simulated/real progress. These findings inform the comparison but do not select MirrorOS behavior. [DEC-001]

Omarchy sources inspected:
- https://github.com/omacom/omarchy/blob/1801adc1983b06f6ab218f8060e430cb3477d8d0/default/sddm/omarchy/Main.qml
- https://github.com/omacom/omarchy/blob/1801adc1983b06f6ab218f8060e430cb3477d8d0/install/login/sddm.sh
- https://github.com/omacom/omarchy/blob/1801adc1983b06f6ab218f8060e430cb3477d8d0/install/login/plymouth.sh
- https://github.com/omacom/omarchy/blob/1801adc1983b06f6ab218f8060e430cb3477d8d0/default/plymouth/omarchy.script

## Greeter implementation

MirrorOS will retain SDDM and deliver a minimal owned theme following Omarchy's implementation approach while matching the existing hyprlock appearance. Existing authentication remains unchanged: no autologin or PAM modifications are included. This avoids replacing the login provider and keeps the runtime change limited to presentation. [DEC-002]

Before adopting the theme, a narrowly scoped ADR and corresponding architecture update must authorize QML for SDDM themes. This exception must not introduce a general QML application framework or custom authentication. DEC-002 resolves the provider/theme choice originally tracked by TODO-001; DEC-003 and DEC-004 define the agreed visual content and account interaction below. [DEC-002, DEC-003, DEC-004]

## Plymouth scope resolution

The initial Plymouth questions tracked by TODO-002 are resolved by the decisions below: reuse the installer wordmark, show a static logo on dark background, cover both supported bootloaders in the installed system, preserve diagnostic access, and use configure as the integration owner with VM-only validation. Simulated progress is excluded. Upstream installation behavior must not be adopted implicitly. [DEC-003, DEC-005, DEC-006, DEC-007, DEC-008, DEC-010, DEC-012, DEC-014]

## Final plan routing

The supplied default numbering is `02-20`, with phase metadata `02-new-phase` and plan metadata `20`; this is a numbering suggestion, not an additional technical decision. Selected dependencies remain exactly `02-18-desktop-shell-guest-prototype` and `02-19-desktop-shell-production` unless explicitly changed by the maintainer. The final draft must be reviewed in chat and separately approved before materialization under `.agents/plans/`.

## Agreed visual direction

The greeter will replace the clock with a centered graphical adaptation of the existing block-letter MIRROROS installer wordmark from `install/confirmation/banner.txt`. Preserve its silhouette rather than redesigning the brand; sizing and spacing may be adjusted for graphical presentation. The resource will be monochrome and scalable, using the existing hyprlock clock's off-white color, without shadows or animation. It will be reusable by the greeter and Plymouth to provide visual continuity rather than relying on terminal glyph rendering. Exact asset format and delivery remain open. [DEC-003]

The greeter will retain the solid dark background, password field and keyboard-layout indicator inspired by the current lock screen. The existing hyprlock configuration will not be modified. This resolves the visual-content choice; the account interaction and Plymouth integration are defined by the subsequent decisions below. [DEC-003, DEC-004, DEC-012]

## Greeter account interaction

The greeter will display the selected user and offer a discreet control to change users. This avoids ambiguity about which account the password field authenticates, including on first login, while preserving the minimal presentation. The existing configured Hyprland/uwsm session remains the session choice; no new session provider is introduced. Exact control styling and first-login selection behavior remain to be specified or established through inspection of native SDDM behavior. [DEC-004]

## Plymouth normal appearance

Plymouth's normal splash will show only the centered MirrorOS logo on the same dark background as the greeter, using the branding direction agreed in DEC-003. It will have no progress bar, animation or artificial delay. In particular, Omarchy's simulated-progress mechanism will not be adopted. Diagnostic behavior and boot-path coverage are specified separately below. [DEC-003, DEC-005, DEC-007, DEC-008, DEC-010]

## Installed-system scope

The greeter changes and Plymouth branding apply only to the installed system. The live installation/rescue ISO boot visuals and installer presentation remain unchanged; using the installer wordmark as the branding reference does not change that presentation. Installation delivery may still require source or packaging changes to produce the agreed installed-system result. [DEC-006]

## Supported boot paths

Plymouth delivery will cover both Limine and systemd-boot across the supported installed-system storage options, so the agreed branding does not depend on the installation's bootloader choice. Preserve the selected bootloader and existing hibernation configuration. Exact native hook ordering, kernel parameters, regeneration ownership and validation details remain to be established through code and upstream inspection. [DEC-007]

## Boot diagnostics

The splash must preserve access to boot messages through Esc, and validation must exercise that behavior rather than assume it. Document how to boot without the splash as a diagnostic alternative. Branding must not conceal boot failures, suppress upstream failure semantics or replace useful diagnostics. [DEC-008]

## New and existing installations

Deliver the greeter and Plymouth change on new installations and through `mirroros-configure` on existing installations. Boot convergence must be restricted to recognized MirrorOS configurations; incompatible local changes are preserved and cause an actionable stop rather than being overwritten. Configure must not restart SDDM or reboot the machine. The new boot presentation takes effect on the next boot. Native regeneration and authoritative ownership must be established without duplicating installation policy or hiding configuration drift. [DEC-009]

## Agreed validation boundary

Validate this greeter/Plymouth slice in VMs across all three supported installation storage schemes, an existing-installation update, an unchanged second configure run and real graphical login. Preserve hibernation parameters without claiming hardware hibernation readiness. Do not touch the laptop within this validation scope. [DEC-007, DEC-009, DEC-010]

## Additional target request context

The maintainer proposed adding a ThinkPad T14s G1 with Ryzen 7 Pro, 16 GB RAM and 256 GB storage, expecting a small change. DEC-011 routes this request separately, resolving TODO-003's scope question. Hardware identity and qualification remain unverified; no hardware operation is authorized by the request alone. [DEC-011]

## Additional target routed separately

The ThinkPad T14s G1 request is routed to a separate plan, not added to this greeter/Plymouth slice. Admission and actual hardware capture come first, with an ADR reviewing the current one-physical-target support boundary; qualification follows separately. Existing AMD rules and dynamic target discovery may reduce implementation work, but do not establish compatibility or justify invented DMI values. No ThinkPad source changes or physical operations are included here. This resolves TODO-003's scope-routing question without creating or approving the separate plan. [DEC-010, DEC-011]

## Plymouth ownership and base-installation boundary

Configure is the sole owner of Plymouth theme delivery and boot integration in both target and running contexts. New installations use the engine's existing post-base-verification configure invocation, rather than a second integration implementation in the installation engine. Detect the supported bootloader, preserve storage and hibernation parameters, and regenerate the required boot artifacts when necessary. Do not rewrite the approved installation plan. [DEC-009, DEC-012]

Contracts and tests must distinguish the verified base boot configuration from the visual overlay subsequently applied by configure. This must be explicit and must preserve safety-relevant checks rather than treating arbitrary command-line differences as acceptable. Recognized-configuration checks and actionable conflict handling remain required for existing installations. [DEC-009, DEC-012]

## Independent implementation and provenance

The SDDM and Plymouth themes will be independently written, using Omarchy only as an idea and implementation-pattern reference. Do not copy its theme code or graphical resources. Document the inspected upstream revision and the MirrorOS-owned installer wordmark origin. This avoids importing progress, password-dialogue and asset complexity that the agreed scope does not need. [DEC-013]

## Normal boot parameters

The configure-owned visual overlay will add `quiet splash` for the normal branded boot, retaining logs and the tested Esc path to boot messages. Do not add `loglevel=0`, disable logs or introduce error-hiding scripts. Preserve all storage and hibernation parameters and document a no-splash diagnostic boot path. [DEC-008, DEC-012, DEC-014]

## Approved final draft and materialization

The maintainer approved the complete final draft through the explicit yes/no gate. It is materialized at `.agents/plans/02-20-greeter-plymouth.md` with phase `02-new-phase`, plan `20`, date `2026-10-25`, status `pending`, and exactly the selected prototype and production-shell dependencies. The plan contains three tasks: shared branding and the SDDM theme; safe Plymouth convergence with contracts and tests; and final-candidate VM/attended qualification. Approval materializes the plan but does not execute it or authorize disruptive VM or physical operations. [DEC-015]

The approved technical details use a font-independent SVG adaptation of the installer wordmark as the authoritative graphical source, with a derived PNG generated during configure using official librsvg. A dedicated branding capability publishes both for the native themes without committing generated raster output. The SDDM theme uses native models, selects a still-present last user or the first available user, disables submission when accounts or a compatible session are unavailable, and clears passwords after account changes or failure. The bounded ADR addresses SDDM QML and Plymouth-native theme scripting without authorizing custom authentication. [DEC-015]

Plymouth convergence preserves the original hook order and storage/resume parameters, adds only the quiet/splash overlay, and uses the supported installed regeneration interface for each bootloader. Delivery records must not conceal incomplete regeneration: pending work remains retryable until actual boot artifacts pass inspection. Existing installed configure snapshots do not update themselves; the procedure must explain use of updated source or an explicitly updated snapshot. Esc and no-splash recovery must account for the existing disabled bootloader editor policy without permanently weakening it. The materialized plan carries the full acceptance criteria, implementation detail, verification matrix and exclusions. [DEC-008, DEC-009, DEC-012, DEC-014, DEC-015]

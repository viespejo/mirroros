# Story 4.4 Shell Panels Planning — Decision Log

Continues the Story 4.4 interview ([log](story-4-4-hardware-connectivity_log.md),
[plan](story-4-4-hardware-connectivity_plan.md)) after plan 02-25 shipped. IDs continue from DEC-018 and TODO-005.

## DEC-019
- **Question**: Is the work deferred from plan 02-25 delivered by a single plan 02-26, or split further?
- **Context/Nuances**: DEC-003 assigned to one plan 02-26 the ADR amending ADR 0012, the audio (including output/source switching), network/Wi-Fi, Bluetooth (including PIN/passkey pairing, TODO-002), display and power panels, the shell media service decision (DEC-008) and graphical VPN access (DEC-007, plan 02-25 SUMMARY). The plan 02-18 panel study counts about 6,000 upstream lines for these five panels alone, plus helpers to replace, against a current shell of about 17,400 lines. Wi-Fi enterprise secrets, the BlueZ pairing agent and OpenConnect authentication are credential boundaries that need their own review and supervised T14s scripts. Plan 02-25 already grew mid-execution (DNS, ADR 0024).
- **User Response**: Approved splitting, and asked whether to split even further, possibly per panel, after researching each Omarchy panel and comparing alternatives.
- **Decision**: The deferred work becomes a sequence of plans instead of one: plan 02-26 (research, prototype and ADR, DEC-020) followed by production plans 02-27 onward. The deferred items in scope are the ADR amending ADR 0012; the audio, network/Wi-Fi, Bluetooth, display and power panels; the shell media service decision; PIN/passkey pairing; and graphical VPN access through an owned wrapper. The number of production plans and the grouping of panels are not fixed here (TODO-006); the initial hypothesis is "shared infrastructure plus local panels" followed by "connectivity with credential boundaries". This supersedes DEC-003's single-plan assignment of the panels; the 02-25 hardware core is unchanged.
- **Status**: Accepted

## DEC-020
- **Question**: What does plan 02-26 deliver?
- **Context/Nuances**: The existing panel study (plan 02-18, brief 2) is source-only, pinned to Omarchy revision `7075b61`, and compares no alternatives; Quattro 4.0.6 already ships additional panels. The admissible surface, privilege and credential boundaries, persistence and NFR38 format, and per-panel maintenance cost are open and are the evidence an ADR needs. AGENTS.md forbids resolving prototype-gated decisions prematurely. DEC-001/DEC-002 already place panel iteration in the laboratory guest (agent optional, Story 4.3 protocol) and real hardware on the T14s (no agent, supervised over SSH); the laboratory lacks Wi-Fi, Bluetooth, battery and backlight. Per-panel plans would duplicate shared work (container, controller, bindings, ADR) and their sizes are unknown.
- **User Response**: Approved; asked for more detail before registration and confirmed the detailed version.
- **Decision**: Plan 02-26 is a research, prototype and ADR plan with no production panels, following the Story 4.3 prototype-then-production pattern, in six stages: (1) host read-only inventory of the reference Omarchy panels (functions, files and lines, helpers to replace, dependencies, persistent writes, privileges and credentials, VM versus laptop testability), updating brief 2; (2) per-panel comparison with alternatives (other Quickshell shells, well-known Omarchy community plugins, dedicated external tools) on the same criteria plus license and extra functionality, producing a comparison matrix; (3) a laboratory-guest prototype of the shared panel container (bar anchoring, keyboard, focus and close) and one or two panels; (4) supervised T14s hardware evidence for what the laboratory cannot exercise; (5) a maintainer gate approving the panel set, per-panel functions, per-panel source (adapt Omarchy, another source or an external tool) and the production plan split; (6) the ADR amending ADR 0012 drafted from that evidence, covering the admitted surface, the shell media service and graphical VPN access. Plan 02-26 does not change `configure`, deliver bindings or ship panels.
- **Status**: Accepted

## TODO-006
- **Question**: How are the production plans (02-27 onward) split and which panels are grouped together?
- **Context/Nuances**: Initial hypothesis: shared infrastructure plus local panels (audio, display, power), then connectivity (network/Wi-Fi, Bluetooth, VPN), possibly separating VPN or Bluetooth if research justifies it.
- **Status**: Pending (plan 02-26 gate)

## DEC-021
- **Question**: Which Omarchy version is the reference for plan 02-26?
- **Context/Nuances**: Existing adapted code is pinned to Omarchy 4.0.6 (shell `Ui/*` and `bar/*` from package `4.0.6-1`, plan 02-25 bindings and helpers, their `UPSTREAM.md` records); the brief 2 panel study used the older revision `7075b61`. Omarchy 4.5 is available and its content has not been checked yet. The study must be redone anyway.
- **User Response**: Approved; downloaded `~/Downloads/omarchy-4.5.0-x86.iso`.
- **Decision**: Plan 02-26 uses Omarchy 4.5 as the primary reference for the inventory, comparison and prototype. The ISO is verified against an official published checksum or signature and inspected read-only outside the repository, as 4.0.6 was. Differences from 4.0.6 to 4.5 in files MirrorOS already copied or adapted (`Ui/Panel*`, `KeyboardPanel`, bar models, `media.lua`) are recorded as evidence; existing code is not updated automatically, and any update is a separate decision recorded in `UPSTREAM.md`. Provenance is per file: fragments adapted from 4.5 cite 4.5, existing ones keep citing 4.0.6 until explicitly updated. The decision reopens if the ISO cannot be verified or 4.5 changes the panels enough to alter the DEC-020 approach.
- **Status**: Accepted

## TODO-007
- **Question**: Is the Omarchy 4.5 ISO authentic?
- **Context/Nuances**: Downloaded to `~/Downloads/omarchy-4.5.0-x86.iso`; verification against an official checksum or signature is an execution prerequisite of plan 02-26 stage 1, not a planning blocker.
- **Status**: Pending (plan 02-26 stage 1)

## DEC-022
- **Question**: How are the alternatives compared in plan 02-26 stage 2 selected?
- **Context/Nuances**: The candidate space (Quickshell shells, Omarchy community plugins, dedicated tools) is large and could grow without bound. Names such as Caelestia, Noctalia, DankMaterialShell or illogical-impulse are unverified candidates. MirrorOS original material is `GPL-3.0-only` and incorporated material keeps its own license (`docs/attribution.md`).
- **User Response**: Approved and asked to record it directly.
- **Decision**: Stage 2 runs in two steps with a mini-gate. First, discovery through web search during execution proposes at most three candidates per category: (a) other Quickshell shells, (b) well-known Omarchy community plugins, (c) dedicated external tools (for example NetworkManager, BlueZ or PipeWire applets and applications). Entry filters: license compatible with `GPL-3.0-only` for code reuse (incompatible licenses are admitted only as design references), active maintenance (recent activity and releases), visible adoption, and for (a) and (b) technical compatibility with the MirrorOS Quickshell and Hyprland. The maintainer approves the shortlist before the deep comparison. The deep comparison is per panel with the DEC-020 criteria and produces a matrix with Omarchy 4.5 as the reference column. Third-party code is never installed or run on the host; it is read as source and, if seeing it run is needed, run only in the laboratory guest on a recoverable snapshot.
- **Status**: Accepted

## DEC-023
- **Question**: Which panels are prototyped in plan 02-26 stage 3?
- **Context/Nuances**: All five panels go through stages 1 (inventory), 2 (comparison) and 5 (gate), and all are covered by the ADR and built in production plans 02-27 onward; only the prototype is selective. Its purpose is to validate the shared container once, measure real cost on at least one panel and test the credential boundary, not to build each panel. Laboratory testability: audio good with a QEMU-emulated audio device; display partial (one virtual output, no backlight); power poor (no battery); network/Wi-Fi wired and states only; Bluetooth none without USB passthrough. Network/Wi-Fi is the largest upstream panel (about 2,150 lines) and carries the most sensitive credential boundary.
- **User Response**: Asked for clarification (whether non-prototyped panels move to another stage), then approved and asked to record it directly.
- **Decision**: Stage 3 prototypes the shared panel container plus the audio panel (including output/source switching) in the laboratory guest with an emulated audio device, and the network/Wi-Fi panel: wired and state behaviour in the laboratory, Wi-Fi with PSK on the T14s through a supervised script. On the T14s the prototype runs as a separate Quickshell instance delivered by checksummed bundle, never replacing the production shell or touching `configure`, and is removed afterwards. Bluetooth, display and power are not prototyped; they are designed from stage 1 and 2 evidence. As the single exception, stage 4 measures on the T14s, supervised and without UI, how a BlueZ agent handles PIN/passkey pairing, to resolve TODO-002 with evidence. If the gate finds a non-prototyped panel risky, its production plan may start with its own spike.
- **Status**: Accepted

## DEC-024
- **Question**: Where do the plan 02-26 outputs live?
- **Context/Nuances**: Story 4.3 (plan 02-18) kept prototype source on a guest branch never integrated into the active host branch, handed it off as a verified bundle into ignored `evidence/`, and recorded conclusions in the committed `docs/procedures/desktop-shell-prototype.md`. `prototypes/` holds self-contained experiments with a track register, and production must never import from it; a panel prototype needs the shell's `Commons/` and `Ui/`.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Following the Story 4.3 pattern: prototype source (container, audio, network) lives on a `story-4-4-panels-prototype` branch in the laboratory guest checkout, on the real `capabilities/desktop/shell/` tree, and never enters the active host branch. The handoff is a checksummed, verified bundle in ignored `evidence/shell-panels-prototype/handoff-<sha>/` with an isolated host review repository. The Omarchy 4.5 inventory, comparison matrix, prototype and T14s findings and the gate outcome are recorded in a new committed `docs/procedures/shell-panels-prototype.md`, which the ADR cites. Raw evidence (logs, captures, T14s and Bluetooth agent measurements) stays in ignored `evidence/shell-panels/`; only a redacted summary (no SSIDs, MAC addresses or device names) enters the procedure. Omarchy ISO extractions stay outside the repository (for example `/tmp/omarchy-45`). The ADR amending ADR 0012 is a new file under `docs/adr/`. After the gate, prototype code is not promoted as-is; production plans reimplement or adapt it under their own review. A committed `prototypes/shell-panels/` track was rejected because it would duplicate or import `Commons/` and `Ui/`.
- **Status**: Accepted

## DEC-025
- **Question**: In which status does the ADR end plan 02-26, and which documents change with it?
- **Context/Nuances**: ADR 0020 is the precedent for amending ADR 0012 for a bounded capability: ADR 0012's "Superseded by" section links it as a partial amendment and the rest of the decision is unchanged. `docs/architecture.md` bounds QML to ADR 0012 and its amendments (language table and Language Selection item). `docs/mvp-scope.md` bounds the desktop shell row to its five surfaces, so adding panels is a scope change. ADR 0024 was accepted within plan 02-25 after its prototype.
- **User Response**: Approved and asked to record it directly.
- **Decision**: The ADR ends plan 02-26 as Accepted, after the gate and a dedicated maintainer review of its text, together with the documents it governs: (1) a new `docs/adr/NNNN-…` amending ADR 0012 on the ADR 0020 model, stating the admitted surface (bar-anchored panel popouts with the approved panel list), the remaining exclusions (general control panel, background management services, authenticating QML), credential and privilege boundaries, the shell media service, graphical VPN access, and that the power watcher stays outside the shell (DEC-015); its Required validation defers per-panel real-hardware validation to production plans, with the Framework still pending; (2) ADR 0012 gains a forward link in "Superseded by" without rewriting its decision; (3) `docs/architecture.md` QML entries cite the new ADR; (4) `docs/mvp-scope.md` records a scope change to the desktop shell row citing Story 4.4 and Story 4.3 DEC-016, in a separate commit; (5) `docs/adr/README.md` lists the new ADR if that is the index convention. Leaving the ADR Proposed until the first production plan was rejected because it would delay the boundary and load that plan with governance.
- **Status**: Accepted

## DEC-026
- **Question**: What happens to the calendar panel and the extra Omarchy panels?
- **Context/Nuances**: Story 4.3 DEC-016 recorded the maintainer's intent for six panels including the calendar; Story 4.4 DEC-003 inherited only the five hardware panels. The current `Clock.qml` records calendar and timezone as integration points. Quattro ships extra panels (`wifiqr`, `speedtest`, `tailscale`, `weather`, `dropbox`, among others) and 4.5 may add more; brief 2 noted that `wifiqr` exposes credentials and `speedtest` initiates network traffic. Adding any of them is a `docs/mvp-scope.md` scope change.
- **User Response**: Approved and asked to record it directly.
- **Decision**: The calendar panel is outside plan 02-26 and Story 4.4 because it is neither hardware nor connectivity; finding its owner is TODO-008, and that plan will build on the container validated by plan 02-26. Extra Omarchy panels enter stage 1 as inventory only; they are not compared, prototyped or covered by the ADR unless the maintainer approves them at the gate, which would be a scope change. Exception: anything in Omarchy 4.5 relevant to VPN (for example `tailscale`) is studied as a design reference for graphical VPN access, which is in scope (DEC-019).
- **Status**: Accepted

## TODO-008
- **Question**: Which story and plan own the calendar/timezone panel?
- **Context/Nuances**: Candidate owner Story 4.8 or another story, through its own `docs/mvp-scope.md` scope change; it reuses the plan 02-26 container. Timezone changes need an approved privilege boundary, never project-owned authentication QML (brief 2).
- **Status**: Pending (outside plan 02-26)

## DEC-027
- **Question**: How is the laboratory's missing hardware covered in plan 02-26?
- **Context/Nuances**: The laboratory launcher (`~/qemu/mirroros-lab/vm`, local tooling outside the repository) defines only a VirtIO GPU, `qemu-xhci` with `usb-tablet`, disk, network and SPICE; there is no audio device. The host's internal Bluetooth is a USB device (`13d3:3567`, MediaTek); passing it through would remove Bluetooth from the host during tests. Display and power are not prototyped (DEC-023).
- **User Response**: Approved and asked to record it directly.
- **Decision**: (1) Add an optional emulated audio flag (for example `--audio`) to the laboratory launcher with an emulated HDA controller (`ich9-intel-hda` plus `hda-duplex`) backed by host audio through SPICE or PipeWire, after a laboratory checkpoint; a second virtual PipeWire sink inside the guest (for example a null sink marked virtual, never `auto_null`) provides a second output for switching. The launcher change stays outside the repository and is documented in evidence and the procedure. (2) No Bluetooth or Wi-Fi passthrough; Wi-Fi and the Bluetooth agent are exercised only on the T14s (DEC-023). (3) Battery, backlight and multiple monitors are not emulated; display and power rely on the study and plan 02-25 T14s evidence. (4) The prototype is also run without the audio flag to confirm absent hardware is shown as unavailable, never failing or fabricating values. Virtual sinks alone were rejected because they do not exercise an ALSA device with ports or headphone detection.
- **Status**: Accepted

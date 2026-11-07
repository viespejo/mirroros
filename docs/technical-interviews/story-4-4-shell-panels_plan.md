# Story 4.4 Shell Panels Planning — Consolidated Plan

This interview continues Story 4.4 after plan 02-25 shipped the hardware core
([previous plan](story-4-4-hardware-connectivity_plan.md)). Decision IDs continue from DEC-018.

## Plan sequence

The work deferred from plan 02-25 is too large and too varied in risk for a single plan: the ADR amending ADR 0012, the audio panel with output and source switching, the network/Wi-Fi panel, the Bluetooth panel with PIN/passkey pairing (TODO-002), the display panel, the power panel, the shell media service decision and graphical VPN access through an owned wrapper. The five panels alone account for about 6,000 upstream lines before helpers, and Wi-Fi enterprise secrets, the BlueZ pairing agent and OpenConnect authentication are credential boundaries that deserve their own review. The deferred work therefore becomes a sequence: plan 02-26 researches, prototypes and drafts the ADR, and production plans from 02-27 onward deliver the panels. This replaces DEC-003's single-plan assignment of the panels; the 02-25 hardware core is unchanged. [DEC-019]

How many production plans there are and which panels travel together is decided at the plan 02-26 gate, not now. The working hypothesis is shared infrastructure plus the local panels (audio, display, power) first, then connectivity (network/Wi-Fi, Bluetooth, VPN), with VPN or Bluetooth possibly separated if the research justifies it. [DEC-019, TODO-006]

## Plan 02-26: research, prototype and ADR

Plan 02-26 ships no production panel, changes no `configure` step and delivers no binding. It follows the Story 4.3 pattern of prototype before production, because the admissible surface, privilege and credential boundaries, persistence and format (NFR38) and per-panel maintenance cost are prototype-gated questions that an ADR must answer with evidence. [DEC-020]

The plan starts with a read-only host inventory of the reference Omarchy panels that refreshes the plan 02-18 brief 2 study, which is source-only, pinned to an older revision and silent on alternatives. For each panel it records functions, files and line counts, helpers to replace, dependencies, persistent writes, privileges and credentials, and whether the laboratory VM can exercise it or the laptop is required. A per-panel comparison then measures the alternatives — other Quickshell shells, well-known Omarchy community plugins and dedicated external tools — on the same criteria plus license and extra functionality, producing a comparison matrix. [DEC-020]

The shared panel container (bar anchoring, keyboard, focus and close) and one or two panels are prototyped in the laboratory guest, where an agent may run under the Story 4.3 protocol. Because the laboratory has no Wi-Fi, Bluetooth, battery or backlight, behaviour that needs real hardware is measured on the T14s through supervised scripts driven from the host, with no agent installed there. [DEC-020, DEC-001, DEC-002]

A maintainer gate closes the research: it approves which panels enter, the functions of each, where each comes from (adapting Omarchy, another source or an external tool) and the split of the production plans. The ADR amending ADR 0012 is then drafted from that evidence and covers the admitted surface, the shell media service and graphical VPN access. [DEC-020, TODO-006]

## Omarchy reference version

Plan 02-26 studies Omarchy 4.5, downloaded by the maintainer to `~/Downloads/omarchy-4.5.0-x86.iso`, verified against an official checksum or signature before stage 1 and inspected read-only outside the repository. Designing new panels against a superseded version makes no sense when the study must be redone anyway. Existing MirrorOS code remains pinned to 4.0.6: the study records the 4.0.6 to 4.5 differences in already copied or adapted files (`Ui/Panel*`, `KeyboardPanel`, bar models, `media.lua`) as evidence, but nothing is updated automatically. Provenance is per file, so 4.5-adapted fragments and existing 4.0.6 fragments may coexist, each cited in its `UPSTREAM.md`. An unverifiable ISO, or panel changes large enough to alter the plan 02-26 approach, reopen this choice. [DEC-021, TODO-007]

## Alternative selection

The comparison of alternatives is bounded by a shortlist gate so it cannot grow without limit. During execution, web discovery proposes at most three candidates in each category — other Quickshell shells, well-known Omarchy community plugins and dedicated external tools such as NetworkManager, BlueZ or PipeWire applets — filtered by license, active maintenance, visible adoption and, for shells and plugins, technical compatibility with the MirrorOS Quickshell and Hyprland. Because MirrorOS is `GPL-3.0-only`, only compatibly licensed candidates may become code sources; the rest serve as design references. The maintainer approves the shortlist before any deep comparison, which then runs panel by panel on the DEC-020 criteria and yields a matrix with Omarchy 4.5 as the reference column. Third-party code is read as source and never installed or run on the host; when it must be seen running, it runs only in the laboratory guest on a recoverable snapshot. [DEC-022, DEC-020, DEC-021]

## Prototype scope

All five panels pass through the inventory, the comparison and the gate, are covered by the ADR and are built in production plans; only the prototype is selective, because its job is to validate the shared container once, measure real cost and probe the credential boundary rather than to build every panel. Stage 3 therefore prototypes the shared container with the audio panel, including output and source switching, in the laboratory guest with an emulated audio device, and the network/Wi-Fi panel, the largest upstream panel and the most sensitive credential boundary. Wired and state behaviour is exercised in the laboratory; Wi-Fi with PSK is exercised on the T14s through a supervised script, with the prototype running as a separate Quickshell instance delivered by checksummed bundle, never replacing the production shell or touching `configure`, and removed afterwards. [DEC-023, DEC-020, DEC-002]

Bluetooth, display and power are designed from the inventory and comparison evidence without a prototype. The one exception is a supervised, UI-free T14s measurement of how a BlueZ agent handles PIN/passkey pairing, which resolves TODO-002 with evidence. A panel the gate judges risky may open its own production plan with a spike. [DEC-023, TODO-002, TODO-006]

## Output locations

Plan 02-26 follows the Story 4.3 prototype pattern. Prototype source for the container, audio and network panels lives on a `story-4-4-panels-prototype` branch in the laboratory guest checkout, on the real `capabilities/desktop/shell/` tree so it can use `Commons/` and `Ui/`, and never enters the active host branch; it reaches the host as a checksummed, verified bundle in ignored `evidence/shell-panels-prototype/handoff-<sha>/`, reviewed in an isolated repository. A committed `prototypes/shell-panels/` track was rejected because it would duplicate or import the shell's shared code. [DEC-024]

The stable conclusions — Omarchy 4.5 inventory, comparison matrix, prototype and T14s findings and the gate outcome — go into a new committed `docs/procedures/shell-panels-prototype.md`, which the ADR amending ADR 0012 cites from its own file under `docs/adr/`. Raw evidence stays in ignored `evidence/shell-panels/`, with only redacted summaries (no SSIDs, MAC addresses or device names) entering the procedure, and Omarchy ISO extractions stay outside the repository. Production plans reimplement or adapt prototype code under their own review rather than promoting it. [DEC-024, DEC-021]

## ADR and governed documents

The ADR amending ADR 0012 ends plan 02-26 as Accepted, after the gate and a dedicated maintainer review of its text, so production plans start from a settled boundary instead of carrying governance themselves, as ADR 0024 was accepted within plan 02-25 after its prototype. Modelled on ADR 0020, it admits bar-anchored panel popouts limited to the approved panel list, keeps the general control panel, background management services and authenticating QML excluded, sets the credential and privilege boundaries, decides the shell media service and graphical VPN access, and keeps the power watcher outside the shell [DEC-015]. Its Required validation leaves per-panel real-hardware checks to the production plans, with the Framework Laptop 13 Pro still pending. [DEC-025, DEC-020]

The documents the ADR governs change with it: ADR 0012 gains a forward link in its "Superseded by" section without rewriting its decision, the QML entries in `docs/architecture.md` cite the new ADR, `docs/mvp-scope.md` records the desktop shell scope change citing Story 4.4 and Story 4.3 DEC-016 in a separate commit, and `docs/adr/README.md` lists the ADR if that is the index convention. [DEC-025]

## Calendar and extra panels

The calendar panel stays outside plan 02-26 and Story 4.4, since it is neither hardware nor connectivity; Story 4.3 DEC-016's intent is preserved as a pending owner search, and whichever plan takes it will reuse the container validated here. Extra Omarchy panels such as `wifiqr`, `speedtest`, `tailscale`, `weather` or `dropbox` are only inventoried in stage 1 so the maintainer knows what exists; they are compared, prototyped or covered by the ADR only if approved at the gate as a scope change. VPN-related material in Omarchy 4.5, such as `tailscale`, is the exception and is studied as a design reference for the in-scope graphical VPN access. [DEC-026, TODO-008, DEC-019]

## Laboratory hardware

The laboratory guest has no audio device, so its local launcher gains an optional emulated audio flag with an HDA controller backed by host audio, added after a laboratory checkpoint and documented in evidence and the procedure while staying outside the repository. A second virtual PipeWire sink, never `auto_null`, gives the audio prototype two outputs to switch between, and the emulated ALSA device exercises ports and headphone detection that virtual sinks alone would not. The prototype also runs without the flag to prove absent hardware is reported as unavailable rather than failing or fabricated. [DEC-027, DEC-023]

The host's internal Bluetooth is not passed through, so Wi-Fi and the Bluetooth agent are exercised only on the T14s. Battery, backlight and multiple monitors are not emulated, because display and power are not prototyped and rely on the study and the plan 02-25 T14s evidence. [DEC-027, DEC-023]

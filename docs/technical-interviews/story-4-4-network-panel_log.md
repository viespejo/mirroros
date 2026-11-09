# Story 4.4 Network Panel Planning — Decision Log

Technical interview for plan 02-28 (network/Wi-Fi panel). IDs continue from the
[panel infrastructure log](story-4-4-panel-infrastructure_log.md) (DEC-048, TODO-022).

## DEC-049
- **Question**: Does plan 02-28 include any part of the VPN listing that ADR 0025 assigns to the network panel?
- **Context/Nuances**: ADR 0025 says the network panel lists NetworkManager VPN profiles and opens them through the
  owned VPN wrapper; plan 02-30 delivers that wrapper. A listing without the wrapper would have no valid action, and
  the NetworkManager-openconnect auth dialog was unusable under Hyprland (plan 02-25).
- **User Response**: Agreed with the recommendation.
- **Decision**: Plan 02-28 ships the network panel without a VPN section. Plan 02-30 adds the wrapper and the panel's
  VPN listing together. VPN profiles do not appear as network rows and are not touched by band or DNS actions.
- **Status**: Accepted

## DEC-050
- **Question**: How does plan 02-28 reuse the plan 02-26 network panel prototype?
- **Context/Nuances**: DEC-024 forbids promoting prototype code as-is; production reimplements or adapts it under its
  own review. The network prototype (`053e7c3`, verified review repository in ignored
  `evidence/shell-panels-prototype/handoff-053e7c3/review`) already copied and adapted Omarchy `v4.5.0` with the G4
  method: `ShellIpc` replaced, QR and speed test removed, missing-provider glyph kept, `omarchy-cmd-present` replaced
  by `command -v`, `network-dns` without the global layer, `sudo`/`pkexec`/sudoers or VPN profile edits, and 6 model
  tests. T14s findings showed what it still got wrong: DNS presets rewrote every Wi-Fi/Ethernet profile without
  confirmation, continuous ping to `1.1.1.1`, an over-sensitive packet-loss indicator, missing `iw`, indistinct band
  states and no double-click protection.
- **User Response**: Asked that the prototype work be valued; approved the proposal.
- **Decision**: The 02-28 implementation starts from the network prototype `053e7c3` as its primary reference. Each
  file is redone on top of `v4.5.0`, applying the prototype adaptations that remain valid and fixing the T14s findings
  and G12–G14; no line enters without reviewing its diff against `v4.5.0`. Provenance in the shell `UPSTREAM.md` and
  `docs/attribution.md` stays Omarchy `v4.5.0`; the prototype is MirrorOS-owned and is cited as a design reference in
  the plan and the procedure, not as a vendored source. Prototype test cases seed production tests rewritten to the
  plan 02-27 pattern; the prototype test files are not copied.
- **Status**: Accepted

## DEC-051
- **Question**: Where do the owned network commands that replace the Omarchy helpers live and how are they delivered?
- **Context/Nuances**: The prototype kept them in the shell (`panels/network/bin/`). Plan 02-27 placed every panel
  command (`audio-device`, `battery-status`, `brightness`) in its system capability, delivered to
  `/usr/share/mirroros/hardware/`. `system/network/apply` currently states "no provider/profile edits" as a
  postcondition; the commands change profiles only at runtime on explicit user action.
- **User Response**: Approved and asked to record it directly.
- **Decision**: `network-status`, `network-band` and `network-dns` are sources in `capabilities/system/network/`
  (starting from the prototype versions per DEC-050), with an `OMARCHY-LICENSE` copy and `sources.md` rows. The
  `system/network` step delivers them with `cfg_tracked_file` to `/usr/share/mirroros/hardware/` (0755) with
  `cfg_require` postconditions, and the license to `/usr/share/mirroros/hardware/licenses/omarchy-network`. `iw` is added
  to `capabilities/system/network/packages`. The panel calls them by absolute path as the session user. The step itself
  still edits no profile; its postcondition comment is clarified to say that profile changes happen only at runtime on
  explicit user action. `CFG_STEPS` stays at 19.
- **Status**: Accepted

## DEC-052
- **Question**: Which profile does `network-dns` change and how is it identified?
- **Context/Nuances**: The prototype `network-dns` wrote every saved `802-11-wireless`/`802-3-ethernet` profile and read
  the provider from the first active one, which caused the T14s finding (G12). With wired and Wi-Fi both up there are
  two active profiles, and the active profile can change between confirmation and action (roaming, band switch).
- **User Response**: Approved.
- **Decision**: `network-dns` takes an explicit target: `network-dns set <connection-uuid> <provider>` and
  `network-dns get <connection-uuid>`. The panel passes the UUID of the profile shown in its header, the default-route
  device's connection reported by `network-status`. `network-dns` refuses, with a distinct exit code and no change, a
  UUID that is not currently active or is not of Wi-Fi or Ethernet type (VPN, bridge, loopback and others). It runs
  `nmcli connection modify` only on that UUID and `nmcli device reapply` only on the device where it is active. There
  is no all-profiles mode and no walk over saved profiles.
- **Status**: Accepted

## DEC-053
- **Question**: What form does the explicit DNS confirmation (G12) take?
- **Context/Nuances**: On the T14s one click or Enter on a preset pill changed DNS persistently. In 4.5 a pill applies
  immediately and "Custom" opens a floating terminal that reads the servers.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Preset pills (DHCP, Cloudflare, Google) apply nothing on activation; they show an inline confirmation
  row in the DNS section ("Set DNS to <provider> for <profile name>?") with Apply and Cancel. Keyboard focus starts on
  Cancel so a repeated Enter does not confirm; Escape cancels; the confirmation is dismissed when the panel closes, the
  header UUID changes or another pill is activated. Custom has no in-panel confirmation, because opening the terminal
  changes nothing: it opens `foot` through `uwsm app --`, shows the target profile, reads the servers, cancels without
  change on empty input and keeps the prototype's Done/Failed wrapper. While `network-dns set` runs, the section shows a
  pending state, pills are dimmed and repeats are ignored (G14). The text is owned English literals in QML, following
  plan 02-27 practice, with no invented catalog keys.
- **Status**: Accepted

## DEC-054
- **Question**: Which DNS presets does the panel offer and with which values?
- **Context/Nuances**: 4.5 and the prototype offer DHCP (DHCP servers, DNS over TLS `default`), Cloudflare
  (`1.1.1.1 1.0.0.1` plus IPv6, `opportunistic`), Google (`8.8.8.8 8.8.4.4` plus IPv6, `opportunistic`) and Custom
  (entered servers, `default`); all but DHCP set `ignore-auto-dns yes` for IPv4 and IPv6. ADR 0024's "no DNS provider
  imposed" holds because the presets are user choices and DHCP remains the untouched default. `ignore-auto-dns yes` also
  drops DHCP search domains on that profile, which can break short names on a corporate wired LAN. Dropping the global
  layer also drops `FallbackDNS` and global DNS over TLS (recorded in plan 02-26).
- **User Response**: Approved and asked to record it directly.
- **Decision**: Keep the four presets with exactly the 4.5 values and per-connection DNS over TLS as above; `get`
  recognises the provider by matching the profile servers, as the prototype does. `docs/procedures/hardware.md`
  documents the loss of DHCP search domains, that the choice is per profile and does not cover profiles created later,
  and the absence of `FallbackDNS` and global DNS over TLS. No provider is added or removed.
- **Status**: Accepted

## DEC-055
- **Question**: What network diagnostics does the panel show, given G13 and ADR 0025?
- **Context/Nuances**: Omarchy 4.5 `network-status --verbose` pings the gateway and `1.1.1.1` every 1.5 s while the
  panel is open and shows only the `1.1.1.1` samples as "Ping" and "Packet loss" (24-sample window; red on any lost
  sample). ADR 0025 (Accepted) states "no continuous probing of a fixed third-party host" (G13), motivated by
  third-party traffic, metered and ICMP-filtering networks, and T14s noise (latency variation, no real loss). Options
  discussed: gateway-only ping (diagnoses the local Wi-Fi hop but not internet latency), removing the rows, an
  on-demand measurement, and an "Internet" row from NetworkManager connectivity, which was rejected as redundant with
  the panel header ("Limited access", "Sign in required"). The maintainer values internet latency and wants a less
  strict loss indicator. Keeping a continuous internet ping contradicts accepted ADR 0025 and must go through an ADR
  (`AGENTS.md`), as ADR 0026 and ADR 0027 did in plan 02-27.
- **User Response**: Keep the internet ping with a less strict loss indicator; approved routing it through an ADR.
- **Decision**: ADR 0028 "Network panel internet latency probe" partially supersedes only ADR 0025's "Diagnostics"
  item, admitting an internet ping only while the network panel is open, never while it is closed. It is the plan's
  first task, with an acceptance checkpoint before any code change. The 4.5 behaviour (gateway and internet ping, with
  "Ping" and "Packet loss" rows describing the internet samples) is kept. Loss is computed over the 24-sample window
  (about 36 s) and turns red only with at least 10 samples and loss of 10 % or more; below that the percentage shows in
  the normal colour; with Portal, Limited or None connectivity the rows show "--" as in 4.5. The ADR records the
  accepted costs: third-party traffic while the panel is open, ICMP-filtering networks where loss is meaningless, and a
  destination fixed in code. Host and cadence are decided separately.
- **Status**: Accepted

## DEC-056
- **Question**: Which host does the internet latency probe use?
- **Context/Nuances**: `1.1.1.1` (Omarchy 4.5; anycast, no DNS resolution, adds Cloudflare as a third party); `9.9.9.9`
  (Quad9; anycast, privacy-oriented, diverges from upstream without clear gain); `ping.archlinux.org` (NetworkManager's
  connectivity host; no new third party, but needs DNS per sample, is a single server whose latency measures distance
  rather than internet quality, and may not answer ICMP).
- **User Response**: Approved and asked to record it directly.
- **Decision**: `1.1.1.1`, as in 4.5, declared as a single constant in `network-status` and named in ADR 0028.
- **Status**: Accepted

## DEC-057
- **Question**: What cadence and timeout does the internet probe use?
- **Context/Nuances**: 4.5 runs `network-status --verbose` every 1.5 s with `ping -c 1 -W 1`. On the T14s, Wi-Fi latency
  spikes above 1 s counted as lost samples, which explains part of the noise besides the strict threshold.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Keep the 1.5 s cadence, only while the panel is open, so the 5-sample average stays responsive and the
  24-sample window stays about 36 s (DEC-055). Raise the timeout from 1 s to 2 s (`-W 2`) so a slow spike counts as
  high latency, not loss. A poll that is still running when the next tick fires makes that tick skip, so probes never
  overlap; execution verifies whether the 4.5 `Process` `running` guard already ensures this and adds it otherwise.
  ADR 0028 records the values (1.5 s, one packet, 2 s timeout, panel open only).
- **Status**: Accepted

## DEC-058
- **Question**: What does the captive-portal action do?
- **Context/Nuances**: The 4.5 helper `omarchy-network-captive-portal` pauses a Tailscale exit node, opens a floating
  Chromium web app (with Hyprland window rules) and closes it once connectivity returns. MirrorOS has no Tailscale
  capability yet and the browser is chosen only in Story 4.5. The prototype opened Arch's connectivity URI, but
  `archlinux.org` is HSTS-preloaded with `includeSubdomains` (verified 2026-11-08 at hstspreload.org and in its
  `Strict-Transport-Security` header), so a browser upgrades `http://ping.archlinux.org/` to HTTPS and a portal cannot
  intercept it. `neverssl.com` is not preloaded and exists for this purpose; `detectportal.firefox.com` redirects to a
  Mozilla support page when online. With a Tailscale exit node active the portal page is routed into a tunnel the portal
  blocks, which is why Omarchy pauses it; plain Tailscale use without an exit node does not conflict. The maintainer
  uses Tailscale and expects to add it to MirrorOS.
- **User Response**: Approved and asked to record it directly; asked to make sure the Tailscale integration is
  remembered when Tailscale is installed.
- **Decision**: The button, shown only under Portal connectivity and acting only on an explicit click, opens
  `http://neverssl.com/` (a constant in `Model.js`; the divergence and its HSTS reason are recorded in the shell
  `UPSTREAM.md`). It launches `uwsm app -- xdg-open <url>` as argv with the default browser, without an owned helper,
  Tailscale pause, web app, window rules or automatic close; the panel closes after a successful launch, and the 10 s
  recheck while in Portal keeps updating the header and bar. It runs through a `Process`; on a non-zero exit the panel
  stays open and the portal row shows the literal "Could not open a web browser". The button text keeps the pinned
  `7075b61` value "Open Captive Portal"; the difference from 4.5 "Sign into network" is recorded in `UPSTREAM.md`.
  Contacting a third party only on that explicit action is not probing and stays within ADR 0025. Tailscale is out of
  scope for plan 02-28 (TODO-023); `docs/procedures/hardware.md` documents the manual step of disabling an exit node
  (`tailscale set --exit-node=`) before signing in to a portal and re-enabling it afterwards.
- **Status**: Accepted

## TODO-023
- **Question**: How does the captive-portal action handle a Tailscale exit node once Tailscale is a MirrorOS capability?
- **Context/Nuances**: Omarchy 4.5 `omarchy-network-captive-portal` pauses the exit node through the `tailscaled`
  local API socket and restores it after sign-in; that requires the user to be a Tailscale operator
  (`tailscale set --operator=$USER`), a privilege question to design with the capability. Until then the manual step is
  documented in `docs/procedures/hardware.md`.
- **Status**: Pending (when Tailscale enters MirrorOS)

## DEC-059
- **Question**: How do we make sure the Tailscale captive-portal integration (TODO-023) is not forgotten?
- **Context/Nuances**: `.pi/` is excluded locally (`.git/info/exclude`), so a local todo is not authoritative; an
  interview TODO is not read by whoever adds Tailscale.
- **User Response**: Asked to ensure the integration is remembered; approved and asked to record it directly.
- **Decision**: Two layers. (1) A mechanical guard: a Node test in the network panel suite walks every
  `capabilities/**/packages` file and fails if any declares `tailscale`, with the message "Tailscale is now a MirrorOS
  package: implement the captive-portal exit-node pause (TODO-023,
  docs/technical-interviews/story-4-4-network-panel_log.md) and then update this guard", so the commit that adds
  Tailscale breaks the tests and forces the integration or an explicit decision. (2) A documentary trail: the
  captive-portal divergence row in the shell `UPSTREAM.md` and the manual note in `docs/procedures/hardware.md` cite
  TODO-023; a local `.pi/todos` item tagged `tailscale` is created as a complementary, non-authoritative reminder.
- **Status**: Accepted

## DEC-060
- **Question**: How does the panel handle enterprise (802.1X) Wi-Fi, and does it gain an "Advanced…" action?
- **Context/Nuances**: Enterprise Wi-Fi (WPA2/WPA3-Enterprise, for example eduroam) authenticates each user against a
  RADIUS server and needs an EAP method, phase-2 authentication and, for security, a CA certificate and server domain.
  4.5 `Model.enterpriseConnectScript` creates a PEAP/MSCHAPv2 profile with neither CA certificate nor domain
  (verified), so it fails on other methods and exposes the user's credentials to an evil-twin access point. ADR 0025
  routes enterprise authentication through the terminal. The maintainer proposed an "Advanced…" button like the audio
  panel's (ADR 0026). `nmtui` ships with `networkmanager` and is the existing permanent terminal fallback, not a new
  GUI tool or resident applet, so unlike `pavucontrol` it needs no ADR; the panel already opens `foot` for Custom DNS.
- **User Response**: Asked for an explanation, proposed the Advanced button, then approved and asked to record it
  directly.
- **Decision**: An "Advanced…" button at the end of the panel, as in the audio panel, opens
  `uwsm app -- foot -e nmtui`; it is keyboard-reachable and the panel closes after launching it. The identity field,
  `connectEnterprise`, the `enterpriseConnect` process and `Model.enterpriseConnectScript` are removed. An unsaved
  enterprise network row shows the literal "Enterprise network: use Advanced…" and activating it opens `nmtui` like
  the button, never a credential field. A saved enterprise profile connects, disconnects and is forgotten like any
  known network through the native API; if connecting fails for missing secrets the row shows the same literal.
  `docs/procedures/hardware.md` documents 802.1X setup in `nmtui`/`nmcli` and recommends setting the CA certificate and
  domain. A test checks that no enterprise credential path remains in the panel. The divergence is recorded in the
  shell `UPSTREAM.md`; no ADR.
- **Status**: Accepted

## DEC-061
- **Question**: How do the band selector and `network-band` behave, and how is G14 met?
- **Context/Nuances**: `network-band` reports the radio's current band (`iw`), the bands where the same SSID is seen
  and the profile's chosen band (`802-11-wireless.band`, empty meaning auto); `network-band <auto|2.4|5|6>` modifies the
  profile, reactivates it with `nmcli connection up` and reverts to the previous band on failure. It targets the first
  connected Wi-Fi device. The T14s showed two marked pills during a switch, a third indistinct keyboard-cursor mark and
  no double-click protection.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Explicit target, consistent with DEC-052: `network-band set <device> <connection-uuid> <band>` and
  `network-band get <device>`; the panel passes the connected Wi-Fi device and its UUID, and the command refuses with a
  distinct exit code if they no longer match. No confirmation: the change is reversible, auto-reverts on failure and
  only causes a brief reconnection (G12 covers DNS, not band). Three distinct states (G14): chosen (profile band or
  Auto) is a filled pill, current (actual radio band) is a small marker beside the label and never a fill, keyboard
  focus is an outline only. While a switch runs, the target pill reads "Switching…", all band pills are dimmed, clicks
  and Enter are ignored until the command exits, and an empty band status is not published (kept from 4.5). Activation
  is bounded with `nmcli --wait 30 connection up`; on timeout the existing revert applies. If `iw` is missing or yields
  no band data, the band section is hidden.
- **Status**: Accepted

## DEC-062
- **Question**: What file structure and provenance does the network panel use?
- **Context/Nuances**: `bar/widgets/Network.qml` (154 lines) is Adapted from `7075b61` as a bar-only widget (icon,
  signal, connectivity, missing-provider glyph, click as integration point); `bar/NetworkModel.js` (47 lines) is an
  Adapted `7075b61` subset imported only by it. Plan 02-27 turned `Power.qml` into the adapted `v4.5.0` panel and
  removed `bar/PowerModel.js` in favour of `panels/power/Model.js`.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Same pattern as power. `bar/widgets/Network.qml` becomes the panel adapted from
  `v4.5.0:shell/plugins/panels/network/Panel.qml` on `Ui/Panel.qml` with `manageIpc: false`, keeping the MirrorOS
  missing-provider glyph and tooltip and the existing OWE and signal behaviour; its `UPSTREAM.md` row carries the
  `v4.5.0:` prefix and lists divergences (no QR or speed test, no enterprise path and an Advanced action, DNS by UUID
  with confirmation, G14 band states, loss threshold and timeout, portal URL, owned commands instead of `omarchy-*`, IPC
  in the bar). `bar/NetworkModel.js` is removed, superseded by `panels/network/Model.js`, Adapted from `v4.5.0` (portal
  URL, no `enterpriseConnectScript`, loss threshold, new helpers for band states and DNS confirmation). `Ui/TextField.qml`
  is Copied from `v4.5.0` byte for byte and added to `Ui/qmldir`. `network-status`, `network-band` and `network-dns` are
  recorded as Adapted from `v4.5.0` in `capabilities/system/network/sources.md`; `docs/attribution.md` is updated. The
  `network.*` keys enter by regenerating the catalog with `i18n-subset.mjs` from `7075b61` and are verified with
  `--check`; `UPSTREAM.md` notes they match `v4.5.0` except `network.openCaptivePortal`. `check-provenance.mjs` and the
  no-Omarchy-coupling test cover the new files without logic changes.
- **Status**: Accepted

## DEC-063
- **Question**: How are the network panel's IPC, shortcut, bar click and positional numbering wired?
- **Context/Nuances**: Plan 02-27 conventions (DEC-030, DEC-038): one plain IPC target per panel declared once in
  `Bar.qml` outside `Variants` with only `open/close/toggle`; `GlobalShortcut` entries in `shell.qml`; `SUPER+CTRL+N`
  reserved for network; positional `SUPER+CTRL+1..9` counts panels of the focused monitor's right section following
  visible icon order (default: tray, keyboard layout, Bluetooth, network, audio, display, power).
- **User Response**: Approved and asked to record it directly.
- **Decision**: One `IpcHandler { target: "network" }` in `Bar.qml` with only `open`, `close` and `toggle` and
  focused-monitor routing; the 4.5 extras (`toggleNetwork`, `openCaptivePortal`, `checkConnectivity`, `showQr`,
  `speedTest`) are dropped. `GlobalShortcut` `panel.network` in `shell.qml` and `SUPER + CTRL + N` in
  `shell-bindings.lua` through `hl.dsp.global("mirroros:panel.network")`; N moves from reserved to bound in the Lua
  comment, the Hyprland `UPSTREAM.md` "Reserved and unbound" list and the binding and ambiguity tests; B stays reserved
  for 02-29. Clicking the bar icon toggles the panel, replacing the integration-point comment. Default numbering becomes
  network 1, audio 2, display 3, power 4 (`SUPER+CTRL+1` no longer opens audio), recorded in
  `docs/procedures/desktop-shell.md` and the `panelWidgetIdAt` tests. `check-panels.sh` gains network cases: open and
  toggle by IPC and global shortcut, Tab switching, and the unavailable state with NetworkManager stopped.
- **Status**: Accepted

## DEC-064
- **Question**: How is the network panel validated?
- **Context/Nuances**: ADR 0025 requires per panel the unavailable state without the service, real-hardware validation
  in an authorized session (T14s non-qualifying) and the Framework Laptop 13 Pro pending. The laboratory guest is
  wired-only and has no browser; no real captive-portal, enterprise or 6 GHz network is available.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Laboratory: wired header and metrics, ping and loss with the new threshold; no `ping` left after the
  panel closes (`pgrep`); unavailable state with NetworkManager stopped and recovery on restart; no Wi-Fi section
  without a Wi-Fi device; DNS presets with confirmation (Cancel default, Escape) and Custom in `foot`, with an
  all-profiles `nmcli` comparison before and after showing only the active profile changed while a second dummy
  Ethernet profile and a dummy VPN profile stay intact; Advanced opens `nmtui`; a simulated portal through a temporary
  guest-only NetworkManager drop-in pointing the connectivity URI at a local HTTP server with a mismatching response,
  exercising the button and the "Could not open a web browser" path, removed afterwards. Supervised T14s (plan
  02-25/02-27 tmux/SSH pattern; the maintainer acts, the agent verifies read-only): scan; forget and PSK reconnect
  including a wrong passphrase that re-prompts; disconnect; band 2.4/5/Auto with `iw`, G14 states visible and no repeat
  on double click; DNS with confirmation on the active profile only (all-profiles diff) and restore to DHCP; corporate
  VPN profile untouched after DNS and band changes; ping and loss without false reds; Advanced; an enterprise network
  hint if one is visible; NetworkManager journal audit showing session-user operations without `sudo` or polkit
  prompts. Out of scope: real portal, real enterprise network, 6 GHz, Tailscale. `docs/procedures/hardware.md` gains
  network panel matrix rows with the Framework Laptop 13 Pro "pending target-laptop validation"; redacted evidence (no
  SSIDs, MACs, UUIDs or PSKs) goes to ignored `evidence/shell-panels/{lab,t14s}-02-28/` with Gitleaks clean.
- **Status**: Accepted

## DEC-065
- **Question**: Which remaining Omarchy 4.5 network panel functions are kept unchanged?
- **Context/Nuances**: Functions not covered by DEC-049..DEC-064. 4.5 copies to the clipboard through
  `bash -c "printf %s <value> | wl-copy"` with `shellQuote`; `wl-clipboard` is already a shell package.
- **User Response**: Approved and asked to record it directly.
- **Decision**: Keep, with only the adaptations already decided: the Wi-Fi radio toggle (`Networking.wifiEnabled`),
  scanning only while the panel is open, the sorted network list with saved and available sections, open and OWE
  connection without a passphrase and PSK through native `connectWithPsk` with re-prompt on failure, disconnect and
  forget with the in-progress guard and safety timeout, the header with rotating phrases and band/speed detail, the
  metrics grid (IP, gateway, receive and transmit rates), copying IP and gateway to the clipboard, active-AP signal
  through `nmcli`, and full keyboard navigation. Clipboard copy changes to `wl-copy` with the value as an argv argument,
  without `bash -c`; the values are not secret.
- **Status**: Accepted

## DEC-066
- **Question**: Which product tests cover the network panel and its commands?
- **Context/Nuances**: Plan 02-27 pattern: Bats with doubles for owned commands, Node tests for adapted model points,
  static boundary checks, updated binding/provenance/i18n/qmllint suites and a session check; prototype test files are
  not promoted (DEC-050).
- **User Response**: Approved and asked to record it directly; authorized skipping the in-chat draft and materializing
  the plan directly.
- **Decision**: Bats with doubles in `tests/capabilities/system/hardware-network-commands.bats`: `network-dns` get/set
  by UUID, refusal of an inactive or VPN/bridge UUID with its exit code and no `modify`, reapply of the right device
  only, exact preset values, Custom cancel on empty input, no global write (`[global-dns]`, `resolved.conf`), no
  `sudo`/`pkexec` and no walk over saved profiles; `network-band` get/set, stale device-UUID pair, `--wait 30`, revert
  on failure, missing `iw`; `network-status` pinging only the gateway and `1.1.1.1` with `-W 2` and a single internet
  host constant. Node `tests/capabilities/desktop/shell/network-panel-model.test.mjs` over the adapted
  `panels/network/Model.js` points: loss threshold (at least 10 samples and 10 %), `--` under Portal/Limited/None, band
  chosen/current/pending states, DNS confirmation dismissed on UUID change, portal URL and no
  `enterpriseConnectScript`. Static checks: no identity field or enterprise credential path, PSK only through
  `connectWithPsk` and never on argv or in logs, no `omarchy-*` calls (existing coupling test), and the Tailscale guard
  (DEC-059). Updated suites: `bar-panels.test.mjs` (numbering, `network` target), Hyprland binding and ambiguity tests,
  configure contract and system tests (command delivery, `iw`), `check-provenance`, `i18n-subset --check`, the
  `qmllint` baseline with no new category (guest), and `check-panels.sh`. ShellCheck on the three commands,
  `git diff --check`, Gitleaks and relative links.
- **Status**: Accepted

## Execution findings — 2026-11-09 (plan 02-28 Task 6)

These findings supplement, and do not rewrite, DEC-049 to DEC-066.

- ADR 0028 was accepted at the explicit checkpoint before implementation (local governance commits `ca8246f`,
  `058c0c8`). Its open-panel-only probe ships; ADR 0025's decision/consequence text was not rewritten.
- Laboratory checkpoint approved on `a629c36`: configure and unchanged rerun (19 steps), command/license delivery,
  qmllint, four session suites (54 PASS), probe lifecycle, unavailable/recovery, DNS single-profile boundary,
  confirmation/Custom and Advanced passed. A temporary guest-only portal simulation exercised the 10 s recheck and
  missing-browser failure, then was removed. Final-fix panel/qmllint regression passed. Records:
  `evidence/shell-panels/lab-02-28/checkpoint.md` (ignored).
- Supervised T14s checkpoint approved, non-qualifying, final candidate `e350075`: scan, access/navigation,
  disconnect/reconnect, forget/PSK including two wrong-passphrase paths with re-prompt, 2.4/5/Auto states and repeat
  protection, all DNS presets and restoration, stable unrelated/VPN/global DNS state, ping/loss, Advanced and
  session-user journal audit passed. No sudo/polkit prompt and no PSK in shell journal. Records:
  `evidence/shell-panels/t14s-02-28/checkpoint.md` (ignored). Real portal/browser sign-in, enterprise, open/OWE,
  6 GHz and live band rollback were not exercised; Framework Laptop 13 Pro remains pending target-laptop validation.
- With about 95 nearby networks, closing candidate `a629c36` blocked the shell for about 1.1 s: stopping the scanner
  removed networks individually and rebuilt the list 56–62 times. Candidate `00fe3bc` deferred scanner shutdown,
  merely moving the stall, and was rejected. Final `e350075` coalesces updates with
  `Qt.callLater(syncWifiNetworks)` (one 17–24 ms sync; close 74–91 ms). Static regression and provenance record added;
  laboratory and maintainer T14s checks passed. Preserve coalescing when updating upstream.
- Newly delivered Hyprland binding files require an explicitly authorized `hyprctl reload` or a new login; restarting
  the shell alone is insufficient. The shell itself still needs a service restart after publication (TODO-018).
- Running configure as root left the candidate checkout's `.git/index` root-owned; a later user checkout failed,
  and configure re-applied the previous candidate. A fresh verified checkout worked around it; configure was not
  changed. Check the candidate commit before every delivery. A T14s reboot cleared `/tmp`, losing early logs and the
  first profile snapshot; band evidence for that interval relies on the NetworkManager journal.
- Source deviations: `iw` is declared from Arch `core`, not the plan's `extra`; catalog regeneration moved to Task 4
  because the scanner reads QML; bar click uses the existing panel `toggle()` pattern. Tasks 2–5 commits were deferred
  to Task 6. The Tailscale package guard is present, but its failure path was not mutation-tested; the complementary
  local todo was not confirmed created. TODO-023 remains pending, with the manual exit-node step documented.
- `docs/architecture.md:486` still states the general no-control-panel boundary without local ADR 0025 alignment;
  that documentation alignment is outside this plan. No global DNS layer, provider configuration, accepted decision
  text, personal configuration or unrelated panel was changed by Task 6.

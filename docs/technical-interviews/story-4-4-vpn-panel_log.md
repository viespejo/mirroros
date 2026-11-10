# Story 4.4 VPN panel — technical interview log

Decision log for plan 02-30 (graphical VPN access through an owned wrapper). Append-only; superseded entries are
marked, not deleted. The consolidated design lives in [story-4-4-vpn-panel_plan.md](story-4-4-vpn-panel_plan.md).

## DEC-075
- **Question**: Is plan 02-30 delivered as a single plan covering the owned VPN commands, the network panel VPN
  section, tests, laboratory and T14s checkpoints, and documentation?
- **Context/Nuances**: ADR 0025 (G8) already fixes the boundary: an owned Bash wrapper in `capabilities/system/vpn`,
  reimplemented (not promoted) from `prototypes/vpn-openconnect-helper`, local graphical session only, effective
  state verified after `down`, preferences under `$XDG_STATE_HOME/mirroros/`, the network panel lists NetworkManager
  VPN profiles and opens the wrapper in `foot`, and no VPN credential passes through QML. Plan 02-28 shipped the
  network panel without a VPN section precisely so that the wrapper and the listing arrive together; splitting them
  again would leave one half without a valid action. Upstream Omarchy v4.5.0 has no VPN section in its network
  panel, so the section is MirrorOS-owned QML (or adapted from a reviewed MIT reference). The size is comparable to
  plan 02-29. No new ADR is needed while the plan stays within ADR 0025.
- **User Response**: Yes.
- **Decision**: Plan 02-30 is a single plan: owned VPN commands in `capabilities/system/vpn` (interactive connect in
  a terminal plus non-interactive disconnect/status), a VPN section in the network panel, tests, a laboratory
  checkpoint, a supervised non-qualifying T14s checkpoint with the real corporate VPN, and documentation and
  provenance (including marking the prototype as superseded). Out of scope: credential-bearing non-OpenConnect
  profiles, Tailscale (TODO-023), a dedicated VPN bar indicator (open for later discussion in this interview) and
  Framework Laptop 13 Pro validation.
- **Status**: Accepted

## DEC-076
- **Question**: Which NetworkManager profiles does the network panel VPN section list?
- **Context/Nuances**: The product installs only `networkmanager-openconnect`. Users may also have native WireGuard
  profiles (`type wireguard`) or profiles from other VPN plugins. Activating those directly with `nmcli connection up`
  would depend on a graphical secret agent, and the prototype showed `nmcli --ask` fails under Hyprland without one.
  Only OpenConnect through the terminal handoff has been validated (prototype and T14s, 2026-11-06). Alternatives:
  (B) list every VPN/WireGuard profile and activate non-OpenConnect ones directly; (C) list all but act only on
  OpenConnect, showing the rest read-only.
- **User Response**: Yes (option A).
- **Decision**: The VPN section lists only `type vpn` profiles whose `vpn.service-type` is
  `org.freedesktop.NetworkManager.openconnect`. Connect opens the owned wrapper in Foot; Disconnect uses the owned
  command. Other VPN plugin and WireGuard profiles are not listed and stay reachable through "Advanced…" (`nmtui`).
  Options B and C remain possible future extensions.
- **Status**: Accepted

## DEC-077
- **Question**: What is the interface of the owned VPN commands?
- **Context/Nuances**: Established pattern: owned commands delivered to `/usr/share/mirroros/hardware/` (like
  `network-dns`, `bluetooth-device`), validated arguments, distinct exit codes, no identities in output, no
  `sudo`/`pkexec`. The prototype refused all arguments to keep private data off argv; a profile UUID is not a secret
  (`network-dns set <uuid>` already passes one). The prototype found that `nmcli connection down` can exit 0 while
  polkit denies the action, so disconnect must verify the effective state. A single `vpn <subcommand>` binary was
  rejected because mixing the credential path with the panel-invoked path complicates guards.
- **User Response**: Yes.
- **Decision**: Two commands in `/usr/share/mirroros/hardware/`:
  - `vpn-connect <uuid>`: interactive only (requires a TTY, local session, no SSH, no root). The panel launches it as
    `uwsm app -- foot -e /usr/share/mirroros/hardware/vpn-connect <uuid>`. It runs `openconnect --authenticate` and
    hands the result to `nmcli connection up ... passwd-file`.
  - `vpn-profile list|disconnect <uuid>`: non-interactive, used by the panel. `list` prints OpenConnect profiles with
    UUID, name and state (inactive/activating/active) in a fixed parseable format; `disconnect` runs
    `nmcli connection down` and then verifies the effective state with a bounded wait, returning a distinct exit
    code when the profile stays active (for example after a polkit denial).
- **Status**: Accepted

## DEC-078
- **Question**: Where does `vpn-connect` get the gateway, protocol and any other connection setting?
- **Context/Nuances**: The prototype asked for the gateway at a prompt or read it from its preferences file, because
  its acceptance question included remembering gateway and username. The hardware procedure (step 1) already stores
  the gateway with its tunnel-group path in the NetworkManager profile (`vpn.data gateway=`), and the plugin also
  stores `protocol=`; `gateway-flags=2` concerns the returned `vpn.secrets.gateway` secret, not the configured
  gateway. The plugin's `vpn.data` also accepts `useragent` (and `reported-os`), which is how the auth dialog passes
  them to OpenConnect. The 02-25 exploration (TODO-004, ignored `evidence/hardware/exploration-20261103T200419Z/`)
  recorded that `--useragent` and `--gnutls-priority`, used by the maintainer on another host, were not needed: all
  modes obtained a cookie without them. The maintainer first recalled a required User-Agent; the evidence corrected
  it. Lowering TLS priorities is a security decision that should not be hidden in a wrapper.
- **User Response**: Accepted, after reviewing the exploration evidence on the User-Agent.
- **Decision**: `vpn-connect` reads its connection settings from the profile (`nmcli -g vpn.data`) with a strict
  parser that only consumes these keys:
  - `gateway`: required; when missing, the command fails with a message pointing to the hardware procedure;
  - `protocol`: checked against an allowlist that initially contains only `anyconnect` (the validated protocol);
    any other value fails with a clear message;
  - `useragent`: optional; when present it is written as `useragent = ...` into the private OpenConnect config file
    on tmpfs, never on argv.
  `--gnutls-priority` is not supported. The gateway is no longer typed or stored in preferences; the
  NetworkManager profile is the single source of connection configuration.
- **Status**: Accepted

## DEC-079
- **Question**: What does `vpn-connect` remember, where, and how is it reset or migrated?
- **Context/Nuances**: After DEC-078 the gateway comes from the profile, so the username is the only remaining
  preference: not a secret, but private. ADR 0025 requires preferences under `$XDG_STATE_HOME/mirroros/`. The T14s
  holds a prototype file under `~/.mirroros-vpn-acceptance/<uuid>.json` that also contains the gateway. The
  prototype's ownership, mode, symlink, hard-link and no-overwrite checks were validated by its synthetic tests.
- **User Response**: Yes.
- **Decision**:
  - Path: `${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/vpn/<uuid>.json`; owned directory mode 0700, owned
    single-link regular file mode 0600, symlinks refused (same checks as the prototype).
  - Schema: `{"schema_version": 1, "username": "..."}` only; values reach `jq` through stdin.
  - Flow: a saved username is reused and the user is told so; otherwise the username is prompted and saved only after
    an explicit `SAVE` (Enter uses it for this connection only). Existing files are never overwritten.
  - Reset: when a username is saved, the prompt offers `FORGET` to delete it and ask again; deleting the file by hand
    is also documented. No separate subcommand.
  - Migration: none. The procedure tells the user to delete `~/.mirroros-vpn-acceptance/`; the wrapper never reads it.
  - Password and OTP are always entered at OpenConnect's own prompts; they are never stored, and cookies are never
    reused.
- **Status**: Accepted

## DEC-080
- **Question**: What preconditions, confirmation, result reporting, exit codes and cleanup does `vpn-connect` have?
- **Context/Nuances**: The prototype was acceptance tooling: it refused root, SSH and non-TTY use, required a private
  tmpfs runtime directory, checked the four not-saved secret flags without changing the profile, refused an active
  profile and required a typed `CONNECT`. The network panel's Custom DNS launches Foot through
  `Quickshell.execDetached` with a `bash -c` wrapper that prints Done/Cancelled/Failed from the exit code and waits for
  a key; the detached panel never receives the exit code and re-reads state instead.
- **User Response**: Yes.
- **Decision**:
  - Preconditions kept from the prototype: not root, not SSH, TTY on stdin/stdout/stderr, `$XDG_RUNTIME_DIR` equal to
    `/run/user/$EUID`, owned, 0700 and on tmpfs; required tools present; valid UUID format; existing OpenConnect
    profile; the four `*-flags=2` present (otherwise refuse without changing the profile and point to the procedure);
    refuse when the profile is already active or activating.
  - The typed `CONNECT` is dropped: clicking Connect in the panel expresses intent; the terminal shows the profile
    name and Ctrl+C at any prompt (username, password, OTP) cancels with full cleanup.
  - Result: the panel wraps the command, as Custom DNS does, to print `Connected`, `Cancelled` or `Failed` and wait
    for a key. The panel shows the real state by re-reading `vpn-profile list`, not the exit code.
  - Exit codes: 2 usage; 3 environment (root, SSH, TTY, runtime directory, missing tool); 4 invalid profile (missing,
    not OpenConnect, secret flags, gateway, protocol); 5 already active; 6 cancelled; 7 authentication failed;
    8 unsupported authentication output (strict parser); 9 activation failed.
  - Cleanup: an EXIT/HUP/INT/TERM trap removes the runtime files and, after a partial activation, brings the profile
    down and verifies the effective state with the same criterion as `vpn-profile disconnect`. No `--verbose`, no
    cookie in `vpn.secrets`, no `--show-secrets`.
- **Status**: Accepted

## DEC-081
- **Question**: What are the output format and behaviour of `vpn-profile list` and `vpn-profile disconnect`?
- **Context/Nuances**: `nmcli -t` escapes `:` inside fields, so a colon-separated format with the name in the middle
  is fragile for the QML parser. The prototype showed `nmcli connection down` exiting 0 under a polkit denial.
  `bluetooth-power` established a test-only wait override through an environment variable.
- **User Response**: Yes.
- **Decision**:
  - `list`: one line per OpenConnect profile, `<uuid>\t<state>\t<name>`, with `state` in
    `inactive|activating|active|deactivating`; tab separator and name last; names containing control characters are
    omitted or replaced so they cannot break the QML parser; active profiles first, then by name; no profiles means
    empty output and exit 0.
  - `disconnect <uuid>`: validates the UUID and that it is an OpenConnect profile; an already inactive profile exits
    0 without action; otherwise runs `nmcli connection down uuid <uuid>` ignoring its exit status and polls the state
    with a bounded wait (5 s by default, overridable only for tests through `MIRROROS_VPN_DOWN_WAIT_SECONDS`); exit 0
    when inactive.
  - Shared exit codes: 2 usage; 3 unknown UUID or not OpenConnect; 4 NetworkManager unavailable; 5 still active after
    the wait (the polkit-denial case).
  - No subcommand prints the gateway, username or anything from `vpn.data`/`vpn.secrets`; `list` prints the profile
    name because the panel needs it (local only, never logged).
- **Status**: Accepted

## RISK-001
- **Question**: Maintainer note: the network panel must not overflow its height when the VPN section is added.
- **Context/Nuances**: In plan 02-29 the Bluetooth panel's Advanced row overflowed the screen-capped card on the T14s
  and was fixed with a list cap (`Style.space(240)`); a robust shared layout is TODO-644fa670. The network panel is
  already the largest panel (about 2,100 lines upstream) with Wi-Fi list, details, band and DNS sections.
- **User Response**: Keep the height in mind so it does not overflow; left to the agent, no decision required.
- **Decision**: None. Recorded as a constraint for the panel design question and for the laboratory and T14s
  checkpoints.
- **Status**: Pending
- **Update (2026-11-10, interview close)**: Mitigated by DEC-082 (section cap `Style.space(96)`, Wi-Fi cap unchanged).
  Stays Pending until the T14s checkpoint confirms that the card does not overflow at real scale; the interview was
  closed with the maintainer after DEC-094.
- **Update (2026-11-10, T14s checkpoint)**: Materialized and closed. The card overflowed with a long Wi-Fi list on
  the T14s; the maintainer chose to let the Wi-Fi list cap yield the VPN section's height, and the card then fit. See
  the execution findings below.

## DEC-082
- **Question**: Where does the VPN section sit in the network panel, when is it visible, and how tall can it grow?
- **Context/Nuances**: `Network.qml` stacks the hero header, details, Wi-Fi band, DNS, a separator and the Wi-Fi
  `ListView` capped at `Style.space(240)`; the Bluetooth panel uses the same cap after the 02-29 overflow (RISK-001,
  TODO-644fa670). Placing the section at the bottom, under the Wi-Fi list, was considered and rejected because it is
  more likely to fall off screen.
- **User Response**: Yes.
- **Decision**:
  - Placement: a `VPN` section (`PanelSectionHeader` plus separator) between DNS and the Wi-Fi list.
  - Visibility: only when at least one OpenConnect profile exists; with none it takes no space. When NetworkManager is
    unavailable it is hidden with the rest of the panel, which already states the reason.
  - Height: its own `ListView` capped at about `Style.space(96)` (two to three rows) with scrolling beyond that; the
    Wi-Fi list cap stays 240. Both checkpoints verify that the card does not overflow on the T14s at its real scale.
    If it does, the fix is lowering the caps, not redesigning the layout (that remains TODO-644fa670).
- **Status**: Accepted

## DEC-083
- **Question**: What does a VPN row show, which actions does each state offer, and how are concurrency and failures
  handled?
- **Context/Nuances**: In the network panel both "Advanced…" and Custom DNS launch Foot through
  `Quickshell.execDetached` and close the panel immediately. Plan 02-29 established one in-flight action with a
  pending label on the acting row, other rows dimmed and inert, and failure literals on that row only. Only a single
  VPN tunnel has been validated; two simultaneous VPNs would mix routes and DNS.
- **User Response**: Yes.
- **Decision**:
  - Row: VPN icon, profile name and a state literal: `Connected`, `Connecting…`, `Disconnecting…` (none when
    inactive).
  - `inactive`: a Connect button launches `vpn-connect` in Foot through the Connected/Cancelled/Failed wrapper and
    closes the panel.
  - `active`: a Disconnect button runs `vpn-profile disconnect <uuid>` from the panel, which stays open to show the
    result.
  - `activating`/`deactivating`: no action; an in-progress connection is cancelled with Ctrl+C in its terminal.
  - One VPN at a time: while any profile is active or activating, Connect is dimmed and inert on the other rows;
    Disconnect stays available.
  - One action in flight: during Disconnect the row shows `Disconnecting…`, other rows are dimmed and inert, and
    repeats are ignored.
  - Failure literals on the affected row only: exit 5 → `Still connected: disconnect not authorized`; exit 4 →
    `NetworkManager unavailable`; anything else → `Disconnect failed`. They clear on the next refresh that reads the
    profile inactive or when the panel closes.
  - Clicking the row itself does nothing; only the buttons act, to avoid accidental connects that open a credential
    terminal.
- **Status**: Accepted

## DEC-084
- **Question**: How does the network panel keep the VPN state current?
- **Context/Nuances**: Checked in the laboratory on 2026-11-10: Quickshell 0.3.2-1 `Quickshell.Networking` exposes
  only `Wifi` and `Wired` device types and no VPN, active-connection or saved-profile API. A native API would make
  reading the state reactive, but connecting would still need the Foot wrapper, because the OpenConnect cookie handoff
  cannot pass through QML (ADR 0025), and disconnect would still need effective-state verification. A `nmcli monitor`
  process while the panel is open was rejected: a long-lived process to stop on close plus an event parser does not
  pay off for one to three profiles.
- **User Response**: Yes, after the Quickshell API check.
- **Decision**: The panel reads `vpn-profile list` when it opens and right after every Disconnect, and polls every 2 s
  only while the panel is open; a tick is skipped while a read is still running; nothing runs while the panel is
  closed. When `list` fails (exit 4) the section hides rather than showing stale rows. A code comment records that the
  polling should be revisited if a future Quickshell exposes VPN connections; no automatic migration.
- **Status**: Accepted

## DEC-085
- **Question**: How does configure deliver the VPN commands through the `system/vpn` step?
- **Context/Nuances**: `system/vpn/packages` declares only `networkmanager-openconnect`; `openconnect` arrives as a
  transitive dependency, `jq` is declared by `system/audio` and `system/network`, and `foot` by `desktop/terminal`.
  `system/network/apply` delivers its commands with `cfg_tracked_file` and `cfg_require cfg_tracked_file_present`.
  The commands are MirrorOS-owned code reimplemented from a MirrorOS-owned prototype; nothing is copied from Omarchy
  or omarchy-vpn.
- **User Response**: Yes.
- **Decision**:
  - `packages`: add `openconnect extra` and `jq extra` explicitly, because the commands call them directly; `foot` is
    not added (the panel uses it and `desktop/terminal` guarantees it).
  - `apply`: deliver `vpn-connect` and `vpn-profile` to `/usr/share/mirroros/hardware/` mode 0755 with
    `cfg_tracked_file` plus `cfg_require cfg_tracked_file_present`, following `system/network`; keep the existing
    plugin check; `CFG_STEPS` stays 19.
  - No license copy: owned `GPL-3.0-only` code with MirrorOS license headers, no `OMARCHY-LICENSE`.
  - `check`: unchanged; configure never creates a profile, authenticates or connects.
  - Delivery tests: a new `tests/capabilities/system/vpn.contract.bats`, or an extension of an existing suite that
    already covers `system/vpn`, asserting paths, modes, packages and that configure never runs the commands.
- **Status**: Accepted

## DEC-086
- **Question**: What is the test strategy for delivery, commands and panel?
- **Context/Nuances**: `tests/capabilities/system/hardware.contract.bats` already covers `system/vpn` (plugin check,
  no corporate profile created, step order), and plan 02-29 extended that file for Bluetooth; this resolves the
  "new or extended suite" alternative left open in DEC-085. Plan 02-29 established namespaced doubles copied under
  their real names only inside the suite that needs them. Bats has no TTY, so the interactive happy path needs a pty.
- **User Response**: Yes.
- **Decision**:
  - Delivery: extend `hardware.contract.bats` (no new `vpn.contract.bats`) for paths, modes, packages and that
    configure never invokes `vpn-connect`, `vpn-profile` or `openconnect`.
  - Commands: new `tests/capabilities/system/hardware-vpn-commands.bats` with namespaced, argv-recording doubles
    (`vpn-nmcli`, `vpn-openconnect`) covering: root/SSH/no-TTY refusal and a pty happy path through `script -qec`;
    profile refusals (missing, not OpenConnect, flags, gateway, protocol, already active) without profile changes;
    `useragent` only in the private config and no username, gateway, cookie or fingerprint on any recorded argv; the
    strict parser (mapping, unknown, duplicate, empty, control characters, no `eval`); cleanup after success,
    authentication failure, Ctrl+C and failed activation, including verified `down` after a partial activation;
    preferences (modes, symlink, hard link, no overwrite, `SAVE`, `FORGET`); exit codes 2–9; `list` format, `:` and
    control characters in names, order and empty output; idempotent `disconnect`, `nmcli` exit 0 while still active
    yielding 5, and the `MIRROROS_VPN_DOWN_WAIT_SECONDS` override; ShellCheck.
  - Panel: new pure helpers in `panels/network/Model.js` with Node tests (list parsing, action per state, one-VPN
    gating, exit-code literals, Connected/Cancelled/Failed wrapper); static guards (exact
    `uwsm app -- foot -e .../vpn-connect` argv, `vpn-connect` never run outside Foot, no password/username field and no
    `nmcli connection up` in the VPN section, no `omarchy-*`, polling only while open); `check-panels.sh` and the
    qmllint baseline reviewed in the laboratory.
  - Prototype tests are not touched here; the prototype's fate is a separate question.
- **Status**: Accepted

## DEC-087
- **Question**: What happens to `prototypes/vpn-openconnect-helper/` and how is provenance recorded?
- **Context/Nuances**: `prototypes/README.md` keeps executed prototypes as evidence, updates their register status
  ("Executed by plan X; outcome in ...") and forbids promotion by renaming. Track 5 currently reads "preserved for
  plan 02-30" and the Layout line says the product wrapper belongs to plan 02-30. `capabilities/system/vpn/sources.md`
  says an owned connect command and graphical UI are deferred to 02-30.
- **User Response**: Yes.
- **Decision**:
  - Keep the prototype directory, its scripts and its 21 synthetic tests unchanged; it is the evidence behind
    DEC-078..DEC-081.
  - `prototypes/README.md`: Track 5 status becomes "Executed during plan 02-25 Task 7; superseded by the owned
    `capabilities/system/vpn` commands (plan 02-30)"; the Layout line drops "the product wrapper belongs to plan
    02-30".
  - `prototypes/vpn-openconnect-helper/README.md`: status updated and a short "Superseded by" section listing the
    deliberate differences (gateway from the profile, new preferences path holding only the username, no `CONNECT`,
    `FORGET`, verified `down`, distinct exit codes); "Findings for plan 02-30" stays as a historical record.
  - `capabilities/system/vpn/sources.md`: records the commands as an owned reimplementation from the prototype, linking
    the prototype and this log, replacing the "deferred to 02-30" sentence.
  - Prototype tests do not join the product suites.
- **Status**: Accepted

## DEC-088
- **Question**: Which documents change and how?
- **Context/Nuances**: `docs/procedures/hardware.md` references VPN at lines 43 ("remains with plan 02-30"), 90 (matrix
  row "Corporate VPN"), 199 ("No VPN section is delivered yet") and 299–339 (private procedure with manual steps 1–6).
  `docs/mvp-scope.md` row 45 describes the corporate VPN through private terminal authentication. ADR 0025 keeps the
  terminal paths from plan 02-25 as the permanent fallback. No third-party material is incorporated.
- **User Response**: Yes.
- **Decision**:
  - `docs/procedures/hardware.md`, "Private corporate VPN procedure": step 1 (private profile with
    `nmcli connection edit` and the `*-flags=2`) stays, clarifying that the gateway with tunnel group,
    `protocol=anyconnect` and an optional `useragent` live in the profile (DEC-078). Steps 2–5 are replaced by
    "Connect and disconnect": Connect from the network panel or `vpn-connect <uuid>` in a local terminal; Disconnect
    from the panel or `vpn-profile disconnect <uuid>`; the exit-code table; preferences with `SAVE`, `FORGET` and
    manual deletion; and an instruction to delete `~/.mirroros-vpn-acceptance/`. The manual steps 2–5 remain,
    condensed, as "Manual fallback" for profiles the command refuses. Lines 43 and 199 are updated, the "Corporate
    VPN" matrix row records the 02-30 V/A results, and a new "Network panel: VPN section" row is added.
  - `docs/procedures/desktop-shell.md`: no IPC or binding change (the section lives in the `network` panel, which
    already has its IPC target and `SUPER+CTRL+N`); at most one line mentioning the section where that panel is
    described.
  - `docs/mvp-scope.md` row 45: text synced to mention the owned `vpn-connect`/`vpn-profile` commands and network panel
    access under ADR 0025; alignment with an accepted decision, not a scope change.
  - `capabilities/desktop/shell/UPSTREAM.md`: the `Network.qml` and `Model.js` rows state that the VPN section is
    MirrorOS-owned, not adapted from upstream.
  - `docs/attribution.md`: unchanged. `docs/architecture.md:486` stays out of scope.
  - This log gains dated "Execution findings" sections during execution (02-29 pattern).
- **Status**: Accepted

## DEC-089
- **Question**: What do the laboratory and T14s checkpoints cover?
- **Context/Nuances**: A NetworkManager VPN profile is only configuration and can be created on any machine,
  including the laboratory guest, which reaches the internet through the host; a real connection then authenticates
  against the corporate server with username, password and OTP. Option B (create the real corporate profile in the
  laboratory through the QEMU graphical console and connect once) is technically possible and would catch happy-path
  defects before the T14s. It was rejected because corporate data would persist in the guest disk and its Limine
  snapshots, the agent operates the guest over SSH, corporate policy may not allow authenticating from a VM or
  unmanaged device, and each real connection costs an OTP and the maintainer's presence. The maintainer initially
  read "no corporate VPN in the laboratory" as a technical impossibility; it was clarified as a data and usage
  choice.
- **User Response**: Option A; then confirmed the full checkpoint summary.
- **Decision**: Two checkpoints, each on a checksummed bundle and a fresh clone (02-29 pattern).
  - Laboratory (option A), fictitious OpenConnect profiles only (`vpn.example.invalid`): delivery and unchanged
    rerun; no profiles (no section, unchanged height); section with 1 and 4 profiles within the height cap
    (RISK-001); Connect opens Foot and closes the panel; a profile without the flags is refused unchanged (exit 4); a
    real authentication failure against the nonexistent host shows `Failed` with an empty runtime directory and no
    active profile; Ctrl+C at the username prompt shows `Cancelled` and cleans up; `SAVE`/`FORGET` create and delete
    the 0600 file; NetworkManager stopped hides the section; session suites and the reviewed qmllint baseline;
    fictitious profiles deleted at the end.
  - T14s, supervised and non-qualifying (tmux sudo window, turn ends before each maintainer action, sanitized evidence
    in ignored `evidence/shell-panels/t14s-02-30/`): the maintainer deletes `~/.mirroros-vpn-acceptance/`; real
    Connect from the panel with `SAVE`, row `Connected` within 2 s; private pass/fail checks of corporate resource,
    split DNS with VPN scope, split routes without a new default route and unchanged profile DNS; Disconnect from the
    panel with no sudo/polkit prompt; a second connection reusing the username; `vpn-profile disconnect` over SSH
    returns 5 with the VPN still active, then a final panel Disconnect; wrong password and Ctrl+C at the OTP prompt
    leave an empty runtime and nothing active; `FORGET` asks again; panel height at real scale with the VPN section
    and a long Wi-Fi list; optional one-VPN gating with a temporary fictitious second profile, deleted afterwards;
    Gitleaks on the evidence and no username or gateway in the shell journal.
  - Out of scope: Framework Laptop 13 Pro, other protocols, cookie reuse.
- **Status**: Accepted

## DEC-090
- **Question**: Does plan 02-30 add a VPN indicator to the bar (left open in DEC-075)?
- **Context/Nuances**: A bar indicator needs the VPN state while the panel is closed. Quickshell exposes no VPN API
  (DEC-084), so it would need permanent `vpn-profile list` polling or an always-running `nmcli monitor`, both against
  DEC-084 (nothing runs while the panel is closed) and close to ADR 0025's exclusion of resident processes.
- **User Response**: Yes.
- **Decision**: No bar indicator in plan 02-30; the VPN state is visible only with the panel open. Recorded as a
  follow-up candidate for when Quickshell exposes VPN connections, or for an explicit decision accepting continuous
  polling.
- **Status**: Accepted

## DEC-091
- **Question**: How is the work committed?
- **Context/Nuances**: Plans 02-28 and 02-29 committed at the end in thematic local blocks, without push, and left
  temporary candidate refs in the local repository for review.
- **User Response**: Yes. The maintainer also asked to skip the in-chat plan draft and materialize the plan directly
  once it can be drafted.
- **Decision**: Three local commits at the end, in order: (1) commands, delivery and command/contract tests;
  (2) model, panel VPN section, guards, qmllint baseline and shell `UPSTREAM.md`; (3) documentation (procedures,
  `mvp-scope`, prototype READMEs, `sources.md`, these interview artifacts). No push. `refs/mirroros-candidates/02-30-*`
  stay local until the maintainer's review.
- **Status**: Accepted

## DEC-092
- **Question**: What does `vpn-connect` do when the profile's `vpn.data` has no `protocol` key?
- **Context/Nuances**: Refines DEC-078, which fixed only the allowlist. Raised after the plan was first materialized
  without closing this branch with the maintainer. Hardware procedure step 1 does not require setting `protocol`, so
  the private T14s profile may lack it. Without the key the plugin passes no `--protocol` and OpenConnect defaults to
  AnyConnect; the prototype always passed `--protocol=anyconnect`. Requiring the key would force editing the existing
  profile without a security gain.
- **User Response**: Yes.
- **Decision**: A missing `protocol` is treated as `anyconnect` and passed explicitly as `--protocol=anyconnect`; a
  present value outside the allowlist exits 4. Procedure step 1 states that setting `protocol=anyconnect` is
  recommended but optional, and the T14s checkpoint no longer requires the key on the private profile.
- **Status**: Accepted

## DEC-093
- **Question**: How does `vpn-profile list` handle profile names containing control characters?
- **Context/Nuances**: Refines DEC-081, which allowed omitting or replacing them; the first materialized plan left
  the choice to the executor. A tab or newline in a name would break the `<uuid>\t<state>\t<name>` format.
  NetworkManager accepts such names although they are rare. Omitting the profile would hide a valid profile from the
  panel without explanation.
- **User Response**: Yes.
- **Decision**: Replace every control character in the name, including tab and newline, with `?`
  (`${name//[[:cntrl:]]/?}`). The profile stays listed and usable, since actions go by UUID. The rule is documented in
  the command header and covered by a Bats case.
- **Status**: Accepted

## DEC-094
- **Question**: How is the VPN section reached and operated from the keyboard?
- **Context/Nuances**: Raised after the plan was first materialized with an unagreed keyboard rule. `Network.qml` uses
  a section focus model (`focusSection`: header, portal, band, dns, dnsConfirm, wifi, advanced): vertical keys move
  between sections in visual order, horizontal keys move within a section, Enter activates. On open, focus goes to
  portal, else wifi, else dns. A hidden `band` section already returns focus to `dns`.
- **User Response**: Yes.
- **Decision**:
  - A new focus section `vpn` with a row index, placed between `dns`/`dnsConfirm` and `wifi` in vertical order;
    moving down walks the VPN rows one by one and then reaches `wifi`, and moving up reverses it.
  - Enter activates the row's single button (Connect or Disconnect); on rows without an action or dimmed and inert
    it does nothing. No horizontal navigation.
  - The default focus on open is unchanged, so an accidental Enter right after opening cannot launch a credential
    terminal.
  - If the section disappears while focused (no profiles or a failed read), focus returns to `dns`, as for `band`.
  - The focused row uses the panel's existing `hasCursor` style.
- **Status**: Accepted

## Execution findings — 2026-11-10 (plan 02-30)

These findings supplement, and do not rewrite, DEC-075 to DEC-094.

- Laboratory checkpoint approved on `1393383`, fictitious profiles only (DEC-089 option A): configure and unchanged
  rerun (19 steps); `vpn-connect` and `vpn-profile` delivered 0755 and byte-identical, never run by configure; no
  section without profiles; one and five profiles within the cap; Connect opens Foot and closes the panel; a profile
  without the flags is refused unchanged (exit 4); authentication against `vpn.example.invalid` shows Failed; `SAVE`
  creates the 0600 file with the exact schema and `FORGET` deletes it; Ctrl+C shows Cancelled; no runtime leftovers
  and nothing active; the section is hidden with NetworkManager stopped. qmllint reported only new entries in
  existing categories for `bar/widgets/Network.qml`; the baseline was updated after review (+72 keys). Records:
  `evidence/shell-panels/lab-02-30/checkpoint.md` (ignored).
- Supervised T14s checkpoint approved, non-qualifying, final candidate `1bf11d5` (earlier `46810b9`), with the
  maintainer's corporate profile: panel Connect with `SAVE` reached Connected and the row followed within 2 s; a
  corporate resource was reachable; split DNS had VPN scope, split routes added no default route and the profile
  settings were unchanged; panel Disconnect needed no sudo or polkit prompt; the saved username was reused;
  `FORGET` asked again; Ctrl+C at the OTP prompt reported Cancelled with cleanup; keyboard Connect from the VPN row;
  one-VPN gating with a fictitious second profile; no gateway or profile identity in the journal. Records:
  `evidence/shell-panels/t14s-02-30/checkpoint.md` (ignored).
- RISK-001 materialized on `46810b9`: with the VPN section above a long Wi-Fi list at scale 1.6 the card was cut
  inside the Wi-Fi list and Advanced… was not visible. While the section is shown, the Wi-Fi list cap is now
  `Style.space(240)` minus the section's height (separator, section and two column gaps); without VPN profiles the
  panel is unchanged. This departs from DEC-082's "the Wi-Fi list cap stays 240" and applies its fallback (lower the
  caps, do not redesign); approved by the maintainer. The robust layout remains TODO-644fa670.
- DEC-081 confirmed on real hardware: `vpn-profile disconnect` over SSH exited 5 after the 5 s wait while the VPN
  stayed active.
- The corporate server asks for the password again after a wrong one instead of failing, so exit 7 (Failed) was not
  observable on the T14s; Ctrl+C at the re-prompt reported Cancelled with cleanup. Exit 7 is covered by the
  laboratory and the Bats suite. The hardware procedure does not promise Failed after a wrong password.
- `nmcli` profile creation and deletion over SSH is denied by polkit; the laboratory suites and the T14s gating
  profile ran through `systemd-run --user`.
- Restarting the shell while NetworkManager is stopped leaves the network panel without a backend until the next
  shell restart, because `Quickshell.Networking` picks its backend once at startup. Not a plan 02-30 regression and
  outside its scope (no `Quickshell.Networking` changes).
- Implementation choices within the decisions: hangup, termination and end of input also exit 6; a deactivating
  profile also exits 5; an unsafe or invalid preference file exits 3; an invalid typed username is asked again; a
  name ending in a newline loses that newline to command substitution instead of showing `?`.

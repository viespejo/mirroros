// Network panel: the adapted v4.5.0 model and the MirrorOS boundaries around it.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const modelSource = readFileSync(path.join(repo, 'capabilities/desktop/shell/panels/network/Model.js'), 'utf8');
const module = { exports: {} };
vm.runInNewContext(modelSource, { module });
const Model = module.exports;
const plain = value => JSON.parse(JSON.stringify(value));
// Network.qml without comment lines, so rationale text never satisfies or trips a check.
const panel = readFileSync(path.join(repo, 'capabilities/desktop/shell/bar/widgets/Network.qml'), 'utf8')
  .split('\n').filter(line => !line.trim().startsWith('//')).join('\n');

// Shape of `network-status --verbose` on a wired link (TEST-NET addresses, placeholder UUID).
const wired = [
  'uuid\t00000000-0000-4000-8000-000000000001', 'connection\tWired', 'connection_type\t802-3-ethernet',
  'router_ping_ms\t0.4', 'internet_ping_ms\t12.5', 'iface\tenp0s4', 'ip\t192.0.2.15', 'prefix\t24',
  'gateway\t192.0.2.2', 'rx_bytes\t1000', 'tx_bytes\t500', 'type\tethernet', 'speed\t1000', 'duplex\tfull',
].join('\n') + '\n';

const samples = (lost, total) => Array.from({ length: total }, (_, index) => index < lost ? null : 10);

test('verbose status feeds the header, profile identity and ping rows', () => {
  const info = Model.parseKeyValue(wired);
  assert.equal(info.uuid, '00000000-0000-4000-8000-000000000001');
  assert.equal(info.connection, 'Wired');
  assert.equal(Model.headerDetail(info), '1gbit');
  const ping = Model.pingLatencyState({}, info, 24, 5);
  assert.equal(ping.routerPingLatency, 0.4);
  assert.equal(ping.internetPingLatency, 12.5);
  // An empty internet probe is a lost sample, not a zero latency.
  const lost = Model.pingLatencyState(ping, { ...info, internet_ping_ms: '' }, 24, 5);
  assert.deepEqual(plain(lost.internetPingSamples), [12.5, null]);
  assert.equal(lost.internetPingPacketLoss, 50);
});

test('packet loss turns urgent only with at least 10 samples and 10 % loss (ADR 0028)', () => {
  assert.equal(Model.packetLossUrgent(samples(1, 1)), false);
  assert.equal(Model.packetLossUrgent(samples(9, 9)), false);
  assert.equal(Model.packetLossUrgent(samples(0, 10)), false);
  assert.equal(Model.packetLossUrgent(samples(1, 10)), true);
  assert.equal(Model.packetLossUrgent(samples(2, 24)), false);
  assert.equal(Model.packetLossUrgent(samples(3, 24)), true);
  assert.equal(Model.packetLossUrgent(undefined), false);
});

test('ping and loss read "--" under Portal, Limited and None connectivity', () => {
  const values = samples(0, 12);
  for (const connectivity of ['portal', 'limited', 'none']) {
    const readable = Model.internetPingReadable(values, connectivity);
    assert.equal(readable, false, connectivity);
    assert.equal(Model.formatPacketLoss(0, readable), '--');
    assert.equal(Model.formatPingLatency(10, readable), '--');
  }
  assert.equal(Model.internetPingReadable(values, 'full'), true);
  assert.equal(Model.formatPingLatency(12.5, true), '13 ms');
});

test('band pills keep chosen, current and switching states distinct', () => {
  const idle = band => plain(Model.bandPillState(band, '5', '2.4', ''));
  assert.deepEqual(idle('5'), { filled: true, current: false, switching: false, dimmed: false, enabled: true });
  assert.deepEqual(idle('2.4'), { filled: false, current: true, switching: false, dimmed: false, enabled: true });
  assert.equal(Model.bandPillState('auto', '', '5', '').filled, true);
  const busy = band => plain(Model.bandPillState(band, '5', '2.4', '2.4'));
  assert.deepEqual(busy('2.4'), { filled: true, current: true, switching: true, dimmed: true, enabled: false });
  assert.deepEqual(busy('5'), { filled: false, current: false, switching: false, dimmed: true, enabled: false });
  assert.deepEqual(plain(Model.parseBandStatus('band\t5\navailable\t2.4 5\nselected\tauto\nuuid\tx\n')),
    { band: '5', selected: 'auto', available: ['2.4', '5'] });
  assert.deepEqual(plain(Model.parseBandStatus('')), { band: '', selected: 'auto', available: [] });
});

test('DNS presets need a confirmation bound to the header profile UUID', () => {
  for (const provider of ['DHCP', 'Cloudflare', 'Google']) assert.equal(Model.dnsNeedsConfirmation(provider), true);
  assert.equal(Model.dnsNeedsConfirmation('Custom'), false);
  const confirmation = { provider: 'Cloudflare', uuid: 'uuid-a', name: 'Home' };
  assert.equal(Model.dnsConfirmationValid(confirmation, 'uuid-a'), true);
  assert.equal(Model.dnsConfirmationValid(confirmation, 'uuid-b'), false);
  assert.equal(Model.dnsConfirmationValid(confirmation, ''), false);
  assert.equal(Model.dnsConfirmationValid({ ...confirmation, provider: 'Custom' }, 'uuid-a'), false);
  assert.equal(Model.dnsConfirmationValid(null, 'uuid-a'), false);
});

test('the captive portal opens a plain-HTTP host that is not HSTS-preloaded', () => {
  assert.equal(Model.captivePortalUrl, 'http://neverssl.com/');
});

test('the model carries no enterprise credential path', () => {
  assert.equal('enterpriseConnectScript' in Model, false);
  assert.doesNotMatch(modelSource, /802-1x|identity|connection edit/);
});

test('the panel has no enterprise credential path or identity field', () => {
  assert.doesNotMatch(panel, /identityText|connectEnterprise|enterpriseConnect|network\.identity|802-1x/);
  assert.match(panel, /"Enterprise network: use Advanced\u2026"/);
  assert.match(panel, /execDetached\(\["uwsm", "app", "--", "foot", "-e", "nmtui"\]\)/);
});

test('the PSK reaches only the native connectWithPsk', () => {
  for (const line of panel.split('\n').filter(l => /passwordText|passphrase\b/.test(l))) {
    assert.doesNotMatch(line, /command|execDetached|console\.|\[\s*"/, line.trim());
  }
  assert.match(panel, /network\.connectWithPsk\(passphrase\)/);
  assert.match(panel, /root\.connectWithPassphrase\(net\.ssid, root\.passwordText\)/);
});

test('clipboard, portal and owned commands run as argv without a shell or privilege', () => {
  assert.match(panel, /execDetached\(\["wl-copy", value\]\)/);
  assert.doesNotMatch(panel, /printf %s|shellQuote/);
  assert.match(panel, /command: \["uwsm", "app", "--", "xdg-open", Model\.captivePortalUrl\]/);
  assert.match(panel, /"Could not open a web browser"/);
  for (const name of ['network-status', 'network-band', 'network-dns'])
    assert.match(panel, new RegExp(`"/usr/share/mirroros/hardware/${name}"`));
  assert.doesNotMatch(panel, /\bsudo\b|\bpkexec\b|omarchy-|ShellIpc|summon\(/);
});

test('the VPN section opens vpn-connect only in Foot and carries no credential (ADR 0025 G8)', () => {
  const argv = 'Quickshell\\.execDetached\\(\\["uwsm", "app", "--", "foot", "-e", "bash", "-c", Model\\.vpnConnectScript, '
    + '"vpn-connect", "/usr/share/mirroros/hardware/vpn-connect", uuid\\]\\)\\s*root\\.close\\(\\)';
  assert.match(panel, new RegExp(argv));
  assert.equal(panel.match(/vpn-connect"/g).length, 2, 'vpn-connect appears only as the Foot argv ($0 and path)');
  assert.match(panel, /vpnDisconnectProc\.command = \[vpnProfileCommand, "disconnect", uuid\]/);
  assert.match(panel, /command: \[root\.vpnProfileCommand, "list"\]/);
  assert.match(panel, /"\/usr\/share\/mirroros\/hardware\/vpn-profile"/);
  const row = panel.slice(panel.indexOf('component VpnRow'), panel.indexOf('component DetailValue'));
  assert.ok(row.length > 0, 'VpnRow component not found');
  assert.doesNotMatch(row, /TextField|echoMode|password|username|execDetached|Process/i);
  assert.doesNotMatch(panel, /echoMode|connection"?,? "?up\b|nmcli[^\n]*connection/);
  assert.equal(panel.match(/TextField \{/g).length, 1, 'only the Wi-Fi passphrase field');
  assert.doesNotMatch(panel, /omarchy-|\bsudo\b|\bpkexec\b/);
});

test('VPN polling runs only while the panel is open and never takes the default focus', () => {
  assert.match(panel, /id: vpnPoll[\s\S]*?interval: 2000[\s\S]*?running: root\.opened[\s\S]*?root\.refreshVpn\(\)/);
  assert.match(panel, /function refreshVpn\(\) \{\s*if \(!opened \|\| vpnListProc\.running\) return/);
  assert.match(panel, /vpnListProc\.running = false/);
  assert.match(panel, /focusSection = hasCaptivePortal \? "portal" : \(wifiNetworks\.length > 0 \? "wifi" : "dns"\)/);
  assert.match(panel, /if \(!vpnShown && focusSection === "vpn"\) focusSection = "dns"/);
  assert.match(panel, /height: Math\.min\(contentHeight, Style\.space\(96\)\)/);
  assert.match(panel, /height: Math\.min\(contentHeight, Style\.space\(240\) - \(root\.vpnShown \? vpnSeparator\.height \+ vpnSection\.height \+ 2 \* column\.spacing : 0\)\)/);
});

test('DNS and band actions still target only Wi-Fi or Ethernet profiles, never VPN rows', () => {
  assert.match(panel, /dnsAvailable: dnsTargetUuid !== ""\s*&& \(info\.connection_type === "802-11-wireless" \|\| info\.connection_type === "802-3-ethernet"\)/);
  assert.match(panel, /actionProc\.command = \[bandCommand, "set", wifiDevice\.name, bandUuid, band\]/);
  assert.doesNotMatch(panel, /(dnsTool|bandCommand)[^\n]*vpn/i);
  assert.doesNotMatch(panel, /(dnsTargetUuid|bandUuid)\s*=[^=][^\n]*vpn/i);
});

test('network-status (which pings) runs only while the panel is open', () => {
  assert.match(panel, /id: detailsPoll[\s\S]*?running: root\.opened[\s\S]*?if \(!detailsProc\.running\)/);
  assert.match(panel, /if \(opened\) \{\s*if \(!detailsProc\.running\) detailsProc\.running = true/);
  assert.match(panel, /detailsProc\.running = false/);
});

test('network-list changes coalesce into one deferred sync', () => {
  assert.match(panel, /onWifiNetworkObjectsChanged: Qt\.callLater\(syncWifiNetworks\)/);
  assert.doesNotMatch(panel, /onWifiNetworkObjectsChanged: syncWifiNetworks\(\)/);
});

// Placeholder UUIDs for the owned VPN section helpers (plan 02-30).
const vpnA = '00000000-0000-4000-8000-00000000000a';
const vpnB = '00000000-0000-4000-8000-00000000000b';

test('vpn-profile list output parses into rows and drops malformed lines', () => {
  const text = [
    `${vpnA}\tactive\tCorp: main`, `${vpnB}\tinactive\tLab ? profile`,
    `${vpnA}\tconnected\tUnknown state`, `${vpnA}\tinactive`, `${vpnA}\tinactive\tA\tB`,
    `not-a-uuid\tinactive\tBad`, `${vpnB}\tinactive\t`, '',
  ].join('\n');
  assert.deepEqual(plain(Model.parseVpnProfiles(text)), [
    { uuid: vpnA, state: 'active', name: 'Corp: main' },
    { uuid: vpnB, state: 'inactive', name: 'Lab ? profile' },
  ]);
  assert.deepEqual(plain(Model.parseVpnProfiles('')), []);
  assert.deepEqual(plain(Model.parseVpnProfiles(undefined)), []);
  for (const state of ['inactive', 'activating', 'active', 'deactivating'])
    assert.equal(Model.parseVpnProfiles(`${vpnA}\t${state}\tX\n`)[0].state, state);
});

test('VPN rows allow one VPN at a time and one Disconnect in flight (DEC-083)', () => {
  assert.equal(Model.vpnRowAction('inactive', false, '', vpnA), 'connect');
  assert.equal(Model.vpnRowAction('active', true, '', vpnA), 'disconnect');
  // Another profile active or activating dims Connect on the other rows.
  assert.equal(Model.vpnRowAction('inactive', true, '', vpnB), 'none');
  for (const state of ['activating', 'deactivating']) {
    assert.equal(Model.vpnRowAction(state, false, '', vpnA), 'none', state);
    assert.equal(Model.vpnRowAction(state, true, '', vpnA), 'none', state);
  }
  // A Disconnect in flight makes every row inert, the acting row included.
  assert.equal(Model.vpnRowAction('active', true, vpnA, vpnA), 'none');
  assert.equal(Model.vpnRowAction('inactive', false, vpnA, vpnB), 'none');
});

test('VPN state labels and Disconnect failure literals', () => {
  assert.equal(Model.vpnStateLabel('active'), 'Connected');
  assert.equal(Model.vpnStateLabel('activating'), 'Connecting\u2026');
  assert.equal(Model.vpnStateLabel('deactivating'), 'Disconnecting\u2026');
  assert.equal(Model.vpnStateLabel('inactive'), '');
  assert.equal(Model.vpnStateLabel(undefined), '');
  assert.equal(Model.vpnDisconnectFailure(5), 'Still connected: disconnect not authorized');
  assert.equal(Model.vpnDisconnectFailure(4), 'NetworkManager unavailable');
  for (const code of [1, 2, 3, 127, -1]) assert.equal(Model.vpnDisconnectFailure(code), 'Disconnect failed');
});

test('the vpn-connect Foot wrapper reports Connected, Cancelled or Failed', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'vpn-wrapper-'));
  try {
    const command = path.join(dir, 'vpn-connect');
    writeFileSync(command, '#!/usr/bin/bash\n[[ $1 == "$EXPECTED_UUID" ]] || exit 99\nexit "$EXIT_CODE"\n');
    chmodSync(command, 0o755);
    for (const [code, word] of [[0, 'Connected'], [6, 'Cancelled'], [7, 'Failed'], [99, 'Failed']]) {
      const run = spawnSync('bash', ['-c', Model.vpnConnectScript, 'vpn-connect', command, vpnA], {
        encoding: 'utf8', input: '',
        env: { ...process.env, EXIT_CODE: String(code === 99 ? 0 : code), EXPECTED_UUID: code === 99 ? vpnB : vpnA },
      });
      assert.equal(run.stdout.trim(), word, `exit ${code}`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
  assert.doesNotMatch(Model.vpnConnectScript, /eval|sudo|pkexec|nmcli/);
});

test('Tailscale guard: no capability declares the tailscale package (TODO-023)', () => {
  const walk = dir => readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
  const files = walk(path.join(repo, 'capabilities')).filter(file => path.basename(file) === 'packages');
  assert.ok(files.length > 0, 'no capabilities/**/packages files found');
  for (const file of files) {
    const names = readFileSync(file, 'utf8').split('\n').map(line => line.replace(/#.*/, '').trim().split(/\s+/)[0]);
    assert.equal(names.includes('tailscale'), false,
      'Tailscale is now a MirrorOS package: implement the captive-portal exit-node pause (TODO-023, '
      + 'docs/technical-interviews/story-4-4-network-panel_log.md) and then update this guard '
      + `(${path.relative(repo, file)})`);
  }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { renderPlan, renderSummary } from '../../../install/plan/render-plan.mjs';
import { planFixturesRoot, ROOT_ACCOUNT_MODES, STORAGE_OPTION_NAMES } from './build-fixtures.mjs';
import { CANARY, generate } from './helpers.mjs';

const HEADINGS = [
  '1. Target',
  '2. Choices and defaults',
  '3. Destructive operations',
  '4. Operations in order',
  '5. Secret requirements',
  '6. Hardware-derived selections',
  '7. Warnings',
  '8. Digest and bindings',
];

function planFor(storageOption, rootAccount, extra = {}) {
  const choices = { ...extra };
  if (storageOption !== 'ext4-systemd-boot') choices.storage_option = storageOption;
  if (rootAccount !== 'locked') choices.root_account = rootAccount;
  return generate({ choices }).plan;
}

test('the render has the eight sections in review-flow order', () => {
  const text = renderPlan(planFor('ext4-systemd-boot', 'locked'));
  const positions = HEADINGS.map(heading => text.indexOf(`\n${heading}\n`));
  assert.ok(positions.every(position => position > 0), positions.join());
  assert.deepEqual([...positions].sort((a, b) => a - b), positions);
});

test('the render is plain text without ANSI sequences or tabs', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      const text = renderPlan(planFor(storageOption, rootAccount));
      assert.doesNotMatch(text, /\u001b/);
      assert.doesNotMatch(text, /\t/);
      assert.ok(text.endsWith('\n') && !text.endsWith('\n\n'));
    }
  }
});

test('lines stay within 80 columns except for unavoidable long values', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    const text = renderPlan(planFor(storageOption, 'password'));
    for (const line of text.split('\n')) {
      if (line.length <= 80) continue;
      const lastToken = line.trim().split(/\s+/).at(-1);
      assert.ok(lastToken.length >= 40 && line.length - lastToken.length <= 80, `too long: ${line}`);
    }
  }
});

test('destructive steps are marked and the destroyed layout is shown', () => {
  const text = renderPlan(planFor('ext4-systemd-boot', 'locked'));
  assert.equal(text.split('\n').filter(line => /^\s+DESTRUCTIVE\s+\w+$/.test(line)).length, 4);
  assert.equal(text.split('\n').filter(line => /^\s+\d+\. \w+\s+DESTRUCTIVE$/.test(line)).length, 4);
  assert.match(text, /this content will be destroyed/);
  assert.match(text, /\/dev\/vda2 .*ext4/);
});

test('choices show their value, provenance, source, and editable marker', () => {
  const text = renderPlan(planFor('ext4-systemd-boot', 'locked'));
  assert.match(text, /hostname: mirroros-ref\n\s+provenance personal_preference; source override \[editable\]/);
  assert.match(text, /kernel: linux\n\s+provenance technical_necessity; source policy\n/);
  assert.match(text, /target_disk: virtio-SYNTH-VDA-0001\n\s+provenance hardware_detection; source detected \[editable\]/);
  assert.match(text, /tier default; filesystem ext4; boot loader systemd-boot/);
});

test('the render shows the digest of the plan and reflects an edit', () => {
  const plan = planFor('ext4-systemd-boot', 'locked');
  assert.ok(renderPlan(plan).includes(plan.digest.value));
  const edited = planFor('btrfs-rescue', 'locked', { hostname: 'edited' });
  const text = renderPlan(edited);
  assert.ok(text.includes(edited.digest.value));
  assert.ok(!text.includes(plan.digest.value));
  assert.match(text, /hostname: edited\n\s+provenance personal_preference; source choice/);
  assert.match(text, /create_btrfs_subvolumes/);
  assert.notEqual(text, renderPlan(plan));
});

test('secrets are named without values and the root password only when chosen', () => {
  assert.doesNotMatch(renderPlan(planFor('ext4-systemd-boot', 'locked')), /root_password/);
  const text = renderPlan(planFor('ext4-systemd-boot', 'password'));
  assert.match(text, /\n  user_password\n/);
  assert.match(text, /\n  root_password\n/);
  assert.match(text, /Values are never stored in the plan/);
  assert.doesNotMatch(text, new RegExp(CANARY));
});

test('experimental options and detected capabilities are explained', () => {
  const text = renderPlan(planFor('btrfs-limine', 'locked'));
  assert.match(text, /tier experimental/);
  assert.match(text, /storage_option_experimental: .*experimental/);
  assert.match(text, /rule not_evaluated; next story 2\.6/);
  assert.match(renderPlan(planFor('ext4-systemd-boot', 'locked')), /7\. Warnings\n=+\n {2}None\./);
});

test('the render is a pure function of the plan', () => {
  const plan = planFor('btrfs-rescue', 'password');
  const before = JSON.stringify(plan);
  assert.equal(renderPlan(plan), renderPlan(structuredClone(plan)));
  assert.equal(JSON.stringify(plan), before);
});

test('the render matches the committed snapshots', () => {
  for (const [storageOption, rootAccount] of [['ext4-systemd-boot', 'locked'], ['btrfs-limine', 'password']]) {
    const path = join(planFixturesRoot, 'render', `${storageOption}--${rootAccount}.txt`);
    const text = renderPlan(planFor(storageOption, rootAccount));
    if (process.env.UPDATE_SNAPSHOTS === '1') {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, text);
    }
    assert.equal(readFileSync(path, 'utf8'), text, path);
  }
});

test('the console summary lists the decision data and ends with the review sentence', () => {
  const plan = planFor('btrfs-rescue', 'password');
  const lines = renderSummary(plan, 'evidence/install/run/installation-plan.json').trimEnd().split('\n');
  assert.deepEqual(lines, [
    'Target: reference-vm',
    'Disk: virtio-SYNTH-VDA-0001 (34359738368 bytes (32.0 GiB))',
    'Storage option: btrfs-rescue (supported)',
    'Destructive operations: 4',
    'Secrets required: user_password, root_password',
    `Digest: sha256 ${plan.digest.value}`,
    'Plan: evidence/install/run/installation-plan.json',
    'Review installation-plan.txt; approval is not part of this stage.',
  ]);
});

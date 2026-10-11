import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { renderPlan, renderSummary } from '../../../install/plan/render-plan.mjs';
import { planFixturesRoot, ROOT_ACCOUNT_MODES, STORAGE_OPTION_NAMES } from './build-fixtures.mjs';
import { CANARY, generate, unqualifiedFacts } from './helpers.mjs';

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

test('the shared account password is named without values and root consumes it only when chosen', () => {
  const locked = renderPlan(planFor('ext4-systemd-boot', 'locked'));
  assert.match(locked, /\n  account_password\n/);
  assert.match(locked, /Required by +create_user\n/);
  assert.doesNotMatch(locked, /configure_root_account\n {6}Create|root account receives the same password/);
  const text = renderPlan(planFor('ext4-systemd-boot', 'password'));
  assert.match(text, /\n  account_password\n/);
  assert.match(text, /Required by +create_user, configure_root_account\n/);
  assert.match(text, /root account receives the same password as the user; it is not an\s+independent recovery credential/);
  assert.doesNotMatch(text, /user_password|root_password/);
  assert.match(text, /Values are never stored in the plan/);
  assert.doesNotMatch(text, new RegExp(CANARY));
});

test('the target section shows the observed machine and the profile without claiming qualification', () => {
  const matched = renderPlan(planFor('ext4-systemd-boot', 'locked'));
  assert.match(matched, /Architecture +x86_64\n/);
  assert.match(matched, /Memory +4294967296 bytes \(4\.0 GiB\)\n/);
  assert.match(matched, /Virtualization +kvm\n/);
  assert.match(matched, /System vendor +QEMU\n/);
  assert.match(matched, /Profile +matched reference-vm \(recognized profile; not a\s+qualification of this machine\)/);
  assert.match(matched, /Profile sha256 +[0-9a-f]{64}\n/);
  assert.doesNotMatch(matched, /Facts target/);
  const unqualifiedPlan = generate({ factsDocument: unqualifiedFacts() }).plan;
  const text = renderPlan(unqualifiedPlan);
  assert.match(text, /Profile +unqualified \(matches no known profile; installation is\s+experimental\)/);
  assert.match(text, /machine_unqualified: [\s\S]*no known profile/);
  assert.match(text, /Next: No compatibility or support is\s+promised/);
  assert.doesNotMatch(text, /Profile sha256|Override sha256/);
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
  const cases = [
    ['ext4-systemd-boot', 'locked', {}, 'locked'],
    ['btrfs-limine', 'password', {}, 'password'],
    ['btrfs-rescue', 'locked', { hibernation: false }, 'hibernation-disabled'],
  ];
  for (const [storageOption, rootAccount, extra, name] of cases) {
    const path = join(planFixturesRoot, 'render', `${storageOption}--${name}.txt`);
    const text = renderPlan(planFor(storageOption, rootAccount, extra));
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
    'Profile: matched reference-vm',
    'Disk: virtio-SYNTH-VDA-0001 (34359738368 bytes (32.0 GiB))',
    'Storage option: btrfs-rescue (supported)',
    'Hibernation: enabled (swapfile 4096 MiB)',
    'Destructive operations: 4',
    'Secrets required: account_password',
    `Digest: sha256 ${plan.digest.value}`,
    'Plan: evidence/install/run/installation-plan.json',
    'Review installation-plan.txt; approval is not part of this stage.',
  ]);
});

test('a disabled hibernation plan states that no swapfile will be created, and an enabled one lists it', () => {
  const disabled = planFor('btrfs-rescue', 'locked', { hibernation: false });
  const text = renderPlan(disabled);
  assert.match(text, /hibernation: false\n\s+provenance personal_preference; source choice \[editable\]\n\s+Hibernation is disabled: no swapfile will be created\./);
  assert.doesNotMatch(text, /swapfile_size|create_swapfile|@swap|resume_offset/);
  assert.match(text, /configure_zram/);
  assert.match(renderSummary(disabled, 'plan.json'), /Hibernation: disabled \(no swapfile\)\n/);
  const enabled = renderPlan(planFor('btrfs-rescue', 'locked'));
  assert.match(enabled, /swapfile_size: 4096\n\s+provenance hardware_detection; source detected \[editable\]/);
  assert.match(enabled, /create_swapfile\n[\s\S]*priority: 0/);
  assert.doesNotMatch(enabled, /Hibernation is disabled/);
  assert.match(planFor('ext4-systemd-boot', 'locked', { swapfile_size: 2048 }).warnings.map(item => item.code).join(), /swapfile_below_ram/);
  assert.match(renderPlan(planFor('ext4-systemd-boot', 'locked', { swapfile_size: 2048 })), /swapfile_below_ram:[\s\S]*may be unavailable under large\s+memory/);
});

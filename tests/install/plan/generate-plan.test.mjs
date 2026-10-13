import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { PlanContractError } from '../../../install/plan/canonical-json.mjs';
import { withDigest } from '../../../install/plan/digest-plan.mjs';
import { generatePlan, loadFacts } from '../../../install/plan/generate-plan.mjs';
import { machineProjection, validatePlan } from '../../../install/plan/validate-plan.mjs';
import { buildValidPlan, REFERENCE_MEMORY_BYTES, ROOT_ACCOUNT_MODES, STORAGE_OPTION_NAMES } from './build-fixtures.mjs';
import {
  CANARY,
  assets,
  facts,
  generate,
  policy,
  referenceOverride,
  referenceProfileDefinition,
  removeDirectory,
  secondEligibleDisk,
  temporaryDirectory,
  unqualifiedFacts,
  withMemory,
  writeJson,
} from './helpers.mjs';

const scratch = temporaryDirectory();
const withDigestOf = plan => withDigest(plan);
after(() => removeDirectory(scratch));
const codes = result => result.reasons.map(item => item.code);

test('defaults for the reference VM produce the independent fixture exactly', () => {
  const { plan, reasons } = generate();
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan, buildValidPlan('btrfs-limine', 'locked'));
  assert.deepEqual(validatePlan(plan, { facts: facts() }), []);
});

test('every storage option and root account mode matches its fixture', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const rootAccount of ROOT_ACCOUNT_MODES) {
      const choices = {};
      if (storageOption !== 'btrfs-limine') choices.storage_option = storageOption;
      if (rootAccount !== 'locked') choices.root_account = rootAccount;
      const { plan, reasons } = generate({ choices });
      assert.deepEqual(reasons, []);
      assert.deepEqual(plan, buildValidPlan(storageOption, rootAccount), `${storageOption} ${rootAccount}`);
    }
  }
});

test('every value carries provenance, source, and editable, and the hostname comes from the override', () => {
  const { plan } = generate();
  for (const [key, entry] of Object.entries(plan.choices)) {
    assert.ok(['personal_preference', 'hardware_detection', 'arch_guidance', 'technical_necessity'].includes(entry.provenance), key);
    assert.ok(['policy', 'detected', 'override', 'choice'].includes(entry.source), key);
    assert.equal(typeof entry.editable, 'boolean', key);
  }
  assert.equal(plan.choices.hostname.value, 'mirroros-ref');
  assert.equal(plan.choices.hostname.source, 'override');
  assert.equal(generate({ override: { values: {} } }).plan.choices.hostname.value, 'mirroros');
});

test('the plan identifies the disk, its layout, and the destructive operations', () => {
  const { plan } = generate();
  assert.equal(plan.target.target_id, undefined);
  assert.equal(plan.target.disk.path, '/dev/vda');
  assert.equal(plan.target.disk.by_id, 'virtio-SYNTH-VDA-0001');
  assert.equal(plan.target.disk.serial, 'SYNTH-VDA-0001');
  assert.equal(plan.target.disk.size_bytes, 34359738368);
  assert.equal(plan.target.disk.current_layout.partitions.length, 2);
  assert.deepEqual(plan.operations.filter(operation => operation.destructive).map(operation => operation.kind), [
    'wipe_disk_signatures', 'create_partition_table', 'create_partitions', 'format_filesystems',
  ]);
});

test('the single eligible disk is preselected as hardware detection', () => {
  const { plan } = generate();
  assert.deepEqual(plan.choices.target_disk, {
    value: 'virtio-SYNTH-VDA-0001', provenance: 'hardware_detection', source: 'detected', editable: true,
  });
  assert.equal(plan.hardware_selections.selections[0].id, 'target_disk');
  assert.equal(plan.hardware_selections.selections[0].rule, 'single_eligible_disk');
  assert.equal(plan.hardware_selections.selections[1].id, 'boot_mode');
  assert.equal(plan.hardware_selections.detected_capabilities, undefined);
});

test('several eligible disks are never guessed', () => {
  const result = generate({ factsDocument: secondEligibleDisk(facts()) });
  assert.equal(result.plan, undefined);
  assert.deepEqual(codes(result), ['disk_selection_required']);
  assert.match(result.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  assert.match(result.reasons[0].message, /virtio-SYNTH-VDB-0002/);
  assert.doesNotMatch(result.reasons[0].message, /sr0/);
});

test('a choice selects among several disks and is recorded as a choice', () => {
  const many = secondEligibleDisk(facts());
  const { plan, reasons } = generate({ factsDocument: many, choices: { target_disk: 'virtio-SYNTH-VDB-0002' } });
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan.choices.target_disk, {
    value: 'virtio-SYNTH-VDB-0002', provenance: 'personal_preference', source: 'choice', editable: true,
  });
  assert.equal(plan.target.disk.path, '/dev/vdb');
  assert.equal(plan.hardware_selections.selections.some(entry => entry.id === 'target_disk'), false);
  const byPath = generate({ factsDocument: many, choices: { target_disk: '/dev/vdb' } });
  assert.equal(byPath.plan.choices.target_disk.value, 'virtio-SYNTH-VDB-0002');
});

test('ineligible and unknown disks are rejected with the eligible candidates', () => {
  const ineligible = generate({ choices: { target_disk: '/dev/sr0' } });
  assert.deepEqual(codes(ineligible), ['disk_ineligible']);
  assert.match(ineligible.reasons[0].message, /live_medium/);
  assert.match(ineligible.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  const unknown = generate({ choices: { target_disk: `${CANARY}-disk` } });
  assert.deepEqual(codes(unknown), ['disk_unknown']);
  assert.match(unknown.reasons[0].message, /virtio-SYNTH-VDA-0001/);
  assert.doesNotMatch(JSON.stringify(unknown), new RegExp(CANARY));
});

test('a disk without by_id is accepted by path with a warning', () => {
  const noById = facts();
  delete noById.layers.detected.storage.disks[0].identity.by_id;
  const { plan, reasons } = generate({ factsDocument: noById });
  assert.deepEqual(reasons, []);
  assert.equal(plan.choices.target_disk.value, '/dev/vda');
  assert.deepEqual(plan.warnings.map(warning => warning.code), ['disk_without_by_id']);
  assert.deepEqual(validatePlan(plan, { facts: noById }), []);
});

test('a disk with neither by_id nor path is rejected', () => {
  const anonymous = facts();
  delete anonymous.layers.detected.storage.disks[0].identity.by_id;
  delete anonymous.layers.detected.storage.disks[0].identity.path;
  assert.deepEqual(codes(generate({ factsDocument: anonymous })), ['disk_unidentifiable']);
});

test('storage options show their tier and only an experimental tier warns', () => {
  const tiers = Object.fromEntries(STORAGE_OPTION_NAMES.map(name => {
    const { plan } = generate({ choices: { storage_option: name } });
    return [name, [plan.choices.storage_option.tier, plan.warnings.map(warning => warning.code)]];
  }));
  assert.deepEqual(tiers, {
    'ext4-systemd-boot': ['supported', []],
    'btrfs-rescue': ['supported', []],
    'btrfs-limine': ['default', []],
  });
  const experimental = structuredClone(policy);
  experimental.storageOptions['btrfs-rescue'].tier = 'experimental';
  const { plan } = generate({ choices: { storage_option: 'btrfs-rescue' }, policyOverride: experimental });
  assert.deepEqual(plan.warnings.map(warning => warning.code), ['storage_option_experimental']);
});

test('one shared account password names the root operation only when root password access is enabled', () => {
  const locked = generate().plan;
  assert.deepEqual(locked.secret_requirements.map(secret => secret.name), ['account_password']);
  assert.deepEqual(locked.secret_requirements[0].required_by, ['create_user']);
  const password = generate({ choices: { root_account: 'password' } }).plan;
  assert.deepEqual(password.secret_requirements.map(secret => secret.name), ['account_password']);
  assert.deepEqual(password.secret_requirements[0].required_by, ['create_user', 'configure_root_account']);
  for (const plan of [locked, password]) {
    const [secret] = plan.secret_requirements;
    assert.deepEqual(Object.keys(secret), ['name', 'purpose', 'required_by', 'channel', 'provenance']);
    assert.equal(secret.channel, 'protected_prompt');
    assert.equal(secret.provenance, 'technical_necessity');
    assert.doesNotMatch(JSON.stringify(plan), /root_password|user_password|"(password|hash)":/);
  }
});

test('a recognized profile is recorded with the observed machine and its definition binding', () => {
  const { plan } = generate();
  assert.deepEqual(plan.target.profile, { status: 'matched', profile_id: 'reference-vm' });
  assert.deepEqual(plan.target.machine, {
    architecture: 'x86_64',
    memory_total_bytes: 4294967296,
    virtualization: 'kvm',
    dmi: { sys_vendor: 'QEMU', product_name: 'Standard PC (Q35 + ICH9, 2009)' },
  });
  assert.deepEqual(plan.target.machine, machineProjection(facts()));
  assert.equal(plan.policy_binding.profile_definition_sha256, referenceProfileDefinition().sha256);
  assert.deepEqual(plan.warnings.map(warning => warning.code), []);
});

test('an unqualified machine produces a plan bound to its observed identity, with no profile adjustments', () => {
  const unqualified = unqualifiedFacts();
  assert.deepEqual(unqualified.profile, { status: 'unqualified' });
  const { plan, reasons } = generate({ factsDocument: unqualified });
  assert.deepEqual(reasons, []);
  assert.deepEqual(plan.target.profile, { status: 'unqualified' });
  assert.equal(plan.target.machine.dmi.sys_vendor, 'Synthetic Vendor');
  assert.equal(plan.policy_binding.profile_definition_sha256, undefined);
  assert.equal(plan.policy_binding.override_sha256, undefined);
  assert.equal(plan.choices.hostname.value, 'mirroros');
  assert.equal(plan.choices.hostname.source, 'policy');
  assert.deepEqual(plan.warnings.map(warning => warning.code), ['machine_unqualified']);
  assert.match(plan.warnings[0].message, /no known profile/);
  assert.match(plan.warnings[0].next_step, /no compatibility or support is promised/i);
  assert.deepEqual(validatePlan(plan, { facts: unqualified }), []);
});

test('the machine projection omits what was not observed and plans keep the field availability', () => {
  const sparse = facts();
  delete sparse.layers.detected.hardware.virtualization;
  delete sparse.layers.detected.firmware.dmi.product_name;
  const { plan } = generate({ factsDocument: sparse });
  assert.deepEqual(plan.target.machine, { architecture: 'x86_64', memory_total_bytes: 4294967296, dmi: { sys_vendor: 'QEMU' } });
  assert.deepEqual(validatePlan(plan, { facts: sparse }), []);
  const none = facts();
  delete none.layers.detected.firmware.dmi;
  assert.equal(generate({ factsDocument: none }).plan.target.machine.dmi, undefined);
});

test('language, regional formats, and keyboard are independent and the formats follow the language by default', () => {
  const english = generate().plan;
  assert.equal(english.choices.regional_format.value, 'follow_language');
  assert.deepEqual(english.choices.locales.value, ['en_US.UTF-8']);
  const spanish = generate({ choices: { lang: 'es_ES.UTF-8' } }).plan;
  assert.deepEqual(spanish.choices.locales.value, ['es_ES.UTF-8']);
  assert.equal(spanish.choices.locale_categories.value.LC_TIME, 'es_ES.UTF-8');
  const mixed = generate({ choices: { lang: 'en_US.UTF-8', regional_format: 'es_ES.UTF-8', console_keymap: 'es' } }).plan;
  assert.deepEqual(mixed.choices.locales.value, ['en_US.UTF-8', 'es_ES.UTF-8']);
  assert.deepEqual(mixed.choices.locale_categories.value, {
    LANG: 'en_US.UTF-8',
    LC_TIME: 'es_ES.UTF-8',
    LC_NUMERIC: 'es_ES.UTF-8',
    LC_MONETARY: 'es_ES.UTF-8',
    LC_MEASUREMENT: 'es_ES.UTF-8',
  });
  assert.equal(mixed.choices.console_keymap.value, 'es');
  const explicitStays = generate({ choices: { regional_format: 'es_ES.UTF-8', lang: 'es_ES.UTF-8' } }).plan;
  assert.deepEqual(explicitStays.choices.locales.value, ['es_ES.UTF-8']);
  for (const plan of [english, spanish, mixed, explicitStays]) {
    assert.equal('LC_ALL' in plan.choices.locale_categories.value, false);
    for (const key of ['locales', 'locale_categories']) {
      assert.deepEqual(
        [plan.choices[key].provenance, plan.choices[key].source, plan.choices[key].editable],
        ['technical_necessity', 'policy', false],
      );
    }
    assert.deepEqual(validatePlan(plan, { facts: facts() }), []);
  }
});

test('an unchanged proposal keeps its provenance and source, and only a changed value becomes a choice', () => {
  const same = generate({ choices: { hostname: 'mirroros-ref', swapfile_size: 4096, target_disk: 'virtio-SYNTH-VDA-0001' } }).plan;
  assert.deepEqual(same, generate().plan);
  assert.equal(same.choices.hostname.source, 'override');
  assert.equal(same.choices.target_disk.source, 'detected');
  const changed = generate({ choices: { swapfile_size: 2048 } }).plan;
  assert.deepEqual(
    [changed.choices.swapfile_size.provenance, changed.choices.swapfile_size.source],
    ['personal_preference', 'choice'],
  );
});

test('identical inputs give an identical digest and no run-specific content', () => {
  const first = generate().plan;
  const second = generate().plan;
  assert.deepEqual(first, second);
  assert.equal(first.digest.value, second.digest.value);
  assert.doesNotMatch(JSON.stringify(first), /"(timestamp|generated_at|created_at)"/);
  assert.equal(first.run_id, undefined);
});

test('the digest binds the facts, the policy, the override, and the choices', () => {
  const base = generate().plan.digest.value;
  assert.notEqual(generate({ factsDocument: withMemory(facts(), REFERENCE_MEMORY_BYTES + 1) }).plan.digest.value, base);
  const changedAssets = structuredClone(assets);
  changedAssets.configure_zram.sha256 = 'f'.repeat(64);
  assert.notEqual(generate({ assetsOverride: changedAssets }).plan.digest.value, base);
  const movedAsset = structuredClone(assets);
  movedAsset.configure_memory_reclaim.destination = '/usr/lib/sysctl.d/70-other.conf';
  // A destination that differs from the policy declaration is an internal contract failure, never a plan.
  assert.throws(() => generate({ assetsOverride: movedAsset }), PlanContractError);
  const changedPolicy = structuredClone(policy);
  changedPolicy.sha256 = 'f'.repeat(64);
  assert.notEqual(generate({ policyOverride: changedPolicy }).plan.digest.value, base);
  assert.notEqual(generate({ override: { values: { hostname: 'other' }, sha256: referenceOverride().sha256 } }).plan.digest.value, base);
  assert.notEqual(generate({ override: { values: {} } }).plan.digest.value, base);
  assert.notEqual(generate({ choices: { hostname: 'edited' } }).plan.digest.value, base);
  const { plan } = generate();
  assert.equal(plan.facts_binding.run_id, facts().source.run_id);
  assert.equal(plan.facts_binding.dirty, false);
  assert.equal(plan.policy_binding.policy_sha256, policy.sha256);
  assert.equal(plan.policy_binding.override_sha256, referenceOverride().sha256);
  assert.equal(generate({ override: { values: {} } }).plan.policy_binding.override_sha256, undefined);
});

test('an edited regeneration is a new plan and leaves the original untouched', () => {
  const original = generate().plan;
  const snapshot = JSON.stringify(original);
  const edited = generate({ choices: { hostname: 'edited', storage_option: 'btrfs-rescue' } }).plan;
  assert.notEqual(edited.digest.value, original.digest.value);
  assert.equal(edited.choices.hostname.value, 'edited');
  assert.equal(edited.choices.hostname.source, 'choice');
  assert.equal(JSON.stringify(original), snapshot);
  for (const plan of [original, edited]) {
    assert.equal(plan.approved, undefined);
    assert.equal(plan.approval, undefined);
  }
});

function withDiskSize(document, bytes) {
  const copy = structuredClone(document);
  copy.layers.detected.storage.disks[0].identity.size_bytes = bytes;
  copy.effective['storage.disks'].value = copy.layers.detected.storage.disks;
  return copy;
}

test('choices that contradict the disk are input errors', () => {
  // The ESP, the root minimum, and the default swapfile need 22548578304 bytes; the root minimum and ESP alone need 18253611008.
  const small = withDiskSize(facts(), 19000000000);
  const tooSmall = generate({ factsDocument: small });
  assert.deepEqual(codes(tooSmall), ['plan_size_does_not_fit']);
  assert.match(tooSmall.reasons[0].next_step, /disable hibernation/);
  assert.deepEqual(codes(generate({ factsDocument: small, choices: { swapfile_size: 4096 } })), ['plan_size_does_not_fit']);
  // The size is never reduced and hibernation is never disabled silently; the user decides.
  const disabled = generate({ factsDocument: small, choices: { hibernation: false } });
  assert.deepEqual(disabled.reasons, []);
  assert.equal(disabled.plan.choices.hibernation.value, false);
  const tinyDisk = withDiskSize(facts(), 17000000000);
  assert.deepEqual(codes(generate({ factsDocument: tinyDisk, choices: { hibernation: false } })), ['plan_size_does_not_fit']);
  const fits = withDiskSize(facts(), 22548578304);
  assert.deepEqual(generate({ factsDocument: fits }).reasons, []);
  assert.deepEqual(codes(generate({ factsDocument: withDiskSize(facts(), 22548578303) })), ['plan_size_does_not_fit']);
});

test('a generated plan that fails its own validator is an invariant violation', () => {
  const broken = structuredClone(policy);
  broken.policy.esp.value.size_bytes = 1.5;
  assert.throws(() => generate({ policyOverride: broken }), PlanContractError);
  const noOption = structuredClone(policy);
  noOption.storageOptions['btrfs-limine'].tier = 'unlisted';
  assert.throws(() => generate({ policyOverride: noOption }), PlanContractError);
});

test('planted secrets never reach the plan', () => {
  const { plan } = generate({ choices: { root_account: 'password' } });
  assert.doesNotMatch(JSON.stringify(plan), new RegExp(CANARY));
  assert.deepEqual(generatePlan({ facts: facts(), policy, profileDefinition: referenceProfileDefinition(), assets }).reasons, []);
});

test('facts that are missing, invalid, or of an unknown format exit as input errors', () => {
  const load = document => loadFacts(writeJson(scratch, `facts-${Math.random()}.json`, document));
  assert.deepEqual(codes(load(facts())), []);
  assert.deepEqual(codes(load('{not json')), ['facts_invalid']);
  assert.deepEqual(codes(loadFacts(`${scratch}/absent.json`)), ['facts_invalid']);
  assert.deepEqual(codes(load([])), ['facts_format_unknown']);
  assert.deepEqual(codes(load({ format_version: 1 })), ['facts_format_unknown']);
  assert.deepEqual(codes(load({ format_version: 3 })), ['facts_format_unknown']);
  const extra = facts();
  extra.layers.detected.firmware.product_serial = CANARY;
  const rejected = load(extra);
  assert.deepEqual(codes(rejected), ['facts_invalid']);
  const invalid = facts('bios');
  assert.equal(invalid.validation.status, 'invalid');
  const result = load(invalid);
  assert.deepEqual(codes(result), ['facts_invalid']);
  assert.match(result.reasons[0].message, /boot_mode_not_uefi/);
});

const hasSwap = plan => plan.operations.some(operation => operation.kind === 'create_swapfile');
const resumeTokens = plan => plan.choices.kernel_cmdline.value.split(' ').filter(token => /^resume(_offset)?=/.test(token));
const offsetResolutions = plan => plan.operations.flatMap(operation => operation.resolved_at_apply ?? []).filter(item => item.name === 'resume_offset');
const kinds = plan => plan.operations.map(operation => operation.kind);

test('hibernation defaults to enabled with the RAM-derived swapfile for every storage option', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    const { plan, reasons } = generate({ choices: { storage_option: storageOption } });
    assert.deepEqual(reasons, [], storageOption);
    assert.deepEqual(plan.choices.hibernation, { value: true, provenance: 'personal_preference', source: 'policy', editable: true });
    assert.deepEqual(plan.choices.swapfile_size, { value: 4096, provenance: 'hardware_detection', source: 'detected', editable: true });
    assert.deepEqual(plan, buildValidPlan(storageOption, 'locked'), storageOption);
    const swapfile = plan.operations.find(operation => operation.kind === 'create_swapfile');
    assert.deepEqual(swapfile.parameters, { path: '/swapfile', size_mib: 4096, priority: 0 });
    assert.deepEqual(swapfile.resolved_at_apply.map(item => item.name), ['resume_offset']);
    assert.equal(resumeTokens(plan).length, 2);
    assert.equal(offsetResolutions(plan).length, 2);
    if (storageOption !== 'ext4-systemd-boot') {
      for (const kind of ['create_btrfs_subvolumes', 'mount_target']) {
        assert.ok(plan.operations.find(operation => operation.kind === kind).parameters.subvolumes.includes('@swap'), `${storageOption} ${kind}`);
      }
    }
    assert.deepEqual(plan.warnings.filter(warning => warning.code === 'swapfile_below_ram'), []);
  }
});

test('disabled hibernation removes the swapfile, @swap, and every resume setting but keeps zram', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    const enabled = generate({ choices: { storage_option: storageOption } }).plan;
    const { plan, reasons } = generate({ choices: { storage_option: storageOption, hibernation: false } });
    assert.deepEqual(reasons, [], storageOption);
    assert.deepEqual(plan, buildValidPlan(storageOption, 'locked', false), storageOption);
    assert.deepEqual(plan.choices.hibernation, { value: false, provenance: 'personal_preference', source: 'choice', editable: true });
    assert.equal('swapfile_size' in plan.choices, false);
    assert.equal(hasSwap(plan), false);
    assert.deepEqual(resumeTokens(plan), []);
    assert.deepEqual(offsetResolutions(plan), []);
    assert.ok(plan.choices.kernel_cmdline.value.split(' ').includes('zswap.enabled=0'));
    assert.ok(plan.choices.kernel_cmdline.value.startsWith('root=UUID=<root> rw'));
    assert.deepEqual(plan.operations.find(operation => operation.kind === 'install_bootloader').resolved_at_apply, [{ name: 'root_uuid', method: 'blkid' }]);
    assert.ok(kinds(plan).includes('configure_zram') && kinds(plan).includes('configure_memory_reclaim'));
    assert.deepEqual(kinds(plan), kinds(enabled).filter(kind => kind !== 'create_swapfile'));
    assert.doesNotMatch(JSON.stringify(plan), /@swap|swapfile_size|create_swapfile|resume_offset=|resume=/);
    assert.equal(plan.warnings.some(warning => warning.code === 'swapfile_below_ram'), false);
    if (storageOption !== 'ext4-systemd-boot') {
      const subvolumes = plan.operations.find(operation => operation.kind === 'create_btrfs_subvolumes').parameters.subvolumes;
      assert.deepEqual(subvolumes, ['@', '@home', '@log', '@pkg', '@snapshots']);
      assert.deepEqual(plan.operations.find(operation => operation.kind === 'mount_target').parameters.subvolumes, subvolumes);
      assert.ok(kinds(plan).includes('configure_snapper'));
    }
    assert.deepEqual(validatePlan(plan, { facts: facts(), assets }), []);
  }
});

test('zram and memory reclaim follow the packages, in order, with asset digests, and zswap is disabled', () => {
  for (const storageOption of STORAGE_OPTION_NAMES) {
    for (const hibernation of [true, false]) {
      const { plan } = generate({ choices: { storage_option: storageOption, hibernation } });
      const order = kinds(plan);
      const packages = order.indexOf('install_packages');
      assert.equal(order[packages + 1], 'configure_zram');
      assert.equal(order[packages + 2], 'configure_memory_reclaim');
      assert.equal(order[packages + 3], 'generate_fstab');
      assert.deepEqual(plan.operations[packages].parameters.packages.filter(name => name === 'zram-generator'), ['zram-generator']);
      assert.equal(plan.choices.zram.value.package_source, 'arch_official_repository');
      assert.deepEqual(plan.operations[packages + 1].parameters, {
        destination: '/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf',
        source_sha256: assets.configure_zram.sha256,
        zram_size: 'ram',
        compression_algorithm: 'zstd',
        swap_priority: 100,
      });
      assert.deepEqual(plan.operations[packages + 2].parameters, {
        destination: '/usr/lib/sysctl.d/60-mirroros-memory.conf',
        source_sha256: assets.configure_memory_reclaim.sha256,
        'vm.swappiness': 180,
        'vm.page-cluster': 0,
        'vm.watermark_scale_factor': 125,
        'vm.watermark_boost_factor': 0,
      });
      assert.ok(plan.choices.kernel_cmdline.value.split(' ').includes('zswap.enabled=0'));
      assert.equal(plan.operations.filter(operation => operation.destructive).length, 4);
    }
  }
});

test('detected memory rounds up to whole GiB for the maximum, including fractional and very large memory', () => {
  const cases = [
    [4090589184, 4096], // 3.81 GiB, the memory of the reference VM evidence
    [REFERENCE_MEMORY_BYTES, 4096],
    [REFERENCE_MEMORY_BYTES + 1, 5120],
    [1073741824, 1024],
    [1073741825, 2048],
    [536870912, 1024], // 0.5 GiB still rounds up to one GiB
    [8589934592, 8192],
    [103079215104, 98304], // 96 GiB, above the old fixed 64 GiB ceiling
    [103079215105, 99328],
  ];
  const roomy = withDiskSize(facts(), 1024 ** 4);
  for (const [bytes, maximum] of cases) {
    const { plan, reasons } = generate({ factsDocument: withMemory(roomy, bytes) });
    assert.deepEqual(reasons, [], String(bytes));
    assert.equal(plan.choices.swapfile_size.value, maximum, String(bytes));
    assert.equal(plan.target.machine.memory_total_bytes, bytes);
    assert.equal(plan.operations.find(operation => operation.kind === 'create_swapfile').parameters.size_mib, maximum);
    const above = generate({ factsDocument: withMemory(roomy, bytes), choices: { swapfile_size: maximum + 1 } });
    assert.deepEqual(codes(above), ['choices_invalid_value'], `${bytes} above`);
  }
});

test('sizes inside the range are accepted, the minimum is not a claim, and sizes below raw RAM warn', () => {
  const warning = plan => plan.warnings.filter(item => item.code === 'swapfile_below_ram');
  const minimum = generate({ choices: { swapfile_size: 512 } });
  assert.deepEqual(minimum.reasons, []);
  assert.equal(minimum.plan.choices.swapfile_size.source, 'choice');
  assert.equal(warning(minimum.plan).length, 1);
  assert.match(warning(minimum.plan)[0].message, /may be unavailable under large memory workloads/);
  assert.match(warning(minimum.plan)[0].message, /used memory and free swapfile space/);
  assert.match(warning(minimum.plan)[0].next_step, /not a guarantee/);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: 511 } })), ['choices_invalid_value']);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: 0 } })), ['choices_invalid_value']);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: -1 } })), ['choices_invalid_value']);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: 1.5 } })), ['choices_invalid_value']);
  assert.deepEqual(codes(generate({ choices: { swapfile_size: '2048' } })), ['choices_invalid_value']);
  // 4096 MiB equals the 4 GiB of the fixture: no warning. One byte more memory makes the same size smaller than raw RAM.
  assert.equal(warning(generate({ choices: { swapfile_size: 4096 } }).plan).length, 0);
  assert.equal(warning(generate({ choices: { swapfile_size: 4095 } }).plan).length, 1);
  const justAbove = withMemory(facts(), REFERENCE_MEMORY_BYTES + 1);
  assert.equal(warning(generate({ factsDocument: justAbove, choices: { swapfile_size: 4096 } }).plan).length, 1);
  assert.equal(warning(generate({ factsDocument: justAbove }).plan).length, 0);
  const justBelow = withMemory(facts(), REFERENCE_MEMORY_BYTES - 1);
  assert.equal(warning(generate({ factsDocument: justBelow, choices: { swapfile_size: 4096 } }).plan).length, 0);
  assert.deepEqual(generate({ choices: { swapfile_size: 2048 } }).plan.choices.swapfile_size.value, 2048);
});

test('missing or unusable detected memory fails generation with repeated discovery guidance', () => {
  for (const bytes of [undefined, 0, -1, 1.5, 2 ** 53, 'unknown', null]) {
    const document = facts();
    if (bytes === undefined) {
      delete document.effective['hardware.memory_total_bytes'];
    } else {
      document.effective['hardware.memory_total_bytes'] = { value: bytes, source: 'detected' };
    }
    for (const hibernation of [true, false]) {
      const result = generate({ factsDocument: document, choices: { hibernation } });
      assert.equal(result.plan, undefined);
      assert.deepEqual(codes(result), ['memory_unavailable'], `${String(bytes)} ${hibernation}`);
      assert.match(result.reasons[0].next_step, /discover/);
    }
  }
  assert.deepEqual(codes(generate({ factsDocument: withMemory(facts(), undefined) })), ['memory_unavailable']);
});

test('contradictory explicit choices are rejected rather than ignored', () => {
  const result = generate({ choices: { hibernation: false, swapfile_size: 2048 } });
  assert.equal(result.plan, undefined);
  assert.deepEqual(codes(result), ['choices_conflict']);
  assert.match(result.reasons[0].next_step, /Remove swapfile_size/);
  assert.deepEqual(codes(generate({ choices: { hibernation: false, swapfile_size: 99999 } })), ['choices_conflict']);
  assert.deepEqual(generate({ choices: { hibernation: true, swapfile_size: 2048 } }).reasons, []);
});

test('generation requires the configuration assets and binds their destinations and digests', () => {
  assert.throws(() => generatePlan({ facts: facts(), policy, profileDefinition: referenceProfileDefinition() }), PlanContractError);
  const { plan } = generate();
  const zram = plan.operations.find(operation => operation.kind === 'configure_zram').parameters;
  assert.equal(zram.source_sha256, assets.configure_zram.sha256);
  assert.match(zram.source_sha256, /^[0-9a-f]{64}$/);
  const stale = structuredClone(plan);
  stale.operations.find(operation => operation.kind === 'configure_zram').parameters.source_sha256 = 'a'.repeat(64);
  assert.ok(codes({ reasons: validatePlan(withDigestOf(stale), { facts: facts(), assets }) }).includes('configuration_asset_mismatch'));
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { NEXT_STEP_REGENERATE, compareSafety, selectedDisk } from '../../../install/confirmation/compare-safety.mjs';
import {
  assets, clone, currentHashes, facts, firstDisk, generate, unqualifiedFacts, unqualifiedHashes, withDisk, withMemory,
} from './helpers.mjs';

function compare({ plan = generate().plan, fresh = facts(), hashes = currentHashes(), baselineFacts, currentAssets = assets } = {}) {
  return compareSafety({ plan, facts: fresh, hashes, baselineFacts, assets: currentAssets });
}

const codes = reasons => reasons.map(item => item.code);

test('identical facts and hashes give no reasons', () => {
  assert.deepEqual(compare({ baselineFacts: facts() }), []);
});

test('rediscovery with a different run id is not a difference', () => {
  const fresh = clone(facts());
  fresh.source.run_id = '20261008T130000Z-aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
  assert.deepEqual(compare({ fresh }), []);
});

test('every reason carries the regenerate next step', () => {
  const fresh = withDisk(facts(), disk => {
    disk.layout.partitions = [];
  });
  const reasons = compare({ fresh });
  assert.ok(reasons.length > 0);
  for (const item of reasons) {
    assert.deepEqual(Object.keys(item), ['code', 'message', 'next_step']);
    assert.equal(item.next_step, NEXT_STEP_REGENERATE);
  }
});

test('no fabricated target id takes part in the comparison', () => {
  const fresh = clone(facts());
  delete fresh.source.requested_profile_id;
  assert.deepEqual(compare({ fresh }), []);
});

test('each observed machine field is compared as machine_identity_changed', () => {
  const changes = {
    'architecture changed': detected => { detected.hardware.architecture = 'aarch64'; },
    'memory_total_bytes changed': detected => { detected.hardware.memory_total_bytes += 1048576; },
    'virtualization changed': detected => { detected.hardware.virtualization = 'none'; },
    'dmi.sys_vendor changed': detected => { detected.firmware.dmi.sys_vendor = 'Other Vendor'; },
    'dmi.product_name changed': detected => { detected.firmware.dmi.product_name = 'Other Product'; },
  };
  for (const [expected, change] of Object.entries(changes)) {
    const fresh = clone(facts());
    change(fresh.layers.detected);
    const reasons = compare({ fresh }).filter(item => item.code === 'machine_identity_changed');
    assert.equal(reasons.length, 1, expected);
    assert.ok(reasons[0].message.includes(expected.replace(/ changed$/, '')), expected);
  }
});

test('a machine field that appeared or disappeared is machine_identity_changed', () => {
  const gone = clone(facts());
  delete gone.layers.detected.hardware.virtualization;
  const missing = compare({ fresh: gone }).find(item => item.code === 'machine_identity_changed');
  assert.match(missing.message, /virtualization is no longer observed/);

  const noVendor = clone(facts());
  delete noVendor.layers.detected.firmware.dmi.sys_vendor;
  const { plan } = generate({ factsDocument: noVendor });
  assert.equal(plan.target.machine.dmi.sys_vendor, undefined);
  const appeared = compare({ plan, fresh: facts() }).find(item => item.code === 'machine_identity_changed');
  assert.match(appeared.message, /dmi\.sys_vendor appeared/);
});

test('a recognized machine that is now unqualified is profile_binding_changed once', () => {
  const reasons = compare({ fresh: unqualifiedFacts(), hashes: unqualifiedHashes() });
  assert.equal(codes(reasons).filter(code => code === 'profile_binding_changed').length, 1);
  assert.ok(!codes(reasons).includes('policy_changed'));
});

test('an unqualified plan on a machine that now matches a profile is profile_binding_changed', () => {
  const { plan } = generate({ factsDocument: unqualifiedFacts() });
  assert.equal(plan.target.profile.status, 'unqualified');
  const fresh = clone(unqualifiedFacts());
  fresh.profile = { status: 'matched', profile_id: 'reference-vm' };
  assert.deepEqual(codes(compare({ plan, fresh, hashes: currentHashes() })).filter(code => code === 'profile_binding_changed'), ['profile_binding_changed']);
});

test('a different matched profile id is profile_binding_changed', () => {
  const fresh = clone(facts());
  fresh.profile = { status: 'matched', profile_id: 'framework-13-pro-amd' };
  assert.deepEqual(codes(compare({ fresh })), ['profile_binding_changed']);
});

test('a changed profile definition hash is profile_binding_changed', () => {
  const hashes = { ...currentHashes(), profile_definition_sha256: 'f'.repeat(64) };
  assert.deepEqual(codes(compare({ hashes })), ['profile_binding_changed']);
});

test('an unqualified machine compares equal to an unqualified plan with only the policy bound', () => {
  const { plan } = generate({ factsDocument: unqualifiedFacts() });
  assert.equal(plan.policy_binding.override_sha256, undefined);
  assert.equal(plan.policy_binding.profile_definition_sha256, undefined);
  assert.deepEqual(compare({ plan, fresh: unqualifiedFacts(), hashes: unqualifiedHashes(), baselineFacts: unqualifiedFacts() }), []);
});

test('a different boot mode is target_identity_changed', () => {
  const fresh = clone(facts());
  fresh.layers.detected.firmware.boot_mode = 'bios';
  assert.deepEqual(codes(compare({ fresh })), ['target_identity_changed']);
});

test('Secure Boot is compared with the first discovery of the run', () => {
  const fresh = clone(facts());
  fresh.layers.detected.firmware.secure_boot = 'enabled';
  assert.deepEqual(codes(compare({ fresh, baselineFacts: facts() })), ['target_identity_changed']);
  assert.deepEqual(compare({ fresh }), []);
});

test('each identity field of the disk is compared', () => {
  const changes = {
    path: '/dev/vdb',
    by_id: 'virtio-SYNTH-VDA-9999',
    serial: 'SYNTH-VDA-9999',
    size_bytes: 68719476736,
    model: 'ADDED-MODEL',
    wwn: 'wwn-0x5000000000000001',
  };
  for (const [key, value] of Object.entries(changes)) {
    const fresh = withDisk(facts(), disk => {
      disk.identity[key] = value;
    });
    const reasons = compare({ fresh });
    assert.ok(codes(reasons).every(code => code === 'target_identity_changed'), `${key}: ${codes(reasons)}`);
    assert.ok(reasons.length > 0, key);
  }
});

test('a missing disk is target_identity_changed', () => {
  const fresh = withDisk(facts(), disk => {
    disk.identity.by_id = 'virtio-SYNTH-OTHER-0002';
  });
  const reasons = compare({ fresh });
  assert.deepEqual(codes(reasons), ['target_identity_changed']);
  assert.match(reasons[0].message, /no longer present/);
});

test('a disk that is no longer eligible is target_layout_changed', () => {
  const fresh = withDisk(facts(), disk => {
    disk.eligible = false;
  });
  assert.deepEqual(codes(compare({ fresh })), ['target_layout_changed']);
});

test('any layout difference is target_layout_changed', () => {
  const edits = {
    'a partition was removed': disk => disk.layout.partitions.pop(),
    'a partition was added': disk => disk.layout.partitions.push({ path: '/dev/vda3', size_bytes: 1048576 }),
    'a filesystem changed': disk => {
      disk.layout.partitions[1].fstype = 'btrfs';
    },
    'a label changed': disk => {
      disk.layout.partitions[0].label = 'OTHER';
    },
    'a partition uuid changed': disk => {
      disk.layout.partitions[0].partuuid = '00000000-0000-4000-8000-0000000000ff';
    },
    'the table type changed': disk => {
      disk.layout.partition_table.type = 'dos';
    },
    'the table was wiped': disk => {
      delete disk.layout.partition_table;
      disk.layout.partitions = [];
    },
  };
  for (const [name, change] of Object.entries(edits)) {
    const reasons = compare({ fresh: withDisk(facts(), change) });
    assert.deepEqual(codes(reasons), ['target_layout_changed'], name);
  }
});

test('a changed policy hash is policy_changed', () => {
  const hashes = { ...currentHashes(), policy_sha256: 'f'.repeat(64) };
  assert.deepEqual(codes(compare({ hashes })), ['policy_changed']);
});

test('a changed, added, or removed override hash is policy_changed', () => {
  assert.deepEqual(codes(compare({ hashes: { ...currentHashes(), override_sha256: 'f'.repeat(64) } })), ['policy_changed']);
  assert.deepEqual(codes(compare({ hashes: { ...currentHashes(), override_sha256: undefined } })), ['policy_changed']);
  const plan = clone(generate().plan);
  delete plan.policy_binding.override_sha256;
  assert.deepEqual(codes(compare({ plan })), ['policy_changed']);
});

test('several differences are all reported', () => {
  const fresh = withDisk(facts(), disk => {
    disk.layout.partitions = [];
  });
  const hashes = { ...currentHashes(), policy_sha256: 'f'.repeat(64) };
  assert.deepEqual(codes(compare({ fresh, hashes })), ['target_layout_changed', 'policy_changed']);
});

test('a disk selected by path is matched by path when the plan has no by_id', () => {
  const noId = withDisk(facts(), disk => {
    delete disk.identity.by_id;
  });
  const { plan } = generate({ factsDocument: noId });
  assert.equal(plan.target.disk.by_id, undefined);
  assert.equal(selectedDisk(plan, noId).identity.path, '/dev/vda');
  assert.deepEqual(compare({ plan, fresh: noId }), []);
  assert.deepEqual(codes(compare({ plan, fresh: facts() })), ['target_identity_changed']);
});

test('the comparison does not modify its inputs', () => {
  const plan = generate().plan;
  const fresh = facts();
  const before = JSON.stringify([plan, fresh]);
  compare({ plan, fresh });
  assert.equal(JSON.stringify([plan, fresh]), before);
  assert.equal(firstDisk(fresh).eligible, true);
});

test('changed or missing detected memory invalidates the plan, with or without hibernation', () => {
  for (const hibernation of [true, false]) {
    const { plan } = generate({ choices: { hibernation } });
    assert.deepEqual(compare({ plan }), [], String(hibernation));
    for (const bytes of [plan.target.machine.memory_total_bytes + 1, plan.target.machine.memory_total_bytes - 1, 8589934592]) {
      const reasons = compare({ plan, fresh: withMemory(facts(), bytes) });
      assert.deepEqual(codes(reasons), ['machine_identity_changed'], `${hibernation} ${bytes}`);
      assert.match(reasons[0].message, /memory_total_bytes changed/);
      assert.equal(reasons[0].next_step, NEXT_STEP_REGENERATE);
    }
    const missing = compare({ plan, fresh: withMemory(facts(), undefined) });
    assert.deepEqual(codes(missing), ['machine_identity_changed'], `${hibernation} missing`);
    assert.match(missing[0].message, /memory_total_bytes is no longer observed/);
  }
});

test('a changed, moved, missing, or damaged configuration asset is configuration_assets_changed', () => {
  const { plan } = generate();
  assert.deepEqual(compare({ plan }), []);
  const variants = {
    'zram hash': { ...assets, configure_zram: { ...assets.configure_zram, sha256: 'a'.repeat(64) } },
    'reclaim hash': { ...assets, configure_memory_reclaim: { ...assets.configure_memory_reclaim, sha256: 'b'.repeat(64) } },
    'zram destination': { ...assets, configure_zram: { ...assets.configure_zram, destination: '/etc/zram.conf' } },
    'reclaim destination': { ...assets, configure_memory_reclaim: { ...assets.configure_memory_reclaim, destination: '/etc/sysctl.conf' } },
    'zram entry gone': { configure_memory_reclaim: assets.configure_memory_reclaim },
    'reclaim entry gone': { configure_zram: assets.configure_zram },
  };
  for (const [name, currentAssets] of Object.entries(variants)) {
    const reasons = compare({ plan, currentAssets });
    assert.deepEqual(codes(reasons), ['configuration_assets_changed'], name);
    assert.equal(reasons[0].next_step, NEXT_STEP_REGENERATE, name);
  }
  // Both assets changed: both are reported.
  const both = compare({ plan, currentAssets: {
    configure_zram: { ...assets.configure_zram, sha256: 'a'.repeat(64) },
    configure_memory_reclaim: { ...assets.configure_memory_reclaim, sha256: 'b'.repeat(64) },
  } });
  assert.equal(codes(both).filter(code => code === 'configuration_assets_changed').length, 2);
  // Unreadable or damaged assets are passed as undefined: the approval is invalidated, never accepted.
  const reasons = compareSafety({ plan, facts: facts(), hashes: currentHashes(), assets: undefined });
  assert.deepEqual(codes(reasons), ['configuration_assets_changed']);
  assert.match(reasons[0].message, /missing or damaged/);
  assert.equal(reasons[0].next_step, NEXT_STEP_REGENERATE);
});

test('a plan with hibernation disabled is still bound to the same assets', () => {
  const { plan } = generate({ choices: { hibernation: false } });
  assert.deepEqual(compare({ plan }), []);
  const changed = { ...assets, configure_zram: { ...assets.configure_zram, sha256: 'c'.repeat(64) } };
  assert.deepEqual(codes(compare({ plan, currentAssets: changed })), ['configuration_assets_changed']);
});

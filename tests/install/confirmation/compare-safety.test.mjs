import test from 'node:test';
import assert from 'node:assert/strict';
import { NEXT_STEP_REGENERATE, compareSafety, selectedDisk } from '../../../install/confirmation/compare-safety.mjs';
import { clone, currentHashes, facts, firstDisk, generate, withDisk } from './helpers.mjs';

function compare({ plan = generate().plan, fresh = facts(), hashes = currentHashes(), baselineFacts } = {}) {
  return compareSafety({ plan, facts: fresh, hashes, baselineFacts });
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

test('a different target id is target_identity_changed', () => {
  const fresh = clone(facts());
  fresh.source.target_id = 'framework-13-pro-amd';
  assert.deepEqual(codes(compare({ fresh })), ['target_identity_changed']);
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
  assert.deepEqual(codes(compare({ hashes: { policy_sha256: currentHashes().policy_sha256 } })), ['policy_changed']);
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

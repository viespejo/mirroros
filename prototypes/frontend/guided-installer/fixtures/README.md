# Synthetic discovery fixture

`target-facts.json` is based on a valid MirrorOS discovery result from:

```text
evidence/reference-vm/discovery/20261008T103556Z-f2281fc5-e382-41da-88e3-ebc9edc341d5/target-facts.json
```

It uses the format documented in `contracts/target-facts.md`. The disk picker reads
`effective["storage.disks"].value`, filters on `eligible`, and retains `identity.by_id`
or, when unavailable, `identity.path` as the `target_disk` choice. It does not inspect
live devices or validate the selected machine against this historical result.
Both target choices currently use the same reference fixture for presentation only.
The original result had one eligible 32 GiB disk without a model or partitions.
For this presentation fixture, that disk now has the synthetic model `Example VirtIO Disk`,
`by_id` and serial `SYNTH-VDA-0001` (with the `virtio-` prefix for `by_id`), and a GPT
layout with a 1 GiB FAT32 ESP and a 30 GiB ext4 root partition. Labels, UUIDs, and
PARTUUIDs are synthetic. No partition is mounted. Both detected and effective storage
views contain identical data. `source.run_id` is `ux-preview-synthetic`; other source
metadata describes the historical base, not a new discovery run. Ineligible optical
and loop devices are omitted from the picker, not from the facts.

These are synthetic example facts, not current discovery or acceptance evidence.
They must never authorize installation. Production integration requires current,
validated facts and the existing plan/digest/confirmation contracts.

Disk-label presentation follows the route/capacity/model/partition-summary idea in
the Omarchy 4.0.4 ISO configurator; no disk operations or installer flow are imported.
Existing upstream notices in `LICENSE-ISO` remain unchanged.

## Storage policy snapshot

`installation-policy.json` is a temporary copy of `install/plan/policy.json`.
The repository policy and accepted ADR 0003 remain authoritative; this snapshot
exists only because the guest preview does not mount the repository.
`lib/storage-layout.sh` presents its three storage options and support tiers,
starting with `ext4-systemd-boot`. Esc preserves the previously confirmed choice.
The screen and review collect a preview choice only: they do not create a plan,
record approval, or execute storage operations. Refresh and review this snapshot
if the repository policy changes; do not promote it as an independent policy.

`lib/swapfile-size.sh` collects an integer from 512 to 65536 MiB, initialized
from this snapshot's `policy.swapfile_size.value` (4096 MiB). It explains that
the default does not guarantee hibernation for every workload. Esc preserves the
confirmed value, including after an invalid edit. The review shows the chosen
size. No swapfile is created; complete layout-fit validation belongs to the real
plan contract, not this presentation prototype.

## Localization preview

After timezone, `lib/localization.sh` presents system language and regional
formats as separate choices. Language starts from the policy snapshot's `lang`.
Formats initially follow the system language, or can explicitly use Spain or
the United States. Following language remains dynamic when the language changes.
The preview derives `LC_TIME`, `LC_NUMERIC`, `LC_MONETARY`, and `LC_MEASUREMENT`
from the formats choice; other categories inherit `LANG`. It never sets `LC_ALL`.
Applications may have their own preferences or ignore these settings.

Required locales are the unique union of the language and formats locales.
This automatic list replaces the snapshot's fixed two-locale default for this
UX exploration only. No locales are generated and no live environment variables
are changed. Esc preserves confirmed answers. The review shows language, formats,
and required locales. Regional settings are not valid production plan fields yet:
integration requires policy, contract, resolver, validator, engine, documentation,
and test updates. Do not feed preview regional choices into the current plan.

## User and root account preview

After hostname, the guide collects the username and root account policy.
`lib/root-account.sh` initializes root from the policy snapshot (`locked`).
The user may keep root locked and administer through the wheel-group user with
sudo, or choose `password` to reuse the user's password for root. Esc preserves
the confirmed policy. The intended UX requests one password, with repetition,
after bound plan approval. It applies to the user and also to root only when
`root_account` is `password`; otherwise root remains locked. The user always has
sudo access under the current wheel policy. Shared credentials are not an
independent recovery credential if the password is forgotten.
This is a prototype design decision, not production integration: the current
plan contract still declares `user_password` and conditional `root_password`
separately. Integration must reconcile secret handling, contracts, documentation,
and tests without placing values or hashes in plans or evidence. This preview
never collects passwords or modifies accounts. Review contains the root policy, not
fake password masks. Git full name and email prompts are removed; personal Git
configuration belongs outside the installation plan.

## Confirmation and password preview

Review now leads to `lib/confirmation-preview.sh`, not directly to the ending.
The screen identifies the synthetic disk and chosen layout, warns that a real
installation would erase the disk, and explicitly labels the interaction as a
simulation with no valid plan or approval. Back is preselected; Simulate
confirmation opens the password explanation, Back/Esc returns to review, and
Cancel preview exits the guide. No approval state or record is produced.

`lib/password-preview.sh` explains one password with repetition, user sudo access,
and conditional reuse for root. It does not open a password field. Finish preview
ends the demo, and Back/Esc returns to the confirmation simulation. No real
installation starts, and finishing retains the prototype's non-success status 2.
Production still requires validated current facts, a real plan and digest, bound
confirmation, protected secret collection, and cancellation before disk writes.

Re-run the preview in the guest without rebooting or remounting:

```bash
bash /mnt/uxdemo/omarchy-style/guest-demo.sh
```

Local checks (outside the guest):

```bash
timeout 5s bash tests/disk-selection.sh
timeout 5s bash tests/storage-layout.sh
timeout 5s bash tests/swapfile-size.sh
timeout 5s bash tests/localization.sh
timeout 5s bash tests/root-account.sh
timeout 5s bash tests/confirmation-preview.sh
```

# Reference VM

This directory owns the fixed reference VM used by `operations/test` to qualify the bootstrap medium of a MirrorOS bundle. It contains the versioned VM configuration, the Bash scripts for bounded process work (preconditions, run resources, NoCloud medium, QEMU launch, stopping and cleanup, outcomes, evidence), the guest checks, and the Node module for structured data.

The command contract, prerequisites, outcomes, and recovery steps are documented in the [test procedure](../../docs/procedures/test.md). Generated runs live in the ignored `build/reference-vm/` and `evidence/reference-vm/` paths, never here.

`qualify-discovery` reuses the same configuration and libraries to qualify read-only target discovery (Story 2.2): it boots the bundle ISO, runs the embedded `mirroros-install discover` through `guest/discovery-trigger.sh`, and compares the disk before and after. Its evidence lives in the ignored `evidence/reference-vm/discovery/` path; see the [test procedure](../../docs/procedures/test.md#discovery-qualification). Its `plan` scenario also qualifies installation plan generation (Story 2.3) on the live medium.

Changing `reference-vm.conf` changes the qualification contract and requires an explicit decision.

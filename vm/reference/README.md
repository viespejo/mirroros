# Reference VM

This directory owns the fixed reference VM used by `operations/test` to qualify the bootstrap medium of a MirrorOS bundle. It contains the versioned VM configuration, the Bash scripts for bounded process work (preconditions, run resources, NoCloud medium, QEMU launch, stopping and cleanup, outcomes, evidence), the guest checks, and the Node module for structured data.

The command contract, prerequisites, outcomes, and recovery steps are documented in the [test procedure](../../docs/procedures/test.md). Generated runs live in the ignored `build/reference-vm/` and `evidence/reference-vm/` paths, never here.

Changing `reference-vm.conf` changes the qualification contract and requires an explicit decision.

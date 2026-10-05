# Story 1.4 Reference VM Bootstrap Validation — Consolidated Plan

## Scope and Existing Foundation

Story 1.4 will qualify the bootstrap medium for UEFI boot and networking in the disposable reference VM. It will validate a constructed bundle, check required KVM acceleration and OVMF prerequisites before launching QEMU, and demonstrate a usable live installation environment with working network connectivity. Repository validation and successful image construction are distinct from this VM qualification. [DEC-001]

Review of the preceding execution summaries, interview plans and relevant log entries, architecture, Accepted ADR 0001, and current test operation establishes the starting state: Story 1.3 is implemented and retains two bundles constructed from a clean clone, neither boot-qualified; `operations/test` is still help-only. QEMU, `/dev/kvm`, and OVMF firmware are present on the current host, but presence alone does not establish functional KVM acceleration or passing VM prerequisites. These are observations, not qualification claims or permanent version pins. [DEC-001]

## Qualification and Ownership Boundaries

Only UEFI/OVMF is the supported boot path. Retaining upstream BIOS/Syslinux assets does not create a support commitment. This story will not select an installation engine or introduce incidental personalization of the Archiso profile. Successful qualification makes the artifact eligible for later installation-engine prototypes; it does not establish installation testing, capability verification, accepted-known-good status, or target-laptop eligibility. [DEC-001]

## Evidence Objectives

The test will retain artifact identity, reference-VM configuration, boot and networking outcomes, test duration, and failure diagnostics with an identified failing stage and actionable next step. Diagnostic collection must be allowlisted and secret-scanned. Accepted ADR 0001 is the existing build scan-scope authority, not a substitute for separately resolving this story's VM evidence policy. [DEC-001]

## Resolved Design and Outstanding Qualification

The interview has resolved automation, guest usability and networking criteria, the fixed reference configuration, bundle selection, guest-check transport, deadlines, privileges, isolation, stopping, normalized outcomes, and evidence content, placement, retention, and scanning. These choices were approved individually rather than inferred from the scope decision or earlier stories' qualification sequences. [DEC-001, DEC-002, DEC-003, DEC-004, DEC-005, DEC-006, DEC-007, DEC-008, DEC-009, DEC-010, DEC-011, DEC-012, DEC-013, DEC-014, DEC-015, DEC-016, DEC-017, DEC-018]

Source-state acceptance, validation coverage, formal real qualification, review flow, the complete argument contract, guest-result validation, manual residual recovery, headless execution, and implementation handoff are also resolved. No substantive design branch remains pending. The approved cloud-init/NoCloud integration still requires demonstration with the real artifact; TODO-001 remains a qualification obligation. Concrete mechanical details are implementing-agent deliverables under the approved contracts, and a finding that changes a contract requires explicit review. [DEC-009, DEC-019, DEC-020, DEC-021, DEC-022, DEC-023, DEC-024, DEC-025, DEC-026, TODO-001]

## Interview Status

The design interview is closed and this plan is ready to guide one implementation plan. Closure establishes approved design, not implementation or story completion, present authorization to execute the VM or create commits, or successful boot qualification. TODO-001 remains pending until actual integration is demonstrated during implementation and qualification. [DEC-026, TODO-001]

## Automated Qualification

`operations/test` will automatically verify boot and network connectivity with actual checks inside the guest and finite execution deadlines. A running QEMU process does not establish guest readiness or successful networking. Automation avoids repeated manual intervention and enables regression detection, at the cost of implementing a guest control and diagnostic channel. The channel uses the separately approved cloud-init/NoCloud and serial-console mechanism without ISO modification. Manual inspection may complement diagnosis but cannot replace the checks that grant qualification. [DEC-002, DEC-009]

## Usable Installation Entry Point

Bootstrap usability requires actual boot from the ISO through OVMF, confirmation inside the guest of UEFI mode, access to a working root shell capable of executing commands, and runtime availability of native installation tools. The current profile declares `arch-install-scripts` and Archinstall and enables root autologin on `tty1`; these declarations are starting-state observations, not substitutes for guest checks or selection of Archinstall. Qualification must not start an installer or modify the disk. These criteria establish readiness to begin subsequent installation work, not proof that installation succeeds. [DEC-003]

## Network Connectivity Criteria

The guest must demonstrate a usable IPv4 address and default route, resolve a public Arch Linux destination through DNS, and complete a small HTTPS request to that destination with TLS validation and a successful response. The profile's DHCP Ethernet configuration and enabled systemd-networkd and systemd-resolved services, together with iproute2, curl, and CA certificates in the retained artifact manifest, establish available foundations rather than proof of connectivity. [DEC-004]

ICMP is not required because filtering can prevent it while HTTPS remains usable. IPv6 is not required for initial qualification, and the connectivity test must not install or update packages. The external destination introduces a dependency that can block qualification even when the ISO is functional; diagnostics must distinguish external causes from local networking failures without treating an unexplained failure as automatically external. The destination and finite deadlines are fixed by the dedicated decisions below. [DEC-004, DEC-010, DEC-011]

## Reference VM Network Topology and Simplicity

The reference VM will use QEMU user networking through SLIRP NAT with one virtual Ethernet interface. No bridge, TAP, or host network changes are required, allowing networking without privileged orchestration. Port forwarding is disabled by default; any forwarding needed by a subsequently approved guest-control mechanism requires an explicit decision. The result qualifies the live environment in this topology, not Wi-Fi, direct LAN access, or all target-laptop networking conditions. [DEC-005]

Keep this story simple while preserving the checks and safeguards already approved. Simplicity is a design constraint for the remaining branches, not permission to silently waive qualification or safety requirements. [DEC-005]

## Disposable Disk Lifecycle

Every test execution creates a new empty virtual disk; existing disks are not accepted and disks from prior runs are not reused. This reduces interface and validation complexity, prevents inherited disk state from influencing the test, and establishes a disk-present VM topology without performing installation. Story 1.4 must not partition or install onto the disk. Remove the current run's disposable disk at completion and retain the test evidence separately. The reference configuration fixes size and format at 32 GiB sparse qcow2; stopping and cleanup failure handling follow the dedicated policies below. [DEC-006, DEC-007, DEC-014, DEC-015]

## Fixed Reference VM Configuration

Use a single versioned configuration without resource-selection CLI options: x86_64, QEMU `q35`, mandatory KVM acceleration, CPU `host`, two vCPUs, and 4 GiB RAM. Attach the per-run empty disk as a sparse 32 GiB qcow2 image through VirtIO, and use one VirtIO Ethernet interface with the approved SLIRP NAT. Boot through OVMF UEFI with Secure Boot disabled, as required by the MVP architecture. Record effective configuration and actual tool versions in test evidence. [DEC-007]

KVM unavailability must not trigger silent software-emulation fallback. CPU `host` makes guest CPU capabilities dependent on the execution host; `q35` defines a virtual platform rather than reproducing the laptop. vCPUs are guest logical processors, and the host needs memory beyond the guest's 4 GiB allocation. The sparse disk initially occupies little storage but grows with writes up to its guest-visible capacity. Secure Boot being disabled does not waive HTTPS TLS validation. This deliberately narrow configuration reduces maintenance and does not constitute a hardware compatibility matrix or guarantee sufficient resources for the complete installed environment. [DEC-007]

## Explicit Bundle Input

Invoke the test with one explicit bundle-directory argument: `operations/test /path/to/bundle`. Require the ISO, `SHA256SUMS`, `artifact-metadata.json`, and native package manifest produced by Story 1.3, and verify integrity and cross-file coherence before launching the VM. The bundle may reside under `dist/` or be relocated; neither automatic latest-artifact selection, standalone ISO inputs, nor implicit builds are supported. Keep `--help` side-effect-free. Checksums identify and compare content integrity, not publisher authenticity or functional correctness. Input-failure classification follows the normalized-outcome policy below, and the closed argument contract specifies the rejection matrix for contract tests. [DEC-008, DEC-015, DEC-022]

## Guest Checks and Result Transport

Use the existing cloud-init services with a temporary NoCloud auxiliary medium containing the guest checks, and collect their results through a serial console. This avoids modifying the ISO, configuring SSH, opening forwarded ports, or automating keystrokes. The supplied instructions must neither install packages nor touch the empty virtual disk. Implement the approved guest usability and networking checks through this mechanism; concrete integration and result-transport details must preserve their actual guest-observation requirements. [DEC-002, DEC-003, DEC-004, DEC-009]

The profile includes cloud-init and enables its services, but these declarations do not prove that NoCloud and serial result collection work with the artifact. Demonstrate that integration with the real artifact during implementation and qualification. Qualification must explicitly identify use of the auxiliary test medium and must not claim to demonstrate an unseeded boot. Incompatibility requires an explicit design review rather than a silent fallback or weakened checks. [DEC-009, TODO-001]

## Fixed External Connectivity Destination

Resolve `archlinux.org` and make a small HTTPS request to `https://archlinux.org/`, discarding the response body and requiring HTTP 200 with TLS validation enabled. The destination is fixed, with no automatic alternatives or CLI selection. This public official endpoint requires neither credentials nor package downloads; success proves reachability to this destination, not availability of all mirrors or successful package installation. Its external availability remains a qualification dependency. [DEC-004, DEC-010]

## Qualification Deadlines and Retry Boundary

Boot and all qualification checks must complete within five minutes of QEMU launch. The HTTPS request has a thirty-second maximum within that global budget, not an additional allowance after it. These fixed values have no CLI overrides, and the complete test is not retried automatically. Deadline expiry prevents qualification and triggers diagnostic retention and VM stopping under the stopping policy, returning execution-failure status 5. The values are initial design bounds rather than measured performance, and changing them in response to real qualification requires explicit review. [DEC-011, DEC-014, DEC-015]

## Host Privilege and Prerequisite Boundary

Invoke domain testing as a normal user with direct KVM access; reject root domain execution, while preserving help for root. Check functional KVM acceleration, available OVMF firmware, and required tools before launching the test VM. Presence alone is not proof of functional KVM. Missing or unusable prerequisites stop the operation with actionable instructions. The harness must not install packages, change permissions or groups, start services, invoke sudo as a fallback, or switch to software emulation. Exact preflight commands are implementation deliverables constrained by these checks. [DEC-012]

## Guest Isolation and Disposable UEFI State

Expose no host directories, credentials, physical devices, or host environment variables to the guest. Its supplied resources are limited to the input ISO, the empty test disk, the temporary NoCloud test medium, firmware, and necessary test-control channels. Use OVMF code read-only and copy its UEFI variable template into fresh per-run state. Never reuse variable state from an earlier run or allow modification of the installed host template; UEFI boot settings must not leak between tests. These boundaries reduce host exposure but do not promise absolute protection from a malicious guest or a hypervisor vulnerability. [DEC-013]

## Current-Run VM Stopping and Cleanup

On completion, failure, or interruption, terminate only the current execution's QEMU process: send SIGTERM and wait at most ten seconds, then, if still alive, send SIGKILL and wait at most five more seconds. Verify process exit before deleting that run's disposable disk, UEFI variable copy, and NoCloud medium. Retain diagnostic evidence separately. If exit cannot be confirmed, preserve the resources, report them for manual investigation, and do not claim success. No action may affect another VM. [DEC-014]

SIGTERM allows QEMU to terminate but is not an orderly guest shutdown; forced termination may also interrupt guest activity. This trade-off is accepted because Story 1.4 performs no installation and retains no guest data. The test does not qualify orderly shutdown behavior, and resource deletion is never a substitute for proving that QEMU has exited. [DEC-006, DEC-014]

## Normalized Outcomes and Failure Precedence

Domain status 0 requires passing guest checks, accepted evidence, and completed cleanup; help status 0 still means only successful help. Invalid arguments, inadmissible bundles, unmet prerequisites, and secret-scan content rejection return 2. Completed checks that report unmet guest criteria, including unavailable external connectivity, return 4. Execution failures involving QEMU, deadline expiry, tools, scanner execution, or cleanup return 5. A damaged checkout or internal contract violation returns 6. Preserve ordinary signal outcomes 130 for SIGINT and 143 for SIGTERM; this story introduces no interactive cancellation mechanism producing 3. [DEC-008, DEC-015]

Retain an earlier non-success outcome when cleanup also fails, reporting the cleanup error separately rather than obscuring the primary failure. If checks and other controls had succeeded but cleanup fails, return 5 and do not claim overall success. [DEC-015]

## Minimum Retained Evidence

Each execution retains one JSON result separate from the input bundle, recording artifact identity and checksum, test-code identity, effective VM configuration, QEMU and OVMF versions, individual check outcomes, duration, failing stage and actionable next step, final exit status, original tool statuses, scan outcomes, and cleanup outcomes. The terminal summary derives from the same result. Concrete field names must follow architecture conventions without introducing an unrelated general verification schema. [DEC-016]

The diagnostic log allowlist consists of guest serial output and QEMU diagnostics, accompanied by redacted secret-scan reports. Do not collect screenshots, memory dumps, or complete host inventories. The input bundle remains unchanged: construction metadata is not rewritten to add boot qualification, which is instead established by separate test evidence. [DEC-016]

## Run Layout, Permissions, and Retention

Place temporary VM resources in `build/reference-vm/<run-id>/` and retained results and diagnostics in `evidence/reference-vm/<run-id>/`. Generate one UTC timestamp plus UUID identifier following the builder's pattern and use it consistently for the execution. Per-run directories use mode 0700 and generated files mode 0600, limiting access to the invoking user and root. Generated outputs remain ignored, not authoritative source. [DEC-017]

Never overwrite earlier runs. Remove only the current run's temporary resources under the confirmed-process-exit cleanup policy, retaining its evidence. This story introduces no automatic evidence-expiry policy. Private filesystem permissions do not exclude root or replace secret scanning. [DEC-014, DEC-017]

## Test Secret Scanning and Terminal Exposure

Require Gitleaks and scan generated NoCloud text before attaching it to the VM. Scan the result JSON, allowlisted diagnostic logs, and retained reports before accepting qualification. Do not re-extract the ISO or scan binary disks or firmware; construction scanning retains its Accepted ADR 0001 scope. This test-specific scope does not claim absolute absence of secrets. [DEC-018]

A finding blocks qualification. Preserve diagnostics privately for maintainer review rather than automatically sanitizing them, keep reports redacted, and display only progress and summaries on the terminal, not raw guest logs. Private retention and terminal restraint complement scanning but do not substitute for it. [DEC-017, DEC-018]

## Development Runs and Formal Acceptance Source State

Development tests may use locally modified harness code or bundles marked dirty, recording those states and distinguishing the results from formal story acceptance. Formal Story 1.4 acceptance requires committed harness code in a clean checkout and a bundle from clean accepted Story 1.3 construction. The habitual checkout is sufficient: no additional clone is mandatory. Reuse the retained clean construction bundle rather than rebuilding the ISO solely because the harness changed. Identify both the artifact's build commit and the test-code commit; they need not match. [DEC-019]

The fresh-clone requirement was proposed but not approved, and was withdrawn in favor of simplicity after explanation. The accepted trade-off is loss of the additional check for accidental dependence on unversioned local files. A clean checkout still does not clean or isolate the host, and dirty development metadata must not claim to identify uncommitted code exactly. [DEC-019]

## Minimum Validation Strategy

Use Bats and built-in Node tests with simulated tools for argument and prerequisite contracts, invalid bundles, guest check failures, deadlines, interruptions, secret scanning, and cleanup. Require one satisfactory real execution using the retained clean accepted construction bundle and committed harness code in a clean checkout. That execution must demonstrate KVM/OVMF, cloud-init/NoCloud integration, the actual guest checks, and final secret-scanned evidence, thereby resolving the integration obligation only when it is observed. [DEC-019, DEC-020, TODO-001]

Do not rebuild the ISO for this gate or require a battery of failures induced in real VMs. Simulation proves the tested error contracts, not actual boot or networking; the successful real run proves the supported integration path, not that every failure branch has been exercised against a real guest. Preserve that distinction in acceptance evidence. [DEC-020]

## Implementation Review and Formal Qualification Flow

After implementation and local tests, present the diff, tests, and documentation for explicit approval at one blocking human checkpoint before the candidate commit. Only after that approval create the commit and perform the real qualification from the clean committed checkout. Story completion requires the approved guest checks, successful evidence controls and cleanup, and retained scanned evidence; a candidate commit alone is not completion. [DEC-015, DEC-019, DEC-020, DEC-021]

Preserve failed qualification evidence and use additional corrective commits rather than rewriting the failed candidate. No second mandatory human checkpoint is introduced. The interview defines this future flow but authorizes neither present commits nor runtime execution. [DEC-021]

## Closed Argument and Help Contract

Accept exactly sole `--help` or one explicit bundle-directory argument. Permit paths containing spaces and resolve relative bundle paths against the caller's working directory; repository-owned resources remain located independently from the executable path. Missing arguments, unknown options, multiple arguments, and combinations with help return 2 before file creation or domain-tool invocation. No additional options or aliases are supported. Replace the former pending-work no-argument diagnostic with a missing-bundle diagnostic and update the current contract tests accordingly. [DEC-008, DEC-022]

Help remains side-effect-free and requires neither QEMU, KVM, OVMF, nor Gitleaks; damaged-checkout failures retain the established contract. Help success is not evidence of VM qualification. [DEC-015, DEC-022]

## Guest Result Acceptance Contract

The guest emits a small JSON report tied to the current run-id. Validate its fields, execution identity, completeness, and all required check results in Node before accepting it as evidence. An incomplete or contradictory report, a report for another execution, or a missing check cannot grant qualification. Success words in serial logs and absence of reported failures are not substitutes for actual validated results. The exact report format is an implementing-agent deliverable with corresponding tests, not a new framework or general capability-verification schema. [DEC-002, DEC-003, DEC-004, DEC-023]

## Conservative Creation and Manual Residual Recovery

Never recover, reuse, or automatically delete earlier runs' resources during a new test. Reject occupied reserved run locations or symbolic-link output directories with status 2, leaving those resources unchanged. Safe creation and ownership checks are implementation deliverables under this refusal and per-run cleanup boundary. [DEC-017, DEC-024]

Provide concise manual recovery instructions: identify the affected execution, establish that its associated QEMU has terminated, then remove only its temporary resources while preserving evidence. This story introduces neither a recovery command nor domain behavior in `operations/clean`. [DEC-014, DEC-024]

## Exclusively Headless Execution

Run QEMU headless without opening a graphical window or requiring a desktop session on the host. Use the approved serial channel for automatic checks and results, and add no optional graphical mode. This simplifies dependencies and removes visual interaction from qualification. The result covers boot and command-based bootstrap usability, not the appearance of the boot menu or graphical-console usability. [DEC-009, DEC-025]

## Implementation Plan Handoff

Deliver Story 1.4 through a single implementation plan. Keep `operations/test` a small lifecycle entry point and place domain implementation in `vm/reference/`, following architecture ownership. Use Bash for bounded process orchestration and checks and JavaScript ESM on Node for structured data. Do not introduce new frameworks. Concrete commands, internal filenames, and JSON fields are implementing-agent deliverables governed by the approved checks, validation, evidence, safety, and outcome contracts. [DEC-026]

Include the approved automated tests, usage and concise manual recovery documentation, README updates, and the real qualification gate. Apply normative repository validation and language rules alongside this story's tests, without modifying unrelated lifecycle behavior or resolving gated installation decisions. The implementation plan must preserve the single pre-commit approval checkpoint and the distinction between simulated contracts and demonstrated real integration. [DEC-001, DEC-020, DEC-021, DEC-024, DEC-026]

Keep TODO-001 open until the real artifact demonstrates cloud-init/NoCloud and serial result collection under the approved criteria. If implementation requires a contract change, return for explicit approval rather than silently selecting a fallback or weakening a check. Interview closure neither grants runtime qualification nor authorizes present commits or execution. [DEC-009, DEC-026, TODO-001]

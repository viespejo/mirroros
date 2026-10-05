# Story 1.4 Reference VM Bootstrap Validation — Decision Log

**Conventions.** The Consolidated Plan (`story-1-4-reference-vm-bootstrap_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding entry, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: Should Story 1.4 be limited to reference-VM bootstrap boot and networking qualification before installation prototypes?
- **Context/Nuances**: The preceding execution summaries, interview plans and relevant log entries, architecture, Accepted ADR 0001, and current test entry point were reviewed. Story 1.3 is implemented and retains two bundles constructed from a clean clone, but neither is boot-qualified. `operations/test` remains help-only. QEMU, `/dev/kvm`, and OVMF firmware are present on the current host; their presence does not establish functional KVM acceleration or successful VM prerequisites. UEFI/OVMF is the supported path; retained BIOS/Syslinux assets do not imply support. Repository checks and successful construction are not VM qualification. ADR 0001 governs build scanning and does not establish a complete VM evidence policy.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed scope, boundaries, and pending design branches.
- **Decision**: Limit Story 1.4 to validating a constructed bundle, checking required KVM acceleration and OVMF prerequisites, booting it in a disposable reference VM, and demonstrating a usable live installation environment with network connectivity. Retain artifact identity, VM configuration, boot and network outcomes, duration, and actionable failure evidence using allowlisted, secret-scanned diagnostics. Success makes the artifact eligible for later installation-engine prototypes, not install-tested, capability-verified, accepted-known-good, or target-laptop eligible. Do not select an installation engine or introduce incidental profile personalization. Resolve automation, the usable installation entry point, connectivity criteria, VM configuration, bundle selection, evidence, deadlines, exit outcomes, and cleanup separately. Registration modifies interview artifacts only and authorizes neither runtime implementation nor VM execution.
- **Status**: Accepted

## DEC-002
- **Question**: Should `operations/test` verify boot and networking automatically, or launch the VM for manual qualification?
- **Context/Nuances**: Automated checks avoid repeated undocumented manual intervention and make regressions detectable. They require a guest control and diagnostic channel, which increases implementation cost. QEMU remaining alive is not evidence that the live environment is usable or that networking works. Manual inspection can aid diagnosis but must not replace qualification checks. Neither a control mechanism nor an ISO modification is implied by this choice.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the automatic-check recommendation and its stated trade-offs.
- **Decision**: `operations/test` will automatically verify boot and network connectivity using actual checks inside the guest and finite execution deadlines. Do not grant qualification solely because QEMU is running. Manual inspection may complement diagnosis but does not substitute for the checks that grant qualification. Resolve the guest control and diagnostic mechanism separately, without assuming changes to the ISO.
- **Status**: Accepted

## DEC-003
- **Question**: What constitutes a usable installation entry point for bootstrap qualification?
- **Context/Nuances**: Inspection of the current Archiso profile found root autologin on `tty1` and package declarations for `arch-install-scripts` and Archinstall. Declared package presence does not establish runtime availability or select Archinstall as the installation engine. Bootstrap usability must be demonstrated without attempting installation or anticipating the installation-engine prototype decision.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed usability criteria and non-installation boundary.
- **Decision**: Require actual boot from the ISO through OVMF, confirmation inside the guest that it is running in UEFI mode, access to a working root shell that can execute commands, and runtime availability of native installation tools. The check must neither start an installer nor modify the disk. This establishes an entry point for later installation work, not successful installation or selection of an installation engine.
- **Status**: Accepted

## DEC-004
- **Question**: What network connectivity must the guest demonstrate for bootstrap qualification?
- **Context/Nuances**: The profile configures Ethernet through DHCP and enables systemd-networkd and systemd-resolved. The retained artifact's native package manifest includes iproute2, curl, and CA certificates. Runtime connectivity still requires guest checks. ICMP can be filtered even when HTTPS works, and package installation or updates would broaden this bootstrap test unnecessarily. An external destination introduces a dependency whose failure can block qualification independently of the ISO; diagnostics must distinguish external causes from local failures without assuming every request failure is external.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed connectivity criteria, exclusions, and external-dependency nuance.
- **Decision**: Require a usable IPv4 address, a default route, DNS resolution of a public Arch Linux destination, and a small HTTPS request to that destination with TLS validation and a successful response, all checked inside the guest. Do not require ICMP or IPv6 for this initial qualification. Do not install or update packages as a connectivity test. Distinguish external dependency problems from local networking failures in diagnostics; either can prevent qualification. Resolve the destination and finite deadlines separately.
- **Status**: Accepted

## DEC-005
- **Question**: Which network topology should the reference VM use?
- **Context/Nuances**: QEMU user networking through SLIRP supplies NAT, DHCP, and outbound connectivity without a bridge, TAP, elevated orchestration, or host network changes. It qualifies live networking in that topology, not Wi-Fi, direct LAN access, or every target-laptop condition. Port forwarding is not required by the approved connectivity checks; a guest-control mechanism might need it and would require a separate explicit decision. The user also requested keeping this story simple.
- **User Response**: "yes, registra directamente la decisión. nota: mantengamonosmantengámonos simple en esta story, si?"
- **Decision**: Use QEMU user networking (SLIRP NAT) with one virtual Ethernet interface, without bridge, TAP, or host network changes. Do not enable port forwarding by default; any forwarding required for guest control must be decided explicitly. Keep Story 1.4 simple while preserving the already approved checks and safeguards. Qualification covers the selected VM topology, not Wi-Fi, direct LAN access, or general laptop networking.
- **Status**: Accepted

## DEC-006
- **Question**: Should each bootstrap test create a new disposable disk or accept and reuse existing disks?
- **Context/Nuances**: A fresh disk avoids inherited state, reduces interface options, and provides a disk-present topology for later installation prototypes without executing installation in this story. Reuse would require additional input validation and ownership rules. Disk size and format are separate reference-VM configuration details. Evidence retention is distinct from retaining the disposable disk.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of a new disk for each execution without reuse.
- **Decision**: Create a new empty virtual disk for each test execution. Do not accept existing disks or reuse disks from earlier runs. Story 1.4 must not partition the disk or install onto it. Remove the current run's disposable disk at completion while retaining test evidence. Resolve size and format with the reference-VM configuration; detailed failure and cleanup handling remains a separate branch.
- **Status**: Accepted

## DEC-007
- **Question**: What fixed configuration should define the reference VM for Story 1.4?
- **Context/Nuances**: The user requested explanations before approval. QEMU supplies the virtual machine and KVM supplies hardware CPU acceleration through Linux; an unavailable KVM path must not silently fall back to software emulation. `q35` models a PCI Express platform, not the physical laptop. CPU `host` exposes host processor capabilities and therefore varies across hosts. Two vCPUs are guest logical processors, not permanently reserved physical cores. Four GiB is guest memory while running, requiring additional host capacity. A sparse qcow2 disk has a 32 GiB guest-visible capacity but initially occupies little host storage and grows with writes. VirtIO supplies virtualization-oriented disk and Ethernet interfaces supported by Linux. OVMF supplies UEFI firmware; disabling Secure Boot follows the MVP architecture and does not disable HTTPS TLS validation. One fixed versioned configuration reduces options and maintenance but is not a compatibility matrix or proof that these resources suffice for the complete future environment.
- **User Response**: After receiving explanations of each proposed component: "yes, registra directamente la decisión."
- **Decision**: Use one versioned reference configuration without CLI resource options: x86_64, QEMU `q35`, mandatory KVM, CPU `host`, two vCPUs, 4 GiB RAM, a new sparse 32 GiB qcow2 disk attached through VirtIO, and one VirtIO Ethernet interface using the approved SLIRP NAT topology. Boot with OVMF UEFI and Secure Boot disabled. Record the effective configuration and actual tool versions. Qualification applies to this reference bootstrap configuration, not general hardware compatibility or full installed-environment resource sufficiency.
- **Status**: Accepted

## DEC-008
- **Question**: How should the test select its input artifact?
- **Context/Nuances**: Story 1.3 publishes a bundle containing the ISO, SHA256SUMS, artifact-metadata.json, and native package manifest. An explicit directory avoids ambiguous latest-artifact selection and preserves the independent build/test boundary. Bundles can remain under dist/ or be relocated. Checksums establish integrity comparison, not publisher authenticity or runtime qualification. This decision does not resolve every validation failure classification or the full argument-rejection matrix.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of a single explicit bundle argument and the stated validation and discovery behavior.
- **Decision**: Invoke the test as `operations/test /path/to/bundle`, with a single explicit bundle-directory argument. Require the ISO, SHA256SUMS, artifact-metadata.json, and native package manifest published by Story 1.3, and validate their integrity and coherence before boot. Do not choose the latest artifact automatically, accept a standalone ISO, or build implicitly. Support bundles under dist/ or relocated elsewhere. Preserve side-effect-free `--help`.
- **Status**: Accepted

## DEC-009
- **Question**: How should the harness execute checks inside the guest and collect their results without modifying the ISO?
- **Context/Nuances**: The current profile declares cloud-init and enables its services. NoCloud is an existing cloud-init mechanism for providing initialization instructions through an auxiliary medium. A serial console provides a text channel between guest and host. Reusing these mechanisms avoids ISO modifications, SSH setup, forwarded ports, and automated keystrokes. Package and service declarations alone do not establish that this integration works with the constructed artifact. Qualification with an auxiliary test medium is not proof of an otherwise identical unseeded boot.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of cloud-init/NoCloud and serial console, subject to verifying the integration.
- **Decision**: Use a temporary NoCloud auxiliary medium to supply guest checks through the existing cloud-init services, and collect results through a serial console. Do not modify the ISO, set up SSH, forward ports, or automate keystrokes for this mechanism. The supplied instructions must not install packages or touch the empty test disk. Verify the integration with the real artifact before representing it as functional. Record that qualification uses this auxiliary test medium and does not demonstrate an unseeded boot. Concrete integration and result-transport details remain implementation deliverables under the approved checks; an incompatible integration requires explicit review rather than an assumed alternative.
- **Status**: Accepted

## TODO-001
- **Question**: Does cloud-init/NoCloud with serial result collection work with the actual bootstrap artifact?
- **Context/Nuances**: The mechanism is approved by DEC-009, but profile declarations are not runtime evidence. The real test must still boot the ISO through OVMF and satisfy DEC-003 and DEC-004 without modifying the ISO, installing packages, or touching the empty disk.
- **User Response**: Approved DEC-009 subject to checking this integration.
- **Decision**: Demonstrate the approved integration against the real constructed artifact during implementation and qualification. Preserve the auxiliary-medium limitation in evidence. If the mechanism is incompatible, return for an explicit design decision rather than silently switching mechanisms or weakening checks.
- **Status**: Pending

## DEC-010
- **Question**: Which fixed external destination should the guest use for DNS and HTTPS validation?
- **Context/Nuances**: The official Arch Linux website is a simple public destination without credentials or package downloads. Discarding the response body avoids retaining unnecessary external content. Success establishes DNS and HTTPS reachability to this destination, not the availability of all package mirrors or the ability to complete installation. External destination failure can prevent qualification under DEC-004.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the fixed destination and absence of automatic alternatives or CLI selection.
- **Decision**: Use `https://archlinux.org/` as the fixed connectivity destination. Perform a small HTTPS request, discard its body, require HTTP 200, and retain TLS validation. Do not add automatic alternative destinations or destination-selection CLI options. Do not interpret success as package-mirror availability or proof that package installation works.
- **Status**: Accepted

## DEC-011
- **Question**: What finite waiting limits should bound bootstrap qualification?
- **Context/Nuances**: Mandatory KVM makes five minutes an initial reasonable bound for boot and checks, not an observed duration or performance guarantee. A separate HTTPS limit prevents an external request from consuming the entire budget unnecessarily. The HTTP limit is nested within, not added after, the global limit. Real qualification may identify a need to revise these values; such a revision requires explicit review. Detailed stopping mechanics and normalized outcome classification remain unresolved.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed fixed deadlines and timeout behavior.
- **Decision**: Allow at most five minutes from QEMU launch to complete boot and all qualification checks. Limit the HTTPS request to at most thirty seconds within that global deadline. Provide no CLI timeout options and no automatic retries of the complete test. Expiry prevents qualification, preserves diagnostic evidence, and initiates VM stopping. Resolve stopping mechanics and exit classification separately. Revisit the limits explicitly if real qualification demonstrates they need adjustment.
- **Status**: Accepted

## DEC-012
- **Question**: What host privilege and prerequisite-management boundary should govern the test?
- **Context/Nuances**: The architecture requires unprivileged orchestration and functional KVM rather than software-emulation fallback. File and binary presence alone does not demonstrate functional acceleration. Automatically installing dependencies, changing permissions or groups, or starting services would make ISO testing reconfigure the host and expand this story. Exact functional preflight commands are implementation deliverables, not permission to waive the checks.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of normal-user execution, prerequisite checks, and no automatic host remediation.
- **Decision**: Run `operations/test` as a normal user with direct KVM access; reject root domain execution while keeping help available to root. Before launching the test VM, check functional KVM, available OVMF, and necessary tools. Missing or unusable prerequisites stop execution with actionable guidance. Do not install packages, change host permissions or groups, start services, fall back to sudo, or fall back to software emulation.
- **Status**: Accepted

## DEC-013
- **Question**: What host resources and firmware state may the guest receive?
- **Context/Nuances**: Sharing host directories, credentials, physical devices, or host environment values would unnecessarily expose private host state. OVMF variables are persistent UEFI configuration, including boot entries; reusing them can carry state across runs, while allowing changes to the installed template would modify the host. Restricting exposure is not an absolute security guarantee against a guest or hypervisor vulnerability. Necessary guest-control channels remain scoped to the test.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the isolation boundary and fresh per-run UEFI state.
- **Decision**: Do not share host directories, credentials, physical devices, or environment variables with the VM. Supply only the input ISO, empty test disk, temporary NoCloud medium, firmware, and necessary control channels. Use read-only OVMF code and a fresh copy of UEFI variables for each execution; do not reuse previous variable state or modify the host template. This limits exposure and inherited state without claiming absolute QEMU isolation guarantees.
- **Status**: Accepted

## DEC-014
- **Question**: How should the harness stop the current VM and dispose of temporary resources?
- **Context/Nuances**: Directly terminating the owned QEMU process avoids adding an unnecessary guest shutdown protocol. SIGTERM permits QEMU to terminate but is not an orderly guest shutdown; this is accepted because the test neither installs nor retains guest data. Removing files while QEMU may still be using them would be unsafe. Diagnostic retention is separate from disposable guest state, and the operation has no authority over other VMs.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed stopping sequence, wait limits, and conservative cleanup boundary.
- **Decision**: On completion, failure, or interruption, stop only the current execution's QEMU process with SIGTERM and wait up to ten seconds. If it remains alive, send SIGKILL and wait up to five more seconds. Confirm process exit before deleting the current run's disposable disk, UEFI variables, and NoCloud medium, while retaining diagnostics. If exit cannot be confirmed, leave its resources intact, do not claim success, and report remaining resources for manual investigation. Never act on another VM. Accept that direct process termination does not demonstrate orderly guest shutdown.
- **Status**: Accepted

## DEC-015
- **Question**: How should normalized exit outcomes apply to bootstrap testing?
- **Context/Nuances**: Architecture defines stable lifecycle statuses and preserves ordinary signal conventions. A completed check reporting an unusable guest differs from failure to execute or complete the check. Cleanup must not erase the primary reason for failure. This non-destructive test has no explicit interactive cancellation flow requiring status 3. Help success remains distinct from domain qualification.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed classification and failure precedence.
- **Decision**: Return 0 for domain testing only when checks pass, evidence is accepted, and cleanup completes. Return 2 for invalid arguments, inadmissible bundles, unmet prerequisites, or content rejected by secret scanning. Return 4 when checks execute but the guest fails the required criteria, including unavailable external connectivity. Return 5 for execution failures, including QEMU, deadline expiry, tools, scanner execution, or cleanup. Return 6 for a damaged checkout or internal contract violation. Preserve 130 for SIGINT and 143 for SIGTERM; no status-3 interaction is introduced. A secondary cleanup failure does not replace an earlier non-success result. Cleanup failure after otherwise successful work changes the result to 5, not success.
- **Status**: Accepted

## DEC-016
- **Question**: What minimum evidence should each test retain?
- **Context/Nuances**: A concise structured result supports artifact attribution and diagnosis without collecting unnecessary host or guest state. Build metadata is immutable after publication under the Story 1.3 contract; boot evidence must remain separate rather than modifying that bundle. Human output and structured evidence must describe the same result. Exact field names and file layout remain implementation or subsequent design details, not a mandate to introduce a general verification schema.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the minimum evidence set and immutable-bundle boundary.
- **Decision**: Retain one JSON result per execution, separate from the bundle. Include artifact identity and checksum, test-code identity, effective VM configuration, QEMU and OVMF versions, individual check results, duration, failing stage and next action, final exit status, original tool statuses, scan outcomes, and cleanup outcomes. Limit logs to guest serial output and QEMU diagnostics, with redacted scan reports. Do not collect screenshots, memory dumps, or complete host inventories. Leave the bundle unchanged; do not rewrite construction metadata to add boot qualification. Derive the terminal summary from the same result.
- **Status**: Accepted

## DEC-017
- **Question**: Where should per-run VM resources and retained evidence live, and how should they be protected?
- **Context/Nuances**: Temporary guest state and retained diagnostic evidence have different lifecycles. The builder already uses UTC timestamp plus UUID run identifiers, but applying that pattern here requires this explicit choice. Private permissions limit access to the invoking user and root, not root itself. Generated paths remain ignored rather than becoming authoritative source. Automatic evidence expiry would require a separate retention policy and is unnecessary for this story.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed directory layout, identifier, permissions, and retention.
- **Decision**: Use `build/reference-vm/<run-id>/` for temporary VM resources and `evidence/reference-vm/<run-id>/` for retained results and diagnostics. Generate a run identifier from UTC timestamp plus UUID, following the builder's pattern. Use mode 0700 for per-run directories and 0600 for generated files. Do not overwrite earlier runs. Cleanup removes only the current execution's temporary resources while preserving evidence. Introduce no automatic evidence-expiry policy.
- **Status**: Accepted

## DEC-018
- **Question**: What secret-scan and terminal-exposure policy should apply to test inputs and retained diagnostics?
- **Context/Nuances**: The test generates NoCloud text and retains a JSON result and allowlisted logs. These require explicit scan coverage; ignored paths and private permissions do not establish that scanning occurred. Accepted ADR 0001 remains the build scan-scope authority, and VM testing does not reopen ISO-layer extraction. Scanning is detection within its declared scope rather than an absolute absence-of-secrets guarantee. Preserving privately retained findings permits review without automatic sanitization or raw terminal exposure.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the proposed scan scope and diagnostic exposure policy.
- **Decision**: Require Gitleaks. Scan generated NoCloud text before attaching it to the VM, and scan the result JSON, allowlisted logs, and retained reports before accepting qualification. Do not re-extract the ISO or scan binary disks or firmware. Preserve the construction scan scope under ADR 0001. Findings block qualification; retain diagnostics privately for review without automatic sanitization. Keep reports redacted and show only progress and summaries on the terminal, not raw guest logs. Do not claim absolute absence of secrets from a clean scan.
- **Status**: Accepted

## DEC-019
- **Question**: Must formal Story 1.4 acceptance run from an additional clean clone, or can it use the existing clean committed checkout?
- **Context/Nuances**: The initial recommendation to require another clone was not approved. The user asked why cloning was needed for testing. A fresh clone can detect accidental dependencies on unversioned local files, but does not clean or isolate the host and requires the ignored input bundle to be supplied separately. Artifact identity and harness-code identity are independent: the ISO is identified by its checksum and build metadata, while a commit identifies harness code only when local modifications are absent. The user approved the simpler alternative after the trade-off was explained. No accepted decision is superseded by withdrawal of the unapproved clone recommendation.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the simplified recommendation without a mandatory additional clone.
- **Decision**: Allow development tests with locally modified test code or dirty bundles, recording their dirty state and distinguishing them from formal story acceptance. Formal Story 1.4 acceptance uses committed test code in a clean checkout, which may be the habitual checkout, and a bundle from clean accepted Story 1.3 construction. Do not require an additional clone or rebuild the ISO merely because the harness changed. The artifact and test-code commits may differ and must both be identified. Accept the loss of the extra fresh-clone check for independence from unversioned local files; a clean checkout does not establish host isolation.
- **Status**: Accepted

## DEC-020
- **Question**: What minimum validation strategy should Story 1.4 require?
- **Context/Nuances**: Earlier stories establish Bats command contracts and built-in Node tests. Simulated tools permit deterministic failure, deadline, interruption, scanning, and cleanup tests without repeatedly constructing or launching full guests. Such tests do not demonstrate actual QEMU/OVMF or cloud-init integration. One successful real execution with the retained clean bundle demonstrates the supported path, while omitting real induced failures leaves those error contracts simulation-tested rather than real-failure-qualified.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the minimum two-level strategy and its qualification limits.
- **Decision**: Use automated Bats and Node tests with simulated tools to cover arguments, prerequisites, invalid bundles, guest check failures, deadlines, interruptions, secret scanning, and cleanup. Require one satisfactory real execution with the retained clean accepted construction bundle, demonstrating KVM/OVMF, NoCloud integration, actual guest checks, and final scanned evidence. Do not require ISO rebuilding or a battery of failures induced in real VMs. Distinguish contract simulation evidence from real integration evidence; neither substitutes for the other.
- **Status**: Accepted

## DEC-021
- **Question**: What review and commit flow should govern implementation and formal qualification?
- **Context/Nuances**: Formal acceptance needs committed harness code in a clean checkout, but committing a candidate is not proof of integration success. One pre-commit human checkpoint keeps the workflow simple while retaining explicit approval of the implementation diff, tests, and documentation. A failed real execution must remain diagnosable rather than disappearing through rewritten history. This flow is a future implementation contract, not interview-time execution authority.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the single pre-commit checkpoint and subsequent real gate.
- **Decision**: After implementation and local tests, present the diff, tests, and documentation at one blocking human checkpoint before creating the candidate commit. Commit only after explicit approval, then run the real qualification from that clean committed checkout. Story completion requires that execution to satisfy the approved criteria and retain scanned evidence. Preserve failed results and make corrections in additional commits rather than rewriting the failed candidate. Do not introduce a second mandatory human checkpoint, and do not treat this interview approval as authorization to commit or execute now.
- **Status**: Accepted

## DEC-022
- **Question**: What complete argument and help contract should `operations/test` expose?
- **Context/Nuances**: Inspection of the existing test contract suite found that no-argument execution still expects pending-work refusal. Implementing domain behavior must update that diagnostic while preserving side-effect-free help and damaged-checkout handling. Relative input paths should resolve against the caller's working directory, independently of locating repository-owned resources from the executable. Early argument rejection must not start domain work or create evidence.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of the closed invocation surface and early refusal contract.
- **Decision**: Accept only sole `--help` or one explicit bundle-directory argument, including paths relative to the caller's working directory and paths containing spaces. Reject missing arguments, unknown options, multiple arguments, and help combined with other arguments with status 2 before creating files or invoking domain tools. The no-argument diagnostic must identify the missing bundle directory rather than unimplemented work. Help requires neither QEMU, KVM, OVMF, nor Gitleaks. Introduce no additional options or aliases; preserve the damaged-checkout outcome contract.
- **Status**: Accepted

## DEC-023
- **Question**: How should the harness determine whether guest output actually establishes passing checks?
- **Context/Nuances**: Serial logs can contain ordinary text, diagnostics, or completion words that are not a coherent check result. A small structured report tied to the execution avoids accepting a success substring or missing observations. Architecture already selects JavaScript ESM on Node for structured validation; this does not require a new framework or prematurely establish a general capability-verification schema.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of structured guest reporting and complete validation.
- **Decision**: Have the guest emit a small JSON report identified by the current run-id, and validate its fields and all required check results in the harness using Node. A missing check, incomplete or contradictory report, or report for another execution must not grant qualification. Do not accept success merely by matching a word such as SUCCESS in logs or infer success from absent results. Delegate the exact small report format to implementation with tests; do not add a framework.
- **Status**: Accepted

## DEC-024
- **Question**: How should new runs and recovery handle pre-existing or residual resources?
- **Context/Nuances**: Automatic recovery or cleanup of prior runs would require additional identity, activity, and authorization machinery beyond this bootstrap story. Output-path collisions and symbolic-link output directories can undermine per-run ownership boundaries. Private evidence remains useful after interrupted executions and must not be deleted with temporary guest state. Manual recovery must establish that the associated QEMU has ended before deleting its resources.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of conservative creation and concise manual recovery.
- **Decision**: A new test must never recover, reuse, or automatically delete resources from previous executions. Reject an occupied reserved run location or symbolic-link output directories with status 2 without modifying those resources. Document a short manual recovery procedure to identify the execution, confirm its QEMU has terminated, and remove only its temporary resources while retaining evidence. Add no recovery command and do not implement or extend operations/clean.
- **Status**: Accepted

## DEC-025
- **Question**: Should the reference test run exclusively headless or support a graphical QEMU mode?
- **Context/Nuances**: The approved NoCloud and serial-channel mechanism can support automatic command-based checks without a graphical host desktop or visual interaction. Headless execution avoids another mode and its dependencies. It does not demonstrate the appearance or interactive usability of the graphical boot menu or graphical console; those are outside the approved command-based bootstrap checks.
- **User Response**: "yes, registra directamente la decisión." Explicit approval of exclusively headless execution and its limits.
- **Decision**: Run QEMU exclusively headless for Story 1.4, opening no graphical window and requiring no graphical desktop on the host. Use the approved serial channel for checks and results. Do not add an optional graphical mode. Qualification covers boot and command-based usability, not boot-menu presentation or the graphical console.
- **Status**: Accepted

## DEC-026
- **Question**: Is the interview ready to close with one implementation-plan handoff and explicit outstanding qualification obligations?
- **Context/Nuances**: The substantive bootstrap design branches have been approved. Architecture places the lifecycle entry point in operations/ and QEMU/OVMF domain ownership in vm/reference/, with Bash for bounded process work and Node ESM for structured logic. Mechanical commands, internal filenames, and JSON fields can be implementation deliverables without reopening every spelling choice. TODO-001 is still a real-integration obligation, not evidence that cloud-init/NoCloud already works. Closure must not conflate approved design with delivered runtime code or accepted boot qualification.
- **User Response**: "yes, registra directamente la decisión." Explicit confirmation of interview closure and the proposed handoff.
- **Decision**: Close the design interview and deliver Story 1.4 through one implementation plan. Keep operations/test small and place domain implementation in vm/reference/ under architecture boundaries. Use Bash for bounded process work and Node ESM for structured data, without new frameworks. Include tests, usage and manual recovery documentation, README updates, and the approved real gate. Delegate concrete commands, internal names, and JSON fields to the implementer under the agreed contracts. Keep TODO-001 pending until real integration is demonstrated; a finding requiring a design change must return for explicit approval. Update the Consolidated Plan's status and obsolete pending-design wording without removing trade-offs. Closure establishes design readiness, not story completion, present commit authority, or boot-qualified artifact status.
- **Status**: Accepted

# Story 1.2 Repository Governance and Lifecycle Discovery — Consolidated Plan

## Scope and Existing Foundation

Story 1.2 completes and validates repository governance and lifecycle discovery rather than rebuilding the foundation established by Story 1.1. Existing licensing, agent rules, generated-output ignore rules, ShellCheck policy, attribution, ADR guidance and template, and the Archiso update procedure must be assessed against this story's acceptance criteria. Repository inspection found no root README, lifecycle entry points, or corresponding procedures and tests. [DEC-001]

The lifecycle surface consists of independently invocable documented scripts for `build`, `test`, `install`, `configure`, `verify`, and `clean`, following the architecture's `operations/` ownership boundary rather than introducing a unified CLI, Make, or Just. Their purpose, prerequisites, inputs, consequential effects, evidence location, and normalized outcomes must be discoverable. [DEC-001]

## Domain Implementation Boundary

This story does not implement ISO construction, VM qualification, installation, environment convergence, or capability verification. An entry point whose domain behavior remains unimplemented must state that limitation, return a documented distinguishable outcome, and neither mutate the system nor report successful completion of the missing work. The outcome and initial invocation contract are defined below: help succeeds, unimplemented work and invalid arguments return `2`, and required-helper failures return `6`. [DEC-001, DEC-002, DEC-003, DEC-008, DEC-018]

## Resolved Scope Dependencies and Deferred Domain Work

Cleanup remains unimplemented, while repository validation uses explicit documented commands rather than a coordinator. The sections below define help, documentation, outcomes, tests, scanning coverage, workflow-tooling treatment, evidence, and acceptance. These selections follow separate approvals rather than being implied by the initial scope decision. [DEC-001, DEC-002, DEC-004, DEC-005, DEC-007, DEC-008, DEC-009, DEC-010, DEC-012, DEC-018, DEC-020]

Actual cleanup policy and later domain implementation remain deferred to their appropriate work, not unresolved requirements for Story 1.2. Concrete validation commands are implementation deliverables constrained by the accepted checks; this story does not invent a final structured evidence schema. [DEC-004, DEC-005, DEC-020, DEC-024]

## Help and Procedure Discovery

Every lifecycle entry point under `operations/` supports `--help` without privilege elevation or state changes. Successfully displaying help returns `0`, even when the command's domain behavior is not implemented: that result certifies only successful help delivery, not lifecycle execution. Normal invocation of an unimplemented operation follows the separately approved refusal contract below. [DEC-002, DEC-003]

Terminal help concisely presents the command's purpose, prerequisites, inputs, consequential effects, evidence location, and normalized exit outcomes, and links to its complete procedure under `docs/procedures/`. The procedure contains the full operational details and can be consulted without running code. [DEC-002]

## Unimplemented Operation Invocation

When invoked without `--help`, a lifecycle operation whose implementation is unavailable returns normalized status `2`, representing an unmet precondition. Its diagnostic goes to `stderr`, identifies the pending operation, and links to the relevant documentation. Refusal performs no privilege elevation and creates no files, including evidence files. Status `5` is reserved for an actual attempted execution that fails; unavailable behavior is never reported as successful completion. [DEC-003]

## Cleanup Boundary

`operations/clean` remains unimplemented in Story 1.2: its help is functional, but normal invocation returns `2` and performs no privilege elevation, file creation, or deletion. The existence of generated local directories does not authorize their removal. Actual cleanup must be designed when the resources it manages and their evidence-retention and recovery requirements are known, rather than anticipating those policies in this story. [DEC-004]

## Repository Validation Invocation

Repository validation is performed through documented explicit commands for static analysis, contract tests, and secret scanning. Story 1.2 introduces no custom validation coordinator; automation may be reconsidered only after demonstrated recurring need. Implementation must supply concrete commands following the selected Bats mechanism, scanning coverage, static checks, and dependency and failure contracts defined below. [DEC-005, DEC-007, DEC-009, DEC-016, DEC-022, DEC-023, DEC-024]

`operations/test` retains its architectural responsibility for VM validation and returns `2` while that behavior is unimplemented. Passing repository checks does not mean an ISO has been boot-tested or otherwise VM-qualified, and documentation must preserve this distinction. [DEC-005]

## Implementation Language and Complexity Escalation

Lifecycle entry points remain small Bash scripts for help, bounded precondition checks, and direct invocation of system tools. They are independent commands rather than a unified CLI and must not absorb or duplicate domain implementation or grow into monolithic installers. [DEC-006]

Responsibilities that require structured-data processing, non-trivial state models, or complex parsing are implemented in JavaScript ESM on Node.js from the outset. If such complexity emerges in an existing Bash responsibility, that responsibility moves to JavaScript before further extension. The choice follows responsibility and complexity rather than the language in which a component happened to start; this criterion makes the existing architecture boundary explicit rather than introducing a competing language policy. [DEC-006]

## Contract Test Mechanism

Bats implements command contract tests under `tests/operations/`, using the architecture's test-naming conventions. The tests check normalized exit statuses, stdout, stderr, and absence of unintended changes, including successful help and refusal of unimplemented operations. The required test matrix and observation approach are defined below; implementation supplies concrete tests and commands that satisfy them. [DEC-007, DEC-014, DEC-015, DEC-018, DEC-024]

Bats is a development-only prerequisite, not an installation-image dependency, and MirrorOS does not install it automatically. Its selection does not determine the production implementation language. The tests run through documented explicit commands without introducing a custom validation coordinator. [DEC-005, DEC-007]

## Initial Argument Contract

For all six lifecycle entry points in Story 1.2, `--help` is accepted only as the sole argument and returns `0` after displaying help. Invocation without arguments returns `2` because domain behavior is unimplemented. Any other argument or combination, including additional arguments alongside `--help`, returns `2` with an unsupported-argument diagnostic on `stderr` and no state changes. Diagnostics distinguish invalid arguments from unavailable implementation even though both map to normalized status `2`. No other options or aliases are provided at this stage; future domain interfaces are not selected speculatively. [DEC-002, DEC-003, DEC-008]

## Secret-Scanning Coverage and Acceptance

Repository validation requires Gitleaks scans of Git history and the working tree. Staging directories and generated outputs presented for acceptance receive explicit coverage even when ignored by Git; source-control exclusion is not evidence that a path has been scanned. This extends the existing Archiso procedure's separate source and evidence scanning approach. [DEC-009]

A finding or scanner failure blocks acceptance. Reports are redacted and do not reproduce secret values. This story does not implement inspection of the ISO's internal contents: that artifact-inspection responsibility belongs to Story 1.3. Implementation supplies explicit scan commands satisfying this coverage, the negative-control test, redaction, evidence, and failure requirements. [DEC-009, DEC-020, DEC-021, DEC-023, DEC-024]

## Workflow-Tooling Boundary

Story 1.2 implementation adds a root-anchored `/.agents/` entry to `.gitignore`, making its exclusion portable to fresh clones instead of relying only on the current checkout's `.git/info/exclude`. Documentation identifies `.agents/` plans and execution records as workflow-tooling content, outside the product runtime and authoritative source control. Its existing contents remain intact and are not incorporated into runtime artifacts. [DEC-010]

The existing `/docs/.obsidian/` ignore rule remains unchanged, and its protected local editor configuration is neither removed nor reorganized. Workflow-tooling retention does not imply inclusion in the product or source-controlled delivery. [DEC-010]

## Root Documentation Entry Point

The root `README.md` serves as an entry map, not a duplicate operational manual. It explains MirrorOS's purpose and actual project state, presents the six lifecycle commands in a table with their availability, and links to complete procedures, repository-validation documentation, licensing, attribution, and repository rules. [DEC-011]

Operational detail stays in the procedures to avoid duplicated instructions and documentation drift. The README clearly distinguishes functional discovery/help from unimplemented domain behavior and must not suggest that pending lifecycle operations already work. [DEC-011]

## Procedure Availability and Intended Contracts

Procedures for pending operations clearly separate currently available behavior from the intended domain contract. Current behavior covers invocation, functional help, invalid-argument refusal, and normal invocation returning `2` without changes. Readers must be able to distinguish discovery support from actual domain execution. [DEC-012]

The intended-contract section describes purpose, known prerequisites, inputs, consequential effects, evidence, and recovery, marking undecided details explicitly as pending rather than inventing them. Executable construction or installation instructions are not presented as supported workflows until implemented and validated. This preserves discoverability without claiming operational support prematurely. [DEC-012]

## Working-Directory Independence

Lifecycle entry points work regardless of the caller's current directory, including invocation by an explicit path from outside the repository. Resource and documentation lookup must not depend on a preliminary `cd` into the checkout. Bats contract tests exercise this behavior. No global command installation or PATH modification is introduced by this contract. [DEC-013]

## Minimum Command Contract Test Matrix

The same minimum Bats matrix applies to `build`, `test`, `install`, `configure`, `verify`, and `clean`. Sole `--help` returns `0`, displays help on stdout, and emits no stderr diagnostics. Invocation without arguments returns `2`, reports the unavailable operation on stderr, and emits no success message. Unsupported arguments, including `--help` combined with additional arguments, return `2` with a diagnostic. [DEC-014]

Tests exercise invocation from outside the repository and checkouts whose paths contain spaces. They verify that commands create, modify, and delete no files and invoke neither privileged tools nor domain-execution tools. Exit status alone is not sufficient evidence of the no-change contract. The observation mechanism is defined in the following section and must preserve this coverage and its stated limitations. [DEC-013, DEC-014, DEC-015]

## Side-Effect Observation in Contract Tests

Contract tests run against disposable temporary copies with a temporary HOME rather than the maintainer's live checkout and home. Privileged and domain-execution tools are replaced by doubles that record attempted calls and fail. File comparisons before and after command execution detect creation, modification, and deletion; test setup and observation must not be mistaken for command-induced changes. [DEC-015]

This mechanism is not a security sandbox. Absolute-path calls can bypass tool doubles, so static review of the small lifecycle scripts complements dynamic tests. Test documentation must state this limitation rather than claim complete filesystem or process isolation. [DEC-015]

## Static Validation Baseline

Documented repository-validation commands use `bash -n` for project-owned Bash executables and libraries, ShellCheck with the existing `.shellcheckrc` policy and no global exclusions, and Bats for contract-test execution. Any ShellCheck exception is narrowly scoped and justified. [DEC-016]

Validation does not drive corrective edits to the unmodified imported Archiso profile. Story 1.2 introduces no mandatory formatter, avoiding unrelated formatting changes or tooling expansion. [DEC-016]

## Shared Discovery Contract Helper

A small Bash helper under `operations/lib/` implements common argument validation and refusal of unimplemented operations for the six concrete lifecycle entry points. Each command retains its identity and help text. This shares an established contract rather than introducing speculative reusable infrastructure. [DEC-017]

The helper owns no domain behavior and must not grow into a general CLI framework. It remains subject to the Bash complexity-escalation criterion and the same static-validation policy as other project-owned shell code. [DEC-006, DEC-016, DEC-017]

## Shared Helper Failure Contract

A missing or unloadable required helper produces normalized status `6`, not the pending-operation status `2` or an accidental generic shell failure status. The entry point reports an actionable diagnostic on stderr identifying the checkout as incomplete or damaged and explaining how to restore it, without making changes. Contract tests cover this failure path in addition to the ordinary invocation matrix. [DEC-018]

## Clean-Clone Acceptance Gate

Final acceptance validates a temporary clean clone of the candidate state already committed to Git. The gate checks documentation and governance, executable permissions of all six commands, static analysis, Bats contract tests, exclusion of generated outputs and local workflow tooling, and corresponding secret scans. It must demonstrate that the design works from version-controlled content rather than depending on untracked local files. [DEC-019]

A local source repository is sufficient: this gate requires neither a configured remote nor ISO construction and does not claim artifact qualification. Approval of the gate does not authorize interview-time commits or runtime implementation changes. [DEC-019]

## Validation Evidence

Retain repository-validation evidence under `evidence/repository-validation/<UTC-timestamp>/`, outside Git. Its minimum content is a non-sensitive summary of the evaluated commit, executed commands, and results, accompanied by redacted reports where applicable. The retained evidence receives a secret scan before acceptance. [DEC-020]

Documented validation commands produce this evidence; unimplemented lifecycle entry points do not. Their no-file-creation contract remains unchanged, and validation evidence does not imply domain execution or ISO qualification. [DEC-003, DEC-005, DEC-020]

## Secret-Scanner Negative Control

A controlled negative test creates a detectable synthetic value in a temporary ignored directory and verifies that Gitleaks reports a detection. This exercises actual detection and coverage of ignored generated paths rather than relying solely on clean-input results. It uses no real credentials and adds no global scanner exceptions. [DEC-021]

After the drill, remove the synthetic input and scan any retained redacted evidence. The drill's expected finding is not a final acceptance exception: final acceptance still requires scans without findings. Retained evidence must not reproduce the synthetic secret-like value. [DEC-009, DEC-021]

## Validation Dependency Boundary

Bash, ShellCheck, Bats, and Gitleaks are external prerequisites for repository validation. Documentation provides availability checks, and validation stops if a required tool is absent rather than accepting an incomplete run. MirrorOS does not install these tools automatically or modify the host to satisfy validation requirements. [DEC-022]

Lifecycle help uses the Bash runtime but does not require ShellCheck, Bats, or Gitleaks. Missing validation-only dependencies therefore do not prevent a user from consulting a command's usage contract. [DEC-022]

## Validation Failure and Recovery

A failed repository-validation step stops the acceptance sequence. Retain the original tool exit status and non-sensitive evidence, and document how to correct the failure and rerun validation. Evidence retention never authorizes storing secret values. The negative-control drill's expected detection is evaluated as a test condition, not treated as a clean final acceptance scan. [DEC-021, DEC-023]

Direct validation commands retain their native exit statuses; Story 1.2 adds no wrapper to normalize them. The normalized MirrorOS statuses `0`, `2`, `3`, `4`, `5`, and `6` continue to govern lifecycle entry points, preserving the distinction between direct development-tool validation and product lifecycle invocation. [DEC-023]

## Implementation Readiness and Completion

The Story 1.2 design interview is closed, and this consolidated plan is ready to drive implementation. Implementation must deliver the documentation, six lifecycle scripts, limited shared helper, contract tests, and explicit repository-validation commands described above. Completing this interview does not mean that the story has been implemented or validated. [DEC-024]

Story completion requires the approved checks and retained clean-clone acceptance evidence. An implementation finding that contradicts this design must return for an explicit decision rather than be resolved silently. Concrete command spelling and mechanical implementation details must preserve the accepted contracts and all stated testing and scanning limitations. [DEC-019, DEC-020, DEC-024]

## Candidate Commit and Review Checkpoint

The clean-clone gate validates a candidate created only after implementation passes local validation with `bash -n`, ShellCheck, Bats, and the Gitleaks scans. A blocking human checkpoint then presents the diff for review; only after explicit approval is a single commit created on `main`, including both Story 1.2 interview artifacts alongside the implementation, consistent with how the Story 1.1 interview artifacts are tracked. [DEC-019, DEC-025]

The clean-clone gate runs against that commit. If it fails, corrections are made in an additional commit rather than by rewriting history, and the gate is repeated, preserving the evidence trail of the failed attempt. ShellCheck availability, found missing during planning and since installed locally, is still re-checked at execution time under the validation dependency boundary. [DEC-022, DEC-023, DEC-025]

## Deliverable Layout

The shared helper is `operations/lib/lifecycle-discovery.sh`. It deliberately avoids the architecture's reserved `exit-status.sh`, `preflight.sh`, and related names, which belong to broader future responsibilities, and defines only the statuses it actually uses. Because a helper that cannot be loaded cannot report its own failure, each entry point returns a literal `6` in that case. [DEC-017, DEC-018, DEC-026]

Each lifecycle command has its procedure at `docs/procedures/<command>.md`. Repository validation is documented in `docs/procedures/repository-validation.md`, covering explicit commands, prerequisite checks, the negative-control drill, evidence, the clean-clone gate, failure recovery, and the statement that test observation is not a security sandbox. [DEC-005, DEC-012, DEC-015, DEC-019, DEC-020, DEC-021, DEC-022, DEC-023, DEC-026]

Contract tests use one `tests/operations/<command>.contract.bats` file per command, sharing `tests/operations/lifecycle-discovery.bash` for the disposable copy, temporary HOME, tool doubles, and before/after file comparison. Every file applies the full minimum matrix, including the helper-failure case. The `.agents/` workflow-tooling boundary is documented in a `README.md` section linked from `AGENTS.md`, without a separate document. [DEC-010, DEC-014, DEC-015, DEC-018, DEC-026]

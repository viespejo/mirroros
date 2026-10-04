# Story 1.2 Repository Governance and Lifecycle Discovery — Decision Log

**Conventions.** The Consolidated Plan (`story-1-2-governance-lifecycle-discovery_plan.md`) is the single source of truth for the *design* — the implementing agent builds from it. This log is *history*: it records the reasoning and the evolution of decisions. When a later decision revises an earlier one, the earlier entry is not rewritten (append-only); instead its `Status` carries a forward pointer to the superseding entry, so the two read as an evolution, not a live contradiction.

## DEC-001
- **Question**: Should Story 1.2 complete and validate repository governance and discovery of the six lifecycle entry points without implementing later domain behavior?
- **Context/Nuances**: Story 1.1 already established the initial governance foundation. Repository inspection found the license, agent rules, ignore rules, ShellCheck configuration, attribution records, ADR template and guidance, and Archiso update procedure, but no root README or lifecycle operations, procedures, or tests. The architecture specifies independently invocable scripts under `operations/`, not a unified CLI or task runner. Story 1.2 must not claim that unimplemented work succeeds. Real cleanup behavior and repository validation remain separate questions rather than implied selections.
- **User Response**: After requesting a brief explanation of the story, the user explicitly approved the proposed scope and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Story 1.2 will complete and validate repository governance and discovery for `build`, `test`, `install`, `configure`, `verify`, and `clean`. It will not implement ISO construction, VM qualification, installation, environment convergence, or capability verification. Unimplemented commands must communicate their limitation, return a distinguishable documented outcome, and perform no system mutation or false successful completion. The interview must separately resolve cleanup behavior, repository validation, help, documentation, normalized outcomes, tests, secret-scanning coverage, and workflow-tooling directory handling.
- **Status**: Accepted

## DEC-002
- **Question**: How should users discover the usage contract of each lifecycle command?
- **Context/Nuances**: Users need both quick terminal guidance and complete procedures readable without executing code. Displaying help is a completed operation in its own right; exit status zero for help must not imply that the underlying lifecycle domain behavior is implemented or has succeeded.
- **User Response**: The user explicitly approved the recommended contract and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Every `operations/<command>` lifecycle entry point will support `--help` without privilege elevation or state changes and return `0` when help is successfully displayed. Help will identify purpose, prerequisites, inputs, consequential effects, evidence location, normalized exit outcomes, and a link to the complete procedure under `docs/procedures/`. Terminal help provides concise discovery while the procedure supplies full details and remains readable without executing code. This decision does not select normal-invocation behavior for unimplemented commands.
- **Status**: Accepted

## DEC-003
- **Question**: What should an unimplemented lifecycle operation do when invoked without `--help`?
- **Context/Nuances**: An unavailable implementation is an unmet precondition, not an upstream operation that was attempted and failed. Exit status `5` remains reserved for actual execution failures. Help success under DEC-002 does not imply domain implementation. Refusing unimplemented work must not itself create evidence or other files.
- **User Response**: The user explicitly approved the recommendation and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Normal invocation of an unimplemented lifecycle operation returns normalized status `2` (unmet precondition). It emits an actionable diagnostic on `stderr` identifying the pending operation and linking to its documentation. It performs no privilege elevation and creates no files. It must not report successful completion or classify missing implementation as execution failure `5`.
- **Status**: Accepted

## DEC-004
- **Question**: Should `clean` delete resources in Story 1.2 or remain unimplemented?
- **Context/Nuances**: The production build workflow does not yet exist to establish which resources are disposable. Implementing deletion now would anticipate evidence-retention and recovery policies. Existing generated directories do not by themselves establish authorization or a cleanup policy. Deferring cleanup does not remove it from the lifecycle design.
- **User Response**: The user explicitly approved leaving `clean` pending and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Story 1.2 will not implement destructive cleanup behavior. `operations/clean` provides functional `--help` under DEC-002; normal invocation follows DEC-003, returning `2` without privilege elevation, file creation, or deletion. Actual cleanup behavior will be designed once its managed resources and evidence-retention and recovery requirements are known.
- **Status**: Accepted

## DEC-005
- **Question**: How should repository validation be invoked in Story 1.2?
- **Context/Nuances**: The architecture assigns `operations/test` to VM validation, not repository-only checks. Repository validation must not imply that an ISO has been tested. Custom automation requires demonstrated recurring need, and this story should not introduce a coordinator before that need is established. This decision selects the invocation approach, not the test framework, precise commands, or secret-scanning coverage.
- **User Response**: The user explicitly approved the separation and documented-command approach and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Story 1.2 will document explicit commands for static analysis, contract tests, and secret scanning without introducing a custom validation coordinator. `operations/test` remains reserved for VM validation and returns `2` while that behavior is unimplemented. Repository-validation results and ISO/VM qualification remain distinct.
- **Status**: Accepted

## DEC-006
- **Question**: Are Bash lifecycle entry points appropriate, and how will the design prevent complex responsibilities from remaining in Bash merely because they started there?
- **Context/Nuances**: The user raised the risk of incremental complexity accumulating in Bash instead of moving directly to JavaScript. The architecture already selects Bash for bounded native Arch integration and JavaScript ESM on Node.js for non-trivial structured logic. These are independent lifecycle scripts, not a unified CLI. Alternatives discussed included JavaScript for all entry points, Python (prohibited for project-owned code without an accepted ADR), and Go or Rust (additional compilation and maintenance infrastructure for this scope). Bats does not determine the implementation language.
- **User Response**: The user approved the escalation criterion, Bash, and Bats: "ok, tanto para este criterio como para el uso de Bash y Bats".
- **Decision**: Keep lifecycle entry points small and implement simple help, bounded precondition checks, and direct tool invocation in Bash. Implement responsibilities requiring structured-data processing, a non-trivial state model, or complex parsing in JavaScript ESM on Node.js from the outset. If that complexity emerges in existing Bash, move the affected responsibility to JavaScript before extending it. Language follows responsibility and complexity, not historical implementation. Entry points must not absorb or duplicate domain logic or become monolithic installers.
- **Status**: Accepted

## DEC-007
- **Question**: Which tool should implement lifecycle command contract tests?
- **Context/Nuances**: Bats (Bash Automated Testing System) provides Bash-written CLI tests that can inspect exit status and captured output without creating a custom test framework. The proposed tests cover help success, unimplemented-operation refusal, output behavior, and absence of unintended changes. Bats adds a development dependency but does not select the production language.
- **User Response**: After asking what Bats is and discussing the Bash/JavaScript boundary, the user approved Bats together with Bash and the escalation criterion: "ok, tanto para este criterio como para el uso de Bash y Bats".
- **Decision**: Use Bats for command contract tests under `tests/operations/`, following architecture test-naming conventions. Tests will check exit statuses, stdout, stderr, and absence of changes. Bats is a development-only prerequisite, will not be included in the installation image, and will not be installed automatically by MirrorOS. Repository validation invokes these tests through documented commands under DEC-005 rather than a custom coordinator.
- **Status**: Accepted

## DEC-008
- **Question**: How should lifecycle commands handle unknown or surplus arguments in Story 1.2?
- **Context/Nuances**: The initial discovery interface must not silently accept options whose behavior does not exist or anticipate the future domain interface. Help success applies only when `--help` is the sole argument. Invalid arguments and unavailable implementations both use normalized status `2`, but their diagnostics distinguish the reasons.
- **User Response**: The user explicitly approved the proposed argument contract and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: In Story 1.2, each lifecycle entry point accepts only a sole `--help` argument, displaying help and returning `0`. Invocation without arguments returns `2` for unimplemented behavior under DEC-003. Any other argument or combination, including `--help` accompanied by additional arguments, returns `2` with a diagnostic on `stderr` identifying unsupported arguments. Invalid invocation performs no state changes. No additional options or aliases are introduced by this contract.
- **Status**: Accepted

## DEC-009
- **Question**: Should Story 1.2 extend the existing Archiso Gitleaks approach to repository validation, and what coverage and acceptance condition should apply?
- **Context/Nuances**: The Archiso update procedure already uses Gitleaks with redacted reports and separate working-tree, history, and evidence scans. Git ignore rules do not establish secret-scan coverage. Story 1.2 establishes repository-validation coverage, not inspection of an ISO's internal filesystem; that artifact inspection belongs to Story 1.3.
- **User Response**: The user explicitly approved the coverage and acceptance condition and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Repository validation requires Gitleaks scans of Git history and the working tree, plus staging directories and generated outputs presented for acceptance even when Git ignores them. Findings or scanner failures block acceptance. Reports must be redacted and must not reproduce secret values. Inspection of ISO internal contents remains Story 1.3 work rather than Story 1.2 implementation.
- **Status**: Accepted

## DEC-010
- **Question**: Should the local exclusion of `.agents/` become an explicit repository `.gitignore` rule?
- **Context/Nuances**: Repository inspection found workflow plans and execution records under `.agents/`, currently excluded by `/.agents/` in `.git/info/exclude`. That local exclusion is not transmitted to fresh clones. The story requires workflow-managed directories to be retained and explicitly separated from the product runtime. `docs/.obsidian/` already has a repository ignore rule and must remain untouched.
- **User Response**: The user explicitly approved the proposed treatment of `.agents/` and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Story 1.2 implementation will add the root-anchored `/.agents/` rule to `.gitignore` and document `.agents/` as workflow-tooling content outside the product runtime and authoritative source control. Existing files in `.agents/` remain intact and are not incorporated into runtime artifacts. The existing `docs/.obsidian/` exclusion and protected local contents remain unchanged. This interview registration updates only the design artifacts, not `.gitignore` or workflow-tooling files.
- **Status**: Accepted

## DEC-011
- **Question**: What role should the root `README.md` serve?
- **Context/Nuances**: A clean clone needs a clear entry point to project governance, lifecycle discovery, and repository validation. Duplicating complete procedures in the README risks documentation drift, while listing commands without their availability could imply that pending domain operations already work.
- **User Response**: The user explicitly approved the proposed README scope and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: The root README will be an entry map rather than a second complete manual. It will explain the project's purpose and actual state, include a table of all six lifecycle commands and their availability, link to their procedures and repository-validation documentation, and reference licensing, attribution, and repository rules. Operational details remain in the procedures. The README must not imply that unimplemented operations are functional.
- **Status**: Accepted

## DEC-012
- **Question**: How should procedures document lifecycle operations whose domain behavior remains pending?
- **Context/Nuances**: Lifecycle discovery requires useful documentation before full implementation, but an intended contract must not be confused with a supported operational journey. Known architecture requirements can be described without inventing undecided inputs, prerequisites, evidence details, or recovery behavior.
- **User Response**: The user explicitly approved separating available behavior from the intended contract and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Each pending-operation procedure will clearly separate currently available behavior from its intended contract. The current section documents invocation, help, invalid-argument refusal, and normal invocation returning `2` without changes. The intended-contract section explains purpose, known prerequisites, inputs, effects, evidence, and recovery, explicitly marking undecided details as pending. Procedures will not offer executable construction or installation instructions as supported workflows before those instructions are implemented and validated.
- **Status**: Accepted

## DEC-013
- **Question**: Should lifecycle commands work when invoked from a directory outside the repository?
- **Context/Nuances**: Requiring an undocumented preliminary `cd` would introduce a hidden precondition. For example, invoking `/path/to/mirroros/operations/build --help` from elsewhere must provide the same help. Independence from the caller's working directory does not imply global command installation or PATH changes.
- **User Response**: The user explicitly approved independence from the current directory and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Lifecycle entry points must work regardless of the caller's current directory and locate their resources and documentation without depending on it. Bats contract tests will exercise invocation from outside the repository. This story does not install commands globally or add them to PATH.
- **Status**: Accepted

## DEC-014
- **Question**: What minimum contract-test coverage should apply to all six lifecycle commands?
- **Context/Nuances**: A script merely running is not proof that it satisfies its discovery and safety contract. Tests must distinguish help success, unavailable implementation, and invalid arguments; cover caller-directory independence and paths containing spaces; and detect forbidden effects rather than relying only on exit status.
- **User Response**: The user explicitly approved the proposed minimum matrix and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Apply the same minimum Bats matrix to all six commands. Sole `--help` returns `0`, writes help to stdout, and emits no stderr diagnostics. No arguments returns `2`, writes a diagnostic to stderr, and emits no success message. Unsupported arguments, including `--help` with extra arguments, return `2` with a diagnostic. Tests cover invocation outside the repository and repository paths containing spaces. Tests verify no files are created, modified, or deleted and no privileged or domain-execution tools are invoked.
- **Status**: Accepted

## DEC-015
- **Question**: How should tests observe the absence of changes without risking the maintainer's real environment?
- **Context/Nuances**: DEC-014 requires observing side effects and forbidden tool invocations, not merely checking exit statuses. Disposable copies, a temporary HOME, and tool doubles reduce exposure but do not constitute security isolation: absolute-path invocations can bypass the doubles. Small scripts permit complementary static review. Test setup and observation must be distinguished from effects caused by the command under test.
- **User Response**: The user explicitly approved the proposed testing approach and its stated limitation and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Run contract tests against disposable temporary copies with a temporary HOME. Substitute privileged and domain-execution tools with doubles that record attempted invocation and fail. Compare files before and after command execution to detect changes. Complement these tests with static review of the small scripts, explicitly documenting that this mechanism is not a security sandbox and that absolute-path calls can bypass tool doubles.
- **Status**: Accepted

## DEC-016
- **Question**: What static-validation baseline should apply to project-owned Bash?
- **Context/Nuances**: The existing `.shellcheckrc` establishes Bash and style-level diagnostics without globally disabled codes. Validation must govern project-owned code without driving changes to the unmodified imported Archiso profile. A mandatory formatter is not needed for this story's scope.
- **User Response**: The user explicitly approved the validation baseline and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Use `bash -n` to check syntax of project-owned Bash executables and libraries, ShellCheck under the existing `.shellcheckrc` policy without global exclusions, and Bats to execute contract tests. ShellCheck exceptions must be narrowly scoped and justified. Do not apply corrective edits to the imported Archiso profile or introduce a mandatory formatter in Story 1.2.
- **Status**: Accepted

## DEC-017
- **Question**: Should the six lifecycle commands share argument validation and refusal of unimplemented operations?
- **Context/Nuances**: All six entry points are concrete consumers of the same accepted argument and refusal contract. Sharing that stable responsibility avoids six duplicated parsers and satisfies the architecture's requirement that helpers follow demonstrated callers, but does not justify a general CLI abstraction.
- **User Response**: The user explicitly approved the limited shared responsibility and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Introduce a small Bash helper under `operations/lib/` for common argument validation and refusal of unimplemented operations. Each entry point retains its command identity and help text. The helper contains no domain behavior and must not become a general CLI framework.
- **Status**: Accepted

## DEC-018
- **Question**: What should a lifecycle entry point do if its shared helper is missing or cannot be loaded?
- **Context/Nuances**: A missing or unloadable required helper indicates an incomplete or damaged checkout, not merely an unimplemented domain operation. It therefore differs from the unmet-precondition refusal under DEC-003 and must not leak an accidental generic shell exit status as the command's normalized outcome.
- **User Response**: The user explicitly approved the proposed behavior and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: If the shared helper is missing or cannot be loaded, the entry point returns normalized status `6` (internal contract failure), emits an actionable diagnostic on stderr identifying an incomplete or damaged checkout and how to restore it, and performs no changes. Add this failure case to the contract tests.
- **Status**: Accepted

## DEC-019
- **Question**: Should Story 1.2 require a final acceptance gate from a clean clone?
- **Context/Nuances**: A working checkout can conceal dependencies on local untracked files or tooling state. The repository does not require a remote for local clone validation, and repository acceptance must remain distinct from ISO construction and qualification. The candidate must already be committed for the clone to validate its actual version-controlled state; this decision does not itself authorize creating commits during the interview.
- **User Response**: The user explicitly approved the clean-clone acceptance gate and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Validate a temporary clean clone of the committed candidate state before Story 1.2 acceptance. Check documentation and governance, executable permissions of all six commands, static analysis, Bats tests, exclusion of generated outputs and local workflow tooling, and the corresponding secret scans. This gate requires neither a remote nor ISO construction and must not depend on untracked local files.
- **Status**: Accepted

## DEC-020
- **Question**: Where should repository-validation evidence be retained, and what minimum content should it contain?
- **Context/Nuances**: Repository acceptance needs retained diagnostic evidence, but unimplemented lifecycle commands must still create no files under DEC-003. The validation workflow consists of documented commands rather than a custom coordinator. Generated evidence is ignored by Git and must receive explicit secret scanning before acceptance.
- **User Response**: The user explicitly approved the proposed location and minimum content and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Retain validation evidence under `evidence/repository-validation/<UTC-timestamp>/`, outside source control. Include a non-sensitive summary identifying the evaluated commit, executed commands, and results, plus redacted reports where applicable. Scan the retained evidence before acceptance. Evidence is produced through the documented validation commands, not by pending lifecycle operations, which continue to create no files.
- **Status**: Accepted

## DEC-021
- **Question**: Should validation include a controlled negative test demonstrating that secret scanning actually detects a secret-like value?
- **Context/Nuances**: Successful scans of clean inputs alone do not demonstrate detection or coverage of ignored generated paths. A deliberately detectable synthetic value can exercise that behavior without exposing real credentials. The expected finding belongs to a controlled drill, not the final acceptance scan.
- **User Response**: The user explicitly approved the proposed check and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Include a controlled negative scanning test that creates a detectable synthetic value in a temporary ignored directory, runs Gitleaks, and verifies detection. Then remove the synthetic input and scan any retained redacted evidence. Use no real credentials and introduce no global exceptions. The expected drill finding demonstrates coverage; final acceptance still requires scans without findings.
- **Status**: Accepted

## DEC-022
- **Question**: How should unavailable validation tools be handled, and should help depend on those tools?
- **Context/Nuances**: Repository validation needs Bash, ShellCheck, Bats, and Gitleaks, but discovery/help is a separate responsibility. Missing validation tools must not lead to automatic host changes or an incomplete validation being accepted. Bash remains the runtime for the entry points; the other tools are validation dependencies, not help dependencies.
- **User Response**: The user explicitly approved the proposed dependency separation and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Treat Bash, ShellCheck, Bats, and Gitleaks as external prerequisites for repository validation. Document availability checks and stop validation if a required tool is absent, without automatic installation or host modification. Command help does not depend on ShellCheck, Bats, or Gitleaks.
- **Status**: Accepted

## DEC-023
- **Question**: What should happen when a repository-validation step fails, and should direct tool outcomes be normalized?
- **Context/Nuances**: Repository validation uses documented direct commands, not a custom coordinator. Native tool statuses therefore differ from the normalized MirrorOS lifecycle contract. Failure evidence must remain non-sensitive; retaining diagnostics does not authorize retaining secret values. The deliberately expected detection in DEC-021 remains a controlled test outcome, not a passing final acceptance scan.
- **User Response**: The user explicitly approved the separation and acceptance blocking on failure and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: A failed validation step stops the acceptance sequence. Preserve the original tool exit status and non-sensitive evidence, and document correction and rerun guidance. Direct validation commands retain native exit statuses without a normalization wrapper. MirrorOS normalized statuses `0`, `2`, `3`, `4`, `5`, and `6` remain the contract of lifecycle entry points.
- **Status**: Accepted

## DEC-024
- **Question**: Should the design interview close and the consolidated plan be finalized for implementation?
- **Context/Nuances**: The principal design choices have been resolved through DEC-001 to DEC-023. Some earlier plan wording still presents resolved questions as pending. Closing the interview does not mean that the story is implemented or validated, and implementation findings that contradict approved design must not be resolved silently.
- **User Response**: The user explicitly approved interview closure and final plan updates and requested direct registration: "yes, regitra directamente la decisión."
- **Decision**: Close the Story 1.2 design interview and make the consolidated plan ready for implementation. Update outdated pending references without changing accepted decisions or losing nuances. Implementation must deliver the documentation, six scripts, limited shared helper, tests, and explicit validation commands. Story completion requires the approved checks and clean-clone evidence. A finding that contradicts the design must return for an explicit decision. Interview closure is not implementation or validation completion.
- **Status**: Accepted

## DEC-025
- **Question**: How is the committed candidate for the clean-clone gate (DEC-019) created?
- **Context/Nuances**: DEC-019 requires validating the committed candidate state, but no decision authorized creating that commit. The Story 1.2 interview artifacts are untracked, while the Story 1.1 artifacts are tracked. Rewriting history after a failed gate would obscure evidence. ShellCheck, a DEC-022 validation prerequisite, was found missing during planning and was then installed locally by the user (0.11.0); execution still re-checks availability.
- **User Response**: The user accepted the recommendation ("recomendacion aceptada") and confirmed the registration summary ("si").
- **Decision**: After implementation and passing local validation (`bash -n`, ShellCheck, Bats, Gitleaks scans), a blocking human checkpoint presents the diff for review. Only after explicit approval, create a single commit on `main` that also includes both Story 1.2 interview artifacts. The clean-clone gate then runs against that commit. If the gate fails, corrections go into an additional commit without rewriting history, and the gate is repeated.
- **Status**: Accepted

## DEC-026
- **Question**: Which file names and layout should the Story 1.2 deliverables use?
- **Context/Nuances**: Architecture requires `lowercase-kebab-case`, `.sh` sourced libraries, `<source>.<type>.bats` test naming, and no `common/` or `utils/` dumping grounds. The `operations/lib/` tree reserves `exit-status.sh`, `evidence.sh`, `logging.sh`, `preflight.sh`, and `privilege.sh` for broader future responsibilities. A helper-load failure cannot be reported by the helper itself.
- **User Response**: The user approved the recommendation ("me parece bien") and confirmed the registration summary ("yes").
- **Decision**: The shared helper is `operations/lib/lifecycle-discovery.sh` and defines only the statuses it uses; each entry point returns a literal `6` when the helper cannot be loaded. Procedures are `docs/procedures/{build,test,install,configure,verify,clean}.md` plus `docs/procedures/repository-validation.md`, which covers explicit commands, prerequisites, the negative-control drill, evidence, the clean-clone gate, recovery, and the non-sandbox limitation. Tests are one `tests/operations/<command>.contract.bats` per command (six files) sharing the support file `tests/operations/lifecycle-discovery.bash` for the disposable copy, temporary HOME, tool doubles, and file comparison; each file covers the helper-failure (`6`) case. The `.agents/` workflow-tooling boundary is documented in a `README.md` section linked from `AGENTS.md`, without a separate document.
- **Status**: Accepted

# Repository validation procedure

Repository validation checks source-level contracts and secret-scanning coverage. It is separate from the `operations/test` lifecycle, ISO construction, ISO boot testing, and VM qualification. Passing this procedure does not establish that an ISO builds or that a VM passes.

The checks are explicit commands; this procedure introduces no validation coordinator. Validation tools are prerequisites, not installation-image dependencies. Do not install tools, start or reconfigure services, change host settings, or modify Git configuration to run these checks.

## Evidence and status recording

Run from the repository root. Each run uses an ignored directory named `evidence/repository-validation/<UTC-timestamp>/`, where the timestamp format is `YYYYMMDDTHHMMSSZ`. If the path already exists, wait until a new UTC second rather than overwriting evidence.

Create the directory and a non-sensitive summary before prerequisite checks so that missing tools and later failures can be recorded:

```bash
REPO_ROOT="$PWD"
UTC_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="$REPO_ROOT/evidence/repository-validation/${UTC_TIMESTAMP}"
mkdir -p "$EVIDENCE_DIR"
printf '%s\n' '# Repository validation summary' '' '| Command or check | Native status | Result |' '| --- | ---: | --- |' > "$EVIDENCE_DIR/summary.md"
git rev-parse HEAD
```

Record the evaluated `HEAD` SHA in `summary.md`; note whether the working tree contains changes. As each check runs, record its exact command, native exit status, and result. Capture `$?` immediately after the command before running another command. Stop at the first unexpected status, preserve that status, and retain the evidence already produced. Do not mask a failing tool status with a later successful command. The negative-control scan is the one expected nonzero status: record its detected finding and native status `1` as a passing control. Never record the synthetic value in evidence.

## Prerequisites

Check the required tools in order and stop at the first missing one:

```bash
command -v bash
command -v shellcheck
command -v bats
command -v gitleaks
command -v git
```

Each command must succeed. Record its native status. If any tool is missing, stop without installing it or modifying the host; retain the summary and report which prerequisite needs to be provided before rerunning.

## Static checks

Run syntax validation and ShellCheck on all six lifecycle entry points, the shared helper, and the shared Bash test support file:

```bash
bash -n \
  operations/build operations/configure operations/install operations/test operations/verify operations/clean \
  operations/lib/lifecycle-discovery.sh tests/operations/lifecycle-discovery.bash
shellcheck \
  operations/build operations/configure operations/install operations/test operations/verify operations/clean \
  operations/lib/lifecycle-discovery.sh tests/operations/lifecycle-discovery.bash
```

Both commands must return `0`. Use the repository `.shellcheckrc`; do not add global exclusions. Any inline exception must be narrowly scoped and justified.

## Contract tests

Run the complete Bats suite and record its native status:

```bash
bats tests/operations
```

All six contract files must pass. Their temporary-copy observations are not a security sandbox: absolute-path calls can bypass tool doubles.

## Gitleaks negative control

This drill places a generated, fake GitHub-token-shaped value only in a temporary directory under ignored `build/`. It uses no real credentials. Gitleaks output and its JSON report are redacted. Do not copy the generated value into the summary, terminal transcript, or any retained file.

```bash
mkdir -p build
NEGATIVE_DIR="$(mktemp -d "$PWD/build/gitleaks-negative-control.XXXXXX")"
synthetic='ghp_'
for ((index = 0; index < 9; index++)); do
  printf -v fragment '%04x' "$RANDOM"
  synthetic+="$fragment"
done
printf 'token=%s\n' "$synthetic" > "$NEGATIVE_DIR/input.txt"
if gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/negative-control.json" "$NEGATIVE_DIR"; then
  negative_status=0
else
  negative_status=$?
fi
```

Gitleaks must detect the synthetic value and return its default finding status `1`. A status of `0` means detection failed; any other nonzero status indicates a scanner or execution failure. In either failure case, remove the synthetic input before stopping and preserve the redacted report and summary.

After recording the detection result, remove the input and temporary directory, then check that the value is absent from retained evidence:

```bash
rm -f "$NEGATIVE_DIR/input.txt"
rmdir "$NEGATIVE_DIR"
if grep -R -F -- "$synthetic" "$EVIDENCE_DIR"; then
  printf '%s\n' 'synthetic value remains in evidence' >&2
  exit 1
else
  evidence_match_status=$?
fi
```

The `grep` check must return `1` (no match); status `0` means the value remains, and any other status is an error. Record the cleanup and evidence-check results without recording the value itself. Do not proceed if the synthetic input remains or the evidence contains it.

## Acceptance secret scans

Run redacted Gitleaks scans with a JSON report in the evidence directory. Do not use an allowlist, baseline, or global exception. Each scan must return `0` findings; record the native status and result.

Scan Git history and the working tree:

```bash
gitleaks git --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-history.json" .
gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-working-tree.json" .
```

Ignored staging and generated outputs are not covered merely because Git ignores them. For each such path presented for acceptance, run a separate explicit directory scan and use a distinct report name. Include `build/` and `dist/` whenever they exist or their contents are presented for acceptance; also scan any separately presented staging or generated-output path. For example:

```bash
gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-build.json" build
gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-dist.json" dist
```

Do not run an example for a path that does not exist; record it as absent. If any scan fails or reports a finding, stop, retain only redacted evidence, correct the issue, and rerun validation in a new timestamped directory.

After all local steps and the summary have been recorded, scan the retained evidence directory itself:

```bash
gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-evidence.json" "$EVIDENCE_DIR"
```

This final scan must report zero findings. Its report and summary contain no secret values; record its native status and result. The synthetic input must no longer exist, and a search for the generated value in evidence must find no match.

## Failure handling and reruns

Any missing prerequisite, unexpected command status, secret finding, or failed test stops the sequence. Preserve the native status, the non-sensitive summary, and redacted reports under the run's evidence directory. Do not install tools, change the host, or continue with partial validation. Correct the reported source or environment issue, then rerun the full sequence in a new UTC-stamped directory. Do not put secrets or unredacted scanner output into retained evidence.

## Clean-clone acceptance gate

Run this gate only after local validation has passed and the maintainer has reviewed and explicitly approved the candidate diff. It verifies committed content; it does not perform an ISO build or boot qualification. Record the new commit SHA and every command, native status, and result in `clean-clone-summary.md` in the local run's evidence directory.

Create a temporary clone using the approved local commit and `--no-local`:

```bash
GATE_ROOT="$(mktemp -d)"
CLONE_DIR="$GATE_ROOT/clone"
git clone --no-local "$PWD" "$CLONE_DIR"
```

In the clone, confirm `HEAD` equals the approved commit SHA. Confirm that these files exist: `README.md`, `LICENSE`, `AGENTS.md`, `CLAUDE.md`, `.shellcheckrc`, `.gitignore`, `docs/attribution.md`, `docs/adr/0000-template.md`, `docs/procedures/update-archiso.md`, and `docs/procedures/{build,test,install,configure,verify,clean,repository-validation}.md`. Confirm all six `operations/<command>` files are executable and that `build/`, `dist/`, `evidence/`, and `.agents/` are absent.

Run and record these checks, substituting the reviewed SHA for `<approved-commit-sha>`:

```bash
git -C "$CLONE_DIR" rev-parse HEAD
test "$(git -C "$CLONE_DIR" rev-parse HEAD)" = '<approved-commit-sha>'
test -f "$CLONE_DIR/README.md" && test -f "$CLONE_DIR/LICENSE" && \
  test -f "$CLONE_DIR/AGENTS.md" && test -f "$CLONE_DIR/CLAUDE.md" && \
  test -f "$CLONE_DIR/.shellcheckrc" && test -f "$CLONE_DIR/.gitignore" && \
  test -f "$CLONE_DIR/docs/attribution.md" && \
  test -f "$CLONE_DIR/docs/adr/0000-template.md" && \
  test -f "$CLONE_DIR/docs/procedures/update-archiso.md" && \
  test -f "$CLONE_DIR/docs/procedures/build.md" && \
  test -f "$CLONE_DIR/docs/procedures/test.md" && \
  test -f "$CLONE_DIR/docs/procedures/install.md" && \
  test -f "$CLONE_DIR/docs/procedures/configure.md" && \
  test -f "$CLONE_DIR/docs/procedures/verify.md" && \
  test -f "$CLONE_DIR/docs/procedures/clean.md" && \
  test -f "$CLONE_DIR/docs/procedures/repository-validation.md"
for command in build test install configure verify clean; do
  test -x "$CLONE_DIR/operations/$command"
done
test ! -e "$CLONE_DIR/build" && test ! -e "$CLONE_DIR/dist" && \
  test ! -e "$CLONE_DIR/evidence" && test ! -e "$CLONE_DIR/.agents"
cd "$CLONE_DIR"
```

The SHA comparison, file checks, executable checks, and absent-directory checks must each return `0`. Run and record the following checks from the clone:

```bash
bash -n \
  operations/build operations/configure operations/install operations/test operations/verify operations/clean \
  operations/lib/lifecycle-discovery.sh tests/operations/lifecycle-discovery.bash
shellcheck \
  operations/build operations/configure operations/install operations/test operations/verify operations/clean \
  operations/lib/lifecycle-discovery.sh tests/operations/lifecycle-discovery.bash
bats tests/operations
gitleaks git --redact --report-format json \
  --report-path "$EVIDENCE_DIR/clean-clone-gitleaks-history.json" .
gitleaks dir --redact --report-format json \
  --report-path "$EVIDENCE_DIR/clean-clone-gitleaks-working-tree.json" .
```

The documentation, executable-bit, and absent-output checks must pass; the static checks and Bats suite must return `0`; both clone scans must report zero findings. Reports are written outside the clone so it remains a clean, version-controlled-content check. Stop on a failed gate, preserve the status and evidence, correct the problem in a new commit after another review checkpoint, and rerun the gate without rewriting history.

After recording the clone results, remove the temporary clone and its parent directory. Record the cleanup status, then perform a final redacted Gitleaks directory scan of the evidence directory and record the result. The clone must no longer exist and the final evidence scan must report zero findings.

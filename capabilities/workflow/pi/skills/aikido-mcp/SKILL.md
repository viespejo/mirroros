---
name: aikido-mcp
description: Query Aikido security findings, run local SAST and secret scans, and ignore findings through Aikido's MCP server via mcporter. Use when working with Aikido security issues or scanning code with Aikido.
disable-model-invocation: true
---

# Aikido MCP

Use the configured `aikido` server through mcporter. Prefer `--args` for structured arguments and arrays:

```bash
mcporter call aikido.TOOL_NAME --args '{"key":"value"}'
```

## List security issues

Use `aikido_issues_list` to list, count, summarize, triage, or retrieve the current findings before fixing them.

```bash
# All visible issues
mcporter call 'aikido.aikido_issues_list()'

# Repository issues
mcporter call aikido.aikido_issues_list --args '{"repo_name":"my-repository","page":0}'

# Typed, branch-scoped issues that are past SLA
mcporter call aikido.aikido_issues_list --args '{"repo_name":"my-repository","repo_branch_name":"main","issue_types":["sast","iac"],"out_of_sla":true}'
```

Parameters:

- Scope: `repo_name`, `cloud_name`, `vm_name`, `domain_name`, `container_name`, `workspace_name`, `team_name`, and `repo_branch_name`.
- Pagination: `page` is zero-based. Request later pages only when needed.
- Types: `open_source`, `leaked_secret`, `cloud`, `sast`, `iac`, `surface_monitoring`, `malware`, `eol`, `mobile`, `docker_container`, `cloud_instance`, `scm_security`, `license`, and `ai_pentest`.
- SLA: `out_of_sla` and `sla_due_soon` are booleans.

Use `repo_name` for issue listings. An Aikido dashboard URL repository ID, such as `/repositories/2445311`, is not accepted by this tool. There is no severity parameter; filter returned issues by severity when requested.

Report every issue in this format:

```text
Issue #<n>: <title>
- ID: <id>
- Issue type: <type>
- Severity: <severity> (<severity label>)
- Remediation: <remediation>
```

Include file and line, location, issue link, and SLA due date when returned.

## Scan local code

Use `aikido_full_scan` for local SAST and secret scanning. It requires `files_to_scan`, an array of objects with `relativeFilePath` and `content`. Paths must be Unix-style and relative to the workspace/repository when possible. Scan at most 50 files per call; split larger scans into batches.

```bash
python3 - <<'PY' >/tmp/aikido-scan-args.json
import json
from pathlib import Path

paths = [Path('src/app.py')]
print(json.dumps({'files_to_scan': [
    {'relativeFilePath': path.as_posix(), 'content': path.read_text()}
    for path in paths
]}))
PY

mcporter call aikido.aikido_full_scan --args "$(< /tmp/aikido-scan-args.json)"
```

For staged or edited code, select only existing text files in scope; do not include generated, binary, or unrelated sensitive files. Add `repository_name` only when the files belong to a repository known by Aikido. `repository_name` is for scans only; it is not the `repo_name` filter used by issue listing.

## Ignore an issue

Use `aikido_ignore_issue` only when the user supplies both the issue ID and a reason. This changes remote state: show the exact ID and reason, then obtain explicit confirmation immediately before the call.

```bash
mcporter call 'aikido.aikido_ignore_issue(issue_id: "ISSUE_ID", reason: "Accepted risk: REASON")'
```

## Refresh the tool schema

Aikido can add tools or parameters. Before relying on undocumented behavior, inspect the configured server:

```bash
mcporter list aikido --schema --all-parameters
```

# Aikido MCP setup

This file is for the person configuring the harness. The agent instructions are in `SKILL.md`.

## mcporter server

Add this server definition to `~/.mcporter/mcporter.json` without storing the secret in the file:

```json
{
  "mcpServers": {
    "aikido": {
      "command": "npx",
      "args": ["-y", "@aikidosec/mcp"],
      "env": {
        "AIKIDO_API_KEY": "${AIKIDO_API_KEY}"
      }
    }
  }
}
```

Create an Aikido Personal Access Token under **Settings → Integrations → MCP Server**, then set it in the shell that invokes mcporter:

```bash
export AIKIDO_API_KEY='YOUR_AIKIDO_API_KEY'
```

For Fish:

```fish
read -s -P 'Aikido API key: ' AIKIDO_API_KEY; echo
set -gx AIKIDO_API_KEY $AIKIDO_API_KEY
```

Do not commit the token, add it to `SKILL.md`, or paste it into a chat.

## Verify

```bash
mcporter list aikido --schema
```

Aikido administrators can enable or disable MCP tools in the Aikido permissions page. If an expected tool is unavailable, ask an administrator to enable it.

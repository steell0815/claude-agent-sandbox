---
name: agents
description: List active/recent subagents and view their logs. Use /agents to list, /agents <id> to view a specific agent's log.
allowed-tools: Bash, Read
---

# Agent Monitor

Show active and recent subagents, and drill into their transcript logs.

## Behavior

Parse the user's arguments:

- **No arguments** (`/agents`): Run the listing script and present the results.
- **With an agent ID** (`/agents <id>`): Run the log viewer script for that agent.

## Scripts

### List all agents
```bash
.claude/skills/agents/scripts/list-agents.sh
```

### View a specific agent's log
```bash
.claude/skills/agents/scripts/view-agent-log.sh "<agent-id>"
```

## Presentation

- For the **list view**: present active agents prominently (with type, start time, and ID), then show recent history below. Offer the user the option to view any agent's log by ID.
- For the **log view**: present the agent's transcript in a readable format showing the conversation flow. At the end, remind the user they can run `/agents` to return to the list.
- Always show agent IDs so the user can reference them.

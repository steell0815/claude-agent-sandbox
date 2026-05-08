---
name: dashboard
description: Show current session dashboard — hooks, skills, settings, active agents, and git state
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
---

# Session Dashboard

Gather and present a comprehensive dashboard of the current Claude Code session environment.

## Data Sources

Run the gathering script, then present the results in a well-formatted summary:

```bash
.claude/skills/dashboard/scripts/gather-session-info.sh
```

## Additional Introspection

After running the script, also report:
- The **current model** you are running as
- The **available skills/slash commands** you can see (list them)
- The **available built-in tools** in this session

Present everything as a clean, organized dashboard with sections. Use tables where appropriate.

# Knowledge-dir mounts for the agent sandbox

Status: draft — design agreed, not yet implemented.
Owner: steell
Created: 2026-05-20

## Problem

`~/.claude` is the only host profile the agent sees today (mounted ro at
`/home/agent/.claude`). Project-external Claude material (skills, hooks,
scripts, MCP configs, knowledge MDs) lives in dedicated repos such as
`~/dev/claude-knowledge-sandbox/.claude` and cannot be picked up without
copying it into `~/.claude` or into each workspace's `.claude/`. We want
a flexible, opt-in way to layer one or more of those external trees into
a sandbox run.

Chosen approach (option #2 from the design discussion): extra read-only
bind mounts driven by an env var, with `run-agent.sh` doing the parsing
and `docker compose run -v` carrying the mounts into the agent container.
Considered and deferred: converting the knowledge sandbox into a Claude
Code plugin (option #1) — cleaner long-term but requires restructuring
the source repo; revisit once transport works.

## Design

### Env var contract

`CAS_KNOWLEDGE_DIRS` — colon-separated list of host `.claude` trees to
layer in. Each entry is either:

- a bare absolute (or `~`-prefixed) path — name defaults to the basename
  of the parent dir (so `.../foo/.claude` → name `foo`), or
- `name=path` — explicit name override.

Examples:

```
CAS_KNOWLEDGE_DIRS=~/dev/claude-knowledge-sandbox/.claude
CAS_KNOWLEDGE_DIRS=ks=~/dev/claude-knowledge-sandbox/.claude:work=~/dev/work-knowledge/.claude
```

Each entry maps to `/home/agent/.claude-knowledge/<name>/` inside the
container, read-only. The list of mounted names is passed to the
container as `CAS_KNOWLEDGE_NAMES` (comma-separated) so the entrypoint
can enumerate them without re-reading `CAS_KNOWLEDGE_DIRS`.

### Transport: `scripts/run-agent.sh`

Insert between the workdir resolution (current line ~90) and the
`docker compose up -d builder` call:

```bash
KNOWLEDGE_MOUNTS=()
KNOWLEDGE_NAMES=()
if [[ -n "${CAS_KNOWLEDGE_DIRS:-}" ]]; then
  IFS=':' read -r -a _entries <<<"$CAS_KNOWLEDGE_DIRS"
  for entry in "${_entries[@]}"; do
    [[ -z "$entry" ]] && continue
    if [[ "$entry" == *=* ]]; then
      name="${entry%%=*}"; path="${entry#*=}"
    else
      path="$entry"
      name="$(basename "$(dirname "$(cd "${path/#\~/$HOME}" && pwd)")")"
    fi
    path="${path/#\~/$HOME}"
    if [[ ! -d "$path" ]]; then
      echo "ERROR: CAS_KNOWLEDGE_DIRS entry not a directory: $path" >&2
      exit 64
    fi
    path="$(cd "$path" && pwd)"
    if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
      echo "ERROR: invalid knowledge name '$name' (from $entry)" >&2
      exit 64
    fi
    KNOWLEDGE_MOUNTS+=(-v "${path}:/home/agent/.claude-knowledge/${name}:ro")
    KNOWLEDGE_NAMES+=("$name")
    echo "knowledge: $path -> /home/agent/.claude-knowledge/$name" >&2
  done
fi
```

Replace the final `exec docker compose run --rm agent "$@"` with:

```bash
exec docker compose run --rm \
  -e CAS_KNOWLEDGE_NAMES="$(IFS=,; echo "${KNOWLEDGE_NAMES[*]}")" \
  "${KNOWLEDGE_MOUNTS[@]}" \
  agent "$@"
```

`docker compose run` layers ad-hoc `-v` / `-e` on top of the service
definition, so no compose change is strictly required for transport.

### Transport (optional): single-dir convenience in compose

For users who invoke `docker compose run agent` directly without the
wrapper, optionally add one fixed slot in `docker-compose.yml`:

```yaml
- ${CAS_KNOWLEDGE_DIR:-./agent/empty-knowledge}:/home/agent/.claude-knowledge/default:ro
```

Requires a checked-in `agent/empty-knowledge/.gitkeep` so the default
doesn't fail. Skip if we're happy mandating `run-agent.sh`.

## Discovery — making Claude actually see the content

Mounting the trees gets bytes inside the container; it does not yet make
Claude find skills/hooks/agents/commands/MCPs. Two stages, ship in order.

### Stage A — settings-side reference (ship first)

Extend `agent/entrypoint.sh` to merge each
`/home/agent/.claude-knowledge/<name>/settings.json` into a generated
combined settings file (start from
`/etc/claude-code/sandbox-settings.json`), then pass that path via
`--settings`. Use `jq` for the merge; resolve hook script paths to their
absolute container path before merging.

Covers: hooks, MCP servers, permissions, env. Does **not** cover skills,
agents, commands — those are filesystem-discovery-based and settings
can't redirect them.

Open questions for A:
- Conflict policy when two knowledge dirs declare the same MCP name —
  last-wins vs error? Default: error, surface clearly.
- Whether to forbid known-dangerous settings (e.g. permissions
  overrides) coming from a knowledge dir. Probably yes; allowlist
  specific top-level keys.

### Stage B — tmpfs-shadow + symlink merge (follow-up)

To cover skills/agents/commands/hooks-as-files:

1. Move the host bind from `${HOME}/.claude:/home/agent/.claude:ro` to
   `${HOME}/.claude:/home/agent/.claude-host:ro`.
2. Make `/home/agent/.claude` a single tmpfs (replaces the current
   per-subdir tmpfs lines for sessions/todos/cache/file-history/projects
   /session-env, which become redundant).
3. In `entrypoint.sh`, populate `/home/agent/.claude` at boot:
   - symlink each top-level entry from `/home/agent/.claude-host/*` into
     `/home/agent/.claude/` (preserves the host profile),
   - for each `<name>` in `CAS_KNOWLEDGE_NAMES`, walk
     `skills/`, `agents/`, `commands/`, `hooks/` under
     `/home/agent/.claude-knowledge/<name>/` and symlink each item into
     the corresponding `/home/agent/.claude/<subdir>/`, erroring on
     name collisions (or applying a documented priority).

Tradeoff: bigger refactor, but Claude is unaware — discovery just works.

## Acceptance

- `CAS_KNOWLEDGE_DIRS=...` runs with zero, one, or many entries.
- Bare-path and `name=path` forms both work; invalid name or missing
  path fails fast with a clear message.
- Stage A: hooks declared in a knowledge dir fire in the agent.
- Stage B (when shipped): a skill placed only in a knowledge dir is
  invocable via `/skill-name` inside the sandbox.
- `docker compose run agent` (no wrapper) still works, with or without
  the optional single-slot mount.
- README updated with the env-var contract and one worked example using
  `claude-knowledge-sandbox`.

## Out of scope

- Plugin-layout conversion of the knowledge sandbox (option #1).
- Auto-discovery of nearby `.claude` dirs (must be explicit via env var).
- Writeable knowledge dirs — all mounts are `:ro` by design.

# Error Codes

All error codes follow the format `CB-{STAGE}{NNN}`.

| Stage | Prefix | Description |
|-------|--------|-------------|
| Hook | CB-H | Pre-commit and Claude Code hook errors |
| Script | CB-S | Utility and gather script errors |
| Guardrail | CB-G | Instant failure rule violations (IF-01 through IF-21) |
| Plan | CB-P | Plan management errors |
| Agent | CB-A | Multi-agent orchestration errors |

## Hook Errors (CB-H)

| Code | Message | Recovery |
|------|---------|----------|
| CB-H001 | Path traversal blocked | Remove '..' from the file path argument |
| CB-H002 | sudo command blocked | Run the command without sudo |
| CB-H003 | Destructive rm blocked | Use a more targeted rm command within the project directory |
| CB-H010 | Guardrail violation in staged files | Fix the violations listed above, then re-stage and retry |
| CB-H011 | Secret detected in staged files | Remove the secret and use an environment variable instead |
| CB-H012 | Bash syntax error in staged script | Fix the syntax error shown above, then re-stage |
| CB-H013 | ShellCheck warning in staged script | Fix the ShellCheck warning shown above, then re-stage |
| CB-H020 | Commit message format invalid | Use conventional commit format: type(scope): description |

## Script Errors (CB-S)

| Code | Message | Recovery |
|------|---------|----------|
| CB-S001 | Required file not found | Check the file path and ensure the file exists |
| CB-S002 | Invalid JSON input | Verify the input is valid JSON using 'jq empty' |
| CB-S003 | Required command not available | Install the missing command (see error details) |
| CB-S010 | jq not available | Install jq: brew install jq (macOS) or apt install jq (Linux) |
| CB-S011 | python3 not available | Install Python 3: brew install python3 (macOS) or apt install python3 (Linux) |

## Guardrail Errors (CB-G)

| Code | Message | Recovery |
|------|---------|----------|
| CB-G001 | IF-01: Framework import in domain center | Move the import to an adapter outside the domain package |
| CB-G002 | IF-02: SQL string concatenation | Use parameterized queries or a query builder |
| CB-G003 | IF-03: Null return where Optional exists | Return Optional.empty() or equivalent absent-value type |
| CB-G004 | IF-04: Internal data structure leaked | Create a response model or DTO for the public contract |
| CB-G005 | IF-05: Internal error leaked in response | Return a structured error with code and message only |
| CB-G006 | IF-06: Mutable event/request/response | Use final fields, records, or readonly properties |
| CB-G007 | IF-07: Business logic outside domain | Move the logic to an entity or interactor |
| CB-G008 | IF-08: Unbounded data without acceptance test | Add acceptance test proving bounded behavior |
| CB-G009 | IF-09: In-memory sequence generation | Use database sequences or distributed ID generators |
| CB-G010 | IF-10: Silent entity state change | Emit a domain event for the state change |
| CB-G011 | IF-11: Partial field sync | Update all representations (entity, DTO, migration, test) |
| CB-G012 | IF-12: Untested code change | Add tests covering the new or changed code |
| CB-G013 | IF-13: Duplicated logic across files | Extract shared logic into a reusable component |
| CB-G014 | IF-14: Hardcoded secret | Use environment variables or a secrets manager |
| CB-G015 | IF-15: Missing /api/ prefix on controller | Add /api/ prefix to the controller path mapping |
| CB-G016 | IF-16: Unbounded list without acceptance test | Add acceptance test proving bounded results |
| CB-G017 | IF-17: Business exception returning 500 | Map the exception to a 4xx status with an error code |
| CB-G018 | IF-18: PII/credentials in telemetry | Remove sensitive data from spans, metrics, and logs |
| CB-G019 | IF-19: Root user in production Dockerfile | Add USER directive to drop to non-root after build |
| CB-G020 | IF-20: N+1 query in list operation | Use batch queries (WHERE id IN ...) or JOINs |
| CB-G021 | IF-21: Missing ownership verification | Add caller ownership check before resource access |

## Plan Errors (CB-P)

| Code | Message | Recovery |
|------|---------|----------|
| CB-P001 | Plan index file not found | Run from project root or ensure plans/index.json exists |
| CB-P002 | Plan ID not found in index | Check plan ID with: ./scripts/plan-index.sh list |
| CB-P003 | Invalid plan status transition | Valid statuses: planned, in_progress, done, unplanned |
| CB-P004 | Plan file not found | Check the file path in plans/index.json |
| CB-P005 | Readiness assessment missing | Run /assess-readiness <plan-id> first |

## Agent Errors (CB-A)

| Code | Message | Recovery |
|------|---------|----------|
| CB-A001 | Implementor did not signal completion | Check agent transcript for errors or timeouts |
| CB-A002 | Verifier checklist incomplete | Re-run Verifier with the full checklist |
| CB-A003 | Implementation Log entry missing | Launch Chronologist to write the log entry |
| CB-A004 | Agent role not detected | Ensure agent prompt contains role identifier |

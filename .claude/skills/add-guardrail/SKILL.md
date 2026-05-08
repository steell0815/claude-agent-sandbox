# /add-guardrail - Add Guardrail Rule

Add a new instant failure rule or golden rule to the guardrails document.

## Arguments

- `<type>`: Either `instant failure` or `golden-rule`
- `<description>`: Brief description of the rule to add

## Workflow

1. **Read current guardrails**

   Read `.claude/guardrails.md` to understand existing rules and avoid duplicates.

2. **Check for duplicates**

   Verify the proposed rule is not already covered by an existing instant failure or golden rule. If it overlaps with an existing rule, suggest strengthening the existing rule instead of adding a duplicate.

3. **Add the rule**

   **For instant failures:**
   - Determine the next IF number (IF-XX)
   - Add a new row to the Instant Failures table:

     ```markdown
     | IF-XX | {Rule description} | {Why this is dangerous} |
     ```

   **For golden rules:**
   - Determine the next rule number
   - Add a new numbered section under Golden Rules with:
     - Rule title
     - Principle explanation (2-4 sentences)
     - Bullet points for specific guidance
     - Pseudocode example if the rule involves a pattern

4. **Suggest ADR**

   If the new rule represents an architectural decision (affects structure, patterns, or technology choices), suggest creating an ADR:

   > "This guardrail represents an architectural decision. Consider running `/add-adr {title}` to document the rationale."

5. **Update layer docs** (if applicable)

   If the rule is layer-specific, suggest adding it to the relevant layer document's instant failures table:
   - `.claude/domain-layer.md`
   - `.claude/application-layer.md`
   - `.claude/infrastructure-layer.md`
   - `.claude/interfaces-layer.md`

6. **Output**

   Display:
   - The rule that was added (with its ID)
   - Which section it was added to
   - Whether an ADR or layer doc update was suggested

## Example

```
/add-guardrail instant failure "No circular dependencies between entities"
```

Adds IF-18 to the instant failures table.

```
/add-guardrail golden-rule "Idempotent Event Consumers"
```

Adds rule 15 to the golden rules section.

## Rules

- Always check for duplicates before adding
- Instant failures are absolute — they describe things that must NEVER happen
- Golden rules are principles — they describe how things SHOULD be done
- Use technology-agnostic language (no framework-specific references)
- Include the "Why" for instant failures — the reason makes the rule enforceable

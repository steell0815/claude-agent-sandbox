# Analysis Heuristics

Reference document for analyst agents. Contains the specific signals, patterns, and comparison logic for each analysis category.

## ADR Signals (adr-analyst)

### Detection Patterns

**ADR directories and files:**
- Glob: `**/adr/**/*.md`, `**/decisions/**/*.md`, `**/doc/architecture/**/*.md`
- Grep: `## Status`, `## Decision`, `## Consequences`, `## Context`
- File naming: `adr-*.md`, `ADR-*.md`, `NNNN-*.md` (numbered decision files)

**Architectural decision indicators (even without formal ADRs):**
- `ARCHITECTURE.md`, `DESIGN.md`, `DECISIONS.md`
- Comments containing: `Decision:`, `We chose`, `Trade-off:`, `Alternative considered:`
- README sections: `## Architecture`, `## Design Decisions`, `## Technical Choices`

### Comparison Logic

For each discovered decision:
1. Extract the core decision (technology choice, pattern adoption, constraint)
2. Check against blueprint ADR index — does an existing ADR cover the same topic?
3. If novel: assess whether the decision is generalizable (not project-specific)
4. If overlapping: check whether the target repo's version adds nuance or depth

### What to Report

- Novel architectural decisions not covered by any existing ADR
- Decisions that extend or refine an existing ADR's scope
- Decision documentation practices (templates, review processes) that improve upon the blueprint's approach

### What to Ignore

- Decisions about specific library versions without architectural rationale
- Project-specific technology choices (e.g., "we use PostgreSQL" without discussing why relational vs. document)
- Decisions that are implicit in the framework choice

---

## Guardrail Signals (practice-analyst)

### Detection Patterns

**Explicit rules and configs:**
- Glob: `**/.eslintrc*`, `**/.eslintrc.json`, `**/.eslintrc.yml`, `**/biome.json`
- Glob: `**/checkstyle*.xml`, `**/pmd*.xml`, `**/spotbugs*.xml`
- Glob: `**/.editorconfig`, `**/prettier.config.*`, `**/.prettierrc*`
- Glob: `**/ArchUnit*`, `**/archunit*`, `**/*ArchTest*`
- Glob: `**/.dependency-cruiser*`, `**/eslint-plugin-import*`

**Pre-commit and hook enforcement:**
- Glob: `**/.husky/**`, `**/.pre-commit-config.yaml`, `**/.git/hooks/*`
- Grep: `pre-commit`, `husky`, `lint-staged`

**Documented constraints:**
- Grep in markdown files: `NEVER`, `MUST NOT`, `FORBIDDEN`, `ALWAYS`, `REQUIRED`
- Grep: `## Rules`, `## Constraints`, `## Guidelines`, `## Standards`

**Architectural enforcement (code-level):**
- ArchUnit rules in Java/Kotlin test files
- dependency-cruiser configs for JS/TS
- Custom ESLint rules or plugins
- Build-time architecture validation

### Comparison Logic

For each discovered guardrail:
1. Classify as enforcement-type: static analysis rule, architecture test, pre-commit hook, documented constraint
2. Extract the intent: what does this rule prevent or enforce?
3. Check against blueprint's `guardrails.md` — is this intent already covered by an IF-* or GR-*?
4. If novel: assess whether the rule is generalizable across stacks

### What to Report

- Code-enforced architectural constraints not in blueprint guardrails
- Novel static analysis rules with clear architectural intent
- Pre-commit workflows that catch classes of errors the blueprint doesn't address
- Documented team conventions with enforcement mechanisms

### What to Ignore

- Standard linter defaults (no customization beyond framework defaults)
- Formatting-only rules (already covered by blueprint's formatting gates)
- Language-specific syntax rules that don't carry architectural meaning

---

## Architecture Signals (practice-analyst)

### Detection Patterns

**Layer separation:**
- Directory structure: `domain/`, `application/`, `infrastructure/`, `interfaces/`, `ports/`, `adapters/`
- Alternative patterns: `core/`, `use-cases/`, `gateways/`, `controllers/`, `repositories/`
- Module structure: monorepo with clear boundaries, workspace definitions

**Domain modeling:**
- Grep: `Entity`, `ValueObject`, `AggregateRoot`, `DomainEvent`, `Repository` (interface)
- Pattern: immutable classes, factory methods, builder patterns
- Event sourcing indicators: `Event`, `Command`, `Aggregate`, `EventStore`

**Port/adapter structure:**
- Grep: `interface.*Port`, `interface.*Gateway`, `implements.*Port`
- Grep: `@Adapter`, `@Infrastructure`, `@UseCase`, `@DomainService`
- Import direction analysis: do domain files import infrastructure? (violation indicator)

**Development workflow:**
- `CONTRIBUTING.md` content: branch naming, commit conventions, review process
- `CLAUDE.md` or `.github/copilot-instructions.md`: AI pair programming guidance
- `.github/PULL_REQUEST_TEMPLATE.md`: review criteria
- Commit message patterns: conventional commits, linked issues

### Comparison Logic

For each discovered pattern:
1. Identify the architectural principle being applied
2. Map to blueprint layer documentation (`.claude/*-layer.md`)
3. Check if the implementation approach adds value beyond current guidance
4. Assess transferability across language/framework boundaries

### What to Report

- Layer separation patterns that are more granular or better enforced
- Domain modeling techniques not described in blueprint layer docs
- Novel dependency direction enforcement mechanisms
- Development workflow practices that improve collaboration or code quality

### What to Ignore

- Standard MVC/MVVM without clean architecture characteristics
- Framework-generated directory structures with no intentional design
- Workflows that are identical to the blueprint's existing guidance

---

## Testing Signals (test-analyst)

### Detection Patterns

**BDD and acceptance testing:**
- Glob: `**/acceptance/**`, `**/*.feature`, `**/features/**`
- Glob: `**/*DSL*`, `**/*Driver*`, `**/*Steps*`, `**/*StepDef*`
- Grep: `Given`, `When`, `Then`, `Scenario`, `Feature`
- Grep: `describe`, `it`, `test`, `expect`, `assert`

**Testing infrastructure:**
- Glob: `**/fixtures/**`, `**/factories/**`, `**/*Factory.*`, `**/*Builder.*`, `**/*Mother.*`
- Test containers: `**/testcontainers*`, `docker-compose.test*`
- Grep: `TestContainer`, `@Testcontainers`, `GenericContainer`

**Coverage and mutation testing:**
- Glob: `**/jacoco*`, `**/.nycrc*`, `**/jest.config*` (with `coverageThreshold`)
- Glob: `**/pitest*`, `**/stryker.conf*`, `**/mutation*`
- Grep: `coverageThreshold`, `mutationThreshold`, `pitest`, `stryker`

**Novel testing approaches:**
- Contract testing: `**/pact/**`, `**/*Contract*`, `**/*Pact*`
- Property-based: `**/quickcheck*`, `**/*Property*`, `fast-check`, `jqwik`
- Visual regression: `**/*visual*`, `**/percy*`, `**/.loki*`, `**/chromatic*`
- Snapshot: `**/__snapshots__/**`, `toMatchSnapshot`, `toMatchInlineSnapshot`
- Architecture testing: `**/ArchTest*`, `**/archunit*`, `**/dependency-cruiser*`

### Comparison Logic

For each discovered testing practice:
1. Classify the testing type (unit, integration, acceptance, contract, property, visual, architecture)
2. Identify the structural pattern (how are tests organized?)
3. Compare against blueprint's BDD 4-layer architecture
4. Check if the practice addresses a testing gap in the blueprint

### What to Report

- Testing patterns that complement or extend the BDD 4-layer architecture
- Novel test organization strategies with clear benefits
- Coverage or mutation testing configurations with higher or more targeted thresholds
- Test infrastructure patterns (factories, builders, containers) that improve test maintainability
- Contract or property-based testing approaches not currently in the blueprint

### What to Ignore

- Standard test framework usage without notable patterns
- Test files that follow the exact patterns already in the blueprint
- Flaky test workarounds (sleeps, retries) — these are anti-patterns

---

## CI/CD Signals (pipeline-analyst)

### Detection Patterns

**CI/CD configuration:**
- Glob: `**/.github/workflows/*.yml`, `**/.github/workflows/*.yaml`
- Glob: `**/Jenkinsfile`, `**/.gitlab-ci.yml`, `**/.circleci/**`
- Glob: `**/azure-pipelines.yml`, `**/bitbucket-pipelines.yml`
- Glob: `**/Makefile`, `**/Taskfile.yml`, `**/justfile`

**Quality gates:**
- Grep in CI files: `coverage`, `mutation`, `sonar`, `lint`, `format`, `type-check`
- Grep: `quality-gate`, `threshold`, `minimum`, `required`
- Grep: `if: failure()`, `needs:`, `depends_on`

**Security scanning:**
- Grep: `SAST`, `DAST`, `SBOM`, `CycloneDX`, `OWASP`, `ZAP`, `Trivy`, `Snyk`
- Grep: `dependency-check`, `dependabot`, `renovate`, `secret-detection`, `gitleaks`
- Glob: `**/.trivyignore`, `**/.snyk`, `**/security*.yml`

**Deployment patterns:**
- Glob: `**/Dockerfile`, `**/docker-compose*.yml`
- Glob: `**/helm/**`, `**/k8s/**`, `**/kubernetes/**`
- Glob: `**/terraform/**`, `**/pulumi/**`, `**/cdk/**`
- Grep: `deploy`, `release`, `promote`, `canary`, `blue-green`, `rolling`
- Glob: `**/.env.example`, `**/config/**`

### Comparison Logic

For each discovered CI/CD practice:
1. Map to blueprint's three-stage pipeline model (commit, acceptance, DAST)
2. Identify additional stages or gates not in the blueprint
3. Check for security scanning tools or approaches beyond blueprint coverage
4. Assess deployment patterns for sophistication beyond current guidance

### What to Report

- Pipeline stages or gates that enhance the three-stage model
- Security scanning tools or configurations not mentioned in the blueprint
- Deployment patterns (canary, blue-green, GitOps) that add value
- Build optimization techniques (caching, parallelism) worth documenting
- Environment management practices that improve reproducibility

### What to Ignore

- CI configurations that implement the exact same stages as the blueprint
- Tool-specific syntax differences (GitHub Actions vs. GitLab CI) without architectural insight
- Standard Docker/container configurations without notable patterns

---

## Workflow Signals (practice-analyst)

### Detection Patterns

**Contributing guidelines:**
- Glob: `**/CONTRIBUTING.md`, `**/DEVELOPMENT.md`, `**/HACKING.md`
- Grep: `## Workflow`, `## Process`, `## Getting Started`, `## How to`

**AI assistant configuration:**
- Glob: `**/CLAUDE.md`, `**/.github/copilot-instructions.md`, `**/.cursorrules`
- Glob: `**/.aider*`, `**/.continue/**`

**PR and review workflows:**
- Glob: `**/.github/PULL_REQUEST_TEMPLATE*`, `**/.github/ISSUE_TEMPLATE/**`
- Grep: `checklist`, `review`, `approval`, `CODEOWNERS`

**Commit conventions:**
- Glob: `**/.commitlintrc*`, `**/commitlint.config.*`
- Grep: `conventional-commit`, `commitlint`, `semantic-release`
- Git log analysis: detect commit message patterns from recent 50 commits

### Comparison Logic

1. Compare development workflow documentation against blueprint's `.claude/workflows.md`
2. Identify workflow steps or practices not captured in the blueprint
3. Check for team collaboration patterns that could improve the blueprint's guidance

### What to Report

- Development workflows with steps not in the blueprint
- AI assistant configurations with novel prompt engineering or guardrails
- Review processes that enforce quality beyond current blueprint guidance
- Commit or branching conventions with clear benefits

### What to Ignore

- Standard GitHub Flow / Git Flow without modifications
- Generic CONTRIBUTING.md without specific practices
- Workflows that duplicate blueprint guidance

---

## Stack Signals (all analysts)

### Detection Patterns

**Build and dependency management:**
- Glob: `**/package.json`, `**/pom.xml`, `**/build.gradle*`, `**/build.sbt`
- Glob: `**/requirements.txt`, `**/pyproject.toml`, `**/go.mod`, `**/Cargo.toml`
- Glob: `**/Gemfile`, `**/mix.exs`, `**/composer.json`

**Framework detection:**
- Grep in config files for framework identifiers (Spring Boot, Express, Next.js, Django, etc.)
- Grep: `@SpringBootApplication`, `createApp`, `NestFactory`, `FastAPI`

**Toolchain:**
- Glob: `**/tsconfig.json`, `**/babel.config.*`, `**/webpack.config.*`, `**/vite.config.*`
- Glob: `**/.tool-versions`, `**/.nvmrc`, `**/.java-version`, `**/.python-version`

### Comparison Logic

1. Identify the target repo's stack (language + framework + toolchain)
2. Check if a matching stack exists in blueprint's `stacks/` directory
3. If matching: compare configurations for improvements
4. If novel: assess whether a new stack configuration is warranted

### What to Report

- Stack-specific configurations that improve upon existing blueprint stacks
- Novel stack combinations not yet represented in the blueprint
- Toolchain practices (version management, build optimization) worth documenting

### What to Ignore

- Standard framework boilerplate without customization
- Version differences without configuration insight

---

## Drift Mode Additions

When running in `--drift` mode, apply these additional heuristics:

### Detecting Deliberate Divergences

1. **File-by-file comparison**: Diff `.claude/` files between target and blueprint origin
2. **ADR additions**: Check if target has ADRs beyond the blueprint's set
3. **Guardrail modifications**: Check if target has added or modified IF-*/GR-* rules
4. **Workflow evolution**: Check if target's `.claude/workflows.md` has new or modified workflows
5. **Stack customization**: Check if target has modified stack-specific configs

### Drift Classification

| Type | Signal | Action |
|------|--------|--------|
| Extension | New file/section not in blueprint | Evaluate for upstream adoption |
| Refinement | Modified blueprint content with more detail | Evaluate for upstream merge |
| Override | Blueprint content replaced with different approach | Flag for review, may indicate blueprint gap |
| Removal | Blueprint content deleted | Flag for review, may indicate unnecessary content |

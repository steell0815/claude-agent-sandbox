# Security Policy

Security and privacy are not optional qualities — they are professional and ethical obligations.

This document describes how security is approached under a **Continuous Integration → Continuous Delivery / Deployment** model.

---

## Mode of Operation

This project is developed and operated using:

- **Continuous Integration**
- **Trunk-Based Development**
- **Continuous Delivery / Continuous Deployment**
- A single long-lived branch: **`main`**

There are no "supported versions" in the traditional sense.

> **`main` is always the system.**

Security is therefore not something that is patched into released versions later — it is continuously designed, verified, deployed, and observed.

---

## Security Is Not an NFR

Security is treated as:

- a **design constraint**
- a **delivery criterion**
- a **runtime concern**
- a **shared professional responsibility**

Security is evaluated continuously:
- before integration (design & coding)
- during integration (CI, SAST, acceptance tests)
- after deployment (DAST, observability, runtime signals)

---

## Continuous Security Verification

### 1) Commit Stage — Prevent Obvious Regressions

Every push to `main` triggers a **commit stage** that includes:

- build and fast-running automated tests
- static checks and linters (as configured)
- **SAST** (Static Application Security Testing)

A commit is not acceptable unless this stage passes.

---

### 2) Acceptance Stage — Security in System Behavior

A dedicated **acceptance stage** runs BDD-style end-to-end tests.

- Acceptance tests are explicitly tagged or organized in dedicated directories
- Only acceptance tests are executed in this stage
- Results are treated as delivery-relevant outcomes

Security-relevant behavior (authorization, data visibility, auditability) is expected to be expressed and validated at this level where possible.

---

### 3) Continuous & Scheduled DAST — Runtime Reality

**DAST (Dynamic Application Security Testing)** should be performed regularly.

- A scheduled job (e.g., daily) spins up the current `main` system
- An **OWASP ZAP baseline scan** is executed
- Findings are published and tracked over time

This acknowledges a core reality:
> Some security weaknesses only exist at runtime.

---

## Controlling Exposure Without Branching

Continuous deployment does **not** mean uncontrolled exposure.

### Supported Patterns

- **Feature flags**
- **Dark launches**
- **Branch by abstraction**

These patterns allow:
- shipping changes safely
- limiting blast radius
- gradual exposure to users
- fast rollback without reverting commits

---

## Observability as a Security Capability

In a continuously deployed system, **security cannot exist without observability**.

This includes:
- meaningful logs (without leaking secrets)
- metrics that reveal abnormal behavior
- traces that support incident analysis
- visibility into authorization failures and access patterns

Security success or failure is measured **in production**, not assumed at deploy time.

---

## Responding to Security Signals

When a security-relevant signal appears (CI, DAST, production telemetry):

1. **Stop the line if necessary**
2. Assess impact and exposure
3. Reduce exposure using flags or abstractions
4. Fix forward on `main`
5. Verify through CI and runtime observation

Rolling back commits is less important than restoring safety and learning.

---

## Secrets & Credentials

- Secrets must never be committed to source control
- Secrets are injected via environment-specific mechanisms
- If a secret is leaked:
    - rotate immediately
    - limit exposure
    - document the incident and mitigation

---

## Dependency Security in Continuous Flow

Dependencies are part of the system and therefore part of delivery.

- Keep dependencies current
- Monitor for known vulnerabilities
- Treat dependency updates as normal work, not exceptional events

When a vulnerability is detected:
- assess exploitability in context
- mitigate or upgrade promptly
- document decisions when trade-offs exist

---

## Threat Modeling as Continuous Design

Threat modeling is not a one-time activity.

It means:
- continuously identifying trust boundaries
- questioning new data flows
- making security assumptions explicit
- documenting trade-offs in architecture decisions

Significant security-impacting changes should include a short design note explaining:
- what threat is addressed
- what boundary is crossed
- how the risk is controlled

---

## Reporting Vulnerabilities

If you discover a security vulnerability:

- report it responsibly to the maintainers
- include reproduction steps if possible
- avoid public disclosure before coordination

Do not include:
- real user data
- credentials
- exploit code beyond what is necessary to explain the issue

---

## Final Principle

> **Security is how we build, deliver, and operate the system — continuously.**

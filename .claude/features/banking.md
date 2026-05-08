# Banking Domain (Bank Account Opening & Securities Account Opening)

> Last updated: 2026-02-13

## Glossary (Ubiquitous Language)

| Term | Definition |
|------|-----------|
| PRI | Private Individual — natural person opening an account for personal use |
| NPE | Non-Private Entity — legal entity (company) opening an account |
| OTP | One-Time Password — phone verification during onboarding |
| OIDC | OpenID Connect — ID Austria authentication flow |
| Soft KO | Non-blocking issue that prevents completion but allows partial progress (e.g. US tax relation) |
| Checklist | Step-based progress tracker with states: `required`, `allowed`, `done` |
| Journey | Multi-step onboarding flow managing roles and their person references |
| Case | Aggregate root for a single person's onboarding within BAO |
| SaoCase | Aggregate root for securities account opening — tracks investor profile, terms, checklist |
| SaoJourney | Multi-actor journey managing owner, co-owners, and signatories for SAO |
| CauseAndEffect | Event sourcing pattern: Cause (command) + Effect (event) pair applied to an entity |
| InvestorProfile | SAO-specific value object capturing investment knowledge, experience, risk readiness |
| StartDepot | Securities product with age restriction (owner must be ≤ 27) |
| SignD | Legitimation service for identity verification |
| Helios | Core banking system integration |
| CoreSystemReference | Person reference linked to the core banking system (has customerId) |
| CaseReference | Person reference linked to an active BAO case (pre-legitimation) |
| EmptyReference | Placeholder for an unassigned role in a journey |

---

## BAO — Bank Account Opening

### Key Type Contracts

#### Case (Entity — Aggregate Root)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| termsAndConditions | Terms | Required for progression |
| nextProposedStep | String | Current step in onboarding flow |
| stepStates | Map | Step → state mapping |
| revision | Revision | Optimistic concurrency |

#### Journey (Entity)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| roles | Map&lt;String, References&gt; | Role → person references |
| finished | boolean | Journey completion flag |
| problemDetails | List | Open issues / problem details |
| revision | Revision | Optimistic concurrency |

#### Terms (Value Object)

| Field | Type | Constraints |
|-------|------|-------------|
| termsAndConditionsAccepted | boolean | Must be true |
| usingOidcAuthentication | boolean | Selects OIDC flow |
| productAgeConfirmed | boolean | Age confirmation for products |
| dataProtectionAgreementAccepted | boolean | GDPR consent |

#### Cause/Effect Events (Case)

| Cause | Effect | Entity |
|-------|--------|--------|
| StartCase | CaseStarted | Case |
| SubmitTerms | TermsSubmitted | Case |
| SubmitTermsWithoutAcceptance | TermsSubmitted | Case |

#### Cause/Effect Events (Journey)

| Cause | Effect | Entity |
|-------|--------|--------|
| StartProspectCaseForRole | ProspectCaseStartedForRole | Journey |
| ReplaceCaseWithCoreSystemReference | CaseReplacedWithCoreSystemReference | Journey |
| RemoveRoleFromJourney | RoleRemovedFromJourney | Journey |
| SetAdditionalProducts | AdditionalProductsSet | Journey |
| SetCaseProblemDetails | CaseProblemDetailsSet | Journey |
| ResetCaseReferenceToEmptyReference | CaseReferenceResetToEmptyReference | Journey |
| SubmitDocuments | DocumentsSubmitted | Journey |
| UpdatePersonInCaseReference | PersonUpdatedInCaseReference | Journey |

### Acceptance Test Scenarios

```java
class ProspectCaseAcceptanceTest {

    @Test void startAsPRI() {
        caseId = caseDriver.startAsPRI();
        caseDriver.assertCaseStartedAsPRI(caseId);
    }

    @Test void startAsNPE() {
        caseId = caseDriver.startAsNPE();
        caseDriver.assertCaseStartedAsNPE(caseId);
    }

    @Test void startedCaseInOpenCases() {
        caseId = caseDriver.startAsPRI();
        caseDriver.assertCaseInOpenCases(caseId);
    }

    @Test void submitTermsAcceptMarketing() {
        caseId = caseDriver.startAsPRI();
        caseDriver.submitTermsAcceptMarketing(caseId);
        caseDriver.assertTermsSubmitted(caseId);
        caseDriver.assertNextStepIsPerson(caseId);
    }

    @Test void submitTermsRejectMarketing() {
        caseId = caseDriver.startAsPRI();
        caseDriver.submitTermsRejectMarketing(caseId);
        caseDriver.assertTermsSubmitted(caseId);
        caseDriver.assertNextStepIsPerson(caseId);
    }

    @Test void submitTermsSelectIDAustria() {
        caseId = caseDriver.startAsPRI();
        caseDriver.submitTermsSelectIDAustria(caseId);
        caseDriver.assertTermsSubmitted(caseId);
        caseDriver.assertNextStepIsOidc(caseId);
    }
}
```

### DSL Model (CaseDriver)

```java
interface CaseDriver {
    // Actions
    String startAsPRI();
    String startAsNPE();
    void submitTermsAcceptMarketing(String caseId);
    void submitTermsRejectMarketing(String caseId);
    void submitTermsSelectIDAustria(String caseId);

    // Assertions
    void assertCaseStartedAsPRI(String caseId);
    void assertCaseStartedAsNPE(String caseId);
    void assertCaseInOpenCases(String caseId);
    void assertTermsSubmitted(String caseId);
    void assertNextStepIsPerson(String caseId);
    void assertNextStepIsOidc(String caseId);
}
```

---

## SAO — Securities Account Opening

### Key Type Contracts

#### SaoCase (Entity — Aggregate Root)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| investorProfile | InvestorProfile | Nested entity with quiz, knowledge, experience |
| terms | Terms | SAO-specific terms acceptance |
| checklist | CheckList | Step progress tracker |
| investorProfileChecklist | InvestorProfileCheckList | Investor profile completion tracker |
| openIssues | OpenIssues | Soft KO / hard failure tracking |
| signRequiredDocuments | Map&lt;String, SystemCreatedDocument&gt; | Documents requiring signature |
| finished | boolean | Case completion flag |
| revision | CurrentRevision | Optimistic concurrency |

#### SaoJourney (Entity)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| productId | String | Assigned securities product |
| roles | Roles | Owner, co-owners, signatories with person references |
| staticDocuments | Map&lt;String, SystemCreatedDocument&gt; | Read-only documents |
| signRequiredDocuments | Map&lt;String, SystemCreatedDocument&gt; | Documents requiring signature |
| selectedAccount | SelectedAccountV0 | Clearing account selection |
| accountInformation | AccountInformationV0 | Created account details |
| openIssues | OpenIssuesV0 | Validation issues |
| finished | boolean | Journey completion flag |
| revision | CurrentRevision | Optimistic concurrency |

#### InvestorProfile (Nested in SaoCase)

| Field | Type | Constraints |
|-------|------|-------------|
| highestEducation | String | Education level |
| experience | Experience | Investment experience |
| knowledge | Knowledge | Asset class knowledge levels |
| riskReadiness | RiskReadiness | Risk tolerance enum |
| investmentGoals | InvestmentGoals | Investment objectives |
| quiz | Quiz | MiFID knowledge quiz with QuizStatus |

#### NaturalPerson (Value Object — shared)

| Field | Type | Constraints |
|-------|------|-------------|
| firstname | String | @NotBlank |
| lastname | String | @NotBlank |
| birthdate | LocalDate | @Age(min=18, max=100) |
| gender | String | @Gender |
| placeOfBirth | String | @NotBlank |
| citizenship | String | @NotBlank |
| email | String | @Email |
| occupation | String | @NotBlank |
| phoneNumber | PhoneNumber | @PhoneNumber |
| numberOfChildren | Integer | @Size(min=0, max=999) |
| countryOfBirth | String | @CountryCode |
| familyStatus | String | @NotBlank |

#### Address (Value Object — shared)

| Field | Type | Constraints |
|-------|------|-------------|
| country | String | @NotBlank, @CountryCode |
| zip | String | @NotBlank, @Size(min=3, max=10) |
| city | String | @NotBlank |
| street | String | @NotBlank |
| streetNumber | String | @NotBlank |

#### Cause/Effect Events (SaoCase)

| Cause | Effect | Entity |
|-------|--------|--------|
| StartSecuritiesCase | SecuritiesCaseStarted | SaoCase |
| StartSecuritiesCaseForProspect | SecuritiesCaseStartedForProspect | SaoCase |
| StartSecuritiesCaseWithProduct | SecuritiesCaseStartedWithProduct | SaoCase |
| AssignSecuritiesCaseTerms | SecuritiesCaseTermsAssigned | SaoCase |
| AssignGainedKnowledge | GainedKnowledgeAssigned | SaoCase |
| SubmitQuizAnswerBlock | QuizAnswerBlockSubmitted | SaoCase |
| SubmitCaseV0 | CaseSubmittedV0 | SaoCase |
| AddDataToCustomer (V1) | DataAddedToCustomer | SaoCase |
| CreateSecuritiesAccount | SecuritiesAccountCreated | SaoCase |

#### Cause/Effect Events (SaoJourney)

| Cause | Effect | Entity |
|-------|--------|--------|
| SubmitDocuments | DocumentsSubmitted | SaoJourney |
| UpdateAddressForCaseReference | AddressUpdatedForCaseReference | SaoJourney |
| UpdatePersonForCaseReference | PersonUpdatedForCaseReference | SaoJourney |
| SetUserDocumentsToRole | UserDocumentsSetToRole | SaoJourney |
| DeleteSaoJourney | SaoJourneyDeleted | SaoJourney |

### Acceptance Test Scenarios

```java
class ProspectUserAcceptanceTest {

    // --- Person Onboarding (shared with BAO) ---

    @Test void startAsPRI() {
        caseId = driver.startAsPRI();
        driver.assertPersonOnboardingStarted(caseId);
    }

    @Test void startAsNPE() {
        caseId = driver.startAsNPE();
        driver.assertPersonOnboardingStarted(caseId);
    }

    @Test void submitTermsAcceptMarketing() {
        caseId = driver.startAsPRI();
        driver.submitTermsAcceptMarketing(caseId);
        driver.assertTermsSubmitted(caseId);
    }

    @Test void submitTermsSelectIDAustria() {
        caseId = driver.startAsPRI();
        driver.submitTermsSelectIDAustria(caseId);
        driver.assertTermsSubmittedWithOidc(caseId);
    }

    @Test void submitPerson() {
        caseId = driver.startAsPRI();
        driver.submitTermsAcceptMarketing(caseId);
        driver.submitPerson(caseId);
        driver.assertPersonSubmitted(caseId);
    }

    @Test void submitOtp() {
        caseId = driver.startAsPRI();
        driver.submitTermsAcceptMarketing(caseId);
        driver.submitPerson(caseId);
        driver.requestOtp(caseId);
        driver.assertOtpRequested(caseId);
        driver.verifyOtp(caseId);
        driver.assertOtpVerified(caseId);
    }

    @Test void submitAddress() {
        // ... terms → person → OTP ...
        driver.submitAddress(caseId);
        driver.assertAddressSubmitted(caseId);
    }

    @Test void submitCompany() {
        caseId = driver.startAsNPE();
        // ... terms → person → OTP → address ...
        driver.submitCompany(caseId);
        driver.assertCompanySubmitted(caseId);
    }

    @Test void submitIncomeAndExpenses() {
        // ... terms → person → OTP → address ...
        driver.submitIncomeAndExpenses(caseId);
        driver.assertIncomeAndExpensesSubmitted(caseId);
    }

    @Test void submitTaxInformation() {
        // ... terms → person → OTP → address → income ...
        driver.submitTaxLiabilityPRI(caseId);
        driver.assertTaxLiabilitySubmitted(caseId);
    }

    @Test void submitSummary() {
        // ... terms → person → OTP → address → income → tax ...
        driver.submitSummary(caseId);
        driver.assertSummarySubmitted(caseId);
    }

    // --- Legitimation ---

    @Test void submitLegitimation_submitsPersonToCoreSystem() {
        // ... full onboarding flow ...
        driver.submitSignDLegitimation(caseId);
        driver.assertPersonCreated(caseId);
    }

    @Test void submitLegitimation_failure() {
        // ... full onboarding flow ...
        driver.submitErroneousSignDLegitimation(caseId);
        driver.assertOnboardingIsSoftKo(caseId);
    }

    @Test void personWithUSRelation_softKoAfterLegitimation() {
        // ... onboarding with US tax relation ...
        driver.submitTaxLiabilityWithUSRelation(caseId);
        driver.submitSummary(caseId);
        driver.submitSignDLegitimation(caseId);
        driver.assertOnboardingIsSoftKo(caseId);
    }

    // --- SAO-specific (post-legitimation) ---

    @Test void submitLegitimation_productValidForPerson() {
        saoCaseId = doPriOnboardingWithPersonMatchingProduct();
        driver.assertProductSubmitted(saoCaseId);
    }

    @Test void submitLegitimation_productNotValidForPerson() {
        saoCaseId = doPriOnboardingWithPersonTooOldForStartDepot();
        driver.assertSaoProductSelectionNecessary(saoCaseId);
    }

    @Test void saoCase_SubmitProduct() {
        saoCaseId = doPriOnboardingWithPersonTooOldForStartDepot();
        driver.submitProduct(saoCaseId);
        driver.assertProductSubmitted(saoCaseId);
    }

    @Test void saoCase_submitTerms() {
        saoCaseId = doPriOnboardingWithPersonMatchingProduct();
        driver.submitSaoTermsAcceptMarketing(saoCaseId);
        driver.assertSaoTermsSubmitted(saoCaseId);
    }

    @Test void saoCase_updatePerson() {
        saoCaseId = doPriOnboardingWithPersonMatchingProduct();
        driver.submitSaoTermsAcceptMarketing(saoCaseId);
        driver.updatePerson(saoCaseId);
        driver.assertPersonUpdated(saoCaseId);
    }

    // --- Helper flows ---

    private String doPriOnboardingWithPersonMatchingProduct() {
        caseId = driver.startAsPRI();
        saoCaseId = driver.findSaoCaseForOnboarding(caseId);
        // terms → person → OTP → address → income → tax → summary → legitimation
        return saoCaseId;
    }

    private String doPriOnboardingWithPersonTooOldForStartDepot() {
        caseId = driver.startAsPRIWithStartDepot();
        saoCaseId = driver.findSaoCaseForOnboarding(caseId);
        // terms → personOver27 → OTP → address → income → tax → summary → legitimation
        return saoCaseId;
    }
}
```

### DSL Model (ProspectUserDriver)

```java
interface ProspectUserDriver {
    // Case lifecycle
    String startAsPRI();
    String startAsPRIWithStartDepot();
    String startAsNPE();
    String findSaoCaseForOnboarding(String caseId);

    // Onboarding actions
    void submitTermsAcceptMarketing(String caseId);
    void submitTermsSelectIDAustria(String caseId);
    void submitPerson(String caseId);
    void submitPersonOver27(String caseId);
    void requestOtp(String caseId);
    void verifyOtp(String caseId);
    void submitAddress(String caseId);
    void submitCompany(String caseId);
    void submitIncomeAndExpenses(String caseId);
    void submitTaxLiabilityPRI(String caseId);
    void submitTaxLiabilityWithUSRelation(String caseId);
    void submitSummary(String caseId);
    void submitSignDLegitimation(String caseId);
    void submitErroneousSignDLegitimation(String caseId);

    // SAO-specific actions
    void submitSaoTermsAcceptMarketing(String saoCaseId);
    void submitProduct(String saoCaseId);
    void updatePerson(String saoCaseId);

    // Onboarding assertions
    void assertPersonOnboardingStarted(String caseId);
    void assertTermsSubmitted(String caseId);
    void assertTermsSubmittedWithOidc(String caseId);
    void assertPersonSubmitted(String caseId);
    void assertOtpRequested(String caseId);
    void assertOtpVerified(String caseId);
    void assertAddressSubmitted(String caseId);
    void assertCompanySubmitted(String caseId);
    void assertIncomeAndExpensesSubmitted(String caseId);
    void assertTaxLiabilitySubmitted(String caseId);
    void assertSummarySubmitted(String caseId);
    void assertPersonCreated(String caseId);
    void assertOnboardingIsSoftKo(String caseId);

    // SAO-specific assertions
    void assertSaoTermsSubmitted(String saoCaseId);
    void assertProductSubmitted(String saoCaseId);
    void assertSaoProductSelectionNecessary(String saoCaseId);
    void assertPersonUpdated(String saoCaseId);
}
```

---

## Shared Concepts

### Person Onboarding Flow

The standard onboarding flow is shared between BAO and SAO:

```
Terms → Person Data → OTP (request + verify) → Address → Income & Expenses → Tax Liability → Summary → Legitimation (SignD)
```

Variations:
- **NPE flow**: adds `Company` step after `Address`
- **OIDC flow**: when ID Austria is selected at Terms, next step changes from `Person` to `OIDC`
- **US relation**: submitting tax liability with US relation triggers soft KO after legitimation

### Checklist Pattern

Both BAO and SAO use a step-based checklist to track onboarding progress:

| State | Meaning |
|-------|---------|
| `required` | Step must be completed before proceeding |
| `allowed` | Step can be completed (prerequisites met) |
| `done` | Step has been completed |

The `nextProposedStep` field on Case indicates which step the user should complete next.

### Event Sourcing (CauseAndEffect Pattern)

All state changes follow the CauseAndEffect pattern from `domain-core`:

```java
interface CauseAndEffect<Entity, Cause, Effect> {
    boolean isApplicable(EventStore.Event event);
    Entity process(Entity entity, EventStore.Event event);
}
```

- **Causes** (commands) are designed outside-in — they represent what the user wants to do
- **Effects** (events) are designed inside-out — they represent what happened in the domain
- Effects are immutable and never modified after creation; new versions are created instead
- The `process` method applies an effect to rebuild the entity from the event store

### Open Issues Pattern

Open issues track problems discovered during processing:
- **Soft KO**: Non-blocking issue (e.g. US tax relation) — onboarding continues but cannot fully complete
- **Hard failure**: Blocking issue that prevents further progress
- Issues are accumulated and surfaced at appropriate checkpoints (typically after legitimation)

---

## Architecture Notes

- **BAO and SAO are separate bounded contexts** sharing the person onboarding flow through a common acceptance test structure
- BAO manages `Case` (single person) and `Journey` (multi-role) as separate aggregates
- SAO manages `SaoCase` (investor profile + terms) and `SaoJourney` (multi-actor with documents) as separate aggregates
- **Event sourcing** via `domain-core` infrastructure — all entity state is derived from replaying CauseAndEffect events
- **BDD acceptance tests** use the 4-layer pattern: Test → DSL (Driver interface) → Protocol Driver → SUT
- `AbstractProspectCaseAcceptanceTest` and `AbstractProspectUserAcceptanceTest` are abstract; concrete subclasses inject domain or controller drivers

### Integration Points

| System | Purpose |
|--------|---------|
| Helios | Core banking system — person/account creation, customer lookup |
| ID Austria | OIDC identity provider for Austrian digital identity |
| SignD | Legitimation service for video/photo identity verification |

### Multi-Actor Journey (SAO)

SaoJourney supports multiple roles with different person reference types:

```
SaoJourney
├── Roles
│   ├── Owner (1) → CoreSystemReference / CaseReference / EmptyReference
│   ├── Co-owners (0..n) → CoreSystemReference / CaseReference / EmptyReference
│   └── Signatories (0..n) → CoreSystemReference / CaseReference / EmptyReference
├── Static Documents (read-only, e.g. terms PDF)
├── Sign-Required Documents (need signature)
└── Account Information (after creation)
```

Reference lifecycle: `EmptyReference` → `CaseReference` (during onboarding) → `CoreSystemReference` (after legitimation)

---

## File Manifest

### BAO

| Circle | File | Purpose |
|--------|------|---------|
| Entity | `bao/case-domain/.../entity/Case.java` | Case aggregate root |
| Entity | `bao/journey-domain/.../entity/Journey.java` | Journey aggregate root |
| Events | `bao/case-domain/.../event/SubmitTermsCauseAndEffect.java` | Terms submission event |
| Events | `bao/journey-domain/.../event/StartProspectCaseForRoleCauseAndEffect.java` | Journey case start |
| Events | `bao/journey-domain/.../event/ReplaceCaseWithCoreSystemReferenceCauseAndEffect.java` | Post-legitimation reference swap |
| Events | `bao/journey-domain/.../event/SubmitDocumentsCauseAndEffect.java` | Document submission |
| Acceptance | `bao/acceptance/.../scenario/AbstractProspectCaseAcceptanceTest.java` | 6 prospect case scenarios |
| Acceptance | `bao/acceptance/.../driver/CaseDriver.java` | BAO test driver interface |

### SAO

| Circle | File | Purpose |
|--------|------|---------|
| Entity | `sao/sao-domain/.../entity/SaoCase.java` | SaoCase aggregate root |
| Entity | `sao/sao-domain/.../entity/SaoJourney.java` | SaoJourney aggregate root |
| Model | `sao/sao-domain/.../model/NaturalPerson.java` | Person value object |
| Model | `sao/sao-domain/.../model/Address.java` | Address value object |
| Events | `sao/sao-domain/.../event/StartSecuritiesCaseCauseAndEffect.java` | Case start event |
| Events | `sao/sao-domain/.../event/SecuritiesCaseTermsAssignedCauseAndEffect.java` | Terms assignment |
| Events | `sao/sao-domain/.../event/SubmitQuizAnswerBlockCauseAndEffect.java` | Quiz submission |
| Events | `sao/sao-domain/.../event/SubmitDocumentsCauseAndEffect.java` | Document submission |
| Events | `sao/sao-domain/.../event/CreateSecuritiesAccountCauseAndEffect.java` | Account creation |
| Acceptance | `sao/acceptance/.../scenario/AbstractProspectUserAcceptanceTest.java` | 19 prospect user scenarios |
| Acceptance | `sao/acceptance/.../driver/ProspectUserDriver.java` | SAO test driver interface |

### Shared

| Circle | File | Purpose |
|--------|------|---------|
| Infrastructure | `domain-core/domain/` | Core domain abstractions (CauseAndEffect, EventStore) |
| Infrastructure | `domain-core/domain-events/` | Event sourcing infrastructure |
| Test Utils | `domain-core/domain-testutils/` | Shared test utilities |

---

## Gotchas / Notes

- **US relation triggers soft KO after legitimation** — `submitTaxLiabilityWithUSRelation` causes `assertOnboardingIsSoftKo` after SignD legitimation completes. The soft KO does not block the onboarding flow itself, only the final completion.
- **StartDepot product has age validation (≤ 27)** — When a person over 27 is onboarded with a StartDepot product, `assertSaoProductSelectionNecessary` fires instead of `assertProductSubmitted`, requiring manual product re-selection.
- **OIDC flow changes next step** — Selecting ID Austria at the terms step changes `nextProposedStep` from `Person` to `OIDC` (verified by `assertNextStepIsOidc` vs `assertNextStepIsPerson`).
- **BAO Case has 6 tests, SAO has 19** — BAO tests cover case start and terms; SAO tests cover the full onboarding + legitimation + SAO-specific flows (product, SAO terms, person update).
- **Event versioning** — Never modify existing events. Version them (e.g. `SubmitSecuritiesCaseCauseAndEffectV0`, `AddDataToCustomerCauseAndEffectV1`). Old CauseAndEffect classes delegate to V1 implementations via `applyOldEffect`.
- **SaoJourney validation** — `SaoJourney.validate()` returns `ValidationResultsV0` with problem keys like `EMPLOYEE_NOT_ASSIGNED`, `AGE_INVALID`, `PERSON_ASSIGNED_TO_MULTIPLE_ROLES`, `INVESTOR_PROFILE_EXPIRED`, etc.
- **Erroneous legitimation** — `submitErroneousSignDLegitimation` simulates a failed SignD flow, which also results in soft KO.

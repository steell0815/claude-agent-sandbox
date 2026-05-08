# Corporate Finance Application (COLE)

> Last updated: 2026-02-14

## Glossary (Ubiquitous Language)

| Term | Definition |
|------|-----------|
| Customer | Base type for any party applying for corporate finance (Prospect or Existing) |
| Prospect | A potential customer not yet in the core banking system |
| Existing | A customer already registered in the core banking system |
| Consultant | Bank employee who manages and advises on finance applications |
| ConditionalOffer | Preliminary financing offer linking a Customer and Consultant |
| FinanceApplication | Abstract base for all corporate finance application types |
| CorporateFinanceApplication | Abstract type for corporate finance — either Simple or Complex |
| SimpleCorporateFinanceApplication | Standard corporate finance application |
| ComplexCorporateFinanceApplication | Corporate finance application requiring additional review |
| TrivialFinanceApplication | Minor financing (Bagatellfinanzierung) — not currently supported in KRAN |
| ActiveLineFinanceApplication | Pre-approved but unused credit line — not currently supported in KRAN |
| CoreDetails | Value object holding amount, currency, purpose, company name, and registration ID |
| COLE | Bounded context name for Corporate Finance Application |
| KRAN | External system for credit application processing |
| WinCube | Document management system integration |
| BILA | Balance analysis (Bilanzanalyse) — triggered when all required documents are locked |
| Draft | Initial status of a finance application before submission |
| Submitted | Status after a valid application is submitted for processing |
| Withdrawn | Status after a customer or consultant withdraws the application |
| Co-borrower | Additional existing customer added as joint applicant |
| SLA | Service Level Agreement — breach events raised if application not picked up in time |

---

## Key Type Contracts

### Customer Hierarchy

| Type | Extends | Description |
|------|---------|-------------|
| Customer | — | Base type for finance application parties |
| Prospect | Customer | Potential customer, not yet in core banking system |
| Existing | Customer | Customer already registered in core banking system |

### Consultant

| Field | Type | Description |
|-------|------|-------------|
| email | String | Consultant's email address |
| name | String | Consultant's display name |

### ConditionalOffer

| Field | Type | Description |
|-------|------|-------------|
| customer | Customer | The customer receiving the offer |
| consultant | Consultant | The consultant creating the offer |

### FinanceApplication Hierarchy

| Type | Extends | Description |
|------|---------|-------------|
| FinanceApplication | — | Abstract base for all finance applications |
| CorporateFinanceApplication | FinanceApplication | Abstract corporate finance type |
| SimpleCorporateFinanceApplication | CorporateFinanceApplication | Standard corporate finance |
| ComplexCorporateFinanceApplication | CorporateFinanceApplication | Complex corporate finance requiring additional review |
| TrivialFinanceApplication | FinanceApplication | Minor financing — not supported in KRAN |
| ActiveLineFinanceApplication | FinanceApplication | Pre-approved unused credit line — not supported in KRAN |

### CoreDetails (Value Object)

| Field | Type | Description |
|-------|------|-------------|
| amount | BigDecimal | Loan amount (e.g. "100000.00") |
| currency | String | Currency code (e.g. "EUR") |
| purpose | String | Purpose of the financing |
| companyName | String | Applicant company name |
| registrationId | String | Company registration ID (e.g. "FN-123456x") |

---

## Acceptance Test Scenarios

```java
@DisplayName("Corporate Finance Application — Acceptance (ATDD/Spec)")
class CorporateFinanceApplicationAcceptance {

    FinanceDomainDriver driver;

    Consultant anna = new Consultant("anna.consultant@bks.at", "Anna Consultant");
    Consultant ben  = new Consultant("ben.consultant@bks.at",  "Ben Consultant");

    Existing erikExisting   = new Existing("erik@corp.example",   "Erik Existing GmbH");
    Prospect paulaProspect  = new Prospect("paula@lead.example",  "Paula Prospect KG");
    Existing eveCoBorrower  = new Existing("eve@partner.example", "Eve Partner AG");

    CoreDetails coreDetails = new CoreDetails()
        .withAmount(new BigDecimal("100000.00"))
        .withCurrency("EUR")
        .withPurpose("Purchase of equipment")
        .withCompanyName("Erik Existing GmbH")
        .withRegistrationId("FN-123456x");

    // --- Basic creation — 7 tests --------------------------------------------

    @Test
    @DisplayName("Prospect customer can start a Corporate Finance application")
    void prospectStartsCorporateFinance() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceIsCreated();
        driver.assertCorporateFinanceCreatorIs(paulaProspect);
    }

    @Test
    @DisplayName("Prospect customer can start a Corporate Finance application - Prospect with no consultant")
    void prospectStartsCorporateFinance_prospectWithNoConsultant() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceIsFromProspect();
        driver.assertCorporateFinanceHasNoConsultantAssigned();
    }

    @Test
    @DisplayName("Prospect customer can start a Corporate Finance application - Status")
    void prospectStartsCorporateFinance_status() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceStatusIsDraft();
    }

    @Test
    @DisplayName("Consultant can start a Corporate Finance application without an assigned customer")
    void consultantStartsCorporateFinanceWithoutCustomer() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceIsCreated();
        driver.assertCorporateFinanceIsAssignedTo(anna);
    }

    @Test
    @DisplayName("Consultant can start a Corporate Finance application without an assigned customer - No customer draft")
    void consultantStartsCorporateFinanceWithoutCustomer_noCustomerDraft() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceHasNoCustomerAssigned();
        driver.assertCorporateFinanceStatusIsDraft();
    }

    @Test
    @DisplayName("Existing customer starts Corporate Finance — no consultant by default")
    void existingCustomerStartsCorporateFinance() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceIsCreated();
        driver.assertCorporateFinanceCreatorIs(erikExisting);
    }

    @Test
    @DisplayName("Existing customer starts Corporate Finance — no consultant by default - No consultant draft")
    void existingCustomerStartsCorporateFinance_noConsultantDraft() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.assertCorporateFinanceHasNoConsultantAssigned();
        driver.assertCorporateFinanceStatusIsDraft();
    }

    // --- Assignment flows -----------------------------------------------------

    @Test
    @DisplayName("Assign consultant to customer-started application")
    void assignConsultantToCustomerStarted() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();
        driver.logoutThenLoginAsConsultant(anna);

        driver.assignConsultantToCurrentApplication(anna);
        driver.assertCorporateFinanceIsAssignedTo(anna);
        driver.assertCustomerIsNotifiedConsultantAssigned(erikExisting);
    }

    @Test
    @DisplayName("Assign existing customer to consultant-started application")
    void assignExistingCustomerToConsultantStarted() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        driver.assignExistingCustomerToCurrentApplication(erikExisting);
        driver.assertCorporateFinanceCustomerIs(erikExisting);
        driver.assertConsultantIs(anna);
    }

    @Test
    @DisplayName("Assign existing customer to consultant-started application - Notification")
    void assignExistingCustomerToConsultantStarted_notification() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        driver.assignExistingCustomerToCurrentApplication(erikExisting);
        driver.assertCustomerIsNotifiedApplicationCreated(erikExisting);
    }

    @Test
    @DisplayName("Assign prospect customer to consultant-started application")
    void assignProspectCustomerToConsultantStarted() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        driver.assignProspectCustomerToCurrentApplication(paulaProspect);
        driver.assertCorporateFinanceCustomerIs(paulaProspect);
        driver.assertCorporateFinanceIsFromProspect();
    }

    @Test
    @DisplayName("Reassign consultant to another consultant (handover)")
    void reassignConsultant() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.reassignConsultantTo(ben);
        driver.assertCorporateFinanceIsAssignedTo(ben);
        driver.assertAuditTrailContains("CONSULTANT_REASSIGNED", "anna", "ben");
    }

    @Test
    @DisplayName("Reassign consultant to another consultant (handover) - Notification")
    void reassignConsultant_notification() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.reassignConsultantTo(ben);
        driver.assertCustomerIsNotifiedConsultantReassigned(erikExisting, ben);
    }

    @Test
    @DisplayName("Idempotent assignments do not duplicate or re-notify")
    void idempotentAssignment() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.assignExistingCustomerToCurrentApplication(erikExisting);
        driver.assignConsultantToCurrentApplication(anna);

        driver.assertOnlyOneCustomerAssignment(erikExisting);
        driver.assertOnlyOneConsultantAssignment(anna);
    }

    @Test
    @DisplayName("Idempotent assignments do not duplicate or re-notify - Notification")
    void idempotentAssignment_notification() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.assignExistingCustomerToCurrentApplication(erikExisting);
        driver.assignConsultantToCurrentApplication(anna);

        driver.assertNoDuplicateNotifications();
    }

    // --- Data entry / validation ---------------------------------------------

    @Test
    @DisplayName("Enter core details (amount, purpose, company) and save draft - Amount/Currency/Purpose")
    void enterCoreDetailsAndSaveDraft_amountCurrencyPurpose() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.setCoreDetails(coreDetails);
        driver.saveDraft();

        driver.assertDraftHasAmountCurrencyPurpose("2500000.00", "EUR", "Working capital and CAPEX");
    }

    @Test
    @DisplayName("Enter core details (amount, purpose, company) and save draft - Applicant")
    void enterCoreDetailsAndSaveDraft_applicant() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.setCoreDetails(coreDetails);
        driver.saveDraft();

        driver.assertDraftHasApplicant("Erik Existing GmbH", "FN-123456x");
        driver.assertCorporateFinanceStatusIsDraft();
    }

    @Test
    @DisplayName("Enter core details (amount, purpose, company) and save draft - Draft status")
    void enterCoreDetailsAndSaveDraft_draftStatus() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.setCoreDetails(coreDetails);
        driver.saveDraft();

        driver.assertCorporateFinanceStatusIsDraft();
    }

    @Test
    @DisplayName("Validation errors block submission until fixed")
    void validationErrorsBlockSubmission() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();

        driver.setLoanAmount(new BigDecimal("-1")); // invalid
        driver.setCurrency("EUR");
        driver.setPurpose(""); // missing

        driver.attemptSubmit();
        driver.assertSubmissionRejectedWithErrors(
            "AMOUNT_POSITIVE_REQUIRED",
            "PURPOSE_REQUIRED"
        );

        driver.setLoanAmount(new BigDecimal("100000.00"));
        driver.setPurpose("Equipment purchase");
        driver.submit();

        driver.assertCorporateFinanceStatusIsSubmitted();
    }

    @Test
    @DisplayName("Currency must be supported; amount must respect min/max per product")
    void currencyAndProductLimits() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.chooseProduct("Corporate Loan Standard");
        driver.setCurrency("ABC"); // unsupported
        driver.setLoanAmount(new BigDecimal("9999999999")); // above product cap
        driver.attemptSubmit();

        driver.assertSubmissionRejectedWithErrors("UNSUPPORTED_CURRENCY", "AMOUNT_EXCEEDS_PRODUCT_CAP");
    }

    @Test
    @DisplayName("Currency must be supported; amount must respect min/max per product - Submitted after correction")
    void currencyAndProductLimits_submittedAfterCorrection() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();

        driver.chooseProduct("Corporate Loan Standard");
        driver.setCurrency("ABC"); // unsupported
        driver.setLoanAmount(new BigDecimal("9999999999")); // above product cap
        driver.attemptSubmit();

        driver.setCurrency("EUR");
        driver.setLoanAmount(new BigDecimal("500000.00"));
        driver.submit();

        driver.assertCorporateFinanceStatusIsSubmitted();
        driver.assertProductIs("Corporate Loan Standard");
    }

    // --- Lifecycle: withdraw ------------------

    @Test
    @DisplayName("Customer can withdraw")
    void withdrawRules_existingCustomer() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();
        driver.enterMinimalValidDraftForSubmission();
        driver.withdraw();
        driver.assertCorporateFinanceStatusIsWithdrawn();
    }

    @Test
    @DisplayName("Customer can withdraw")
    void withdrawRules_prospectCustomer() {
        driver.startCorporateFinance();
        driver.enterMinimalValidDraftForSubmission();
        driver.submit();
        driver.withdraw();
        driver.assertCorporateFinanceStatusIsWithdrawn();
    }


    // --- Co-borrowers / multiple applicants ----------------------------------

    @Test
    @DisplayName("Consultant adds a co-borrower (existing customer) to the application")
    void addCoBorrower() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.addCoBorrower(eveCoBorrower);
        driver.assertCoBorrowersInclude(eveCoBorrower);

        driver.setJointLiability(true);
        driver.submit();

        driver.assertCorporateFinanceStatusIsSubmitted();
    }

    @Test
    @DisplayName("Consultant adds a co-borrower (existing customer) to the application - Notification")
    void addCoBorrower_notification() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        driver.assignExistingCustomerToCurrentApplication(erikExisting);

        driver.addCoBorrower(eveCoBorrower);

        driver.setJointLiability(true);
        driver.submit();

        driver.assertCustomerIsNotifiedCoBorrowerAdded(erikExisting, eveCoBorrower);
    }

    // --- Permissions / visibility --------------------------------------------

    @Test
    @DisplayName("Only creator or assigned consultant can edit draft")
    void permissionsEditDraft() {
        driver.loginAsCustomer(erikExisting);
        driver.startCorporateFinance();
        String appId = driver.currentApplicationId();

        driver.logoutThenLoginAsConsultant(ben);
        driver.attemptEditDraft(appId, "purpose", "New purpose by Ben");
        driver.assertOperationRejected("NOT_ASSIGNED");

        driver.assignConsultantToApplication(appId, ben);
        driver.editDraft(appId, "purpose", "Updated by Ben");
        driver.assertDraftFieldEquals("purpose", "Updated by Ben");
    }

    @Test
    @DisplayName("Draft visible to creator; submitted visible to assigned consultant + back office - Draft visibility")
    void visibilityRules_draft() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();

        driver.assertVisibleTo(paulaProspect);
        driver.assertNotVisibleTo(anna);
    }

    @Test
    @DisplayName("Draft visible to creator; submitted visible to assigned consultant + back office - Submitted visibility")
    void visibilityRules_submitted() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();
        String appId = driver.currentApplicationId();
        driver.submit();

        driver.logoutThenLoginAsConsultant(anna);
        driver.assignProspectCustomerToApplication(appId, paulaProspect);
        driver.assertVisibleTo(anna);
        driver.assertVisibleToBackOffice();
    }

    // --- Referential integrity / IDs / external references -------------------

    @Test
    @DisplayName("Application has stable external ID across refreshes")
    void stableReferences_externalId() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        UUID externalId = driver.assertHasExternalId();

        driver.refresh();
        driver.assertExternalIdEquals(externalId);
    }

    @Test
    @DisplayName("Application has stable human-friendly number across refreshes")
    void stableReferences_humanReadableNumber() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();

        String humanId = driver.assertHasHumanReadableNumberLike("CFA-YYYY-SEQ");

        driver.refresh();
        driver.assertHumanReadableNumberEquals(humanId);
    }

    // --- Security / access boundaries ----------------------------------------

    @Test
    @DisplayName("Users cannot access applications they are not party to")
    void accessBoundaries() {
        driver.loginAsConsultant(anna);
        driver.startCorporateFinance();
        String appId = driver.currentApplicationId();

        driver.logoutThenLoginAsConsultant(ben);
        driver.attemptOpenApplication(appId);
        driver.assertOperationRejected("FORBIDDEN");
    }

    // --- SLA / timers (spec-level, without implementation detail) ------------

    @Test
    @DisplayName("Submitted applications raise SLA breach event if not picked up in time")
    void slaBreachWhenNotPickedUp() {
        driver.loginAsCustomer(paulaProspect);
        driver.startCorporateFinance();
        driver.enterMinimalValidDraftForSubmission();
        driver.submit();

        driver.fastForwardBusinessHours(48); // abstract time control in driver
        driver.assertSlaEventRaised("PICKUP_OVERDUE");
        driver.assertBackOfficeIsNotifiedForPickup();
    }
}
```

### 32 Tests in 9 Categories

#### 1) Basic creation — 7 tests

- **prospectStartsCorporateFinance** — Verifies that a prospect customer can initiate a corporate finance application and the creator is recorded.
- **prospectStartsCorporateFinance_prospectWithNoConsultant** — Confirms the application is marked as from a prospect with no consultant assigned.
- **prospectStartsCorporateFinance_status** — Confirms the application starts in Draft status.
- **consultantStartsCorporateFinanceWithoutCustomer** — Ensures a consultant can create an application and it is assigned to them.
- **consultantStartsCorporateFinanceWithoutCustomer_noCustomerDraft** — Confirms no customer is assigned and the application is in Draft status.
- **existingCustomerStartsCorporateFinance** — Confirms that when an existing customer starts an application, it is created with them as creator.
- **existingCustomerStartsCorporateFinance_noConsultantDraft** — Confirms no consultant is assigned by default and the application is in Draft status.

#### 2) Assignment flows — 8 tests

- **assignConsultantToCustomerStarted** — Checks that a consultant can be assigned to an application started by a customer, and the customer is notified.
- **assignExistingCustomerToConsultantStarted** — Validates that an existing customer can be assigned to an application created by a consultant.
- **assignExistingCustomerToConsultantStarted_notification** — Verifies that the customer is notified when they are assigned to a consultant-started application.
- **assignProspectCustomerToConsultantStarted** — Confirms that a consultant can assign a prospect customer to their newly created application.
- **reassignConsultant** — Tests consultant handover: reassignment is recorded and the audit trail reflects the change.
- **reassignConsultant_notification** — Ensures that the customer is notified when a consultant handover occurs.
- **idempotentAssignment** — Validates that re-assigning the same consultant or customer does not create duplicates.
- **idempotentAssignment_notification** — Confirms that redundant assignments do not produce duplicate notifications.

#### 3) Data entry / validation — 6 tests

- **enterCoreDetailsAndSaveDraft_amountCurrencyPurpose** — Ensures loan amount, currency, and purpose can be entered and are persisted in a saved draft.
- **enterCoreDetailsAndSaveDraft_applicant** — Verifies that company name and registration ID are correctly stored when saving a draft.
- **enterCoreDetailsAndSaveDraft_draftStatus** — Confirms that saving draft details keeps the application in "Draft" status.
- **validationErrorsBlockSubmission** — Tests that invalid inputs (negative amount, missing purpose) block submission until corrected.
- **currencyAndProductLimits** — Validates that unsupported currencies and amounts exceeding product caps are rejected.
- **currencyAndProductLimits_submittedAfterCorrection** — After fixing validation errors, the application is submitted with the correct product.

#### 4) Lifecycle (withdraw) — 2 tests

- **withdrawRules_existingCustomer** — Ensures an existing customer can withdraw an application before decision.
- **withdrawRules_prospectCustomer** — Confirms that a prospect customer can also withdraw their application in the draft/submitted state.

#### 5) Co-borrowers — 2 tests

- **addCoBorrower** — Verifies that a consultant can add an additional existing customer as co-borrower, set joint liability, and submit.
- **addCoBorrower_notification** — Confirms the primary customer is notified when a co-borrower is added.

#### 6) Permissions / visibility — 3 tests

- **permissionsEditDraft** — Checks that only the creator or assigned consultant can edit a draft, and unauthorized edits are blocked.
- **visibilityRules_draft** — Ensures drafts are visible to their creator but not to unassigned consultants.
- **visibilityRules_submitted** — After submission, the application is visible to the assigned consultant and back office.

#### 7) Referential integrity — 2 tests

- **stableReferences_externalId** — Validates that an application has a stable external ID that persists across refreshes.
- **stableReferences_humanReadableNumber** — Validates that an application has a stable human-friendly number that persists across refreshes.

#### 8) Security — 1 test

- **accessBoundaries** — Ensures that consultants who are not assigned cannot access an application (forbidden access is enforced).

#### 9) SLA / timers — 1 test

- **slaBreachWhenNotPickedUp** — Confirms that if a submitted application is not picked up within the SLA time window, a breach event is raised and back office is notified.

---

## DSL Model

### FinanceDomainSpecificLanguage (Base Interface)

```java
interface FinanceDomainSpecificLanguage {
    // Authentication
    void loginAsConsultant(Consultant consultant);
    void loginAsCustomer(Customer customer);
    void unauthenticate();

    // Creation
    void startCorporateFinance();

    // Base assertions
    void assertCorporateFinanceIsCreated();
    void assertCorporateFinanceCreatorIs(Customer customer);
    void assertCorporateFinanceIsFromProspect();
    void assertCorporateFinanceHasNoCustomerAssigned();
    void assertCorporateFinanceIsAssignedTo(Consultant consultant);
    void assertCorporateFinanceHasNoConsultantAssigned();
}
```

### FinanceDomainDriver (Extended — used in pseudocode tests)

```java
interface FinanceDomainDriver extends FinanceDomainSpecificLanguage {
    // Session management
    void logoutThenLoginAsConsultant(Consultant consultant);

    // Assignment actions
    void assignConsultantToCurrentApplication(Consultant consultant);
    void assignConsultantToApplication(String appId, Consultant consultant);
    void assignExistingCustomerToCurrentApplication(Existing customer);
    void assignProspectCustomerToCurrentApplication(Prospect customer);
    void assignProspectCustomerToApplication(String appId, Prospect customer);
    void reassignConsultantTo(Consultant consultant);

    // Data entry
    void setCoreDetails(CoreDetails details);
    void setLoanAmount(BigDecimal amount);
    void setCurrency(String currency);
    void setPurpose(String purpose);
    void chooseProduct(String productName);
    void saveDraft();

    // Submission
    void attemptSubmit();
    void submit();

    // Lifecycle
    void enterMinimalValidDraftForSubmission();
    void withdraw();

    // Co-borrowers
    void addCoBorrower(Existing coBorrower);
    void setJointLiability(boolean joint);

    // Permissions / editing
    String currentApplicationId();
    void attemptEditDraft(String appId, String field, String value);
    void editDraft(String appId, String field, String value);
    void attemptOpenApplication(String appId);
    void refresh();

    // Time control
    void fastForwardBusinessHours(int hours);

    // Assignment assertions
    void assertCorporateFinanceCustomerIs(Customer customer);
    void assertConsultantIs(Consultant consultant);
    void assertOnlyOneCustomerAssignment(Customer customer);
    void assertOnlyOneConsultantAssignment(Consultant consultant);
    void assertCorporateFinanceStatusIsDraft();
    void assertCorporateFinanceStatusIsSubmitted();
    void assertCorporateFinanceStatusIsWithdrawn();

    // Notification assertions
    void assertCustomerIsNotifiedConsultantAssigned(Customer customer);
    void assertCustomerIsNotifiedApplicationCreated(Customer customer);
    void assertCustomerIsNotifiedConsultantReassigned(Customer customer, Consultant newConsultant);
    void assertCustomerIsNotifiedCoBorrowerAdded(Customer customer, Existing coBorrower);
    void assertNoDuplicateNotifications();

    // Data assertions
    void assertDraftHasAmountCurrencyPurpose(String amount, String currency, String purpose);
    void assertDraftHasApplicant(String companyName, String registrationId);
    void assertDraftFieldEquals(String field, String value);
    void assertSubmissionRejectedWithErrors(String... errorCodes);
    void assertProductIs(String productName);

    // Co-borrower assertions
    void assertCoBorrowersInclude(Existing coBorrower);

    // Visibility assertions
    void assertVisibleTo(Customer customer);
    void assertNotVisibleTo(Consultant consultant);
    void assertVisibleToBackOffice();
    void assertOperationRejected(String reason);

    // Reference assertions
    UUID assertHasExternalId();
    String assertHasHumanReadableNumberLike(String pattern);
    void assertExternalIdEquals(UUID externalId);
    void assertHumanReadableNumberEquals(String humanId);

    // Audit trail
    void assertAuditTrailContains(String event, String... details);

    // SLA assertions
    void assertSlaEventRaised(String eventType);
    void assertBackOfficeIsNotifiedForPickup();
}
```

---

## Architecture Notes

- **COLE is a bounded context** for Corporate Finance Applications, separate from Banking (BAO/SAO) but sharing the same Customer/Consultant identity model
- **COLE originates Document Exchange (DOCX)** — as soon as a finance application is created, a DocumentExchange is started to manage required documents
- **Application lifecycle**: Draft → Submitted → (Withdrawn | In Review | ...) — status transitions are enforced by the domain
- **Dual-initiation model**: Both customers and consultants can start applications; assignment flows link the other party afterward
- **Notification pattern**: Status changes and assignments trigger notifications to affected parties (customer, consultant, back office)
- **Status: specification stage** — only dummy drivers are implemented; no production domain or controller drivers yet

### Integration Points

| System | Purpose |
|--------|---------|
| KRAN | Credit application processing — real API; receives financing data |
| WinCube | Document management — receives documents when BILA is triggered |
| BILA | Balance analysis — activated when all required documents are locked in DOCX |

### Relationship to DOCX

- Finance applications determine which documents are required in the Document Exchange
- Document requirements are driven by finance product type and conditions (securities, collateral type, etc.)
- Once all shown documents are locked in DOCX, BILA (balance analysis) can be triggered
- BILA triggers two actions: WinCube document transfer and customer data entry in "Zentraler Auftrag" (AM Workflow)

---

## Gotchas / Notes

- **TrivialFinanceApplication and ActiveLineFinanceApplication are not supported in KRAN** — these finance types exist in the domain model but cannot be processed through the external KRAN system
- **Currently 7 systems involved** in corporate finance processing — COLE aims to simplify this
- **Risk thresholds at 400k** — different processing rules apply above/below this boundary
- **Document requirements depend on questionnaire/input form** — criteria include loan size, financing type, and collateral
- **"Vorläufiges Angebot" (conditional offer)** is the entry point for new customers — requires a user account
- **Consultant options control DOCX requirements** — choices like Bilanzierer/Einnahmen-Ausgaben-Rechner, insurance type, account package, and pledge of corporate shares determine which documents are needed
- **Idempotent assignments** — re-assigning the same customer or consultant must not create duplicates or trigger duplicate notifications
- **Human-readable application number** follows pattern `CFA-YYYY-SEQ` (year + sequence)
- **SLA breach at 48 business hours** — unassigned submitted applications trigger back office notification
- **Skeleton tests not yet implemented** — the Java acceptance test class (`CorporateFinanceApplicationAcceptanceTest`) has only 3 implemented tests; the remaining are method stubs with comments describing future behavior (document exchange start, customer assignment, mortgage addition, margin definition, conditional offer creation, option setting)

# Document Exchange (DOCX)

> Last updated: 2026-02-14

## Glossary (Ubiquitous Language)

| Term | Definition |
|------|-----------|
| DocumentExchange | Aggregate root for a document exchange session between consultant and customers |
| Document | A file with metadata (type, content, mime type, dates, active/locked flags) |
| DocumentType | Classification of a document with name, designation, and description |
| CustomerDocuments | Per-customer document scope — links a Customer to their set of Documents |
| DocumentExchangeCreator | Abstract creator type — either ConsultantCreator or CustomerDocumentsCreator |
| ConsultantCreator | Creator type when a consultant initiates the exchange |
| CustomerDocumentsCreator | Creator type when a customer initiates the exchange |
| FinanceApplicationDocumentExchange | Document exchange that originates from a FinanceApplication |
| Shared document | Document visible to all customers in the exchange |
| Customer-scoped document | Document visible only to a specific customer |
| Active document | Document visible to customers (inactive documents are hidden until activated) |
| Locked document | Document that cannot be modified; locking triggers customer notification |
| Sealed exchange | Exchange marked as closed; all customers are notified |
| DOCX | Bounded context name for Document Exchange |
| BILA | Balance analysis — triggered when all shown documents are locked |
| WinCube | Document management system — receives documents on BILA trigger |
| KRAN | Credit application processing system — integration target |
| CutoffDate | Bilanzstichtag (balance sheet date) — set when locking a document, needed for WinCube |

---

## Key Type Contracts

### DocumentExchange (Aggregate Root)

| Field | Type | Description |
|-------|------|-------------|
| consultant | Consultant | Assigned consultant (from Finance DSL) |
| customerDocuments | Set&lt;CustomerDocuments&gt; | Per-customer document scopes |
| sealed | boolean | Whether the exchange is closed |
| documents | Set&lt;Document&gt; | Shared documents visible to all customers |
| documentExchangeCreator | DocumentExchangeCreator | Who created the exchange |

### FinanceApplicationDocumentExchange (extends DocumentExchange)

| Field | Type | Description |
|-------|------|-------------|
| financeApplication | FinanceApplication | The originating finance application |

### Document

| Field | Type | Description |
|-------|------|-------------|
| id | String | Unique document identifier |
| type | DocumentType | Classification (WinCube categories) |
| content | byte[] | File content |
| mimeType | String | MIME type (e.g. "application/pdf") |
| name | String | Display name |
| description | String | Document description |
| locked | boolean | Whether document is locked (immutable) |
| active | boolean | Whether document is visible to customers |
| dateOfIssue | LocalDateTime | When the document was issued |
| dateOfExpiry | LocalDateTime | When the document expires |
| dateOfProvision | LocalDateTime | When the document was provided |

### DocumentType

| Field | Type | Description |
|-------|------|-------------|
| name | String | Type name |
| designation | String | Type designation code |
| description | String | Type description |

### CustomerDocuments

| Field | Type | Description |
|-------|------|-------------|
| customer | Customer | The customer this scope belongs to |
| documents | Set&lt;Document&gt; | Documents specific to this customer |

### Creator Hierarchy

| Type | Extends | Description |
|------|---------|-------------|
| DocumentExchangeCreator | — | Abstract base for exchange creators |
| ConsultantCreator | DocumentExchangeCreator | Exchange created by a consultant |
| CustomerDocumentsCreator | DocumentExchangeCreator | Exchange created by a customer |

---

## Acceptance Test Scenarios

```java
class DocumentExchangeAcceptance {

    DocumentExchangeDomainDriver driver;

    Consultant anna = new Consultant();
    Existing   erikExisting = new Existing();
    Prospect   paulaProspect = new Prospect();

    @AfterEach
    void tearDown() { /* if needed: unauthenticate via Finance DSL driver */ }

    // --- Creation from Finance Application — 12 tests ---

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication with no customer yet")
    void startDE_FromFinance_AsConsultant_NoCustomer() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantWithoutCustomer();

        driver.assertDocumentExchangeIsCreated();
        driver.assertDocumentExchangeOriginatesInFinanceApplication();
    }

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication with no customer yet - Participants")
    void startDE_FromFinance_AsConsultant_NoCustomer_participants() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantWithoutCustomer();

        driver.assertDocumentExchangeHasConsultantAssigned();
        driver.assertDocumentExchangeHasNoCustomerAssigned();
    }

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication with no customer yet - Creator")
    void startDE_FromFinance_AsConsultant_NoCustomer_creator() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantWithoutCustomer();

        driver.assertDocumentExchangeCreatorIsConsultant();
    }

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication for an existing customer")
    void startDE_FromFinance_AsConsultant_ForExisting() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantForCustomer();

        driver.assertDocumentExchangeIsCreated();
        driver.assertDocumentExchangeOriginatesInFinanceApplication();
    }

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication for an existing customer - Participants")
    void startDE_FromFinance_AsConsultant_ForExisting_participants() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantForCustomer();

        driver.assertDocumentExchangeHasConsultantAssigned();
        driver.assertDocumentExchangeHasExistingCustomerAssigned();
    }

    @Test
    @DisplayName("Consultant starts DocumentExchange from FinanceApplication for an existing customer - Creator")
    void startDE_FromFinance_AsConsultant_ForExisting_creator() {
        driver.startDocumentExchangeFromFinanceApplicationAsConsultantForCustomer();

        driver.assertDocumentExchangeCreatorIsConsultant();
    }

    @Test
    @DisplayName("Existing customer starts DocumentExchange from FinanceApplication")
    void startDE_FromFinance_AsExistingCustomer() {
        driver.startDocumentExchangeFromFinanceApplicationAsExistingCustomer();

        driver.assertDocumentExchangeIsCreated();
        driver.assertDocumentExchangeOriginatesInFinanceApplication();
    }

    @Test
    @DisplayName("Existing customer starts DocumentExchange from FinanceApplication - Participants")
    void startDE_FromFinance_AsExistingCustomer_participants() {
        driver.startDocumentExchangeFromFinanceApplicationAsExistingCustomer();

        driver.assertDocumentExchangeHasNoConsultantAssigned();
        driver.assertDocumentExchangeHasExistingCustomerAssigned();
    }

    @Test
    @DisplayName("Existing customer starts DocumentExchange from FinanceApplication - Creator")
    void startDE_FromFinance_AsExistingCustomer_creator() {
        driver.startDocumentExchangeFromFinanceApplicationAsExistingCustomer();

        driver.assertDocumentExchangeCreatorIsCustomer();
    }

    @Test
    @DisplayName("Prospect customer starts DocumentExchange from FinanceApplication")
    void startDE_FromFinance_AsProspectCustomer() {
        driver.startDocumentExchangeFromFinanceApplicationAsProspectCustomer();

        driver.assertDocumentExchangeIsCreated();
        driver.assertDocumentExchangeOriginatesInFinanceApplication();
    }

    @Test
    @DisplayName("Prospect customer starts DocumentExchange from FinanceApplication - Participants")
    void startDE_FromFinance_AsProspectCustomer_participants() {
        driver.startDocumentExchangeFromFinanceApplicationAsProspectCustomer();

        driver.assertDocumentExchangeHasNoConsultantAssigned();
        driver.assertDocumentExchangeHasProspectCustomerAssigned();
    }

    @Test
    @DisplayName("Prospect customer starts DocumentExchange from FinanceApplication - Creator")
    void startDE_FromFinance_AsProspectCustomer_creator() {
        driver.startDocumentExchangeFromFinanceApplicationAsProspectCustomer();

        driver.assertDocumentExchangeCreatorIsCustomer();
    }

    // --- Multi-customer association & visibility ---

    @Test
    @DisplayName("Consultant can add an additional existing customer to the DocumentExchange")
    void addAdditionalExistingCustomer() {
        driver.addAdditionalExistingCustomerToDocumentExchange();

        driver.assertDocumentExchangeHasAdditionalExistingCustomerAssigned();
        driver.assertCustomerCanSeeAdditionalExistingCustomerInDocumentExchange();
    }

    @Test
    @DisplayName("Consultant can add an additional prospect customer to the DocumentExchange")
    void addAdditionalProspectCustomer() {
        driver.addAdditionalProspectCustomerToDocumentExchange();

        driver.assertDocumentExchangeHasAdditionalProspectCustomerAssigned();
        // (mirror visibility assertion when DSL exposes it for prospects)
    }

    // --- Documents & per-customer visibility ---

    @Test
    @DisplayName("Consultant adds a document to the DocumentExchange (shared document)")
    void addSharedDocument() {
        driver.addDocumentToDocumentExchange();
        driver.assertDocumentIsAddedToDocumentExchange();
        driver.assertCustomerCanSeeDocumentsInDocumentExchange();
    }

    @Test
    @DisplayName("Consultant adds a document specifically to a given customer - only that customer can see it")
    void addDocumentForSpecificCustomer() {
        driver.addDocumentToCustomerInDocumentExchange();
        driver.assertDocumentIsAddedToCustomerInDocumentExchange();
        driver.assertCustomerCanOnlySeeHisDocumentsInDocumentExchange();
    }

    // --- Document activation lifecycle & notifications ---

    @Test
    @DisplayName("Inactive document is not visible to customers until activated - Inactive state")
    void inactiveThenActivateDocument_inactiveState() {
        driver.addInactiveDocumentToDocumentExchange();

        driver.assertInactiveDocumentIsAddedToDocumentExchange();
        driver.assertInactiveDocumentIsNotShownToCustomer();
    }

    @Test
    @DisplayName("Inactive document is not visible to customers until activated - Activated state")
    void inactiveThenActivateDocument_activatedState() {
        driver.addInactiveDocumentToDocumentExchange();
        driver.activateDocumentInDocumentExchange();

        driver.assertDocumentIsActivatedInDocumentExchange();
        driver.assertDocumentIsShownToCustomerInDocumentExchange();
    }

    @Test
    @DisplayName("Inactive document is not visible to customers until activated - Notification")
    void inactiveThenActivateDocument_notification() {
        driver.addInactiveDocumentToDocumentExchange();
        driver.activateDocumentInDocumentExchange();

        driver.assertCustomerIsNotifiedAboutActivatedDocument();
    }

    @Test
    @DisplayName("Consultant locks a document; customer is notified")
    void lockDocument() {
        driver.lockDocumentInDocumentExchange();
        driver.assertDocumentIsLockedInDocumentExchange();
        driver.assertCustomerIsNotifiedAboutLockedDocument();
    }

    // --- Customer upload & consultant notification ---

    @Test
    @DisplayName("Customer uploads a document; consultant is notified")
    void customerUploads() {
        driver.uploadDocumentToDocumentExchangeAsCustomer();
        driver.assertDocumentIsUploadedToDocumentExchangeAsCustomer();
        driver.assertConsultantIsNotifiedAboutUploadedDocument();
    }

    // --- Seal exchange & notify all customers ---

    @Test
    @DisplayName("Consultant seals the DocumentExchange; all customers are notified")
    void sealExchange() {
        driver.sealDocumentExchange();
        driver.assertDocumentExchangeIsSealed();
        driver.assertCustomersAreNotifiedAboutSealedDocumentExchange();
    }

    // --- Per-customer scoping: add/remove + visibility isolation ----------------

    @Test
    @DisplayName("Customer A sees shared + A-specific docs, but not B-specific docs - Customer A scope")
    void visibilityIsolation_perCustomer_customerA() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Terms.pdf");
        String aSpec  = driver.addDocumentToCustomer("A", "A-IdDocs.pdf");
        String bSpec  = driver.addDocumentToCustomer("B", "B-IdDocs.pdf");

        driver.asCustomer("A").openExchange();

        driver.asCustomer("A").assertVisibleDocumentsAre(shared, aSpec);
        driver.asCustomer("A").assertDocumentNotVisible(bSpec);
    }

    @Test
    @DisplayName("Customer A sees shared + A-specific docs, but not B-specific docs - Customer B scope")
    void visibilityIsolation_perCustomer_customerB() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Terms.pdf");
        String aSpec  = driver.addDocumentToCustomer("A", "A-IdDocs.pdf");
        String bSpec  = driver.addDocumentToCustomer("B", "B-IdDocs.pdf");

        driver.asCustomer("B").openExchange();

        driver.asCustomer("B").assertVisibleDocumentsAre(shared, bSpec);
        driver.asCustomer("B").assertDocumentNotVisible(aSpec);
    }

    @Test
    @DisplayName("Consultant adds/removes a customer-scoped document - Scoped visibility")
    void addRemoveCustomerScopedDocument_scopedVisibility() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-BalanceSheet.pdf");

        driver.asCustomer("A").assertDocumentVisible(aSpec);
        driver.asCustomer("B").assertDocumentNotVisible(aSpec);
    }

    @Test
    @DisplayName("Consultant adds/removes a customer-scoped document - Removed from all parties")
    void addRemoveCustomerScopedDocument_removedFromAllParties() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-BalanceSheet.pdf");
        driver.removeDocumentFromCustomer("A", aSpec);

        driver.asCustomer("A").assertDocumentNotVisible(aSpec);
        driver.asCustomer("B").assertDocumentNotVisible(aSpec);
    }

    @Test
    @DisplayName("Consultant adds/removes a customer-scoped document - Audit trail")
    void addRemoveCustomerScopedDocument_auditTrail() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-BalanceSheet.pdf");
        driver.removeDocumentFromCustomer("A", aSpec);

        driver.asConsultant().assertDocumentNotVisible(aSpec);
        driver.assertAuditTrailContains("DOC_REMOVED_FOR_CUSTOMER", "A", "A-BalanceSheet.pdf");
    }

    @Test
    @DisplayName("Removing a customer-scoped doc does not affect shared or other-customer docs - Customer visibility")
    void removeCustomerDoc_DoesNotAffectOthers_customerVisibility() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Checklist.pdf");
        String aSpec  = driver.addDocumentToCustomer("A", "A-Statement.pdf");
        String bSpec  = driver.addDocumentToCustomer("B", "B-Statement.pdf");

        driver.removeDocumentFromCustomer("A", aSpec);

        driver.asCustomer("A").assertVisibleDocumentsAre(shared);
        driver.asCustomer("B").assertVisibleDocumentsAre(shared, bSpec);
    }

    @Test
    @DisplayName("Removing a customer-scoped doc does not affect shared or other-customer docs - Consultant visibility")
    void removeCustomerDoc_DoesNotAffectOthers_consultantVisibility() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Checklist.pdf");
        String aSpec  = driver.addDocumentToCustomer("A", "A-Statement.pdf");
        String bSpec  = driver.addDocumentToCustomer("B", "B-Statement.pdf");

        driver.removeDocumentFromCustomer("A", aSpec);

        driver.asConsultant().assertVisibleDocumentsInclude(shared, bSpec);
        driver.asConsultant().assertDocumentNotVisible(aSpec);
    }

    @Test
    @DisplayName("Customer cannot see another customer's newly added specific document - Before addition")
    void isolationOnNewAdditions_beforeAddition() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Intro.pdf");

        driver.asCustomer("A").openExchange();

        driver.asCustomer("A").assertVisibleDocumentsAre(shared);
    }

    @Test
    @DisplayName("Customer cannot see another customer's newly added specific document - After addition")
    void isolationOnNewAdditions_afterAddition() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Intro.pdf");

        driver.asCustomer("A").openExchange();

        // Consultant adds B-specific while A is viewing
        String bSpec = driver.addDocumentToCustomer("B", "B-ExtraInfo.pdf");

        driver.asCustomer("A").refreshExchangeView();
        driver.asCustomer("A").assertVisibleDocumentsAre(shared);
        driver.asCustomer("A").assertDocumentNotVisible(bSpec);
    }

    @Test
    @DisplayName("Customer may remove only their own uploads - Own document removed")
    void customerRemoveOwnDocs_ownDocRemoved() {
        driver.createExchangeWithTwoCustomersAandB();
        String aOwn = driver.asCustomer("A").uploadDocument("A-OwnUpload.pdf");

        driver.asCustomer("A").removeOwnDocument(aOwn);

        driver.asCustomer("A").assertDocumentNotVisible(aOwn);
    }

    @Test
    @DisplayName("Customer may remove only their own uploads - Forbidden on other customers' docs")
    void customerRemoveOwnDocs_forbiddenOnOthers() {
        driver.createExchangeWithTwoCustomersAandB();
        String bOwn = driver.asCustomer("B").uploadDocument("B-OwnUpload.pdf");

        driver.asCustomer("A").attemptRemoveDocument(bOwn);

        driver.asCustomer("A").assertOperationRejected("FORBIDDEN");
        driver.asCustomer("B").assertDocumentVisible(bOwn);
    }

    @Test
    @DisplayName("Consultant cannot remove a shared doc scoped to all if document is locked")
    void consultantCannotRemoveLockedSharedDoc() {
        driver.createExchangeWithTwoCustomersAandB();
        String shared = driver.addSharedDocument("Offer.pdf");

        driver.lockDocument(shared);
        driver.asConsultant().attemptRemoveSharedDocument(shared);
        driver.assertOperationRejected("DOC_LOCKED");

        // Unlock then remove succeeds
        driver.unlockDocument(shared);
        driver.asConsultant().removeSharedDocument(shared);
        driver.assertAuditTrailContains("DOC_REMOVED_SHARED", "Offer.pdf");
    }

    @Test
    @DisplayName("Switching document scope: from shared to customer A only - Visibility")
    void switchScope_sharedToCustomer() {
        driver.createExchangeWithTwoCustomersAandB();
        String doc = driver.addSharedDocument("DraftOffer.pdf");

        driver.changeDocumentScopeToCustomer("A", doc);

        driver.asCustomer("A").assertDocumentVisible(doc);
        driver.asCustomer("B").assertDocumentNotVisible(doc);
    }

    @Test
    @DisplayName("Switching document scope: from shared to customer A only - Audit trail")
    void switchScope_sharedToCustomer_auditTrail() {
        driver.createExchangeWithTwoCustomersAandB();
        String doc = driver.addSharedDocument("DraftOffer.pdf");

        driver.changeDocumentScopeToCustomer("A", doc);

        driver.assertAuditTrailContains("DOC_SCOPE_CHANGED", "SHARED", "CUSTOMER_A", "DraftOffer.pdf");
    }

    @Test
    @DisplayName("Switching document scope: from customer A to shared - Shared visibility")
    void switchScope_customerToShared() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-Guarantee.pdf");

        driver.changeDocumentScopeToShared(aSpec);

        driver.asCustomer("A").assertDocumentVisible(aSpec);
        driver.asCustomer("B").assertDocumentVisible(aSpec);
    }

    @Test
    @DisplayName("Switching document scope: from customer A to shared - Isolation maintained")
    void switchScope_customerToShared_isolationMaintained() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-Guarantee.pdf");

        driver.changeDocumentScopeToShared(aSpec);

        // Other customer-specific docs remain hidden to A
        String bSpec = driver.addDocumentToCustomer("B", "B-Collateral.pdf");
        driver.asCustomer("A").assertDocumentNotVisible(bSpec);
    }

    @Test
    @DisplayName("Removing a customer hides their scoped docs from everyone - Visibility after removal")
    void removingCustomerHidesTheirDocs_visibility() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-Private.pdf");
        String shared = driver.addSharedDocument("Welcome.pdf");

        driver.removeCustomerFromExchange("A");

        driver.asConsultant().assertDocumentNotVisible(aSpec);
        driver.asCustomer("B").assertDocumentVisible(shared);
    }

    @Test
    @DisplayName("Removing a customer hides their scoped docs from everyone - Audit trail")
    void removingCustomerHidesTheirDocs_auditTrail() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpec = driver.addDocumentToCustomer("A", "A-Private.pdf");
        String shared = driver.addSharedDocument("Welcome.pdf");

        driver.removeCustomerFromExchange("A");

        driver.assertAuditTrailContains("CUSTOMER_REMOVED", "A");
        driver.assertAuditTrailContains("DOCS_HIDDEN_FOR_REMOVED_CUSTOMER", "A");
    }

    @Test
    @DisplayName("Replacing a customer-scoped document preserves scope - Version replaced")
    void replaceCustomerScopedDocument_PreservesScope_versionReplaced() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpecV1 = driver.addDocumentToCustomer("A", "A-FS-v1.pdf");

        String aSpecV2 = driver.replaceCustomerDocument("A", aSpecV1, "A-FS-v2.pdf");

        driver.asCustomer("A").assertDocumentVisible(aSpecV2);
        driver.asCustomer("A").assertDocumentNotVisible(aSpecV1);
    }

    @Test
    @DisplayName("Replacing a customer-scoped document preserves scope - Isolation and audit")
    void replaceCustomerScopedDocument_PreservesScope_isolationAndAudit() {
        driver.createExchangeWithTwoCustomersAandB();
        String aSpecV1 = driver.addDocumentToCustomer("A", "A-FS-v1.pdf");

        String aSpecV2 = driver.replaceCustomerDocument("A", aSpecV1, "A-FS-v2.pdf");

        driver.asCustomer("B").assertDocumentNotVisible(aSpecV2);
        driver.assertAuditTrailContains("DOC_REPLACED_FOR_CUSTOMER", "A", "A-FS-v1.pdf", "A-FS-v2.pdf");
    }
}
```

### 42 Tests in 7 Categories

#### 1) Creation from Finance Application — 12 tests

- **startDE_FromFinance_AsConsultant_NoCustomer** — Exchange is created and originates in a FinanceApplication.
- **startDE_FromFinance_AsConsultant_NoCustomer_participants** — Consultant is assigned, no customer yet.
- **startDE_FromFinance_AsConsultant_NoCustomer_creator** — Creator is recorded as consultant.
- **startDE_FromFinance_AsConsultant_ForExisting** — Exchange is created and originates in a FinanceApplication.
- **startDE_FromFinance_AsConsultant_ForExisting_participants** — Consultant and existing customer are both assigned.
- **startDE_FromFinance_AsConsultant_ForExisting_creator** — Creator is recorded as consultant.
- **startDE_FromFinance_AsExistingCustomer** — Exchange is created and originates in a FinanceApplication.
- **startDE_FromFinance_AsExistingCustomer_participants** — No consultant assigned, existing customer is assigned.
- **startDE_FromFinance_AsExistingCustomer_creator** — Creator is recorded as customer.
- **startDE_FromFinance_AsProspectCustomer** — Exchange is created and originates in a FinanceApplication.
- **startDE_FromFinance_AsProspectCustomer_participants** — No consultant assigned, prospect customer is assigned.
- **startDE_FromFinance_AsProspectCustomer_creator** — Creator is recorded as customer.

#### 2) Multi-customer association & visibility — 2 tests

- **addAdditionalExistingCustomer** — A consultant adds another existing customer into the same exchange, and customers can see the extra participant.
- **addAdditionalProspectCustomer** — A consultant adds a prospect customer to the exchange, preparing the ground for multi-party collaboration.

#### 3) Documents & per-customer visibility — 2 tests

- **addSharedDocument** — A consultant adds a shared document; it's visible to all linked customers.
- **addDocumentForSpecificCustomer** — A consultant adds a document targeted to one customer; only that customer sees it, proving per-customer scoping.

#### 4) Document activation lifecycle & notifications — 4 tests

- **inactiveThenActivateDocument_inactiveState** — An inactive document is added to the exchange and is not shown to the customer.
- **inactiveThenActivateDocument_activatedState** — Once activated, the document becomes visible to the customer.
- **inactiveThenActivateDocument_notification** — Activation triggers a customer notification.
- **lockDocument** — A consultant locks a document, preventing changes, and the customer is notified of the lock.

#### 5) Customer upload & consultant notification — 1 test

- **customerUploads** — A customer uploads a document to the exchange; the upload is recorded and the consultant is notified.

#### 6) Seal exchange & notify all customers — 1 test

- **sealExchange** — A consultant seals the exchange, marking it closed and notifying all customers involved.

#### 7) Per-customer scoping & visibility isolation — 20 tests

- **visibilityIsolation_perCustomer_customerA** — Customer A sees shared and A-specific documents, but not B-specific documents.
- **visibilityIsolation_perCustomer_customerB** — Customer B sees shared and B-specific documents, but not A-specific documents.
- **addRemoveCustomerScopedDocument_scopedVisibility** — A customer-scoped document is visible to that customer and hidden from others.
- **addRemoveCustomerScopedDocument_removedFromAllParties** — After removal, the customer-scoped document is not visible to any customer.
- **addRemoveCustomerScopedDocument_auditTrail** — Removal is recorded in the audit trail and the consultant no longer sees the document.
- **removeCustomerDoc_DoesNotAffectOthers_customerVisibility** — Removing a customer-scoped document preserves shared and other customers' documents for customers.
- **removeCustomerDoc_DoesNotAffectOthers_consultantVisibility** — Removing a customer-scoped document preserves shared and other customers' documents for the consultant.
- **isolationOnNewAdditions_beforeAddition** — Before a B-specific document is added, Customer A sees only shared documents.
- **isolationOnNewAdditions_afterAddition** — After a B-specific document is added, Customer A still sees only shared documents.
- **customerRemoveOwnDocs_ownDocRemoved** — A customer can remove their own uploaded document.
- **customerRemoveOwnDocs_forbiddenOnOthers** — A customer is forbidden from removing another customer's document; the other customer still sees it.
- **consultantCannotRemoveLockedSharedDoc** — A locked shared document cannot be removed until unlocked; once unlocked, removal succeeds with audit trail.
- **switchScope_sharedToCustomer** — Changing scope from shared to customer A restricts visibility to A only.
- **switchScope_sharedToCustomer_auditTrail** — Scope change from shared to customer is recorded in the audit trail.
- **switchScope_customerToShared** — Changing scope from customer A to shared makes the document visible to all customers.
- **switchScope_customerToShared_isolationMaintained** — After scope change to shared, other customer-specific documents remain isolated.
- **removingCustomerHidesTheirDocs_visibility** — Removing a customer hides their scoped documents; shared documents remain visible.
- **removingCustomerHidesTheirDocs_auditTrail** — Customer removal and document hiding are recorded in the audit trail.
- **replaceCustomerScopedDocument_PreservesScope_versionReplaced** — Replacing a customer-scoped document shows the new version and hides the old.
- **replaceCustomerScopedDocument_PreservesScope_isolationAndAudit** — Replacement preserves customer scope isolation and is recorded in the audit trail.

---

## DSL Model

### DocumentExchangeDomainSpecificLanguage (Base Interface)

```java
interface DocumentExchangeDomainSpecificLanguage {
    // --- Creation (4 variants) ---
    void startDocumentExchangeFromFinanceApplicationAsConsultantWithoutCustomer();
    void startDocumentExchangeFromFinanceApplicationAsConsultantForCustomer();
    void startDocumentExchangeFromFinanceApplicationAsExistingCustomer();
    void startDocumentExchangeFromFinanceApplicationAsProspectCustomer();

    // --- Creation assertions ---
    void assertDocumentExchangeIsCreated();
    void assertDocumentExchangeOriginatesInFinanceApplication();
    void assertDocumentExchangeHasNoConsultantAssigned();
    void assertDocumentExchangeHasNoCustomerAssigned();
    void assertDocumentExchangeHasConsultantAssigned();
    void assertDocumentExchangeHasExistingCustomerAssigned();
    void assertDocumentExchangeHasProspectCustomerAssigned();
    void assertDocumentExchangeCreatorIsConsultant();
    void assertDocumentExchangeCreatorIsCustomer();

    // --- Multi-customer management ---
    void addAdditionalExistingCustomerToDocumentExchange();
    void assertDocumentExchangeHasAdditionalExistingCustomerAssigned();
    void assertCustomerCanSeeAdditionalExistingCustomerInDocumentExchange();
    void addAdditionalProspectCustomerToDocumentExchange();
    void assertDocumentExchangeHasAdditionalProspectCustomerAssigned();
    void assertCustomerCanSeeAdditionalProspectCustomerInDocumentExchange();
    void assertCustomerIsNotifiedAboutAdditionalCustomerInDocumentExchange();
    void removeAdditionalCustomerFromDocumentExchange();
    void assertAdditionalCustomerIsRemovedFromDocumentExchange();
    void assertCustomerIsNotifiedAboutRemovedAdditionalCustomer();

    // --- Document management ---
    void addDocumentToDocumentExchange();
    void assertDocumentIsAddedToDocumentExchange();
    void addDocumentToCustomerInDocumentExchange();
    void assertDocumentIsAddedToCustomerInDocumentExchange();
    void assertCustomerCanSeeDocumentsInDocumentExchange();
    void assertCustomerCanOnlySeeHisDocumentsInDocumentExchange();

    // --- Activation / deactivation ---
    void addInactiveDocumentToDocumentExchange();
    void assertInactiveDocumentIsAddedToDocumentExchange();
    void assertInactiveDocumentIsNotShownToCustomer();
    void activateDocumentInDocumentExchange();
    void assertDocumentIsActivatedInDocumentExchange();
    void assertDocumentIsShownToCustomerInDocumentExchange();
    void assertCustomerIsNotifiedAboutActivatedDocument();

    // --- Locking ---
    void lockDocumentInDocumentExchange();
    void assertDocumentIsLockedInDocumentExchange();
    void assertCustomerIsNotifiedAboutLockedDocument();

    // --- Upload ---
    void uploadDocumentToDocumentExchangeAsCustomer();
    void assertDocumentIsUploadedToDocumentExchangeAsCustomer();
    void assertConsultantIsNotifiedAboutUploadedDocument();

    // --- Seal ---
    void sealDocumentExchange();
    void assertDocumentExchangeIsSealed();
    void assertCustomersAreNotifiedAboutSealedDocumentExchange();
}
```

### DocumentExchangeDomainDriver (Extended — used in pseudocode tests)

```java
interface DocumentExchangeDomainDriver extends DocumentExchangeDomainSpecificLanguage {
    // --- Multi-customer exchange setup ---
    void createExchangeWithTwoCustomersAandB();

    // --- Shared document management ---
    String addSharedDocument(String name);
    void removeDocumentFromCustomer(String customer, String docId);
    void removeCustomerFromExchange(String customer);

    // --- Customer-scoped document management ---
    String addDocumentToCustomer(String customer, String name);
    String replaceCustomerDocument(String customer, String oldDocId, String newName);

    // --- Scope switching ---
    void changeDocumentScopeToCustomer(String customer, String docId);
    void changeDocumentScopeToShared(String docId);

    // --- Locking / unlocking ---
    void lockDocument(String docId);
    void unlockDocument(String docId);

    // --- Role-scoped view (returns a CustomerView or ConsultantView) ---
    CustomerView asCustomer(String customerId);
    ConsultantView asConsultant();

    // --- Assertions ---
    void assertAuditTrailContains(String event, String... details);
    void assertOperationRejected(String reason);

    // --- CustomerView (role-scoped operations) ---
    interface CustomerView {
        void openExchange();
        void refreshExchangeView();
        String uploadDocument(String name);
        void removeOwnDocument(String docId);
        void attemptRemoveDocument(String docId);

        void assertVisibleDocumentsAre(String... docIds);
        void assertVisibleDocumentsInclude(String... docIds);
        void assertDocumentVisible(String docId);
        void assertDocumentNotVisible(String docId);
        void assertOperationRejected(String reason);
    }

    // --- ConsultantView (role-scoped operations) ---
    interface ConsultantView {
        void attemptRemoveSharedDocument(String docId);
        void removeSharedDocument(String docId);

        void assertVisibleDocumentsInclude(String... docIds);
        void assertDocumentVisible(String docId);
        void assertDocumentNotVisible(String docId);
    }
}
```

---

## Architecture Notes

- **DOCX is a bounded context** for managing document exchange between consultants and customers, separate from but closely linked to COLE (Corporate Finance Application)
- **DocumentExchange always originates from a FinanceApplication** — when a finance application is created, its associated document exchange starts automatically
- **Per-customer document scoping** is a core concept — each customer in a multi-party exchange sees only shared documents and their own customer-scoped documents
- **Dual visibility model**: shared documents (visible to all) vs. customer-scoped documents (visible only to one customer)
- **Document lifecycle**: Inactive → Active (visible to customer) → Locked (immutable, with CutoffDate)
- **Notification pattern**: Status changes trigger notifications between consultant and customer(s) — activation, locking, upload, and sealing all produce notifications
- **Status: specification stage** — only dummy drivers are implemented; no production domain or controller drivers yet

### Integration Points

| System | Purpose |
|--------|---------|
| WinCube | Document management — receives locked documents when BILA is triggered; document types use WinCube categories |
| KRAN | Credit application processing — receives data when documents are finalized |
| BILA | Balance analysis — triggered when all shown (active) documents are locked; sends to WinCube + triggers "Zentraler Auftrag" |
| VERA | Webhook notifications (potential integration) |

### Relationship to COLE

- COLE (FinanceApplication) determines which documents are required in DOCX
- Document requirements are driven by: finance product type, loan amount, collateral type, and consultant option selections
- The COLE bounded context options (Bilanzierer/Einnahmen-Ausgaben-Rechner, insurance type, collateral categories) control which documents appear in DOCX
- BILA trigger in DOCX feeds back into the COLE workflow

### Multi-Customer Model

```
DocumentExchange
├── Consultant (1)
├── Shared Documents (visible to all customers)
├── CustomerDocuments[Customer A]
│   └── Documents (visible only to A + consultant)
├── CustomerDocuments[Customer B]
│   └── Documents (visible only to B + consultant)
└── Sealed flag
```

Visibility rules:
- Customer A sees: shared documents + A's customer-scoped documents
- Customer B sees: shared documents + B's customer-scoped documents
- Consultant sees: all documents (shared + all customer-scoped)
- Removing a customer hides their scoped documents from everyone (preserved in audit trail)

---

## Gotchas / Notes

- **BILA trigger** — as soon as all shown (active) documents are locked, BILA (balance analysis) is activated; this sends documents to WinCube and triggers customer data entry in "Zentraler Auftrag (AM Workflow)"
- **WinCube/KRAN integration** — documents flagged for financing application create entries in both WinCube and KRAN; KRAN is a "real" API integration
- **CutoffDate (Bilanzstichtag)** — when locking a document, a cutoff date and additional text can be set; this metadata is transferred to WinCube annotations
- **Multi-user authorization** — supports scenarios like "assistant uploads documents, managing director signs"; different access levels (read, upload) are configurable by the customer, with signing rights tied to signatory authority
- **GDPR 6-month deletion** — if a process is inactive for 6 months, a warning email is sent 2 weeks before automatic deletion within the GDPR retention period
- **Per-customer document isolation is real-time** — if a consultant adds a document for Customer B while Customer A is viewing, A will not see B's document even after refreshing
- **Locked documents cannot be removed** — attempting to remove a locked shared document is rejected with "DOC_LOCKED"; the document must be unlocked first
- **Document scope switching** — documents can be re-scoped from shared to customer-specific (and vice versa); audit trail records all scope changes
- **Customer removal hides documents** — removing a customer from the exchange hides their scoped documents from everyone, but preserves them in the audit trail
- **Document versioning** — replacing a customer-scoped document preserves the scope; the old version becomes invisible while the new version inherits the customer scope
- **Currently 7 systems involved** in corporate finance processing — DOCX aims to serve as the unified document exchange platform
- **Desired future capabilities** (from stakeholder feedback): simultaneous editing (SSE), parent/subsidiary company document linking, AI document reading, ID Austria for digital signatures, business-independent document collection, re-targeting notifications for inactive customers

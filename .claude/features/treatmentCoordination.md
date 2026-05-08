# Treatment Coordination (TACO)

> Last updated: 2026-02-14

## Glossary (Ubiquitous Language)

| Term | Definition |
|------|-----------|
| TreatmentCoordination | Aggregate root representing the active coordination overlay for a single Case — manages who does what, when, and in what order across providers and patient |
| Referral | A request from the coordinating provider (typically the Traumatologist) to another provider (Therapist, Radiologist) specifying the service type, timing constraints, and clinical instructions |
| ReferralResponse | Value object capturing a provider's answer to a Referral — acceptance, decline, or counter-proposal with alternative dates/duration |
| CoordinationTimeline | Read model projection computed from Referrals, Appointments, and Duties — never stored directly, always assembled on read |
| Appointment | A scheduled treatment session between a provider and the patient, linked to an accepted Referral |
| PatientDuty | A task assigned to the patient by a provider (exercises, restrictions, preparation instructions) with optional recurrence |
| Reminder | A notification instance generated for a PatientDuty — one per occurrence for recurring duties, delivered until the duty is marked complete |
| ProviderRole | Classification of a provider's function within the coordination: TRAUMATOLOGIST (coordinating), THERAPIST, or RADIOLOGIST |
| CoordinationParticipant | Value object linking a provider or patient to a TreatmentCoordination with their role and join timestamp |
| Milestone | A significant target date on the CoordinationTimeline — derived from Referral requested dates, Appointment scheduled dates, and duty deadlines |
| Escalation | Domain event raised when a Referral response deadline expires (default: 48 business hours) — triggers notification to the coordinating provider |

---

## Key Type Contracts

### TreatmentCoordination (Entity — Aggregate Root)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| caseId | String | Required, immutable — reference to the Case bounded context |
| status | CoordinationStatus | ACTIVE, COMPLETED, CANCELLED |
| coordinatingProviderId | String | Required — the provider who initiated the coordination |
| participants | Set&lt;CoordinationParticipant&gt; | At least one (the coordinating provider) |
| referrals | Set&lt;Referral&gt; | Zero or more |
| appointments | Set&lt;Appointment&gt; | Zero or more |
| duties | Set&lt;PatientDuty&gt; | Zero or more |
| createdAt | Instant | Required, immutable |

### CoordinationParticipant (Value Object)

| Field | Type | Constraints |
|-------|------|-------------|
| userId | String | Required — provider ID or patient ID |
| role | ParticipantRole | COORDINATING_PROVIDER, REFERRED_PROVIDER, PATIENT |
| providerRole | ProviderRole | TRAUMATOLOGIST, THERAPIST, RADIOLOGIST — null for patients |
| joinedAt | Instant | Required, immutable |

### Referral (Entity)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| coordinationId | String | Required |
| fromProviderId | String | Required — coordinating provider |
| toProviderId | String | Required — target provider |
| serviceType | ServiceType | PHYSICAL_THERAPY, RADIOLOGY |
| requestedStartDate | LocalDate | Required |
| requestedDuration | Duration | Optional — null for single-visit referrals |
| clinicalInstructions | String | Free text — anti-corruption layer to Case clinical data |
| status | ReferralStatus | PENDING, ACCEPTED, DECLINED, COUNTER_PROPOSED, CANCELLED |
| response | ReferralResponse | Null until provider responds |
| responseDeadline | Instant | Default: createdAt + 48 business hours |
| createdAt | Instant | Required, immutable |

### ReferralResponse (Value Object)

| Field | Type | Constraints |
|-------|------|-------------|
| type | ResponseType | ACCEPTED, DECLINED, COUNTER_PROPOSED |
| proposedStartDate | LocalDate | Required for COUNTER_PROPOSED, null otherwise |
| proposedDuration | Duration | Optional — only for COUNTER_PROPOSED |
| reason | String | Optional — explanation for decline or counter-proposal |
| respondedAt | Instant | Required |

### Appointment (Entity)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| referralId | String | Required — link to accepted Referral |
| providerId | String | Required |
| patientId | String | Required |
| scheduledAt | Instant | Required |
| duration | Duration | Required |
| status | AppointmentStatus | SCHEDULED, COMPLETED, CANCELLED |
| notes | String | Optional — provider notes after completion |
| createdAt | Instant | Required, immutable |

### PatientDuty (Entity)

| Field | Type | Constraints |
|-------|------|-------------|
| id | String | Required, immutable |
| coordinationId | String | Required |
| assignedByProviderId | String | Required — only providers can assign duties |
| patientId | String | Required |
| description | String | Required — exercise, restriction, or preparation instruction |
| recurrence | Recurrence | DAILY, WEEKLY, NONE |
| startDate | LocalDate | Required |
| endDate | LocalDate | Optional — null for ongoing duties |
| status | DutyStatus | ACTIVE, COMPLETED, CANCELLED |
| completions | List&lt;DutyCompletion&gt; | Timestamped completion records by patient |

### Reminder (Value Object)

| Field | Type | Constraints |
|-------|------|-------------|
| dutyId | String | Required |
| scheduledAt | Instant | Required |
| deliveredAt | Instant | Null until delivered |
| type | ReminderType | DUTY_REMINDER, APPOINTMENT_REMINDER |

### Milestone (Value Object)

| Field | Type | Constraints |
|-------|------|-------------|
| label | String | Required — human-readable description |
| targetDate | LocalDate | Required |
| referralId | String | Optional — link to originating Referral |
| type | MilestoneType | THERAPY_START, CONTROL_EXAMINATION, THERAPY_END, APPOINTMENT |

### Cause/Effect Events

| Cause | Effect | Entity |
|-------|--------|--------|
| StartCoordination | CoordinationStarted | TreatmentCoordination |
| CreateReferral | ReferralCreated | TreatmentCoordination |
| RespondToReferral | ReferralResponseRecorded | TreatmentCoordination |
| CancelReferral | ReferralCancelled | TreatmentCoordination |
| ScheduleAppointment | AppointmentScheduled | TreatmentCoordination |
| CompleteAppointment | AppointmentCompleted | TreatmentCoordination |
| CancelAppointment | AppointmentCancelled | TreatmentCoordination |
| AssignPatientDuty | PatientDutyAssigned | TreatmentCoordination |
| CompletePatientDuty | PatientDutyCompleted | TreatmentCoordination |
| EscalateReferral | ReferralEscalated | TreatmentCoordination |
| CompleteCoordination | CoordinationCompleted | TreatmentCoordination |
| CancelCoordination | CoordinationCancelled | TreatmentCoordination |

---

## Acceptance Test Scenarios

```java
@DisplayName("Treatment Coordination (TACO) — Acceptance (ATDD/Spec)")
class TreatmentCoordinationAcceptance {

    TreatmentCoordinationDriver driver;

    // --- Providers ---
    Provider drMueller = new Provider("dr.mueller@hospital.example", "Dr. Mueller", TRAUMATOLOGIST);
    Provider lisaTherapist = new Provider("lisa@physio.example", "Lisa Therapist", THERAPIST);
    Provider markRadiologist = new Provider("mark@radiology.example", "Mark Radiologist", RADIOLOGIST);
    Provider unrelatedProvider = new Provider("other@clinic.example", "Other Provider", TRAUMATOLOGIST);

    // --- Patient ---
    Patient hannahPatient = new Patient("hannah@patient.example", "Hannah Patient");

    // --- Shared test data ---
    String existingCaseId = "case-fracture-001";

    // =========================================================================
    // a) Case & Referral Creation (traumatologist) — 11 tests
    // =========================================================================

    @Test
    @DisplayName("Traumatologist starts a treatment coordination from an existing case - Creation identity")
    void traumatologistStartsCoordinationFromCase_creationIdentity() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.assertCoordinationIsCreated(coordinationId);
        driver.assertCoordinationIsLinkedToCase(coordinationId, existingCaseId);
    }

    @Test
    @DisplayName("Traumatologist starts a treatment coordination from an existing case - Status and provider")
    void traumatologistStartsCoordinationFromCase_statusAndProvider() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.assertCoordinationStatusIs(coordinationId, ACTIVE);
        driver.assertCoordinatingProviderIs(coordinationId, drMueller);
    }

    @Test
    @DisplayName("Traumatologist starts a treatment coordination from an existing case - Participant count")
    void traumatologistStartsCoordinationFromCase_participantCount() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.assertParticipantCount(coordinationId, 1);
    }

    @Test
    @DisplayName("Traumatologist creates a therapy referral with timing constraints")
    void traumatologistCreatesTherapyReferral() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90))
                .withClinicalInstructions("Post-fracture rehabilitation, focus on range of motion"));

        driver.assertReferralIsCreated(referralId);
        driver.assertReferralStatusIs(referralId, PENDING);
    }

    @Test
    @DisplayName("Traumatologist creates a therapy referral with timing constraints - Service type and deadline")
    void traumatologistCreatesTherapyReferral_serviceTypeAndDeadline() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90))
                .withClinicalInstructions("Post-fracture rehabilitation, focus on range of motion"));

        driver.assertReferralServiceTypeIs(referralId, PHYSICAL_THERAPY);
        driver.assertReferralHasResponseDeadline(referralId);
    }

    @Test
    @DisplayName("Traumatologist creates a therapy referral with timing constraints - Notification")
    void traumatologistCreatesTherapyReferral_notification() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90))
                .withClinicalInstructions("Post-fracture rehabilitation, focus on range of motion"));

        driver.assertProviderIsNotified(lisaTherapist, "NEW_REFERRAL");
    }

    @Test
    @DisplayName("Traumatologist creates a radiology referral for control examination")
    void traumatologistCreatesRadiologyReferral() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6))
                .withClinicalInstructions("Control X-ray, check fracture healing"));

        driver.assertReferralIsCreated(referralId);
        driver.assertReferralStatusIs(referralId, PENDING);
    }

    @Test
    @DisplayName("Traumatologist creates a radiology referral for control examination - Service type")
    void traumatologistCreatesRadiologyReferral_serviceType() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6))
                .withClinicalInstructions("Control X-ray, check fracture healing"));

        driver.assertReferralServiceTypeIs(referralId, RADIOLOGY);
    }

    @Test
    @DisplayName("Traumatologist creates therapy + radiology referrals — timeline shows both milestones")
    void traumatologistCreatesMultipleReferrals() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        driver.addPatientToCoordination(coordinationId, hannahPatient);

        // Therapy referral: start in 1 week, duration 3 months
        String therapyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90))
                .withClinicalInstructions("Post-fracture rehabilitation"));

        // Radiology referral: control in 6 weeks
        String radiologyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6))
                .withClinicalInstructions("Control X-ray"));

        driver.assertTimelineContainsMilestone(coordinationId, "Therapy Start", now().plusWeeks(1));
        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(6));
    }

    @Test
    @DisplayName("Traumatologist creates therapy + radiology referrals — milestone count")
    void traumatologistCreatesMultipleReferrals_milestoneCount() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        driver.addPatientToCoordination(coordinationId, hannahPatient);

        String therapyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90))
                .withClinicalInstructions("Post-fracture rehabilitation"));

        String radiologyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6))
                .withClinicalInstructions("Control X-ray"));

        driver.assertTimelineMilestoneCount(coordinationId, 2);
    }

    @Test
    @DisplayName("Non-participant provider cannot view coordination — FORBIDDEN")
    void nonParticipantProviderCannotViewCoordination() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.loginAsProvider(unrelatedProvider);
        driver.attemptViewCoordination(coordinationId);
        driver.assertOperationRejected("FORBIDDEN");
    }

    // =========================================================================
    // b) Multi-Provider Coordination (cross-perspective) — 11 tests
    // =========================================================================

    @Test
    @DisplayName("Therapist accepts referral - Referral accepted")
    void therapistAcceptsReferral_referralAccepted() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(referralId, ReferralResponse.accept());

        driver.assertReferralStatusIs(referralId, ACCEPTED);
    }

    @Test
    @DisplayName("Therapist accepts referral - Participant added")
    void therapistAcceptsReferral_participantAdded() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(referralId, ReferralResponse.accept());

        driver.assertParticipantIncludes(coordinationId, lisaTherapist);
    }

    @Test
    @DisplayName("Therapist accepts referral - Notification")
    void therapistAcceptsReferral_notification() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(referralId, ReferralResponse.accept());

        driver.assertProviderIsNotified(drMueller, "REFERRAL_ACCEPTED");
    }

    @Test
    @DisplayName("Therapist declines referral - Referral declined")
    void therapistDeclinesReferral_referralDeclined() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(referralId, ReferralResponse.decline("Fully booked for next 3 months"));

        driver.assertReferralStatusIs(referralId, DECLINED);
    }

    @Test
    @DisplayName("Therapist declines referral - Notification")
    void therapistDeclinesReferral_notification() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(referralId, ReferralResponse.decline("Fully booked for next 3 months"));

        driver.assertProviderIsNotified(drMueller, "REFERRAL_DECLINED");
    }

    @Test
    @DisplayName("Radiologist counter-proposes date - Referral status")
    void radiologistCounterProposesDate_referralStatus() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(referralId, ReferralResponse.counterPropose(now().plusWeeks(7), "Earlier slot unavailable"));

        driver.assertReferralStatusIs(referralId, COUNTER_PROPOSED);
    }

    @Test
    @DisplayName("Radiologist counter-proposes date - Timeline updated")
    void radiologistCounterProposesDate_timelineUpdated() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(referralId, ReferralResponse.counterPropose(now().plusWeeks(7), "Earlier slot unavailable"));

        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(7));
    }

    @Test
    @DisplayName("Radiologist counter-proposes date - Notification")
    void radiologistCounterProposesDate_notification() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(referralId, ReferralResponse.counterPropose(now().plusWeeks(7), "Earlier slot unavailable"));

        driver.assertProviderIsNotified(drMueller, "REFERRAL_COUNTER_PROPOSED");
    }

    @Test
    @DisplayName("Referral response overdue after 48 business hours - Escalation event")
    void referralResponseDeadlineEscalation_escalationEvent() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.fastForwardBusinessHours(48);

        driver.assertEscalationEventRaised(referralId, "RESPONSE_OVERDUE");
    }

    @Test
    @DisplayName("Referral response overdue after 48 business hours - Notification")
    void referralResponseDeadlineEscalation_notification() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.fastForwardBusinessHours(48);

        driver.assertProviderIsNotified(drMueller, "REFERRAL_ESCALATED");
    }

    @Test
    @DisplayName("Coordination cannot complete while referrals are still pending")
    void coordinationCannotCompleteWithPendingReferrals() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1)));

        driver.attemptCompleteCoordination(coordinationId);
        driver.assertOperationRejected("PENDING_REFERRALS_EXIST");
        driver.assertCoordinationStatusIs(coordinationId, ACTIVE);
    }

    // =========================================================================
    // c) Therapy Coordination (therapist) — 9 tests
    // =========================================================================

    @Test
    @DisplayName("Therapist schedules appointment after accepting referral")
    void therapistSchedulesAppointmentAfterAccepting() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.assertAppointmentIsCreated(appointmentId);
        driver.assertAppointmentStatusIs(appointmentId, SCHEDULED);
    }

    @Test
    @DisplayName("Therapist schedules appointment after accepting referral - Notification")
    void therapistSchedulesAppointmentAfterAccepting_notification() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.assertPatientIsNotified(hannahPatient, "NEW_APPOINTMENT");
    }

    @Test
    @DisplayName("Therapist schedules recurring appointments for therapy duration")
    void therapistSchedulesRecurringAppointments() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        List<String> appointmentIds = driver.scheduleRecurringAppointments(referralId, new RecurringAppointmentRequest()
                .withPatient(hannahPatient)
                .withStartDate(now().plusWeeks(1))
                .withRecurrence(WEEKLY)
                .withCount(12)
                .withDuration(Duration.ofMinutes(45)));

        driver.assertAppointmentCount(referralId, 12);
        driver.assertAllAppointmentsStatusIs(appointmentIds, SCHEDULED);
    }

    @Test
    @DisplayName("Therapist assigns patient duty with daily recurrence")
    void therapistAssignsPatientDuty() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Knee flexion exercises: 3 sets of 10 repetitions")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusWeeks(4)));

        driver.assertDutyIsCreated(dutyId);
        driver.assertDutyStatusIs(dutyId, ACTIVE);
    }

    @Test
    @DisplayName("Therapist assigns patient duty with daily recurrence - Notification")
    void therapistAssignsPatientDuty_notification() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Knee flexion exercises: 3 sets of 10 repetitions")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusWeeks(4)));

        driver.assertPatientIsNotified(hannahPatient, "NEW_DUTY");
    }

    @Test
    @DisplayName("Therapist cancels appointment - Status")
    void therapistCancelsAppointment_status() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.cancelAppointment(appointmentId);

        driver.assertAppointmentStatusIs(appointmentId, CANCELLED);
    }

    @Test
    @DisplayName("Therapist cancels appointment - Notification")
    void therapistCancelsAppointment_notification() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.cancelAppointment(appointmentId);

        driver.assertPatientIsNotified(hannahPatient, "APPOINTMENT_CANCELLED");
    }

    @Test
    @DisplayName("Therapist completes appointment - Status")
    void therapistCompletesAppointment_status() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.completeAppointment(appointmentId, "Good range of motion improvement, continue current plan");

        driver.assertAppointmentStatusIs(appointmentId, COMPLETED);
    }

    @Test
    @DisplayName("Therapist completes appointment - Notes recorded")
    void therapistCompletesAppointment_notesRecorded() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.completeAppointment(appointmentId, "Good range of motion improvement, continue current plan");

        driver.assertAppointmentNotesContain(appointmentId, "range of motion improvement");
    }

    // =========================================================================
    // d) Radiology Coordination (radiologist) — 7 tests
    // =========================================================================

    @Test
    @DisplayName("Radiologist schedules control examination after accepting referral")
    void radiologistSchedulesControlExamination() {
        String referralId = driver.setupAcceptedRadiologyReferral(drMueller, markRadiologist, hannahPatient, existingCaseId);

        driver.loginAsProvider(markRadiologist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(6).atTime(9, 0))
                .withDuration(Duration.ofMinutes(30)));

        driver.assertAppointmentIsCreated(appointmentId);
        driver.assertAppointmentStatusIs(appointmentId, SCHEDULED);
    }

    @Test
    @DisplayName("Radiologist schedules control examination after accepting referral - Notification")
    void radiologistSchedulesControlExamination_notification() {
        String referralId = driver.setupAcceptedRadiologyReferral(drMueller, markRadiologist, hannahPatient, existingCaseId);

        driver.loginAsProvider(markRadiologist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(6).atTime(9, 0))
                .withDuration(Duration.ofMinutes(30)));

        driver.assertPatientIsNotified(hannahPatient, "NEW_APPOINTMENT");
    }

    @Test
    @DisplayName("Radiologist records examination results - Status")
    void radiologistRecordsExaminationResults_status() {
        String referralId = driver.setupAcceptedRadiologyReferral(drMueller, markRadiologist, hannahPatient, existingCaseId);
        driver.loginAsProvider(markRadiologist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(6).atTime(9, 0))
                .withDuration(Duration.ofMinutes(30)));

        driver.completeAppointment(appointmentId, "Fracture healing progressing well, callus formation visible");

        driver.assertAppointmentStatusIs(appointmentId, COMPLETED);
    }

    @Test
    @DisplayName("Radiologist records examination results - Notes recorded")
    void radiologistRecordsExaminationResults_notesRecorded() {
        String referralId = driver.setupAcceptedRadiologyReferral(drMueller, markRadiologist, hannahPatient, existingCaseId);
        driver.loginAsProvider(markRadiologist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(6).atTime(9, 0))
                .withDuration(Duration.ofMinutes(30)));

        driver.completeAppointment(appointmentId, "Fracture healing progressing well, callus formation visible");

        driver.assertAppointmentNotesContain(appointmentId, "callus formation visible");
    }

    @Test
    @DisplayName("Radiologist completes appointment — traumatologist is notified")
    void radiologistCompletesAppointmentAndNotifiesTraumatologist() {
        String referralId = driver.setupAcceptedRadiologyReferral(drMueller, markRadiologist, hannahPatient, existingCaseId);
        driver.loginAsProvider(markRadiologist);
        String appointmentId = driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(6).atTime(9, 0))
                .withDuration(Duration.ofMinutes(30)));

        driver.completeAppointment(appointmentId, "Control X-ray complete, results available");

        driver.assertProviderIsNotified(drMueller, "APPOINTMENT_COMPLETED");
    }

    @Test
    @DisplayName("Radiologist counter-proposal updates milestone date on timeline - Milestone updated")
    void radiologistCounterProposalUpdatesTimeline_milestoneUpdated() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(6));

        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(referralId, ReferralResponse.counterPropose(now().plusWeeks(8), "Equipment maintenance scheduled week 6-7"));

        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(8));
    }

    @Test
    @DisplayName("Radiologist counter-proposal updates milestone date on timeline - Old milestone removed")
    void radiologistCounterProposalUpdatesTimeline_oldMilestoneRemoved() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(6));

        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(referralId, ReferralResponse.counterPropose(now().plusWeeks(8), "Equipment maintenance scheduled week 6-7"));

        driver.assertTimelineDoesNotContainMilestoneAt(coordinationId, "Control Radiology", now().plusWeeks(6));
    }

    // =========================================================================
    // e) Patient Perspective & Duties — 7 tests
    // =========================================================================

    @Test
    @DisplayName("Patient views all appointments across providers in one view")
    void patientViewsAllAppointmentsAcrossProviders() {
        String coordinationId = driver.setupFullCoordination(drMueller, lisaTherapist, markRadiologist, hannahPatient, existingCaseId);

        driver.loginAsPatient(hannahPatient);
        List<Appointment> appointments = driver.getPatientAppointments(coordinationId);

        driver.assertAppointmentsIncludeProvider(appointments, lisaTherapist);
        driver.assertAppointmentsIncludeProvider(appointments, markRadiologist);
    }

    @Test
    @DisplayName("Patient marks duty complete - Completion recorded")
    void patientMarksDutyComplete_completionRecorded() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Ice knee for 15 minutes")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusWeeks(2)));

        driver.loginAsPatient(hannahPatient);
        driver.markDutyComplete(dutyId);

        driver.assertDutyCompletionRecorded(dutyId);
    }

    @Test
    @DisplayName("Patient marks duty complete - Notification")
    void patientMarksDutyComplete_notification() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Ice knee for 15 minutes")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusWeeks(2)));

        driver.loginAsPatient(hannahPatient);
        driver.markDutyComplete(dutyId);

        driver.assertProviderIsNotified(lisaTherapist, "DUTY_COMPLETED");
    }

    @Test
    @DisplayName("Patient cannot modify referrals — read-only access")
    void patientCannotModifyReferrals() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        driver.addPatientToCoordination(coordinationId, hannahPatient);
        String referralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1)));

        driver.loginAsPatient(hannahPatient);
        driver.attemptRespondToReferral(referralId, ReferralResponse.accept());
        driver.assertOperationRejected("FORBIDDEN");
    }

    @Test
    @DisplayName("Patient cannot access another patient's coordination")
    void patientCannotAccessOtherPatientsCoordination() {
        Patient otherPatient = new Patient("other@patient.example", "Other Patient");

        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        driver.addPatientToCoordination(coordinationId, hannahPatient);

        driver.loginAsPatient(otherPatient);
        driver.attemptViewCoordination(coordinationId);
        driver.assertOperationRejected("FORBIDDEN");
    }

    @Test
    @DisplayName("Patient views timeline with all milestones")
    void patientViewsTimelineWithAllMilestones() {
        String coordinationId = driver.setupFullCoordination(drMueller, lisaTherapist, markRadiologist, hannahPatient, existingCaseId);

        driver.loginAsPatient(hannahPatient);
        CoordinationTimeline timeline = driver.getTimeline(coordinationId);

        driver.assertTimelineContainsMilestone(coordinationId, "Therapy Start", now().plusWeeks(1));
        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(6));
    }

    @Test
    @DisplayName("Patient views timeline with all milestones - Milestone count")
    void patientViewsTimelineWithAllMilestones_milestoneCount() {
        String coordinationId = driver.setupFullCoordination(drMueller, lisaTherapist, markRadiologist, hannahPatient, existingCaseId);

        driver.loginAsPatient(hannahPatient);
        CoordinationTimeline timeline = driver.getTimeline(coordinationId);

        driver.assertTimelineMilestoneCount(coordinationId, 2);
    }

    // =========================================================================
    // f) Reminders & Notifications — 5 tests
    // =========================================================================

    @Test
    @DisplayName("Recurring duty generates daily reminders - Reminder count")
    void recurringDutyGeneratesReminders_reminderCount() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Knee flexion exercises")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusDays(3)));

        driver.fastForwardDays(3);

        driver.assertReminderCount(dutyId, 3);
    }

    @Test
    @DisplayName("Recurring duty generates daily reminders - All delivered")
    void recurringDutyGeneratesReminders_allDelivered() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Knee flexion exercises")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusDays(3)));

        driver.fastForwardDays(3);

        driver.assertAllRemindersDelivered(dutyId);
    }

    @Test
    @DisplayName("Reminder firing stops after patient completes duty for the day")
    void reminderFiringStopsAfterCompletion() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Apply compression bandage")
                .withRecurrence(DAILY)
                .withStartDate(now())
                .withEndDate(now().plusDays(5)));

        driver.loginAsPatient(hannahPatient);
        driver.markDutyComplete(dutyId);

        driver.fastForwardDays(1);

        driver.assertNoReminderDeliveredAfterCompletion(dutyId, now());
    }

    @Test
    @DisplayName("Provider is notified when patient completes a duty")
    void providerNotifiedWhenPatientCompletesDuty() {
        String coordinationId = driver.setupAcceptedTherapyCoordination(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        driver.loginAsProvider(lisaTherapist);
        String dutyId = driver.assignPatientDuty(coordinationId, new PatientDutyRequest()
                .withPatient(hannahPatient)
                .withDescription("Stretching exercises")
                .withRecurrence(NONE)
                .withStartDate(now()));

        driver.loginAsPatient(hannahPatient);
        driver.markDutyComplete(dutyId);

        driver.assertProviderIsNotified(lisaTherapist, "DUTY_COMPLETED");
    }

    @Test
    @DisplayName("Patient is notified of a new appointment")
    void patientNotifiedOfNewAppointment() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);

        driver.loginAsProvider(lisaTherapist);
        driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.assertPatientIsNotified(hannahPatient, "NEW_APPOINTMENT");
    }

    // =========================================================================
    // g) Timeline & Progress Tracking — 5 tests
    // =========================================================================

    @Test
    @DisplayName("Timeline reflects all referral milestones - Therapy and radiology")
    void timelineReflectsAllReferralMilestones_therapyAndRadiology() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.assertTimelineContainsMilestone(coordinationId, "Therapy Start", now().plusWeeks(1));
        driver.assertTimelineContainsMilestone(coordinationId, "Control Radiology", now().plusWeeks(6));
    }

    @Test
    @DisplayName("Timeline reflects all referral milestones - Therapy end")
    void timelineReflectsAllReferralMilestones_therapyEnd() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);

        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1))
                .withRequestedDuration(Duration.ofDays(90)));

        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        driver.assertTimelineContainsMilestone(coordinationId, "Therapy End", now().plusWeeks(1).plusDays(90));
    }

    @Test
    @DisplayName("Timeline updates when appointment is scheduled")
    void timelineUpdatesWhenAppointmentScheduled() {
        String referralId = driver.setupAcceptedTherapyReferral(drMueller, lisaTherapist, hannahPatient, existingCaseId);
        String coordinationId = driver.getCoordinationForReferral(referralId);

        driver.loginAsProvider(lisaTherapist);
        driver.scheduleAppointment(referralId, new AppointmentRequest()
                .withPatient(hannahPatient)
                .withScheduledAt(now().plusWeeks(1).atTime(10, 0))
                .withDuration(Duration.ofMinutes(60)));

        driver.assertTimelineContainsMilestone(coordinationId, "Therapy Appointment", now().plusWeeks(1));
    }

    @Test
    @DisplayName("Coordination completes when all referrals are resolved")
    void coordinationCompletesWhenAllReferralsResolved() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String therapyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1)));
        String radiologyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        // Both providers accept
        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(therapyReferralId, ReferralResponse.accept());
        driver.loginAsProvider(markRadiologist);
        driver.respondToReferral(radiologyReferralId, ReferralResponse.accept());

        // Coordinating provider completes
        driver.loginAsProvider(drMueller);
        driver.completeCoordination(coordinationId);
        driver.assertCoordinationStatusIs(coordinationId, COMPLETED);
    }

    @Test
    @DisplayName("Coordination progress shows referral statuses")
    void coordinationProgressShowsReferralStatuses() {
        driver.loginAsProvider(drMueller);
        String coordinationId = driver.startCoordination(existingCaseId);
        String therapyReferralId = driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(lisaTherapist)
                .withServiceType(PHYSICAL_THERAPY)
                .withRequestedStartDate(now().plusWeeks(1)));
        driver.createReferral(coordinationId, new ReferralRequest()
                .withToProvider(markRadiologist)
                .withServiceType(RADIOLOGY)
                .withRequestedStartDate(now().plusWeeks(6)));

        // Only therapy referral accepted so far
        driver.loginAsProvider(lisaTherapist);
        driver.respondToReferral(therapyReferralId, ReferralResponse.accept());

        driver.loginAsProvider(drMueller);
        driver.assertCoordinationProgress(coordinationId, 1, 2); // 1 of 2 referrals resolved
    }
}
```

### 55 Tests in 7 Categories

#### a) Case & Referral Creation (traumatologist) — 11 tests

- **traumatologistStartsCoordinationFromCase_creationIdentity** — Coordination is created and linked to the existing case.
- **traumatologistStartsCoordinationFromCase_statusAndProvider** — Coordination status is ACTIVE and the coordinating provider is Dr. Mueller.
- **traumatologistStartsCoordinationFromCase_participantCount** — Initial coordination has exactly one participant (the coordinating provider).
- **traumatologistCreatesTherapyReferral** — Therapy referral is created with PENDING status.
- **traumatologistCreatesTherapyReferral_serviceTypeAndDeadline** — Therapy referral has correct service type (PHYSICAL_THERAPY) and a response deadline.
- **traumatologistCreatesTherapyReferral_notification** — Confirms the referred provider is notified of the new therapy referral.
- **traumatologistCreatesRadiologyReferral** — Radiology referral is created with PENDING status.
- **traumatologistCreatesRadiologyReferral_serviceType** — Radiology referral has correct service type (RADIOLOGY).
- **traumatologistCreatesMultipleReferrals** — Timeline shows milestones for both therapy start and control radiology.
- **traumatologistCreatesMultipleReferrals_milestoneCount** — Timeline has exactly 2 milestones after creating both referrals.
- **nonParticipantProviderCannotViewCoordination** — Ensures providers not participating in the coordination receive FORBIDDEN when attempting to view it.

#### b) Multi-Provider Coordination (cross-perspective) — 11 tests

- **therapistAcceptsReferral_referralAccepted** — After therapist accepts, the referral status changes to ACCEPTED.
- **therapistAcceptsReferral_participantAdded** — After therapist accepts, the therapist is added as a coordination participant.
- **therapistAcceptsReferral_notification** — After therapist accepts, the coordinating provider is notified of acceptance.
- **therapistDeclinesReferral_referralDeclined** — After therapist declines, the referral status changes to DECLINED.
- **therapistDeclinesReferral_notification** — After therapist declines, the coordinating provider is notified of the decline.
- **radiologistCounterProposesDate_referralStatus** — After radiologist counter-proposes, the referral status changes to COUNTER_PROPOSED.
- **radiologistCounterProposesDate_timelineUpdated** — After radiologist counter-proposes, the timeline milestone updates to the new date.
- **radiologistCounterProposesDate_notification** — After radiologist counter-proposes, the coordinating provider is notified.
- **referralResponseDeadlineEscalation_escalationEvent** — After 48 business hours without response, an escalation event is raised.
- **referralResponseDeadlineEscalation_notification** — After 48 business hours without response, the coordinating provider is notified of the escalation.
- **coordinationCannotCompleteWithPendingReferrals** — Attempting to complete a coordination with unresolved referrals is rejected with PENDING_REFERRALS_EXIST.

#### c) Therapy Coordination (therapist) — 9 tests

- **therapistSchedulesAppointmentAfterAccepting** — After accepting a referral, the therapist schedules an appointment with correct status.
- **therapistSchedulesAppointmentAfterAccepting_notification** — After scheduling an appointment, the patient is notified.
- **therapistSchedulesRecurringAppointments** — Therapist creates a recurring weekly appointment series (12 weeks) for the therapy duration.
- **therapistAssignsPatientDuty** — Therapist assigns a daily exercise duty to the patient with start and end dates.
- **therapistAssignsPatientDuty_notification** — After assigning a duty, the patient is notified.
- **therapistCancelsAppointment_status** — After cancellation, the appointment status changes to CANCELLED.
- **therapistCancelsAppointment_notification** — After cancellation, the patient is notified.
- **therapistCompletesAppointment_status** — After completion, the appointment status changes to COMPLETED.
- **therapistCompletesAppointment_notesRecorded** — After completion, clinical notes are recorded on the appointment.

#### d) Radiology Coordination (radiologist) — 7 tests

- **radiologistSchedulesControlExamination** — Radiologist schedules a control examination after accepting a referral with correct status.
- **radiologistSchedulesControlExamination_notification** — After scheduling a control examination, the patient is notified.
- **radiologistRecordsExaminationResults_status** — After recording results, the appointment status changes to COMPLETED.
- **radiologistRecordsExaminationResults_notesRecorded** — After recording results, clinical notes are stored on the appointment.
- **radiologistCompletesAppointmentAndNotifiesTraumatologist** — When the radiologist completes an appointment, the coordinating traumatologist is notified.
- **radiologistCounterProposalUpdatesTimeline_milestoneUpdated** — A counter-proposal replaces the milestone with the proposed date on the timeline.
- **radiologistCounterProposalUpdatesTimeline_oldMilestoneRemoved** — A counter-proposal removes the original milestone date from the timeline.

#### e) Patient Perspective & Duties — 7 tests

- **patientViewsAllAppointmentsAcrossProviders** — Patient sees appointments from all providers (therapist, radiologist) in a unified view.
- **patientMarksDutyComplete_completionRecorded** — After marking a duty complete, the completion is recorded.
- **patientMarksDutyComplete_notification** — After marking a duty complete, the assigning provider is notified.
- **patientCannotModifyReferrals** — Patient attempting to respond to a referral is rejected with FORBIDDEN.
- **patientCannotAccessOtherPatientsCoordination** — A different patient cannot view another patient's coordination (FORBIDDEN).
- **patientViewsTimelineWithAllMilestones** — Patient sees therapy start and control radiology milestones on the timeline.
- **patientViewsTimelineWithAllMilestones_milestoneCount** — Patient's timeline has exactly 2 milestones.

#### f) Reminders & Notifications — 5 tests

- **recurringDutyGeneratesReminders_reminderCount** — A daily recurring duty generates one reminder per day over the duty period.
- **recurringDutyGeneratesReminders_allDelivered** — All generated reminders for a recurring duty are delivered.
- **reminderFiringStopsAfterCompletion** — After the patient marks a duty complete for the day, no further reminders are delivered until the next occurrence.
- **providerNotifiedWhenPatientCompletesDuty** — The assigning provider receives a DUTY_COMPLETED notification when the patient marks a duty as done.
- **patientNotifiedOfNewAppointment** — Patient receives a NEW_APPOINTMENT notification when a provider schedules an appointment.

#### g) Timeline & Progress Tracking — 5 tests

- **timelineReflectsAllReferralMilestones_therapyAndRadiology** — Timeline includes milestones for therapy start and control radiology.
- **timelineReflectsAllReferralMilestones_therapyEnd** — Timeline includes a therapy end milestone computed from start date plus duration.
- **timelineUpdatesWhenAppointmentScheduled** — Scheduling an appointment adds a new milestone to the timeline at the appointment date.
- **coordinationCompletesWhenAllReferralsResolved** — When all referrals are accepted (or otherwise resolved), the coordinating provider can complete the coordination.
- **coordinationProgressShowsReferralStatuses** — Progress is reported as resolved/total referral ratio (e.g. 1 of 2 resolved).

---

## DSL Model

### TreatmentCoordinationDomainSpecificLanguage (Base Interface)

```java
interface TreatmentCoordinationDomainSpecificLanguage {

    // --- Authentication ---
    void loginAsProvider(Provider provider);
    void loginAsPatient(Patient patient);
    void unauthenticate();

    // --- Types ---
    record Provider(String email, String name, ProviderRole role) {}
    record Patient(String email, String name) {}

    enum ProviderRole { TRAUMATOLOGIST, THERAPIST, RADIOLOGIST }
    enum ServiceType { PHYSICAL_THERAPY, RADIOLOGY }
    enum CoordinationStatus { ACTIVE, COMPLETED, CANCELLED }
    enum ReferralStatus { PENDING, ACCEPTED, DECLINED, COUNTER_PROPOSED, CANCELLED }
    enum AppointmentStatus { SCHEDULED, COMPLETED, CANCELLED }
    enum DutyStatus { ACTIVE, COMPLETED, CANCELLED }
    enum Recurrence { DAILY, WEEKLY, NONE }

    // --- Creation ---
    String startCoordination(String caseId);
    void addPatientToCoordination(String coordinationId, Patient patient);

    // --- Base assertions ---
    void assertCoordinationIsCreated(String coordinationId);
    void assertCoordinationIsLinkedToCase(String coordinationId, String caseId);
    void assertCoordinationStatusIs(String coordinationId, CoordinationStatus status);
    void assertCoordinatingProviderIs(String coordinationId, Provider provider);
    void assertParticipantCount(String coordinationId, int count);
    void assertParticipantIncludes(String coordinationId, Provider provider);
    void assertOperationRejected(String reason);
}
```

### TreatmentCoordinationDriver (Extended — used in pseudocode tests)

```java
interface TreatmentCoordinationDriver extends TreatmentCoordinationDomainSpecificLanguage {

    // --- Referral actions ---
    String createReferral(String coordinationId, ReferralRequest request);
    void respondToReferral(String referralId, ReferralResponse response);
    void attemptRespondToReferral(String referralId, ReferralResponse response);
    void cancelReferral(String referralId);

    // --- Appointment actions ---
    String scheduleAppointment(String referralId, AppointmentRequest request);
    List<String> scheduleRecurringAppointments(String referralId, RecurringAppointmentRequest request);
    void completeAppointment(String appointmentId, String notes);
    void cancelAppointment(String appointmentId);

    // --- Patient duty actions ---
    String assignPatientDuty(String coordinationId, PatientDutyRequest request);
    void markDutyComplete(String dutyId);

    // --- Coordination lifecycle ---
    void attemptCompleteCoordination(String coordinationId);
    void completeCoordination(String coordinationId);
    void attemptViewCoordination(String coordinationId);

    // --- Timeline ---
    CoordinationTimeline getTimeline(String coordinationId);
    List<Appointment> getPatientAppointments(String coordinationId);
    String getCoordinationForReferral(String referralId);

    // --- Time control ---
    void fastForwardBusinessHours(int hours);
    void fastForwardDays(int days);

    // --- Setup helpers (compose multi-step setups) ---
    String setupAcceptedTherapyReferral(Provider coordinator, Provider therapist, Patient patient, String caseId);
    String setupAcceptedRadiologyReferral(Provider coordinator, Provider radiologist, Patient patient, String caseId);
    String setupAcceptedTherapyCoordination(Provider coordinator, Provider therapist, Patient patient, String caseId);
    String setupFullCoordination(Provider coordinator, Provider therapist, Provider radiologist, Patient patient, String caseId);

    // --- Referral assertions ---
    void assertReferralIsCreated(String referralId);
    void assertReferralStatusIs(String referralId, ReferralStatus status);
    void assertReferralServiceTypeIs(String referralId, ServiceType type);
    void assertReferralHasResponseDeadline(String referralId);
    void assertEscalationEventRaised(String referralId, String eventType);
    void assertCoordinationProgress(String coordinationId, int resolved, int total);

    // --- Appointment assertions ---
    void assertAppointmentIsCreated(String appointmentId);
    void assertAppointmentStatusIs(String appointmentId, AppointmentStatus status);
    void assertAllAppointmentsStatusIs(List<String> appointmentIds, AppointmentStatus status);
    void assertAppointmentCount(String referralId, int count);
    void assertAppointmentNotesContain(String appointmentId, String text);
    void assertAppointmentsIncludeProvider(List<Appointment> appointments, Provider provider);

    // --- Duty assertions ---
    void assertDutyIsCreated(String dutyId);
    void assertDutyStatusIs(String dutyId, DutyStatus status);
    void assertDutyCompletionRecorded(String dutyId);

    // --- Reminder assertions ---
    void assertReminderCount(String dutyId, int count);
    void assertAllRemindersDelivered(String dutyId);
    void assertNoReminderDeliveredAfterCompletion(String dutyId, LocalDate completionDate);

    // --- Timeline assertions ---
    void assertTimelineContainsMilestone(String coordinationId, String label, LocalDate targetDate);
    void assertTimelineDoesNotContainMilestoneAt(String coordinationId, String label, LocalDate date);
    void assertTimelineMilestoneCount(String coordinationId, int count);

    // --- Notification assertions ---
    void assertProviderIsNotified(Provider provider, String notificationType);
    void assertPatientIsNotified(Patient patient, String notificationType);

    // --- Request builders ---
    record ReferralRequest(
        Provider toProvider,
        ServiceType serviceType,
        LocalDate requestedStartDate,
        Duration requestedDuration,
        String clinicalInstructions
    ) {
        ReferralRequest() { this(null, null, null, null, null); }
        ReferralRequest withToProvider(Provider p) { return new ReferralRequest(p, serviceType, requestedStartDate, requestedDuration, clinicalInstructions); }
        ReferralRequest withServiceType(ServiceType t) { return new ReferralRequest(toProvider, t, requestedStartDate, requestedDuration, clinicalInstructions); }
        ReferralRequest withRequestedStartDate(LocalDate d) { return new ReferralRequest(toProvider, serviceType, d, requestedDuration, clinicalInstructions); }
        ReferralRequest withRequestedDuration(Duration d) { return new ReferralRequest(toProvider, serviceType, requestedStartDate, d, clinicalInstructions); }
        ReferralRequest withClinicalInstructions(String s) { return new ReferralRequest(toProvider, serviceType, requestedStartDate, requestedDuration, s); }
    }

    record ReferralResponse(ResponseType type, LocalDate proposedStartDate, Duration proposedDuration, String reason) {
        enum ResponseType { ACCEPTED, DECLINED, COUNTER_PROPOSED }
        static ReferralResponse accept() { return new ReferralResponse(ResponseType.ACCEPTED, null, null, null); }
        static ReferralResponse decline(String reason) { return new ReferralResponse(ResponseType.DECLINED, null, null, reason); }
        static ReferralResponse counterPropose(LocalDate date, String reason) { return new ReferralResponse(ResponseType.COUNTER_PROPOSED, date, null, reason); }
    }

    record AppointmentRequest(
        Patient patient,
        Instant scheduledAt,
        Duration duration
    ) {
        AppointmentRequest() { this(null, null, null); }
        AppointmentRequest withPatient(Patient p) { return new AppointmentRequest(p, scheduledAt, duration); }
        AppointmentRequest withScheduledAt(Instant t) { return new AppointmentRequest(patient, t, duration); }
        AppointmentRequest withDuration(Duration d) { return new AppointmentRequest(patient, scheduledAt, d); }
    }

    record RecurringAppointmentRequest(
        Patient patient,
        LocalDate startDate,
        Recurrence recurrence,
        int count,
        Duration duration
    ) {
        RecurringAppointmentRequest() { this(null, null, null, 0, null); }
        RecurringAppointmentRequest withPatient(Patient p) { return new RecurringAppointmentRequest(p, startDate, recurrence, count, duration); }
        RecurringAppointmentRequest withStartDate(LocalDate d) { return new RecurringAppointmentRequest(patient, d, recurrence, count, duration); }
        RecurringAppointmentRequest withRecurrence(Recurrence r) { return new RecurringAppointmentRequest(patient, startDate, r, count, duration); }
        RecurringAppointmentRequest withCount(int c) { return new RecurringAppointmentRequest(patient, startDate, recurrence, c, duration); }
        RecurringAppointmentRequest withDuration(Duration d) { return new RecurringAppointmentRequest(patient, startDate, recurrence, count, d); }
    }

    record PatientDutyRequest(
        Patient patient,
        String description,
        Recurrence recurrence,
        LocalDate startDate,
        LocalDate endDate
    ) {
        PatientDutyRequest() { this(null, null, null, null, null); }
        PatientDutyRequest withPatient(Patient p) { return new PatientDutyRequest(p, description, recurrence, startDate, endDate); }
        PatientDutyRequest withDescription(String d) { return new PatientDutyRequest(patient, d, recurrence, startDate, endDate); }
        PatientDutyRequest withRecurrence(Recurrence r) { return new PatientDutyRequest(patient, description, r, startDate, endDate); }
        PatientDutyRequest withStartDate(LocalDate d) { return new PatientDutyRequest(patient, description, recurrence, d, endDate); }
        PatientDutyRequest withEndDate(LocalDate d) { return new PatientDutyRequest(patient, description, recurrence, startDate, d); }
    }
}
```

---

## Architecture Notes

- **TACO is a bounded context** for treatment coordination, separate from Case/Patient/Provider but referencing them by ID. Clinical data (diagnoses, images, therapy records) stays in the Case bounded context; TACO manages _who does what, when, and in what order_.
- **Anti-corruption layer** — TACO references Case, Patient, and Provider contexts by ID only. Clinical instructions on Referrals are free text, not structured clinical data. This prevents TACO from coupling to the Case domain model.
- **One active coordination per Case** — simplifies the aggregate model. Parallel treatments use separate Cases.
- **Perspective via authentication** — following the COLE pattern (`loginAsConsultant`/`loginAsCustomer`), perspectives are expressed through `loginAsProvider`/`loginAsPatient` calls. Authorization rules enforce what each participant can see and do.
- **Timeline is a read model** — computed on demand from referrals, appointments, and duties. Never stored as a separate aggregate.
- **Status: specification stage** — only dummy drivers are planned; no production domain or controller drivers yet.

### State Machines

#### Referral Lifecycle

```
PENDING → ACCEPTED → (appointments scheduled)
PENDING → DECLINED
PENDING → COUNTER_PROPOSED → ACCEPTED / DECLINED / COUNTER_PROPOSED
PENDING → CANCELLED
(any non-terminal) → CANCELLED
```

After 48 business hours in PENDING: EscalateReferral → ReferralEscalated (Referral remains PENDING).

#### Appointment Lifecycle

```
SCHEDULED → COMPLETED
SCHEDULED → CANCELLED
```

#### Coordination Lifecycle

```
ACTIVE → COMPLETED (only when all referrals are resolved)
ACTIVE → CANCELLED
```

#### PatientDuty Lifecycle

```
ACTIVE → COMPLETED (patient marks complete; for recurring, generates per-occurrence completions)
ACTIVE → CANCELLED (provider cancels)
```

### Integration Points

| System | Purpose |
|--------|---------|
| Case Management | Source of clinical context — TACO references Case by ID |
| Provider Registry | Source of provider identity and roles |
| Notification System | Delivers reminders and notifications — TACO emits domain events, infrastructure handles delivery |
| Patient Identity | Source of patient identity — referenced by ID |

### Relationship to Case

- Case (existing Casura bounded context) contains clinical data: diagnosis, imaging, therapies, therapy recommendations, control examinations
- TACO references Case by ID but never reads or writes clinical data directly
- When a Referral is created, clinical instructions are captured as free text — the anti-corruption layer
- Appointment completion notes in TACO are coordination-level; detailed clinical documentation happens in Case

### BDD 4-Layer Architecture

```
Test → DSL → Protocol Driver → SUT
```

- **Test**: `TreatmentCoordinationAcceptance` — intent-focused scenarios using DSL vocabulary
- **DSL**: `TreatmentCoordinationDomainSpecificLanguage` — stable domain language interface
- **Protocol Driver**: Domain driver (direct interactor calls), Controller driver (HTTP), UI driver (Playwright)
- **SUT**: The running TACO bounded context

### Planned File Manifest

| Circle | File | Purpose |
|--------|------|---------|
| Entity | `taco/taco-domain/.../entity/TreatmentCoordination.java` | Aggregate root |
| Entity | `taco/taco-domain/.../entity/Referral.java` | Referral entity |
| Entity | `taco/taco-domain/.../entity/Appointment.java` | Appointment entity |
| Entity | `taco/taco-domain/.../entity/PatientDuty.java` | Patient duty entity |
| Value Object | `taco/taco-domain/.../model/CoordinationParticipant.java` | Participant value object |
| Value Object | `taco/taco-domain/.../model/ReferralResponse.java` | Response value object |
| Value Object | `taco/taco-domain/.../model/Reminder.java` | Reminder value object |
| Value Object | `taco/taco-domain/.../model/Milestone.java` | Milestone value object |
| Read Model | `taco/taco-domain/.../model/CoordinationTimeline.java` | Timeline projection |
| Events | `taco/taco-domain/.../event/StartCoordinationCauseAndEffect.java` | Coordination start |
| Events | `taco/taco-domain/.../event/CreateReferralCauseAndEffect.java` | Referral creation |
| Events | `taco/taco-domain/.../event/RespondToReferralCauseAndEffect.java` | Referral response |
| Events | `taco/taco-domain/.../event/ScheduleAppointmentCauseAndEffect.java` | Appointment scheduling |
| Events | `taco/taco-domain/.../event/CompleteAppointmentCauseAndEffect.java` | Appointment completion |
| Events | `taco/taco-domain/.../event/AssignPatientDutyCauseAndEffect.java` | Duty assignment |
| Events | `taco/taco-domain/.../event/CompletePatientDutyCauseAndEffect.java` | Duty completion |
| Events | `taco/taco-domain/.../event/EscalateReferralCauseAndEffect.java` | Referral escalation |
| Acceptance | `taco/acceptance/.../scenario/TreatmentCoordinationAcceptance.java` | 55 acceptance scenarios |
| Acceptance | `taco/acceptance/.../driver/TreatmentCoordinationDomainSpecificLanguage.java` | DSL interface |
| Acceptance | `taco/acceptance/.../driver/TreatmentCoordinationDriver.java` | Extended driver interface |

---

## Gotchas / Notes

- **Referral response deadline defaults to 48 business hours** — configurable per coordination. After expiry, an EscalateReferral cause is applied but the Referral remains in PENDING status; it is not auto-cancelled.
- **Patient duties are provider-assigned only** — patients cannot create their own duties. They can only mark duties as complete.
- **Radiologist counter-proposals update timeline dates** — when a counter-proposal is recorded, the milestone for that referral is recomputed using the proposed date, replacing the original requested date.
- **Notification delivery is an infrastructure concern** — TACO emits domain events (ReferralCreated, AppointmentScheduled, etc.); the notification system subscribes and handles delivery via email, push, or in-app channels.
- **Recurrence generates per-occurrence reminders** — a DAILY duty from Jan 1 to Jan 5 produces 5 individual Reminder instances, each with their own scheduledAt/deliveredAt timestamps.
- **Clinical instructions are free text** — the anti-corruption layer between TACO and Case. TACO does not import structured clinical types (Diagnosis, Therapy, etc.) from the Case bounded context.
- **Coordination cannot complete with pending referrals** — the coordinating provider must wait for all referrals to reach a terminal state (ACCEPTED, DECLINED, or CANCELLED) before completing the coordination.
- **Timeline milestone types** — THERAPY_START and THERAPY_END are derived from referrals with duration; CONTROL_EXAMINATION from radiology referrals; APPOINTMENT from scheduled appointments.
- **One active coordination per Case** — enforced at creation time. Starting a second coordination for a case with an ACTIVE coordination is rejected.
- **Setup helpers compose multi-step flows** — `setupAcceptedTherapyReferral` combines login, coordination start, patient addition, referral creation, provider login, and acceptance into a single call for test readability.

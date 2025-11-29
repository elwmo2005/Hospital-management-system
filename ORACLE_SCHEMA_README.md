# Hospital Management System - Oracle Database Schema & PL/SQL APIs

## Overview

This repository contains comprehensive Oracle database schemas and PL/SQL packages designed specifically to support the Hospital Management System HTML screens. The database structure is optimized for Oracle APEX integration and includes advanced features for laboratory management, pharmacy operations, billing, emergency triage, and clinical workflows.

## Files Included

### 1. `hospital_oracle_schema.sql`
Base schema with core hospital management tables including:
- Hospitals and departments
- Patients and demographics
- Staff members
- Beds and rooms
- Medical equipment
- Appointments
- Basic lab tests
- Medications
- Prescriptions
- Billing
- Patient insurance

### 2. `hospital_enhanced_schema.sql` (NEW)
Enhanced schema with advanced features for HTML screens:

#### Laboratory Management
- **LAB_TEST_PARAMETERS**: Detailed test components with normal and critical ranges
- **LAB_SPECIMENS**: Complete specimen tracking workflow
- **LAB_RESULT_PARAMETERS**: Detailed results for each test component
- **LAB_QUALITY_CONTROL**: QC management for lab equipment
- **LAB_CRITICAL_NOTIFICATIONS**: Critical value alert system

#### Pharmacy Management
- **DRUG_INTERACTIONS**: Drug-drug interaction database
- **MEDICATION_DISPENSING**: Complete dispensing workflow and audit trail
- **MEDICATION_STOCK_MOVEMENTS**: Inventory tracking with movement history

#### Billing & Finance
- **PAYMENTS**: Payment processing with multiple payment methods
- **INSURANCE_CLAIM_DETAILS**: Insurance claim management and tracking

#### Emergency & Clinical
- **EMERGENCY_TRIAGE**: Emergency department triage workflow
- **DISCHARGE_PLANNING**: Comprehensive discharge planning

#### PL/SQL Packages
- **PKG_LABORATORY**: Laboratory workflow automation
- **PKG_PHARMACY**: Pharmacy operations and stock management

### 3. `hospital_clinical_apis.sql` (NEW)
Clinical workflow APIs:

#### Packages Included:
1. **PKG_ADMISSION_DISCHARGE**: Patient admission, discharge, and transfer workflows
2. **PKG_VITAL_SIGNS**: Vital signs recording and trending
3. **PKG_BILLING**: Billing generation and payment processing
4. **PKG_EMERGENCY**: Emergency triage management

#### Database Views:
- **V_LAB_DASHBOARD**: Real-time laboratory dashboard
- **V_EMERGENCY_TRIAGE_BOARD**: Emergency department board
- **V_PHARMACY_DISPENSING_QUEUE**: Pharmacy work queue
- **V_BILLING_SUMMARY**: Billing summary with payments

## Installation Instructions

### Prerequisites
- Oracle Database 19c or later (12c may work with minor modifications)
- Oracle APEX 20.1 or later (recommended for HTML screen integration)
- Sufficient database privileges (CREATE TABLE, CREATE SEQUENCE, CREATE PACKAGE, etc.)

### Installation Steps

```sql
-- Step 1: Connect as schema owner
CONNECT your_schema/your_password@your_database

-- Step 2: Execute base schema (if not already done)
@hospital_oracle_schema.sql

-- Step 3: Execute enhanced schema with laboratory and pharmacy enhancements
@hospital_enhanced_schema.sql

-- Step 4: Execute clinical API packages
@hospital_clinical_apis.sql

-- Step 5: Verify installation
SELECT 'Tables: ' || COUNT(*) FROM USER_TABLES;
SELECT 'Views: ' || COUNT(*) FROM USER_VIEWS;
SELECT 'Packages: ' || COUNT(*) FROM USER_OBJECTS WHERE OBJECT_TYPE = 'PACKAGE';
SELECT 'Triggers: ' || COUNT(*) FROM USER_TRIGGERS;
```

### Post-Installation Configuration

```sql
-- Grant execute permissions to APEX workspace (if using Oracle APEX)
GRANT EXECUTE ON PKG_LABORATORY TO APEX_WORKSPACE_SCHEMA;
GRANT EXECUTE ON PKG_PHARMACY TO APEX_WORKSPACE_SCHEMA;
GRANT EXECUTE ON PKG_ADMISSION_DISCHARGE TO APEX_WORKSPACE_SCHEMA;
GRANT EXECUTE ON PKG_VITAL_SIGNS TO APEX_WORKSPACE_SCHEMA;
GRANT EXECUTE ON PKG_BILLING TO APEX_WORKSPACE_SCHEMA;
GRANT EXECUTE ON PKG_EMERGENCY TO APEX_WORKSPACE_SCHEMA;

-- Grant select on views
GRANT SELECT ON V_LAB_DASHBOARD TO APEX_WORKSPACE_SCHEMA;
GRANT SELECT ON V_EMERGENCY_TRIAGE_BOARD TO APEX_WORKSPACE_SCHEMA;
GRANT SELECT ON V_PHARMACY_DISPENSING_QUEUE TO APEX_WORKSPACE_SCHEMA;
GRANT SELECT ON V_BILLING_SUMMARY TO APEX_WORKSPACE_SCHEMA;
```

## HTML Screen to API Mapping

### Laboratory Screens (`laboratory_apex.html`)

#### Test Ordering
```sql
-- Create lab order
DECLARE
    v_order_id NUMBER;
BEGIN
    PKG_LABORATORY.CREATE_LAB_ORDER(
        p_patient_id => :P1_PATIENT_ID,
        p_hospital_id => :APP_HOSPITAL_ID,
        p_doctor_id => :APP_USER_ID,
        p_priority => :P1_PRIORITY,
        p_clinical_indication => :P1_CLINICAL_INDICATION,
        p_order_id => v_order_id
    );
    :P1_ORDER_ID := v_order_id;
END;
```

#### Specimen Collection
```sql
DECLARE
    v_specimen_id NUMBER;
BEGIN
    PKG_LABORATORY.COLLECT_SPECIMEN(
        p_order_id => :P1_ORDER_ID,
        p_specimen_type => :P1_SPECIMEN_TYPE,
        p_collected_by => :APP_USER_ID,
        p_collection_method => :P1_COLLECTION_METHOD,
        p_specimen_quality => :P1_SPECIMEN_QUALITY,
        p_specimen_id => v_specimen_id
    );
END;
```

#### Results Entry
```sql
DECLARE
    v_result_id NUMBER;
BEGIN
    PKG_LABORATORY.ENTER_LAB_RESULT(
        p_order_id => :P1_ORDER_ID,
        p_test_id => :P1_TEST_ID,
        p_parameter_id => :P1_PARAMETER_ID,
        p_result_value => :P1_RESULT_VALUE,
        p_numeric_value => :P1_NUMERIC_VALUE,
        p_result_id => v_result_id
    );
END;
```

#### Dashboard Query
```sql
-- Use in APEX Interactive Report
SELECT * FROM V_LAB_DASHBOARD
WHERE HOSPITAL_ID = :APP_HOSPITAL_ID
  AND (:P1_STATUS IS NULL OR ORDER_STATUS = :P1_STATUS)
  AND (:P1_PRIORITY IS NULL OR PRIORITY = :P1_PRIORITY)
ORDER BY
    CASE WHEN HAS_CRITICAL_VALUES = 'Y' THEN 0 ELSE 1 END,
    ORDER_DATE DESC;
```

### Admission/Discharge Screens (`admission_discharge.html`)

#### Patient Admission
```sql
DECLARE
    v_admission_id NUMBER;
BEGIN
    PKG_ADMISSION_DISCHARGE.ADMIT_PATIENT(
        p_patient_id => :P1_PATIENT_ID,
        p_hospital_id => :APP_HOSPITAL_ID,
        p_admission_type => :P1_ADMISSION_TYPE,
        p_department_id => :P1_DEPARTMENT_ID,
        p_attending_doctor => :P1_DOCTOR_ID,
        p_room_id => :P1_ROOM_ID,
        p_bed_id => :P1_BED_ID,
        p_chief_complaint => :P1_CHIEF_COMPLAINT,
        p_preliminary_diagnosis => :P1_DIAGNOSIS,
        p_admission_id => v_admission_id
    );
    :P1_ADMISSION_ID := v_admission_id;
END;
```

#### Patient Discharge
```sql
BEGIN
    PKG_ADMISSION_DISCHARGE.DISCHARGE_PATIENT(
        p_admission_id => :P1_ADMISSION_ID,
        p_discharge_date => SYSTIMESTAMP,
        p_discharge_disposition => :P1_DISPOSITION,
        p_final_diagnosis => :P1_FINAL_DIAGNOSIS,
        p_discharge_summary => :P1_DISCHARGE_SUMMARY,
        p_followup_instructions => :P1_FOLLOWUP,
        p_discharge_medications => :P1_MEDICATIONS,
        p_diet_instructions => :P1_DIET
    );
END;
```

#### Available Beds LOV
```sql
-- Use in APEX List of Values
SELECT r.ROOM_NUMBER || ' - Bed ' || b.BED_NUMBER AS DISPLAY_VALUE,
       b.BED_ID AS RETURN_VALUE
FROM TABLE(PKG_ADMISSION_DISCHARGE.GET_AVAILABLE_BEDS(
    p_hospital_id => :APP_HOSPITAL_ID,
    p_department_id => :P1_DEPARTMENT_ID
)) b
JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID;
```

### Emergency Triage Screen

#### Register Emergency Patient
```sql
DECLARE
    v_triage_id NUMBER;
BEGIN
    PKG_EMERGENCY.REGISTER_EMERGENCY_PATIENT(
        p_patient_id => :P1_PATIENT_ID,
        p_hospital_id => :APP_HOSPITAL_ID,
        p_arrival_method => :P1_ARRIVAL_METHOD,
        p_chief_complaint => :P1_CHIEF_COMPLAINT,
        p_triage_level => :P1_TRIAGE_LEVEL,
        p_triage_nurse => :APP_USER_ID,
        p_pain_score => :P1_PAIN_SCORE,
        p_triage_id => v_triage_id
    );
END;
```

#### Emergency Board
```sql
SELECT * FROM V_EMERGENCY_TRIAGE_BOARD
WHERE HOSPITAL_ID = :APP_HOSPITAL_ID
ORDER BY PRIORITY_ORDER, WAITING_TIME_MINUTES DESC;
```

### Pharmacy Screens

#### Check Drug Interactions
```sql
-- Display as warning before prescribing
SELECT * FROM TABLE(PKG_PHARMACY.CHECK_DRUG_INTERACTIONS(
    p_patient_id => :P1_PATIENT_ID,
    p_new_medication_id => :P1_MEDICATION_ID
));
```

#### Dispense Medication
```sql
DECLARE
    v_dispensing_id NUMBER;
BEGIN
    PKG_PHARMACY.DISPENSE_MEDICATION(
        p_prescription_id => :P1_PRESCRIPTION_ID,
        p_quantity => :P1_QUANTITY,
        p_dispensed_by => :APP_USER_ID,
        p_batch_number => :P1_BATCH_NUMBER,
        p_counseling_provided => :P1_COUNSELING,
        p_dispensing_id => v_dispensing_id
    );
END;
```

### Billing Screens

#### Generate Bill
```sql
DECLARE
    v_bill_id NUMBER;
BEGIN
    PKG_BILLING.GENERATE_BILL(
        p_admission_id => :P1_ADMISSION_ID,
        p_hospital_id => :APP_HOSPITAL_ID,
        p_patient_id => :P1_PATIENT_ID,
        p_include_services => 'Y',
        p_include_medications => 'Y',
        p_include_lab => 'Y',
        p_bill_id => v_bill_id
    );
    :P1_BILL_ID := v_bill_id;
END;
```

#### Process Payment
```sql
DECLARE
    v_payment_id NUMBER;
BEGIN
    PKG_BILLING.PROCESS_PAYMENT(
        p_bill_id => :P1_BILL_ID,
        p_payment_amount => :P1_PAYMENT_AMOUNT,
        p_payment_method => :P1_PAYMENT_METHOD,
        p_reference_number => :P1_REFERENCE_NUMBER,
        p_received_by => :APP_USER_ID,
        p_payment_id => v_payment_id
    );
END;
```

## Key Features

### 1. Automated Business Logic
- **Triggers**: Automatic stock updates, critical value alerts, billing status updates
- **Constraints**: Data integrity enforcement at database level
- **Sequences**: Auto-generated numbers for bills, specimens, claims

### 2. Critical Value Management
- Automatic detection based on configured ranges
- Notification tracking with acknowledgment
- Read-back verification for critical results

### 3. Drug Interaction Checking
- Database of drug-drug interactions
- Severity levels and clinical guidance
- Real-time checking before dispensing

### 4. Quality Control
- Equipment QC tracking
- Control level management
- Pass/fail status with trending

### 5. Audit Trail
- Created/updated timestamps on all tables
- User tracking (CREATED_BY, UPDATED_BY)
- Complete medication dispensing log
- Stock movement history

## Sample Queries

### Get Pending Lab Orders
```sql
SELECT * FROM V_LAB_DASHBOARD
WHERE ORDER_STATUS IN ('ORDERED', 'COLLECTED', 'PROCESSING')
  AND PRIORITY = 'STAT'
ORDER BY ORDER_DATE;
```

### Get Patients with Critical Results
```sql
SELECT DISTINCT
    p.PATIENT_NUMBER,
    p.FIRST_NAME || ' ' || p.LAST_NAME AS PATIENT_NAME,
    o.ORDER_ID,
    lt.TEST_NAME,
    r.RESULT_DATE
FROM LAB_ORDERS o
JOIN PATIENTS p ON o.PATIENT_ID = p.PATIENT_ID
JOIN LAB_TESTS lt ON o.TEST_ID = lt.TEST_ID
JOIN LAB_RESULTS r ON o.ORDER_ID = r.ORDER_ID
WHERE EXISTS (
    SELECT 1 FROM LAB_RESULT_PARAMETERS lrp
    WHERE lrp.RESULT_ID = r.RESULT_ID
      AND lrp.CRITICAL_FLAG = 'Y'
)
AND r.RESULT_DATE >= TRUNC(SYSDATE);
```

### Get Medication Reorder List
```sql
SELECT * FROM TABLE(PKG_PHARMACY.GET_REORDER_LIST(
    p_hospital_id => 1
));
```

### Daily Billing Report
```sql
SELECT
    TO_CHAR(b.BILL_DATE, 'YYYY-MM-DD') AS BILL_DATE,
    COUNT(*) AS TOTAL_BILLS,
    SUM(b.TOTAL_AMOUNT) AS TOTAL_BILLED,
    SUM(CASE WHEN b.BILLING_STATUS = 'PAID' THEN b.TOTAL_AMOUNT ELSE 0 END) AS TOTAL_PAID,
    SUM(CASE WHEN b.BILLING_STATUS = 'PENDING' THEN b.PATIENT_AMOUNT ELSE 0 END) AS TOTAL_PENDING
FROM BILLING b
WHERE b.BILL_DATE >= TRUNC(SYSDATE) - 30
GROUP BY TO_CHAR(b.BILL_DATE, 'YYYY-MM-DD')
ORDER BY BILL_DATE DESC;
```

## Performance Optimization

### Indexes Created
- All foreign keys are indexed
- Status fields have functional indexes
- Date fields for common queries
- Barcode and specimen number unique indexes

### Recommended Additional Indexes
```sql
-- For large datasets, consider:
CREATE INDEX IDX_LAB_ORDERS_COMPOSITE ON LAB_ORDERS(HOSPITAL_ID, ORDER_STATUS, ORDER_DATE);
CREATE INDEX IDX_BILLING_STATUS_DATE ON BILLING(BILLING_STATUS, BILL_DATE);
CREATE INDEX IDX_PRESCRIPTIONS_STATUS ON PRESCRIPTIONS(PRESCRIPTION_STATUS, HOSPITAL_ID);
```

## Security Recommendations

1. **Use Stored Procedures**: All HTML screens should use PL/SQL packages rather than direct table access
2. **Row Level Security**: Implement VPD for multi-hospital environments
3. **Audit Logging**: Enable Oracle audit for sensitive operations
4. **Encryption**: Use TDE for PHI data encryption at rest

## Troubleshooting

### Common Issues

#### Package Compilation Errors
```sql
-- Check for invalid objects
SELECT OBJECT_NAME, OBJECT_TYPE, STATUS
FROM USER_OBJECTS
WHERE STATUS = 'INVALID'
ORDER BY OBJECT_TYPE, OBJECT_NAME;

-- Recompile
ALTER PACKAGE PKG_LABORATORY COMPILE;
ALTER PACKAGE PKG_PHARMACY COMPILE;
```

#### Foreign Key Violations
Make sure base schema is installed first and contains required reference data.

#### View Access Issues
Ensure APEX workspace has SELECT privileges on all views.

## Support and Maintenance

### Backup Recommendations
```sql
-- Export schema regularly
expdp system/password SCHEMAS=hospital_schema DIRECTORY=backup_dir DUMPFILE=hospital_backup.dmp
```

### Monitoring Queries
```sql
-- Check system health
SELECT 'Patients Today' AS METRIC, COUNT(*) AS VALUE FROM PATIENTS WHERE REGISTRATION_DATE >= TRUNC(SYSDATE)
UNION ALL
SELECT 'Lab Orders Today', COUNT(*) FROM LAB_ORDERS WHERE ORDER_DATE >= TRUNC(SYSDATE)
UNION ALL
SELECT 'Admissions Today', COUNT(*) FROM PATIENT_ADMISSIONS WHERE ADMISSION_DATE >= TRUNC(SYSDATE)
UNION ALL
SELECT 'Bills Generated Today', COUNT(*) FROM BILLING WHERE BILL_DATE >= TRUNC(SYSDATE);
```

## License

This database schema is designed for the Hospital Management System project.

## Contributors

Created for Hospital Management System Oracle APEX Integration
Compatible with 28 HTML screens covering all hospital operations

## Version History

- **v1.0** (2024-12): Initial base schema
- **v2.0** (2024-12): Enhanced schema with laboratory, pharmacy, and clinical APIs
  - Added 15+ new tables
  - Created 6 PL/SQL packages
  - Added 4 comprehensive views
  - Implemented automated triggers
  - Added sample data for testing

---

For questions or issues, please refer to the GitHub repository or contact the development team.

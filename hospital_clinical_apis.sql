-- ===================================================================
-- HOSPITAL MANAGEMENT SYSTEM - CLINICAL API PROCEDURES
-- ===================================================================
-- PL/SQL APIs for Clinical Workflows: Admission, Discharge, Vitals, etc.
-- Compatible with Oracle APEX HTML Screens
-- ===================================================================

-- ===================================================================
-- PACKAGE: PATIENT ADMISSION & DISCHARGE MANAGEMENT
-- ===================================================================

CREATE OR REPLACE PACKAGE PKG_ADMISSION_DISCHARGE IS

    -- Admit patient to hospital
    PROCEDURE ADMIT_PATIENT(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_admission_type        IN VARCHAR2,
        p_department_id         IN NUMBER,
        p_attending_doctor      IN NUMBER,
        p_room_id               IN NUMBER,
        p_bed_id                IN NUMBER,
        p_admission_source      IN VARCHAR2 DEFAULT NULL,
        p_chief_complaint       IN VARCHAR2,
        p_preliminary_diagnosis IN VARCHAR2 DEFAULT NULL,
        p_admission_id          OUT NUMBER
    );

    -- Discharge patient
    PROCEDURE DISCHARGE_PATIENT(
        p_admission_id          IN NUMBER,
        p_discharge_date        IN TIMESTAMP,
        p_discharge_disposition IN VARCHAR2,
        p_final_diagnosis       IN VARCHAR2,
        p_discharge_summary     IN CLOB DEFAULT NULL,
        p_followup_instructions IN CLOB DEFAULT NULL,
        p_discharge_medications IN CLOB DEFAULT NULL,
        p_diet_instructions     IN CLOB DEFAULT NULL
    );

    -- Transfer patient to different department/room
    PROCEDURE TRANSFER_PATIENT(
        p_admission_id          IN NUMBER,
        p_new_department_id     IN NUMBER DEFAULT NULL,
        p_new_room_id           IN NUMBER DEFAULT NULL,
        p_new_bed_id            IN NUMBER DEFAULT NULL,
        p_transfer_reason       IN VARCHAR2,
        p_transfer_notes        IN CLOB DEFAULT NULL,
        p_transfer_id           OUT NUMBER
    );

    -- Get available beds
    FUNCTION GET_AVAILABLE_BEDS(
        p_hospital_id           IN NUMBER,
        p_department_id         IN NUMBER DEFAULT NULL,
        p_bed_type              IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    -- Get current admissions summary
    FUNCTION GET_CURRENT_ADMISSIONS(
        p_hospital_id           IN NUMBER,
        p_department_id         IN NUMBER DEFAULT NULL,
        p_status                IN VARCHAR2 DEFAULT 'ADMITTED'
    ) RETURN SYS_REFCURSOR;

    -- Calculate length of stay
    FUNCTION GET_LENGTH_OF_STAY(
        p_admission_id          IN NUMBER
    ) RETURN NUMBER;

END PKG_ADMISSION_DISCHARGE;
/

CREATE OR REPLACE PACKAGE BODY PKG_ADMISSION_DISCHARGE IS

    PROCEDURE ADMIT_PATIENT(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_admission_type        IN VARCHAR2,
        p_department_id         IN NUMBER,
        p_attending_doctor      IN NUMBER,
        p_room_id               IN NUMBER,
        p_bed_id                IN NUMBER,
        p_admission_source      IN VARCHAR2 DEFAULT NULL,
        p_chief_complaint       IN VARCHAR2,
        p_preliminary_diagnosis IN VARCHAR2 DEFAULT NULL,
        p_admission_id          OUT NUMBER
    ) IS
        v_admission_number VARCHAR2(50);
    BEGIN
        -- Generate admission number
        SELECT 'ADM-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' ||
               LPAD(HOSPITALS_BILL_SEQ.NEXTVAL, 5, '0')
        INTO v_admission_number FROM DUAL;

        -- Create admission record
        INSERT INTO PATIENT_ADMISSIONS (
            PATIENT_ID, HOSPITAL_ID, ADMISSION_NUMBER, ADMISSION_DATE,
            ADMISSION_TYPE, DEPARTMENT_ID, ATTENDING_DOCTOR,
            ROOM_ID, BED_ID, ADMISSION_SOURCE,
            ADMISSION_STATUS
        ) VALUES (
            p_patient_id, p_hospital_id, v_admission_number, SYSTIMESTAMP,
            p_admission_type, p_department_id, p_attending_doctor,
            p_room_id, p_bed_id, p_admission_source,
            'ADMITTED'
        ) RETURNING ADMISSION_ID INTO p_admission_id;

        -- Update bed status
        UPDATE BEDS
        SET BED_STATUS = 'OCCUPIED',
            CURRENT_PATIENT_ID = p_patient_id,
            OCCUPIED_DATE = SYSTIMESTAMP
        WHERE BED_ID = p_bed_id;

        -- Create initial medical record
        INSERT INTO MEDICAL_RECORDS (
            PATIENT_ID, HOSPITAL_ID, ADMISSION_ID, DOCTOR_ID,
            RECORD_DATE, RECORD_TYPE, CHIEF_COMPLAINT, DIAGNOSIS
        ) VALUES (
            p_patient_id, p_hospital_id, p_admission_id, p_attending_doctor,
            SYSTIMESTAMP, 'ADMISSION_NOTE', p_chief_complaint, p_preliminary_diagnosis
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END ADMIT_PATIENT;

    PROCEDURE DISCHARGE_PATIENT(
        p_admission_id          IN NUMBER,
        p_discharge_date        IN TIMESTAMP,
        p_discharge_disposition IN VARCHAR2,
        p_final_diagnosis       IN VARCHAR2,
        p_discharge_summary     IN CLOB DEFAULT NULL,
        p_followup_instructions IN CLOB DEFAULT NULL,
        p_discharge_medications IN CLOB DEFAULT NULL,
        p_diet_instructions     IN CLOB DEFAULT NULL
    ) IS
        v_bed_id NUMBER;
        v_patient_id NUMBER;
        v_hospital_id NUMBER;
        v_doctor_id NUMBER;
    BEGIN
        -- Get admission details
        SELECT BED_ID, PATIENT_ID, HOSPITAL_ID, ATTENDING_DOCTOR
        INTO v_bed_id, v_patient_id, v_hospital_id, v_doctor_id
        FROM PATIENT_ADMISSIONS
        WHERE ADMISSION_ID = p_admission_id;

        -- Update admission record
        UPDATE PATIENT_ADMISSIONS
        SET DISCHARGE_DATE = p_discharge_date,
            DISCHARGE_DISPOSITION = p_discharge_disposition,
            DISCHARGE_SUMMARY = p_discharge_summary,
            ADMISSION_STATUS = 'DISCHARGED'
        WHERE ADMISSION_ID = p_admission_id;

        -- Create discharge medical record
        INSERT INTO MEDICAL_RECORDS (
            PATIENT_ID, HOSPITAL_ID, ADMISSION_ID, DOCTOR_ID,
            RECORD_DATE, RECORD_TYPE, DIAGNOSIS, TREATMENT_PLAN, NOTES
        ) VALUES (
            v_patient_id, v_hospital_id, p_admission_id, v_doctor_id,
            p_discharge_date, 'DISCHARGE_SUMMARY',
            p_final_diagnosis,
            p_followup_instructions,
            p_discharge_summary
        );

        -- Create or update discharge plan
        MERGE INTO DISCHARGE_PLANNING dp
        USING (SELECT p_admission_id AS admission_id FROM DUAL) src
        ON (dp.ADMISSION_ID = src.admission_id)
        WHEN MATCHED THEN
            UPDATE SET
                DISCHARGE_INSTRUCTIONS = p_discharge_summary,
                MEDICATION_EDUCATION = p_discharge_medications,
                DIET_INSTRUCTIONS = p_diet_instructions,
                FOLLOW_UP_APPOINTMENTS = p_followup_instructions,
                PLAN_STATUS = 'COMPLETED'
        WHEN NOT MATCHED THEN
            INSERT (
                ADMISSION_ID, PATIENT_ID, HOSPITAL_ID,
                DISCHARGE_INSTRUCTIONS, MEDICATION_EDUCATION,
                DIET_INSTRUCTIONS, FOLLOW_UP_APPOINTMENTS,
                DISCHARGE_DESTINATION, PLAN_STATUS
            ) VALUES (
                p_admission_id, v_patient_id, v_hospital_id,
                p_discharge_summary, p_discharge_medications,
                p_diet_instructions, p_followup_instructions,
                p_discharge_disposition, 'COMPLETED'
            );

        -- Free up bed
        UPDATE BEDS
        SET BED_STATUS = 'AVAILABLE',
            CURRENT_PATIENT_ID = NULL,
            OCCUPIED_DATE = NULL
        WHERE BED_ID = v_bed_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END DISCHARGE_PATIENT;

    PROCEDURE TRANSFER_PATIENT(
        p_admission_id          IN NUMBER,
        p_new_department_id     IN NUMBER DEFAULT NULL,
        p_new_room_id           IN NUMBER DEFAULT NULL,
        p_new_bed_id            IN NUMBER DEFAULT NULL,
        p_transfer_reason       IN VARCHAR2,
        p_transfer_notes        IN CLOB DEFAULT NULL,
        p_transfer_id           OUT NUMBER
    ) IS
        v_old_bed_id NUMBER;
        v_old_department_id NUMBER;
        v_patient_id NUMBER;
    BEGIN
        -- Get current admission info
        SELECT BED_ID, DEPARTMENT_ID, PATIENT_ID
        INTO v_old_bed_id, v_old_department_id, v_patient_id
        FROM PATIENT_ADMISSIONS
        WHERE ADMISSION_ID = p_admission_id;

        -- Create transfer record (using PATIENT_TRANSFERS table if exists)
        -- If table doesn't exist, you can log in medical records instead

        -- Update admission with new location
        UPDATE PATIENT_ADMISSIONS
        SET DEPARTMENT_ID = COALESCE(p_new_department_id, DEPARTMENT_ID),
            ROOM_ID = COALESCE(p_new_room_id, ROOM_ID),
            BED_ID = COALESCE(p_new_bed_id, BED_ID)
        WHERE ADMISSION_ID = p_admission_id;

        -- Free old bed if changing beds
        IF p_new_bed_id IS NOT NULL AND p_new_bed_id != v_old_bed_id THEN
            UPDATE BEDS
            SET BED_STATUS = 'AVAILABLE',
                CURRENT_PATIENT_ID = NULL,
                OCCUPIED_DATE = NULL
            WHERE BED_ID = v_old_bed_id;

            -- Occupy new bed
            UPDATE BEDS
            SET BED_STATUS = 'OCCUPIED',
                CURRENT_PATIENT_ID = v_patient_id,
                OCCUPIED_DATE = SYSTIMESTAMP
            WHERE BED_ID = p_new_bed_id;
        END IF;

        -- Log transfer in medical records
        INSERT INTO MEDICAL_RECORDS (
            PATIENT_ID, ADMISSION_ID, RECORD_DATE, RECORD_TYPE, NOTES
        )
        SELECT PATIENT_ID, ADMISSION_ID, SYSTIMESTAMP, 'TRANSFER',
               'Transfer Reason: ' || p_transfer_reason || CHR(10) ||
               'Transfer Notes: ' || COALESCE(p_transfer_notes, 'N/A')
        FROM PATIENT_ADMISSIONS
        WHERE ADMISSION_ID = p_admission_id
        RETURNING RECORD_ID INTO p_transfer_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END TRANSFER_PATIENT;

    FUNCTION GET_AVAILABLE_BEDS(
        p_hospital_id           IN NUMBER,
        p_department_id         IN NUMBER DEFAULT NULL,
        p_bed_type              IN VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT b.BED_ID,
                   b.BED_NUMBER,
                   r.ROOM_NUMBER,
                   b.BED_TYPE,
                   d.DEPARTMENT_NAME,
                   b.BED_STATUS
            FROM BEDS b
            JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
            JOIN DEPARTMENTS d ON r.DEPARTMENT_ID = d.DEPARTMENT_ID
            WHERE b.HOSPITAL_ID = p_hospital_id
              AND b.BED_STATUS = 'AVAILABLE'
              AND (p_department_id IS NULL OR d.DEPARTMENT_ID = p_department_id)
              AND (p_bed_type IS NULL OR b.BED_TYPE = p_bed_type)
            ORDER BY d.DEPARTMENT_NAME, r.ROOM_NUMBER, b.BED_NUMBER;

        RETURN v_cursor;
    END GET_AVAILABLE_BEDS;

    FUNCTION GET_CURRENT_ADMISSIONS(
        p_hospital_id           IN NUMBER,
        p_department_id         IN NUMBER DEFAULT NULL,
        p_status                IN VARCHAR2 DEFAULT 'ADMITTED'
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT pa.ADMISSION_ID,
                   pa.ADMISSION_NUMBER,
                   pa.ADMISSION_DATE,
                   p.PATIENT_NUMBER,
                   p.FIRST_NAME || ' ' || p.LAST_NAME AS PATIENT_NAME,
                   d.DEPARTMENT_NAME,
                   r.ROOM_NUMBER,
                   b.BED_NUMBER,
                   sm.FIRST_NAME || ' ' || sm.LAST_NAME AS ATTENDING_DOCTOR,
                   pa.ADMISSION_STATUS,
                   ROUND((SYSTIMESTAMP - pa.ADMISSION_DATE), 0) AS LENGTH_OF_STAY_DAYS
            FROM PATIENT_ADMISSIONS pa
            JOIN PATIENTS p ON pa.PATIENT_ID = p.PATIENT_ID
            JOIN DEPARTMENTS d ON pa.DEPARTMENT_ID = d.DEPARTMENT_ID
            LEFT JOIN BEDS b ON pa.BED_ID = b.BED_ID
            LEFT JOIN ROOMS r ON b.ROOM_ID = r.ROOM_ID
            LEFT JOIN STAFF_MEMBERS sm ON pa.ATTENDING_DOCTOR = sm.STAFF_ID
            WHERE pa.HOSPITAL_ID = p_hospital_id
              AND (p_department_id IS NULL OR pa.DEPARTMENT_ID = p_department_id)
              AND pa.ADMISSION_STATUS = p_status
            ORDER BY pa.ADMISSION_DATE DESC;

        RETURN v_cursor;
    END GET_CURRENT_ADMISSIONS;

    FUNCTION GET_LENGTH_OF_STAY(
        p_admission_id          IN NUMBER
    ) RETURN NUMBER IS
        v_los NUMBER;
        v_discharge_date TIMESTAMP;
        v_admission_date TIMESTAMP;
    BEGIN
        SELECT ADMISSION_DATE,
               COALESCE(DISCHARGE_DATE, SYSTIMESTAMP)
        INTO v_admission_date, v_discharge_date
        FROM PATIENT_ADMISSIONS
        WHERE ADMISSION_ID = p_admission_id;

        v_los := ROUND((v_discharge_date - v_admission_date), 0);

        RETURN v_los;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_LENGTH_OF_STAY;

END PKG_ADMISSION_DISCHARGE;
/

-- ===================================================================
-- PACKAGE: VITAL SIGNS TRACKING
-- ===================================================================

CREATE OR REPLACE PACKAGE PKG_VITAL_SIGNS IS

    -- Record vital signs
    PROCEDURE RECORD_VITAL_SIGNS(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_admission_id          IN NUMBER DEFAULT NULL,
        p_recorded_by           IN NUMBER,
        p_bp_systolic           IN NUMBER DEFAULT NULL,
        p_bp_diastolic          IN NUMBER DEFAULT NULL,
        p_heart_rate            IN NUMBER DEFAULT NULL,
        p_respiratory_rate      IN NUMBER DEFAULT NULL,
        p_temperature           IN NUMBER DEFAULT NULL,
        p_oxygen_saturation     IN NUMBER DEFAULT NULL,
        p_weight                IN NUMBER DEFAULT NULL,
        p_height                IN NUMBER DEFAULT NULL,
        p_bmi                   IN NUMBER DEFAULT NULL,
        p_pain_score            IN NUMBER DEFAULT NULL,
        p_notes                 IN VARCHAR2 DEFAULT NULL,
        p_vital_id              OUT NUMBER
    );

    -- Get latest vitals for patient
    FUNCTION GET_LATEST_VITALS(
        p_patient_id            IN NUMBER
    ) RETURN SYS_REFCURSOR;

    -- Get vitals trend (last 24 hours)
    FUNCTION GET_VITALS_TREND(
        p_patient_id            IN NUMBER,
        p_hours                 IN NUMBER DEFAULT 24
    ) RETURN SYS_REFCURSOR;

    -- Check for abnormal vitals
    FUNCTION CHECK_ABNORMAL_VITALS(
        p_vital_id              IN NUMBER
    ) RETURN VARCHAR2;

END PKG_VITAL_SIGNS;
/

CREATE OR REPLACE PACKAGE BODY PKG_VITAL_SIGNS IS

    PROCEDURE RECORD_VITAL_SIGNS(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_admission_id          IN NUMBER DEFAULT NULL,
        p_recorded_by           IN NUMBER,
        p_bp_systolic           IN NUMBER DEFAULT NULL,
        p_bp_diastolic          IN NUMBER DEFAULT NULL,
        p_heart_rate            IN NUMBER DEFAULT NULL,
        p_respiratory_rate      IN NUMBER DEFAULT NULL,
        p_temperature           IN NUMBER DEFAULT NULL,
        p_oxygen_saturation     IN NUMBER DEFAULT NULL,
        p_weight                IN NUMBER DEFAULT NULL,
        p_height                IN NUMBER DEFAULT NULL,
        p_bmi                   IN NUMBER DEFAULT NULL,
        p_pain_score            IN NUMBER DEFAULT NULL,
        p_notes                 IN VARCHAR2 DEFAULT NULL,
        p_vital_id              OUT NUMBER
    ) IS
        v_bmi NUMBER;
    BEGIN
        -- Calculate BMI if not provided but height and weight are available
        IF p_bmi IS NULL AND p_weight IS NOT NULL AND p_height IS NOT NULL AND p_height > 0 THEN
            v_bmi := p_weight / ((p_height / 100) * (p_height / 100)); -- Height in cm
        ELSE
            v_bmi := p_bmi;
        END IF;

        INSERT INTO VITAL_SIGNS (
            PATIENT_ID, HOSPITAL_ID, ADMISSION_ID, RECORDED_BY,
            RECORDING_DATE,
            BLOOD_PRESSURE_SYSTOLIC, BLOOD_PRESSURE_DIASTOLIC,
            HEART_RATE, RESPIRATORY_RATE, TEMPERATURE,
            OXYGEN_SATURATION, WEIGHT, HEIGHT, BMI,
            PAIN_SCORE, NOTES
        ) VALUES (
            p_patient_id, p_hospital_id, p_admission_id, p_recorded_by,
            SYSTIMESTAMP,
            p_bp_systolic, p_bp_diastolic,
            p_heart_rate, p_respiratory_rate, p_temperature,
            p_oxygen_saturation, p_weight, p_height, v_bmi,
            p_pain_score, p_notes
        ) RETURNING VITAL_ID INTO p_vital_id;

        COMMIT;
    END RECORD_VITAL_SIGNS;

    FUNCTION GET_LATEST_VITALS(
        p_patient_id            IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT *
            FROM (
                SELECT vs.*,
                       sm.FIRST_NAME || ' ' || sm.LAST_NAME AS RECORDED_BY_NAME,
                       BLOOD_PRESSURE_SYSTOLIC || '/' || BLOOD_PRESSURE_DIASTOLIC AS BLOOD_PRESSURE
                FROM VITAL_SIGNS vs
                LEFT JOIN STAFF_MEMBERS sm ON vs.RECORDED_BY = sm.STAFF_ID
                WHERE vs.PATIENT_ID = p_patient_id
                ORDER BY vs.RECORDING_DATE DESC
            )
            WHERE ROWNUM = 1;

        RETURN v_cursor;
    END GET_LATEST_VITALS;

    FUNCTION GET_VITALS_TREND(
        p_patient_id            IN NUMBER,
        p_hours                 IN NUMBER DEFAULT 24
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT RECORDING_DATE,
                   BLOOD_PRESSURE_SYSTOLIC,
                   BLOOD_PRESSURE_DIASTOLIC,
                   HEART_RATE,
                   RESPIRATORY_RATE,
                   TEMPERATURE,
                   OXYGEN_SATURATION,
                   PAIN_SCORE
            FROM VITAL_SIGNS
            WHERE PATIENT_ID = p_patient_id
              AND RECORDING_DATE >= SYSTIMESTAMP - (p_hours / 24)
            ORDER BY RECORDING_DATE;

        RETURN v_cursor;
    END GET_VITALS_TREND;

    FUNCTION CHECK_ABNORMAL_VITALS(
        p_vital_id              IN NUMBER
    ) RETURN VARCHAR2 IS
        v_status VARCHAR2(4000) := '';
        v_bp_sys NUMBER;
        v_bp_dia NUMBER;
        v_hr NUMBER;
        v_rr NUMBER;
        v_temp NUMBER;
        v_spo2 NUMBER;
    BEGIN
        SELECT BLOOD_PRESSURE_SYSTOLIC, BLOOD_PRESSURE_DIASTOLIC,
               HEART_RATE, RESPIRATORY_RATE, TEMPERATURE, OXYGEN_SATURATION
        INTO v_bp_sys, v_bp_dia, v_hr, v_rr, v_temp, v_spo2
        FROM VITAL_SIGNS
        WHERE VITAL_ID = p_vital_id;

        -- Check Blood Pressure
        IF v_bp_sys < 90 OR v_bp_sys > 180 OR v_bp_dia < 60 OR v_bp_dia > 120 THEN
            v_status := v_status || 'Abnormal BP; ';
        END IF;

        -- Check Heart Rate
        IF v_hr < 60 OR v_hr > 100 THEN
            v_status := v_status || 'Abnormal HR; ';
        END IF;

        -- Check Respiratory Rate
        IF v_rr < 12 OR v_rr > 20 THEN
            v_status := v_status || 'Abnormal RR; ';
        END IF;

        -- Check Temperature
        IF v_temp < 36.1 OR v_temp > 37.8 THEN
            v_status := v_status || 'Abnormal Temp; ';
        END IF;

        -- Check Oxygen Saturation
        IF v_spo2 < 95 THEN
            v_status := v_status || 'Low SpO2; ';
        END IF;

        IF LENGTH(v_status) > 0 THEN
            RETURN RTRIM(v_status, '; ');
        ELSE
            RETURN 'Normal';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N/A';
    END CHECK_ABNORMAL_VITALS;

END PKG_VITAL_SIGNS;
/

-- ===================================================================
-- PACKAGE: BILLING AND PAYMENT PROCESSING
-- ===================================================================

CREATE OR REPLACE PACKAGE PKG_BILLING IS

    -- Generate bill for admission
    PROCEDURE GENERATE_BILL(
        p_admission_id          IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_patient_id            IN NUMBER,
        p_include_services      IN CHAR DEFAULT 'Y',
        p_include_medications   IN CHAR DEFAULT 'Y',
        p_include_lab           IN CHAR DEFAULT 'Y',
        p_bill_id               OUT NUMBER
    );

    -- Add line item to bill
    PROCEDURE ADD_BILL_ITEM(
        p_bill_id               IN NUMBER,
        p_item_type             IN VARCHAR2,
        p_item_description      IN VARCHAR2,
        p_quantity              IN NUMBER,
        p_unit_price            IN NUMBER,
        p_service_date          IN DATE DEFAULT SYSDATE
    );

    -- Process payment
    PROCEDURE PROCESS_PAYMENT(
        p_bill_id               IN NUMBER,
        p_payment_amount        IN NUMBER,
        p_payment_method        IN VARCHAR2,
        p_reference_number      IN VARCHAR2 DEFAULT NULL,
        p_received_by           IN NUMBER DEFAULT NULL,
        p_payment_id            OUT NUMBER
    );

    -- Submit insurance claim
    PROCEDURE SUBMIT_INSURANCE_CLAIM(
        p_bill_id               IN NUMBER,
        p_insurance_id          IN NUMBER,
        p_claim_amount          IN NUMBER,
        p_authorization_number  IN VARCHAR2 DEFAULT NULL,
        p_claim_id              OUT NUMBER
    );

    -- Get patient balance
    FUNCTION GET_PATIENT_BALANCE(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER
    ) RETURN NUMBER;

    -- Get billing summary
    FUNCTION GET_BILLING_SUMMARY(
        p_bill_id               IN NUMBER
    ) RETURN SYS_REFCURSOR;

END PKG_BILLING;
/

CREATE OR REPLACE PACKAGE BODY PKG_BILLING IS

    PROCEDURE GENERATE_BILL(
        p_admission_id          IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_patient_id            IN NUMBER,
        p_include_services      IN CHAR DEFAULT 'Y',
        p_include_medications   IN CHAR DEFAULT 'Y',
        p_include_lab           IN CHAR DEFAULT 'Y',
        p_bill_id               OUT NUMBER
    ) IS
        v_bill_number VARCHAR2(50);
        v_total_amount NUMBER := 0;
    BEGIN
        -- Generate bill number
        SELECT 'BILL-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' ||
               LPAD(HOSPITALS_BILL_SEQ.NEXTVAL, 6, '0')
        INTO v_bill_number FROM DUAL;

        -- Create bill
        INSERT INTO BILLING (
            HOSPITAL_ID, PATIENT_ID, ADMISSION_ID,
            BILL_NUMBER, BILL_DATE, BILLING_STATUS
        ) VALUES (
            p_hospital_id, p_patient_id, p_admission_id,
            v_bill_number, SYSDATE, 'PENDING'
        ) RETURNING BILL_ID INTO p_bill_id;

        -- Add admission/room charges
        IF p_include_services = 'Y' THEN
            INSERT INTO BILLING_ITEMS (
                BILL_ID, ITEM_TYPE, ITEM_DESCRIPTION, QUANTITY,
                UNIT_PRICE, SERVICE_DATE
            )
            SELECT p_bill_id, 'ROOM_CHARGE', 'Room Charge - ' || d.DEPARTMENT_NAME,
                   ROUND((COALESCE(pa.DISCHARGE_DATE, SYSTIMESTAMP) - pa.ADMISSION_DATE), 0),
                   500, -- Default room charge per day
                   TRUNC(pa.ADMISSION_DATE)
            FROM PATIENT_ADMISSIONS pa
            JOIN DEPARTMENTS d ON pa.DEPARTMENT_ID = d.DEPARTMENT_ID
            WHERE pa.ADMISSION_ID = p_admission_id;
        END IF;

        -- Add medication charges
        IF p_include_medications = 'Y' THEN
            INSERT INTO BILLING_ITEMS (
                BILL_ID, ITEM_TYPE, ITEM_DESCRIPTION, QUANTITY,
                UNIT_PRICE, SERVICE_DATE
            )
            SELECT p_bill_id, 'MEDICATION', m.MEDICATION_NAME,
                   pr.DISPENSED_QUANTITY,
                   m.COST_PRICE * 1.2, -- 20% markup
                   TRUNC(pr.DISPENSED_DATE)
            FROM PRESCRIPTIONS pr
            JOIN MEDICATIONS m ON pr.MEDICATION_ID = m.MEDICATION_ID
            WHERE pr.ADMISSION_ID = p_admission_id
              AND pr.DISPENSED_QUANTITY > 0;
        END IF;

        -- Add lab test charges
        IF p_include_lab = 'Y' THEN
            INSERT INTO BILLING_ITEMS (
                BILL_ID, ITEM_TYPE, ITEM_DESCRIPTION, QUANTITY,
                UNIT_PRICE, SERVICE_DATE
            )
            SELECT p_bill_id, 'LAB_TEST', lt.TEST_NAME,
                   1,
                   lt.TEST_COST,
                   TRUNC(lo.ORDER_DATE)
            FROM LAB_ORDERS lo
            JOIN LAB_TESTS lt ON lo.TEST_ID = lt.TEST_ID
            WHERE lo.ADMISSION_ID = p_admission_id;
        END IF;

        -- Calculate total
        SELECT NVL(SUM(QUANTITY * UNIT_PRICE), 0)
        INTO v_total_amount
        FROM BILLING_ITEMS
        WHERE BILL_ID = p_bill_id;

        -- Update bill totals
        UPDATE BILLING
        SET TOTAL_AMOUNT = v_total_amount,
            PATIENT_AMOUNT = v_total_amount, -- Before insurance
            DUE_DATE = SYSDATE + 30
        WHERE BILL_ID = p_bill_id;

        COMMIT;
    END GENERATE_BILL;

    PROCEDURE ADD_BILL_ITEM(
        p_bill_id               IN NUMBER,
        p_item_type             IN VARCHAR2,
        p_item_description      IN VARCHAR2,
        p_quantity              IN NUMBER,
        p_unit_price            IN NUMBER,
        p_service_date          IN DATE DEFAULT SYSDATE
    ) IS
        v_total_amount NUMBER;
    BEGIN
        INSERT INTO BILLING_ITEMS (
            BILL_ID, ITEM_TYPE, ITEM_DESCRIPTION,
            QUANTITY, UNIT_PRICE, SERVICE_DATE
        ) VALUES (
            p_bill_id, p_item_type, p_item_description,
            p_quantity, p_unit_price, p_service_date
        );

        -- Recalculate bill total
        SELECT NVL(SUM(QUANTITY * UNIT_PRICE), 0)
        INTO v_total_amount
        FROM BILLING_ITEMS
        WHERE BILL_ID = p_bill_id;

        UPDATE BILLING
        SET TOTAL_AMOUNT = v_total_amount,
            PATIENT_AMOUNT = v_total_amount
        WHERE BILL_ID = p_bill_id;

        COMMIT;
    END ADD_BILL_ITEM;

    PROCEDURE PROCESS_PAYMENT(
        p_bill_id               IN NUMBER,
        p_payment_amount        IN NUMBER,
        p_payment_method        IN VARCHAR2,
        p_reference_number      IN VARCHAR2 DEFAULT NULL,
        p_received_by           IN NUMBER DEFAULT NULL,
        p_payment_id            OUT NUMBER
    ) IS
        v_hospital_id NUMBER;
        v_patient_id NUMBER;
    BEGIN
        SELECT HOSPITAL_ID, PATIENT_ID
        INTO v_hospital_id, v_patient_id
        FROM BILLING
        WHERE BILL_ID = p_bill_id;

        INSERT INTO PAYMENTS (
            BILL_ID, HOSPITAL_ID, PATIENT_ID,
            PAYMENT_DATE, PAYMENT_AMOUNT, PAYMENT_METHOD,
            REFERENCE_NUMBER, RECEIVED_BY, PAYMENT_STATUS
        ) VALUES (
            p_bill_id, v_hospital_id, v_patient_id,
            SYSTIMESTAMP, p_payment_amount, p_payment_method,
            p_reference_number, p_received_by, 'COMPLETED'
        ) RETURNING PAYMENT_ID INTO p_payment_id;

        -- The trigger TRG_PAYMENT_UPDATE_BILLING will automatically update bill status

        COMMIT;
    END PROCESS_PAYMENT;

    PROCEDURE SUBMIT_INSURANCE_CLAIM(
        p_bill_id               IN NUMBER,
        p_insurance_id          IN NUMBER,
        p_claim_amount          IN NUMBER,
        p_authorization_number  IN VARCHAR2 DEFAULT NULL,
        p_claim_id              OUT NUMBER
    ) IS
        v_hospital_id NUMBER;
        v_claim_number VARCHAR2(100);
    BEGIN
        SELECT HOSPITAL_ID INTO v_hospital_id
        FROM BILLING WHERE BILL_ID = p_bill_id;

        -- Generate claim number
        SELECT 'CLM-' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '-' ||
               LPAD(CLAIM_NUMBER_SEQ.NEXTVAL, 6, '0')
        INTO v_claim_number FROM DUAL;

        INSERT INTO INSURANCE_CLAIM_DETAILS (
            BILL_ID, INSURANCE_ID, HOSPITAL_ID,
            CLAIM_NUMBER, CLAIM_DATE, CLAIM_AMOUNT,
            AUTHORIZATION_NUMBER, CLAIM_STATUS, SUBMISSION_DATE
        ) VALUES (
            p_bill_id, p_insurance_id, v_hospital_id,
            v_claim_number, SYSDATE, p_claim_amount,
            p_authorization_number, 'SUBMITTED', SYSDATE
        ) RETURNING CLAIM_DETAIL_ID INTO p_claim_id;

        -- Update billing record
        UPDATE BILLING
        SET INSURANCE_AMOUNT = p_claim_amount,
            PATIENT_AMOUNT = TOTAL_AMOUNT - p_claim_amount
        WHERE BILL_ID = p_bill_id;

        COMMIT;
    END SUBMIT_INSURANCE_CLAIM;

    FUNCTION GET_PATIENT_BALANCE(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER
    ) RETURN NUMBER IS
        v_balance NUMBER;
    BEGIN
        SELECT NVL(SUM(
            b.PATIENT_AMOUNT - NVL((
                SELECT SUM(p.PAYMENT_AMOUNT)
                FROM PAYMENTS p
                WHERE p.BILL_ID = b.BILL_ID
                  AND p.PAYMENT_STATUS = 'COMPLETED'
            ), 0)
        ), 0)
        INTO v_balance
        FROM BILLING b
        WHERE b.PATIENT_ID = p_patient_id
          AND b.HOSPITAL_ID = p_hospital_id
          AND b.BILLING_STATUS NOT IN ('PAID', 'CANCELLED');

        RETURN v_balance;
    END GET_PATIENT_BALANCE;

    FUNCTION GET_BILLING_SUMMARY(
        p_bill_id               IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT bi.ITEM_DESCRIPTION,
                   bi.ITEM_TYPE,
                   bi.QUANTITY,
                   bi.UNIT_PRICE,
                   bi.QUANTITY * bi.UNIT_PRICE AS TOTAL,
                   bi.SERVICE_DATE
            FROM BILLING_ITEMS bi
            WHERE bi.BILL_ID = p_bill_id
            ORDER BY bi.SERVICE_DATE, bi.ITEM_TYPE;

        RETURN v_cursor;
    END GET_BILLING_SUMMARY;

END PKG_BILLING;
/

-- ===================================================================
-- EMERGENCY TRIAGE API
-- ===================================================================

CREATE OR REPLACE PACKAGE PKG_EMERGENCY IS

    -- Register emergency patient
    PROCEDURE REGISTER_EMERGENCY_PATIENT(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_arrival_method        IN VARCHAR2,
        p_chief_complaint       IN VARCHAR2,
        p_triage_level          IN VARCHAR2,
        p_triage_nurse          IN NUMBER,
        p_pain_score            IN NUMBER DEFAULT NULL,
        p_triage_id             OUT NUMBER
    );

    -- Assign patient to doctor
    PROCEDURE ASSIGN_TO_DOCTOR(
        p_triage_id             IN NUMBER,
        p_doctor_id             IN NUMBER
    );

    -- Update triage status
    PROCEDURE UPDATE_TRIAGE_STATUS(
        p_triage_id             IN NUMBER,
        p_new_status            IN VARCHAR2,
        p_disposition           IN VARCHAR2 DEFAULT NULL
    );

    -- Get emergency board
    FUNCTION GET_EMERGENCY_BOARD(
        p_hospital_id           IN NUMBER
    ) RETURN SYS_REFCURSOR;

END PKG_EMERGENCY;
/

CREATE OR REPLACE PACKAGE BODY PKG_EMERGENCY IS

    PROCEDURE REGISTER_EMERGENCY_PATIENT(
        p_patient_id            IN NUMBER,
        p_hospital_id           IN NUMBER,
        p_arrival_method        IN VARCHAR2,
        p_chief_complaint       IN VARCHAR2,
        p_triage_level          IN VARCHAR2,
        p_triage_nurse          IN NUMBER,
        p_pain_score            IN NUMBER DEFAULT NULL,
        p_triage_id             OUT NUMBER
    ) IS
    BEGIN
        INSERT INTO EMERGENCY_TRIAGE (
            PATIENT_ID, HOSPITAL_ID, ARRIVAL_DATE,
            ARRIVAL_METHOD, CHIEF_COMPLAINT, TRIAGE_LEVEL,
            TRIAGE_NURSE, PAIN_SCORE, TRIAGE_START_TIME, STATUS
        ) VALUES (
            p_patient_id, p_hospital_id, SYSTIMESTAMP,
            p_arrival_method, p_chief_complaint, p_triage_level,
            p_triage_nurse, p_pain_score, SYSTIMESTAMP, 'WAITING'
        ) RETURNING TRIAGE_ID INTO p_triage_id;

        COMMIT;
    END REGISTER_EMERGENCY_PATIENT;

    PROCEDURE ASSIGN_TO_DOCTOR(
        p_triage_id             IN NUMBER,
        p_doctor_id             IN NUMBER
    ) IS
    BEGIN
        UPDATE EMERGENCY_TRIAGE
        SET ASSIGNED_TO_DOCTOR = p_doctor_id,
            STATUS = 'IN_PROGRESS'
        WHERE TRIAGE_ID = p_triage_id;

        COMMIT;
    END ASSIGN_TO_DOCTOR;

    PROCEDURE UPDATE_TRIAGE_STATUS(
        p_triage_id             IN NUMBER,
        p_new_status            IN VARCHAR2,
        p_disposition           IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE EMERGENCY_TRIAGE
        SET STATUS = p_new_status,
            DISPOSITION = COALESCE(p_disposition, DISPOSITION),
            TRIAGE_END_TIME = CASE WHEN p_new_status IN ('COMPLETED', 'DISCHARGED', 'ADMITTED') THEN SYSTIMESTAMP ELSE TRIAGE_END_TIME END
        WHERE TRIAGE_ID = p_triage_id;

        COMMIT;
    END UPDATE_TRIAGE_STATUS;

    FUNCTION GET_EMERGENCY_BOARD(
        p_hospital_id           IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT * FROM V_EMERGENCY_TRIAGE_BOARD
            WHERE HOSPITAL_ID = p_hospital_id;

        RETURN v_cursor;
    END GET_EMERGENCY_BOARD;

END PKG_EMERGENCY;
/

-- ===================================================================
-- COMPLETION MESSAGE
-- ===================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Clinical API Packages Created Successfully');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Packages Created:');
    DBMS_OUTPUT.PUT_LINE('- PKG_ADMISSION_DISCHARGE');
    DBMS_OUTPUT.PUT_LINE('- PKG_VITAL_SIGNS');
    DBMS_OUTPUT.PUT_LINE('- PKG_BILLING');
    DBMS_OUTPUT.PUT_LINE('- PKG_EMERGENCY');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Ready for Oracle APEX Integration');
    DBMS_OUTPUT.PUT_LINE('============================================');
END;
/

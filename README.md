# Central Sydney Hospital Database Schema - README
## File Information
**Filename:** `central_hospital_schema.sql`  
**Database:** Central Sydney Hospital (CSH) Information System   
**PostgreSQL Version:** 16.2

## Overview
This document provides comprehensive documentation for the Central Sydney Hospital (CSH) database schema. The schema models a complete hospital information system including departments, staff management, patient admissions, and billing operations.

## Database Design

<img width="1270" height="669" alt="image" src="https://github.com/user-attachments/assets/9c5c7377-db33-4f76-a18d-7a5e395ee7f4" />

## Quick Start Guide

### Installation Steps
1. Ensure PostgreSQL 16.2 is installed on your system
2. Create a new database:
   ```bash
   createdb csh_hospital
   ```

3. Execute the schema file:
   ```bash
   psql -d csh_hospital -f central_hospital_schema.sql
   ```

4. Verify installation:
   ```sql
   \dt  -- List all tables
   SELECT COUNT(*) FROM Patient;
   SELECT COUNT(*) FROM Staff;
   SELECT COUNT(*) FROM Department;
   ```

### Expected Output
- 13 tables created successfully
- Sample data populated (4 departments, 4 staff, 3 patients, 3 admissions)
- All constraints enforced
- No errors or warnings

## Database Schema Overview

### Entity-Relationship Summary

```
HOSPITAL SYSTEM
│
├── DEPARTMENTS & FACILITIES
│   ├── Department (4 records)
│   ├── Ward (3 records)
│   └── Bed (3 records)
│
├── STAFF MANAGEMENT
│   ├── Staff (4 records)
│   ├── Doctor (2 records)
│   ├── Nurse (2 records)
│   ├── Specialty (3 records)
│   └── DoctorSpecialty (2 records)
│
├── PATIENT CARE
│   ├── Patient (3 records)
│   ├── Admission (3 records)
│   ├── PlannedAdmission (2 records)
│   └── EmergencyAdmission (1 record)
│
└── BILLING & PAYMENT
    ├── BillingStatement (2 records)
    ├── Invoice (2 records)
    └── Payment (2 records)
```

## Detailed Table Documentation

### 1. Department Tables

#### **Department**
Stores information about hospital departments.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| dept_name | VARCHAR(100) | PRIMARY KEY | Unique department name |
| operating_hours | VARCHAR(100) | NOT NULL | Daily operating hours |
| staff_headcount | INTEGER | DEFAULT 0, ≥ 0 | Number of staff in department |

**Sample Data:**
- General: 10:00 AM - 8:00 PM
- Emergency Department: 24 Hours
- Pediatrics: 10:00 AM - 8:00 PM
- Surgery: 8:00 AM - 6:00 PM

#### **Ward**
Represents wards within departments (General or ICU).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| ward_id | SERIAL | PRIMARY KEY | Auto-increment ward ID |
| ward_name | VARCHAR(100) | NOT NULL | Ward name |
| dept_name | VARCHAR(100) | FK → Department | Parent department |
| ward_type | VARCHAR(20) | IN ('General', 'ICU') | Ward classification |

**Relationships:**
- Many-to-One with Department (CASCADE on delete)

#### **Bed**
Individual beds with specific dimensions and costs.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| bed_id | SERIAL | PRIMARY KEY | Auto-increment bed ID |
| ward_id | INTEGER | FK → Ward | Parent ward |
| bed_length | DECIMAL(5,2) | > 0 AND ≤ 2.13 | Length in meters |
| bed_width | DECIMAL(5,2) | > 0 AND ≤ 1.27 | Width in meters |
| mattress_thickness | DECIMAL(5,2) | ≥ 15.24 AND ≤ 17.78 | Thickness in cm |
| comfort_level | VARCHAR(50) | - | Comfort description |
| bed_cost | DECIMAL(10,2) | ≥ 0 | Daily bed cost |

**Relationships:**
- Many-to-One with Ward (CASCADE on delete)

### 2. Staff Tables

#### **Staff**
Base table for all hospital employees.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| staff_id | SERIAL | PRIMARY KEY | Auto-increment staff ID |
| full_name | VARCHAR(255) | NOT NULL | Staff full name |
| mobile | VARCHAR(20) | NOT NULL | Mobile phone |
| address | VARCHAR(255) | NOT NULL | Residential address |
| salary | DECIMAL(10,2) | NOT NULL, > 0 | Annual salary |
| dept_name | VARCHAR(100) | FK → Department | Assigned department |
| staff_type | VARCHAR(20) | IN ('Doctor', 'Nurse', 'Allied Health') | Staff category |

**Relationships:**
- Many-to-One with Department (SET NULL on delete)

#### **Doctor**
Extends Staff for medical doctors.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| doctor_id | INTEGER | PRIMARY KEY, FK → Staff | Reference to staff record |

**Relationships:**
- One-to-One with Staff (CASCADE on delete)
- One-to-Many with DoctorSpecialty

#### **Specialty**
Medical specialties available at CSH.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| specialty_name | VARCHAR(100) | PRIMARY KEY | Unique specialty name |

**Sample Data:**
- General Medicine
- Pediatrics
- Emergency Medicine

#### **DoctorSpecialty**
Junction table linking doctors to their specialties (1-5 per doctor).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| doctor_id | INTEGER | PK, FK → Doctor | Doctor reference |
| specialty_name | VARCHAR(100) | PK, FK → Specialty | Specialty reference |
| training_date | DATE | NOT NULL | Date of specialty training |
| proficiency_level | VARCHAR(50) | NOT NULL | Skill level |

**Relationships:**
- Many-to-Many between Doctor and Specialty

#### **Nurse**
Extends Staff for nursing staff.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| nurse_id | INTEGER | PRIMARY KEY, FK → Staff | Reference to staff record |
| wwcc_clearance | BOOLEAN | DEFAULT FALSE | Working with Children Check status |
| wwcc_expiry_date | DATE | Required if clearance = TRUE | Clearance expiry (3-year validity) |

**Relationships:**
- One-to-One with Staff (CASCADE on delete)

### 3. Patient & Admission Tables

#### **Patient**
Registered patients at CSH.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| patient_id | SERIAL | PRIMARY KEY | Auto-increment patient ID |
| full_name | VARCHAR(255) | NOT NULL | Patient full name |
| email | VARCHAR(255) | NOT NULL | Email address |
| address | VARCHAR(255) | NOT NULL | Residential address |
| date_of_birth | DATE | NOT NULL | Date of birth |
| mobile | VARCHAR(20) | NOT NULL | Mobile phone |
| emergency_contact_name | VARCHAR(255) | NOT NULL | Emergency contact name |
| emergency_contact_phone | VARCHAR(20) | NOT NULL | Emergency contact phone |
| insurance_number | VARCHAR(100) | NOT NULL | Insurance policy number |

#### **Admission**
Central table for all patient admissions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| admission_id | SERIAL | PRIMARY KEY | Auto-increment admission ID |
| patient_id | INTEGER | FK → Patient | Patient reference |
| admission_date | TIMESTAMP | NOT NULL | Date and time of admission |
| admission_type | VARCHAR(20) | IN ('Planned', 'Emergency') | Admission category |
| nurse_id | INTEGER | FK → Nurse | Admitting nurse |
| doctor_id | INTEGER | FK → Doctor | Attending doctor |
| discharge_date | DATE | - | Date of discharge (NULL if current) |

**Relationships:**
- Many-to-One with Patient (CASCADE on delete)
- Many-to-One with Nurse (SET NULL on delete)
- Many-to-One with Doctor (SET NULL on delete)

#### **PlannedAdmission**
Planned admission-specific details.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| admission_id | INTEGER | PRIMARY KEY, FK → Admission | Admission reference |
| referring_practitioner | VARCHAR(255) | NOT NULL | Referring doctor name |
| reference_number | VARCHAR(100) | NOT NULL, UNIQUE | Unique referral number |

**Relationships:**
- One-to-One with Admission (CASCADE on delete)

#### **EmergencyAdmission**
Emergency admission-specific details.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| admission_id | INTEGER | PRIMARY KEY, FK → Admission | Admission reference |
| triage_nurse_id | INTEGER | FK → Nurse | Nurse who performed triage |
| patient_condition | VARCHAR(500) | - | Description of condition |
| severity_level | VARCHAR(20) | IN ('Critical', 'High', 'Medium', 'Low') | Triage severity |

**Relationships:**
- One-to-One with Admission (CASCADE on delete)
- Many-to-One with Nurse for triage (SET NULL on delete)

### 4. Billing & Payment Tables

#### **BillingStatement**
Generated upon patient discharge.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| billing_id | SERIAL | PRIMARY KEY | Auto-increment billing ID |
| admission_id | INTEGER | FK → Admission, UNIQUE | One bill per admission |
| discharge_date | DATE | NOT NULL | Date of discharge |
| services_description | TEXT | - | Description of services |
| total_cost | DECIMAL(10,2) | > 0 AND ≤ 50000 | Total service cost |
| insurance_covered_amount | DECIMAL(10,2) | ≥ 0, ≤ total_cost | Amount covered by insurance |
| remaining_balance | DECIMAL(10,2) | GENERATED | Auto-calculated balance owed |

**Formula:** `remaining_balance = total_cost - insurance_covered_amount`

**Relationships:**
- One-to-One with Admission (CASCADE on delete)

#### **Invoice**
Invoice for amount owed by patient.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| invoice_id | SERIAL | PRIMARY KEY | Auto-increment invoice ID |
| billing_id | INTEGER | FK → BillingStatement | Billing reference |
| issue_date | DATE | NOT NULL, DEFAULT CURRENT_DATE | Date invoice issued |
| amount_due | DECIMAL(10,2) | ≥ 0 | Amount owed |

**Relationships:**
- Many-to-One with BillingStatement (CASCADE on delete)

#### **Payment**
Credit card payment records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| payment_id | SERIAL | PRIMARY KEY | Auto-increment payment ID |
| invoice_id | INTEGER | FK → Invoice | Invoice reference |
| cardholder_name | VARCHAR(255) | NOT NULL | Name on card |
| card_number | VARCHAR(19) | NOT NULL | Card number (16-19 digits) |
| expiry_date | DATE | NOT NULL | Card expiry date |
| cvv | VARCHAR(4) | NOT NULL | Card verification value |
| payment_date | DATE | NOT NULL, DEFAULT CURRENT_DATE | Date of payment |
| payment_amount | DECIMAL(10,2) | > 0 | Amount paid |

**Relationships:**
- Many-to-One with Invoice (CASCADE on delete)

## Constraint Summary

### Assignment Requirements Compliance

| Requirement | Constraint Implementation | Status |
|-------------|---------------------------|--------|
| 1. Date/time fields always have values | NOT NULL on all date/timestamp columns | ✅ |
| 2. Bed dimensions | bed_length: > 0, ≤ 2.13m<br>bed_width: > 0, ≤ 1.27m<br>mattress_thickness: 15.24-17.78cm | ✅ |
| 3. All name fields have values | NOT NULL on full_name, emergency_contact_name, etc. | ✅ |
| 4. Staff salary > 0 | CHECK (salary > 0) | ✅ |
| 5. Patient email required | NOT NULL on Patient.email | ✅ |
| 6. Bill total cost constraints | CHECK (total_cost > 0 AND total_cost <= 50000) | ✅ |
| 7. Non-negative financial values | CHECK (insurance_covered_amount >= 0)<br>CHECK (remaining_balance >= 0 via formula) | ✅ |

### CHECK Constraints

**Dimension Constraints:**
```sql
CHECK (bed_length > 0 AND bed_length <= 2.13)
CHECK (bed_width > 0 AND bed_width <= 1.27)
CHECK (mattress_thickness >= 15.24 AND mattress_thickness <= 17.78)
```

**Financial Constraints:**
```sql
CHECK (salary > 0)
CHECK (total_cost > 0 AND total_cost <= 50000)
CHECK (insurance_covered_amount >= 0)
CHECK (insurance_covered_amount <= total_cost)
CHECK (bed_cost >= 0)
CHECK (payment_amount > 0)
```

**Enumeration Constraints:**
```sql
CHECK (staff_type IN ('Doctor', 'Nurse', 'Allied Health'))
CHECK (admission_type IN ('Planned', 'Emergency'))
CHECK (ward_type IN ('General', 'ICU'))
CHECK (severity_level IN ('Critical', 'High', 'Medium', 'Low'))
```

**Business Logic Constraints:**
```sql
-- WWCC clearance validation
CHECK (wwcc_clearance = FALSE OR 
       (wwcc_clearance = TRUE AND wwcc_expiry_date IS NOT NULL))

-- Staff headcount non-negative
CHECK (staff_headcount >= 0)
```

### Foreign Key ON DELETE Behaviors

**CASCADE (child records deleted with parent):**
- Ward → Department
- Bed → Ward
- Doctor → Staff
- Nurse → Staff
- DoctorSpecialty → Doctor
- DoctorSpecialty → Specialty
- Admission → Patient
- PlannedAdmission → Admission
- EmergencyAdmission → Admission
- BillingStatement → Admission
- Invoice → BillingStatement
- Payment → Invoice

**SET NULL (relationship cleared, child preserved):**
- Staff → Department (staff can exist without assignment)
- Admission → Nurse (preserve admission if nurse leaves)
- Admission → Doctor (preserve admission if doctor leaves)
- EmergencyAdmission → Nurse (triage) (preserve record if nurse leaves)

## Design Decisions & Rationale

### 1. Single-Table Inheritance for Admissions

**Design Choice:** One `Admission` table with `admission_type` discriminator, plus separate detail tables.

**Rationale:**
- Avoids PostgreSQL `INHERITS` problems with foreign key constraints
- Shared attributes (patient, dates, staff) stored once
- Maintains full referential integrity
- Admission-specific details (referral info, triage data) in specialized tables
- Simplifies querying across all admission types

**Alternative Considered:** PostgreSQL INHERITS - Rejected due to foreign key limitations

### 2. Staff Type Hierarchy

**Design Choice:** Base `Staff` table with `Doctor` and `Nurse` subtables.

**Rationale:**
- Common attributes (name, salary, contact) avoid duplication
- Role-specific attributes (specialties, WWCC) in appropriate tables
- Accommodates "Allied Health" staff without empty subtables
- Maintains normalization (3NF)
- Allows easy salary/headcount reporting across all staff

### 3. Doctor Specialty as Many-to-Many

**Design Choice:** Junction table `DoctorSpecialty` with training details.

**Rationale:**
- Doctors can have 1-5 specialties (per assignment requirements)
- Training date and proficiency tracked per specialty
- Prevents data redundancy
- Facilitates queries like "find all pediatricians"
- Allows specialty reuse across doctors

### 4. Generated Column for Remaining Balance

**Design Choice:** `GENERATED ALWAYS AS` for `remaining_balance`.

**Rationale:**
- Ensures balance = total_cost - insurance_covered_amount
- Automatic recalculation on updates
- Prevents data inconsistency
- Database enforces calculation (not application)
- Follows DRY principle

### 5. WWCC Conditional Requirement

**Design Choice:** Optional clearance, but expiry required if clearance = TRUE.

**Rationale:**
- Only pediatric nurses need WWCC
- CHECK constraint enforces data integrity
- Supports compliance monitoring (3-year validity)
- Flexible for nurses changing departments
- Prevents incomplete records

### 6. Unique Reference Numbers

**Design Choice:** UNIQUE constraint on PlannedAdmission.reference_number.

**Rationale:**
- Each referral has unique identifier
- Prevents duplicate bookings
- Facilitates tracking and auditing
- Matches real-world healthcare practice

### 7. Separate Invoice from Billing

**Design Choice:** Distinct `Invoice` and `BillingStatement` tables.

**Rationale:**
- Billing statement = complete service record
- Invoice = payment request for amount owed
- Supports multiple invoices per bill (payment plans)
- Matches accounting practices
- Clear separation of concerns

## Sample Data Overview

The schema includes realistic sample data demonstrating all features:

### Departments (4 records)
- General: 10AM-8PM, 1 staff
- Emergency Department: 24 hours, 1 staff
- Pediatrics: 10AM-8PM, 2 staff
- Surgery: 8AM-6PM, 0 staff

### Staff (4 records)
- **Doctors (2):**
  - Dr. Sarah Johnson (General Medicine, $180k)
  - Dr. Michael Wong (Pediatrics, $195k)
- **Nurses (2):**
  - Nurse Emily Chen (Emergency, no WWCC, $85k)
  - Nurse Lisa Brown (Pediatrics, WWCC valid until 2026, $88k)

### Patients (3 records)
- John Smith (b. 1985) - Planned admission
- Emma Wilson (b. 1990) - Emergency admission
- Oliver Taylor (b. 2015) - Planned admission (current)

### Admissions (3 records)
1. **Planned (John Smith):** Aug 1-5, 2024 - Discharged
2. **Emergency (Emma Wilson):** Aug 15-18, 2024 - Critical chest pain - Discharged
3. **Planned (Oliver Taylor):** Aug 20, 2024 - Current admission

### Billing Cycles (2 completed)
1. John Smith: $3,500 total, $2,800 insurance, $700 owed (PAID)
2. Emma Wilson: $8,500 total, $7,000 insurance, $1,500 owed (PAID)



## Troubleshooting

### Common Issues

**Issue 1: Foreign key violation when inserting data**
```
ERROR: insert or update on table "..." violates foreign key constraint
```
**Solution:** Ensure parent records exist before inserting child records. Follow the order in the sample data section.

**Issue 2: Check constraint violation**
```
ERROR: new row for relation "..." violates check constraint
```
**Solution:** Review the constraint requirements (e.g., bed dimensions, salary > 0). Adjust values accordingly.

**Issue 3: Unique constraint violation**
```
ERROR: duplicate key value violates unique constraint
```
**Solution:** Ensure primary keys and unique fields (e.g., reference_number) have distinct values.

**Issue 4: Generated column error**
```
ERROR: cannot insert into column "remaining_balance"
```
**Solution:** Do not include generated columns in INSERT statements. They are calculated automatically.

### Debug Queries

```sql
-- Check orphaned records
SELECT 'Admission' as table_name, admission_id, patient_id
FROM Admission a
WHERE NOT EXISTS (SELECT 1 FROM Patient p WHERE p.patient_id = a.patient_id);

-- Verify data counts
SELECT 'Department' as table_name, COUNT(*) FROM Department
UNION ALL
SELECT 'Staff', COUNT(*) FROM Staff
UNION ALL
SELECT 'Patient', COUNT(*) FROM Patient
UNION ALL
SELECT 'Admission', COUNT(*) FROM Admission;

-- Check for NULL values in NOT NULL columns
SELECT 'Patient' as table_name, 
       COUNT(*) FILTER (WHERE full_name IS NULL) as null_names,
       COUNT(*) FILTER (WHERE email IS NULL) as null_emails
FROM Patient;
```

## File Structure

```
central_hospital_schema.sql
├── DROP TABLE statements (cleanup)
├── CREATE TABLE statements
│   ├── Department tables (Department, Ward, Bed)
│   ├── Staff tables (Staff, Doctor, Nurse, Specialty, DoctorSpecialty)
│   ├── Patient tables (Patient, Admission, PlannedAdmission, EmergencyAdmission)
│   └── Billing tables (BillingStatement, Invoice, Payment)
└── INSERT statements (sample data)
    ├── Departments and facilities
    ├── Staff and specialties
    ├── Patients and admissions
    └── Billing and payments
```

## Maintenance & Extensions

### Recommended Indexes (Future Enhancement)

```sql
-- Performance indexes for common queries
CREATE INDEX idx_admission_patient ON Admission(patient_id);
CREATE INDEX idx_admission_dates ON Admission(admission_date, discharge_date);
CREATE INDEX idx_staff_dept ON Staff(dept_name);
CREATE INDEX idx_billing_admission ON BillingStatement(admission_id);
CREATE INDEX idx_payment_invoice ON Payment(invoice_id);
```

### Potential Extensions

1. **Audit Trail:** Add created_at/updated_at timestamps
2. **Bed Assignment:** Track which patients occupy which beds
3. **Medication Records:** Track prescriptions and administration
4. **Appointment Scheduling:** Add appointment management
5. **Medical Records:** Store diagnosis and treatment notes
6. **Operating Theatre Management:** Track surgery schedules
7. **Insurance Provider:** Normalize insurance information
8. **Staff Scheduling:** Track shifts and availability


## Version History


**End of README**

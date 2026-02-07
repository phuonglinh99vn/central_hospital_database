# Central Sydney Hospital Database Schema - README
## File Information
**Filename:** `central_hospital_schema.sql`, `central_hospital_queries.sql`
**Database:** Central Sydney Hospital (CSH) Information System   
**PostgreSQL Version:** 16.2

## Overview
This document provides comprehensive documentation for the Central Sydney Hospital (CSH) database schema. The schema models a complete hospital information system including departments, staff management, patient admissions, and billing operations.

## Database Design

<img width="1884" height="1589" alt="Untitled" src="https://github.com/user-attachments/assets/19b9a250-f33f-4486-8401-44e3ddaca911" />


### Department Module
Manages hospital organizational structure and physical resources.

**Department**
- Stores hospital departments (General, Emergency, Pediatrics, Surgery)
- Tracks operating hours and staff headcount per department

**Ward**
- Hospital wards within departments (General wards and ICU)
- Links wards to their parent department
- Tracks bed capacity per ward

**Bed**
- Individual hospital beds with specifications
- Records bed dimensions, mattress thickness, comfort level
- Tracks bed status (Available, Occupied, Maintenance, Reserved)
- Includes cost per bed for billing purposes

---

### Staff Module
Manages all hospital personnel and their qualifications.

**Staff**
- Base table for all hospital employees
- Stores personal info (name, email, mobile, address)
- Records salary and department assignment
- Staff types: Doctor, Nurse, Allied Health

**Doctor**
- Specialized staff table for doctors only
- Links to Staff via `doctor_id = staff_id`
- Tracks medical license number and expiry date
- **Constraint:** Each doctor must have 1-5 specialties

**Nurse**
- Specialized staff table for nurses only
- Links to Staff via `nurse_id = staff_id`
- Tracks Working with Children Check (WWCC) clearance and expiry

**Specialty**
- Medical specialties (General Medicine, Pediatrics, Cardiology, etc.)
- Categorizes specialties (Surgical, Medical, Diagnostic, Emergency, Pediatric)
- Records certification requirements and minimum training years

**DoctorSpecialty**
- Junction table linking doctors to their specialties (many-to-many)
- Records training date and proficiency level per specialty
- Marks primary specialty for each doctor

---

### Patient Module
Stores patient information and medical history.

**Patient**
- Patient demographics and contact information
- Emergency contact details for next of kin
- Insurance information for billing
- Medical info: blood type and known allergies (critical for patient safety)

---

### Admission Module
Tracks patient hospital stays from admission to discharge.

**Admission**
- Records all patient hospital admissions
- Links patient, assigned doctor, assigned nurse, and bed
- Tracks admission date/time and discharge date
- Records primary diagnosis and discharge summary
- Two types: Planned or Emergency

**PlannedAdmission**
- Scheduled hospital admissions
- Stores referring practitioner information
- Unique reference number from referring doctor

**EmergencyAdmission**
- Unscheduled emergency admissions
- Records triage nurse assessment
- Patient condition and severity level (Critical, High, Medium, Low)

---

### Billing Module
Manages patient billing and payments (PCI-DSS compliant).

**BillingStatement**
- Generated upon patient discharge
- Itemizes services provided during admission
- Calculates total cost, insurance coverage, and patient balance
- **Constraint:** Total cost capped at $50,000

**Invoice**
- Billing invoice sent to patient
- Tracks issue date, due date, and payment status
- Amount due equals remaining balance after insurance

**Payment**
- Records patient payments for invoices
- **Security:** Only stores last 4 digits of card (PCI-DSS compliant)
- Uses payment tokens and transaction IDs from payment processors
- Supports multiple payment methods (Credit Card, Debit Card, Cash, Insurance)
- **Note:** Never stores full credit card numbers or CVV codes

---

## 🔑 Key Relationships

### ISA Hierarchies (Inheritance)
- `Staff` → `Doctor` and `Nurse` (staff_id = doctor_id = nurse_id)
- `Admission` → `PlannedAdmission` and `EmergencyAdmission`

### Many-to-Many
- `Doctor` ↔ `Specialty` through `DoctorSpecialty` (1-5 specialties per doctor)

### One-to-Many
- `Department` → `Ward` → `Bed`
- `Patient` → `Admission`
- `Admission` → `BillingStatement` → `Invoice` → `Payment`

---

## ⚙️ Key Features

### Business Rules Enforced
- ✅ Doctors must have 1-5 specialties (enforced via trigger)
- ✅ Bed dimensions within realistic limits (length ≤2.13m, width ≤1.27m)
- ✅ Mattress thickness between 15.24cm and 17.78cm
- ✅ Salaries must be positive values
- ✅ Discharge date must be after admission date
- ✅ WWCC clearance must be valid and not expired for nurses working with children
- ✅ Medical licenses must have valid expiry dates

### Automated Features
- 🔄 Bed status automatically updates when admission is created/discharged
- 🔄 Department staff headcount auto-calculated
- 🔄 Billing remaining balance auto-computed (total_cost - insurance_covered)

### Security & Compliance
- 🔒 PCI-DSS compliant payment storage (card_last_four only)
- 🔒 Patient allergies tracked for safety
- 🔒 Medical license tracking for compliance
- 🔒 WWCC monitoring for child protection

---

## 📝 Notes

### Important Design Decisions

1. **Staff Inheritance:** `Doctor` and `Nurse` tables use same ID as `Staff` table (doctor_id = staff_id, nurse_id = staff_id). This ISA (is-a) relationship allows role-specific attributes while maintaining common staff information.

2. **Specialty Constraint:** Doctors must have 1-5 specialties. This is enforced via database trigger rather than a stored count to maintain data integrity.

3. **Payment Security:** Full credit card numbers and CVV codes are NEVER stored. Only last 4 digits retained for reference. Payment processing uses external tokens.

4. **Computed Fields:** `remaining_balance` in BillingStatement is a generated column (total_cost - insurance_covered_amount) to prevent data inconsistency.

5. **Bed Status Management:** Bed status automatically updates via trigger when admissions are created or discharged to ensure real-time accuracy.

---

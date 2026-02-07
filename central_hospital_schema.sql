-- ========================================
-- Central Sydney Hospital Database Schema
-- ========================================

-- Drop tables in reverse order of dependencies
DROP TABLE IF EXISTS Payment CASCADE;
DROP TABLE IF EXISTS Invoice CASCADE;
DROP TABLE IF EXISTS BillingStatement CASCADE;
DROP TABLE IF EXISTS EmergencyAdmission CASCADE;
DROP TABLE IF EXISTS PlannedAdmission CASCADE;
DROP TABLE IF EXISTS Admission CASCADE;
DROP TABLE IF EXISTS Patient CASCADE;
DROP TABLE IF EXISTS DoctorSpecialty CASCADE;
DROP TABLE IF EXISTS Specialty CASCADE;
DROP TABLE IF EXISTS Nurse CASCADE;
DROP TABLE IF EXISTS Doctor CASCADE;
DROP TABLE IF EXISTS Staff CASCADE;
DROP TABLE IF EXISTS Bed CASCADE;
DROP TABLE IF EXISTS Ward CASCADE;
DROP TABLE IF EXISTS Department CASCADE;

-- ========================================
-- DEPARTMENT TABLES
-- ========================================

CREATE TABLE Department (
    dept_name VARCHAR(100) PRIMARY KEY,
    operating_hours VARCHAR(100) NOT NULL,
    staff_headcount INTEGER DEFAULT 0,
    CHECK (staff_headcount >= 0)
);

CREATE TABLE Ward (
    ward_id SERIAL PRIMARY KEY,
    ward_name VARCHAR(100) NOT NULL,
    dept_name VARCHAR(100) NOT NULL,
    ward_type VARCHAR(20) NOT NULL CHECK (ward_type IN ('General', 'ICU')),
    bed_capacity INTEGER CHECK (bed_capacity > 0),
    FOREIGN KEY (dept_name) REFERENCES Department(dept_name) ON DELETE CASCADE
);

CREATE TABLE Bed (
    bed_id SERIAL PRIMARY KEY,
    ward_id INTEGER NOT NULL,
    bed_length DECIMAL(5,2) NOT NULL CHECK (bed_length > 0 AND bed_length <= 2.13),
    bed_width DECIMAL(5,2) NOT NULL CHECK (bed_width > 0 AND bed_width <= 1.27),
    mattress_thickness DECIMAL(5,2) NOT NULL CHECK (mattress_thickness >= 15.24 AND mattress_thickness <= 17.78),
    comfort_level VARCHAR(50),
    bed_cost DECIMAL(10,2) NOT NULL CHECK (bed_cost >= 0),
    bed_status VARCHAR(20) DEFAULT 'Available' CHECK (bed_status IN ('Available', 'Occupied', 'Maintenance', 'Reserved')),
    FOREIGN KEY (ward_id) REFERENCES Ward(ward_id) ON DELETE CASCADE
);

-- ========================================
-- STAFF TABLES
-- ========================================

CREATE TABLE Staff (
    staff_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,  -- Added for professional communication
    mobile VARCHAR(20) NOT NULL,
    address VARCHAR(255) NOT NULL,
    salary DECIMAL(10,2) NOT NULL CHECK (salary > 0),
    dept_name VARCHAR(100),
    staff_type VARCHAR(20) NOT NULL CHECK (staff_type IN ('Doctor', 'Nurse', 'Allied Health')),
    FOREIGN KEY (dept_name) REFERENCES Department(dept_name) ON DELETE SET NULL
);

CREATE TABLE Doctor (
    doctor_id INTEGER PRIMARY KEY,
    medical_license_number VARCHAR(50) UNIQUE,  -- Added for compliance
    license_expiry_date DATE,  -- Added for compliance tracking
    license_state VARCHAR(50),
    FOREIGN KEY (doctor_id) REFERENCES Staff(staff_id) ON DELETE CASCADE,
    -- Ensure license is valid if provided
    CHECK (medical_license_number IS NULL OR 
           (license_expiry_date IS NOT NULL AND license_expiry_date > CURRENT_DATE))
);

-- Enhanced Specialty table with additional attributes
CREATE TABLE Specialty (
    specialty_name VARCHAR(100) PRIMARY KEY,
    specialty_category VARCHAR(50) NOT NULL CHECK (specialty_category IN ('Surgical', 'Medical', 'Diagnostic', 'Emergency', 'Pediatric', 'Other')),
    certification_required BOOLEAN DEFAULT TRUE,
    min_years_training INTEGER NOT NULL CHECK (min_years_training >= 0),
    description TEXT
);

CREATE TABLE DoctorSpecialty (
    doctor_id INTEGER,
    specialty_name VARCHAR(100),
    training_date DATE NOT NULL,
    proficiency_level VARCHAR(50) NOT NULL CHECK (proficiency_level IN ('Beginner', 'Intermediate', 'Advanced', 'Expert')),
    is_primary_specialty BOOLEAN DEFAULT FALSE,  -- Added to mark primary specialty
    PRIMARY KEY (doctor_id, specialty_name),
    FOREIGN KEY (doctor_id) REFERENCES Doctor(doctor_id) ON DELETE CASCADE,
    FOREIGN KEY (specialty_name) REFERENCES Specialty(specialty_name) ON DELETE CASCADE
);

CREATE TABLE Nurse (
    nurse_id INTEGER PRIMARY KEY,
    wwcc_clearance BOOLEAN DEFAULT FALSE,
    wwcc_expiry_date DATE,
    FOREIGN KEY (nurse_id) REFERENCES Staff(staff_id) ON DELETE CASCADE,
    -- Ensure WWCC expiry is valid and in the future
    CHECK (wwcc_clearance = FALSE OR 
           (wwcc_clearance = TRUE AND wwcc_expiry_date IS NOT NULL AND wwcc_expiry_date > CURRENT_DATE))
);

-- ========================================
-- PATIENT TABLES
-- ========================================

CREATE TABLE Patient (
    patient_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    emergency_contact_name VARCHAR(255) NOT NULL,
    emergency_contact_phone VARCHAR(20) NOT NULL,
    insurance_number VARCHAR(100) NOT NULL,
    blood_type VARCHAR(5) CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown')),  -- Added for emergency care
    allergies TEXT  -- Added for patient safety
);

CREATE TABLE Admission (
    admission_id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    admission_date TIMESTAMP NOT NULL,
    admission_type VARCHAR(20) NOT NULL CHECK (admission_type IN ('Planned', 'Emergency')),
    nurse_id INTEGER,
    doctor_id INTEGER,
    bed_id INTEGER,  -- Added to track bed assignment
    discharge_date DATE,
    primary_diagnosis VARCHAR(255),  -- Added for medical records
    discharge_summary TEXT,  -- Added for continuity of care
    discharge_disposition VARCHAR(50) CHECK (discharge_disposition IN ('Home', 'Transfer', 'Deceased', 'Against Medical Advice')),
    FOREIGN KEY (patient_id) REFERENCES Patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (nurse_id) REFERENCES Nurse(nurse_id) ON DELETE SET NULL,
    FOREIGN KEY (doctor_id) REFERENCES Doctor(doctor_id) ON DELETE SET NULL,
    FOREIGN KEY (bed_id) REFERENCES Bed(bed_id) ON DELETE SET NULL,
    -- Ensure discharge date is after admission date
    CHECK (discharge_date IS NULL OR discharge_date >= admission_date::date)
);

CREATE TABLE PlannedAdmission (
    admission_id INTEGER PRIMARY KEY,
    referring_practitioner VARCHAR(255) NOT NULL,
    reference_number VARCHAR(100) NOT NULL UNIQUE,
    FOREIGN KEY (admission_id) REFERENCES Admission(admission_id) ON DELETE CASCADE
);

CREATE TABLE EmergencyAdmission (
    admission_id INTEGER PRIMARY KEY,
    triage_nurse_id INTEGER,
    patient_condition VARCHAR(500),
    severity_level VARCHAR(20) CHECK (severity_level IN ('Critical', 'High', 'Medium', 'Low')),
    FOREIGN KEY (admission_id) REFERENCES Admission(admission_id) ON DELETE CASCADE,
    FOREIGN KEY (triage_nurse_id) REFERENCES Nurse(nurse_id) ON DELETE SET NULL
);

-- ========================================
-- BILLING TABLES
-- ========================================

CREATE TABLE BillingStatement (
    billing_id SERIAL PRIMARY KEY,
    admission_id INTEGER NOT NULL UNIQUE,
    discharge_date DATE NOT NULL,
    services_description TEXT,
    total_cost DECIMAL(10,2) NOT NULL CHECK (total_cost > 0 AND total_cost <= 50000),
    insurance_covered_amount DECIMAL(10,2) NOT NULL CHECK (insurance_covered_amount >= 0),
    remaining_balance DECIMAL(10,2) GENERATED ALWAYS AS (total_cost - insurance_covered_amount) STORED,
    FOREIGN KEY (admission_id) REFERENCES Admission(admission_id) ON DELETE CASCADE,
    CHECK (insurance_covered_amount <= total_cost)
);

CREATE TABLE Invoice (
    invoice_id SERIAL PRIMARY KEY,
    billing_id INTEGER NOT NULL,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,  -- Added for payment tracking
    amount_due DECIMAL(10,2) NOT NULL CHECK (amount_due >= 0),
    payment_status VARCHAR(20) DEFAULT 'Unpaid' CHECK (payment_status IN ('Unpaid', 'Partially Paid', 'Paid', 'Overdue', 'Cancelled')),  -- Added for tracking
    FOREIGN KEY (billing_id) REFERENCES BillingStatement(billing_id) ON DELETE CASCADE,
    -- Ensure due date is after issue date
    CHECK (due_date IS NULL OR due_date >= issue_date)
);

-- CRITICAL SECURITY FIX: PCI-DSS Compliant Payment Table
CREATE TABLE Payment (
    payment_id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('Credit Card', 'Debit Card', 'Insurance', 'Cash', 'Bank Transfer')),
    cardholder_name VARCHAR(255),
    card_last_four VARCHAR(4),  -- ONLY last 4 digits (PCI-DSS compliant)
    card_type VARCHAR(20) CHECK (card_type IN ('Visa', 'Mastercard', 'Amex', 'Discover', 'Other')),
    payment_processor VARCHAR(50),  -- e.g., 'Stripe', 'Square', 'PayPal'
    transaction_id VARCHAR(100) UNIQUE,  -- External transaction reference
    payment_token VARCHAR(255),  -- Encrypted token from payment processor
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_amount DECIMAL(10,2) NOT NULL CHECK (payment_amount > 0),
    payment_status VARCHAR(20) DEFAULT 'Completed' CHECK (payment_status IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    FOREIGN KEY (invoice_id) REFERENCES Invoice(invoice_id) ON DELETE CASCADE
);

-- ========================================
-- TRIGGERS TO ENFORCE 1-5 SPECIALTY RULE
-- ========================================

-- Function to check doctor has 1-5 specialties
CREATE OR REPLACE FUNCTION validate_doctor_specialty_count()
RETURNS TRIGGER AS $$
DECLARE
    specialty_count INTEGER;
BEGIN
    -- Count specialties for the doctor
    SELECT COUNT(*) INTO specialty_count
    FROM DoctorSpecialty
    WHERE doctor_id = COALESCE(NEW.doctor_id, OLD.doctor_id);
    
    -- Check constraints based on operation
    IF (TG_OP = 'DELETE') THEN
        IF specialty_count < 1 THEN
            RAISE EXCEPTION 'Doctor must have at least 1 specialty. Cannot delete this specialty.';
        END IF;
    ELSIF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        IF specialty_count > 5 THEN
            RAISE EXCEPTION 'Doctor cannot have more than 5 specialties. Current count: %', specialty_count;
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_doctor_specialty_count
AFTER INSERT OR UPDATE OR DELETE ON DoctorSpecialty
FOR EACH ROW
EXECUTE FUNCTION validate_doctor_specialty_count();

-- ========================================
-- TRIGGERS FOR BED STATUS MANAGEMENT
-- ========================================

-- Auto-update bed status when admission is assigned
CREATE OR REPLACE FUNCTION update_bed_status()
RETURNS TRIGGER AS $$
BEGIN
    -- When bed is assigned to admission, mark as Occupied
    IF NEW.bed_id IS NOT NULL AND NEW.discharge_date IS NULL THEN
        UPDATE Bed SET bed_status = 'Occupied' WHERE bed_id = NEW.bed_id;
    END IF;
    
    -- When patient is discharged, mark bed as Available
    IF NEW.discharge_date IS NOT NULL AND NEW.bed_id IS NOT NULL THEN
        UPDATE Bed SET bed_status = 'Available' WHERE bed_id = NEW.bed_id;
    END IF;
    
    -- If bed is changed, update old bed status
    IF TG_OP = 'UPDATE' AND OLD.bed_id IS DISTINCT FROM NEW.bed_id THEN
        IF OLD.bed_id IS NOT NULL THEN
            UPDATE Bed SET bed_status = 'Available' WHERE bed_id = OLD.bed_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER manage_bed_status
AFTER INSERT OR UPDATE ON Admission
FOR EACH ROW
EXECUTE FUNCTION update_bed_status();

-- ========================================
-- PERFORMANCE INDEXES
-- ========================================

CREATE INDEX idx_admission_patient ON Admission(patient_id);
CREATE INDEX idx_admission_doctor ON Admission(doctor_id);
CREATE INDEX idx_admission_nurse ON Admission(nurse_id);
CREATE INDEX idx_admission_date ON Admission(admission_date);
CREATE INDEX idx_admission_discharge ON Admission(discharge_date);
CREATE INDEX idx_billing_admission ON BillingStatement(admission_id);
CREATE INDEX idx_payment_invoice ON Payment(invoice_id);
CREATE INDEX idx_doctor_specialty ON DoctorSpecialty(doctor_id, specialty_name);

-- ========================================
-- SAMPLE DATA POPULATION
-- ========================================

-- Insert Departments
INSERT INTO Department (dept_name, operating_hours, staff_headcount) VALUES
('General', '10:00 AM - 8:00 PM', 0),
('Emergency Department', '24 Hours', 0),
('Pediatrics', '10:00 AM - 8:00 PM', 0),
('Surgery', '8:00 AM - 6:00 PM', 0);

-- Insert Wards
INSERT INTO Ward (ward_name, dept_name, ward_type, bed_capacity) VALUES
('General Ward A', 'General', 'General', 20),
('Pediatric ICU', 'Pediatrics', 'ICU', 10),
('Emergency Ward', 'Emergency Department', 'General', 15);

-- Insert Beds
INSERT INTO Bed (ward_id, bed_length, bed_width, mattress_thickness, comfort_level, bed_cost, bed_status) VALUES
(1, 2.00, 1.00, 16.00, 'Standard', 50.00, 'Available'),
(1, 2.00, 1.00, 16.00, 'Standard', 50.00, 'Available'),
(2, 2.10, 1.20, 17.50, 'Premium', 150.00, 'Available'),
(3, 2.05, 1.10, 16.50, 'Standard', 75.00, 'Available');

-- Insert Staff
INSERT INTO Staff (full_name, email, mobile, address, salary, dept_name, staff_type) VALUES
('Dr. Sarah Johnson', 'sarah.johnson@csh.com.au', '0412345678', '123 Medical St, Sydney NSW 2000', 180000.00, 'General', 'Doctor'),
('Nurse Emily Chen', 'emily.chen@csh.com.au', '0423456789', '456 Care Ave, Sydney NSW 2000', 85000.00, 'Emergency Department', 'Nurse'),
('Dr. Michael Wong', 'michael.wong@csh.com.au', '0434567890', '789 Health Rd, Sydney NSW 2000', 195000.00, 'Pediatrics', 'Doctor'),
('Nurse Lisa Brown', 'lisa.brown@csh.com.au', '0445678901', '321 Nurse Lane, Sydney NSW 2000', 88000.00, 'Pediatrics', 'Nurse');

-- Insert Doctors
INSERT INTO Doctor (doctor_id, medical_license_number, license_expiry_date, license_state) VALUES 
(1, 'MED123456', '2027-12-31', 'NSW'),
(3, 'MED789012', '2028-06-30', 'NSW');

-- Insert Specialties
INSERT INTO Specialty (specialty_name, specialty_category, certification_required, min_years_training, description) VALUES
('General Medicine', 'Medical', TRUE, 5, 'Comprehensive care for adult patients with acute and chronic conditions'),
('Pediatrics', 'Pediatric', TRUE, 6, 'Medical care for infants, children, and adolescents'),
('Emergency Medicine', 'Emergency', TRUE, 5, 'Acute care for patients with urgent and life-threatening conditions'),
('Cardiology', 'Medical', TRUE, 7, 'Diagnosis and treatment of heart and cardiovascular system disorders'),
('General Surgery', 'Surgical', TRUE, 6, 'Surgical procedures for diseases and injuries');

-- Insert Doctor Specialties
INSERT INTO DoctorSpecialty (doctor_id, specialty_name, training_date, proficiency_level, is_primary_specialty) VALUES
(1, 'General Medicine', '2015-06-15', 'Expert', TRUE),
(1, 'Cardiology', '2018-03-20', 'Advanced', FALSE),
(3, 'Pediatrics', '2016-08-20', 'Expert', TRUE);

-- Insert Nurses
INSERT INTO Nurse (nurse_id, wwcc_clearance, wwcc_expiry_date) VALUES
(2, FALSE, NULL),
(4, TRUE, '2026-12-31');

-- Insert Patients
INSERT INTO Patient (full_name, email, address, date_of_birth, mobile, emergency_contact_name, emergency_contact_phone, insurance_number, blood_type, allergies) VALUES
('John Smith', 'john.smith@email.com', '10 Patient St, Sydney NSW 2000', '1985-03-15', '0456789012', 'Jane Smith', '0467890123', 'INS123456', 'O+', 'Penicillin'),
('Emma Wilson', 'emma.wilson@email.com', '20 Family Ave, Sydney NSW 2000', '1990-07-22', '0478901234', 'Robert Wilson', '0489012345', 'INS789012', 'A+', 'None'),
('Oliver Taylor', 'oliver.taylor@email.com', '30 Child Rd, Sydney NSW 2000', '2015-11-10', '0490123456', 'Sophie Taylor', '0401234567', 'INS345678', 'B+', 'Latex, Peanuts');

-- Insert Admissions
INSERT INTO Admission (patient_id, admission_date, admission_type, nurse_id, doctor_id, bed_id, discharge_date, primary_diagnosis) VALUES
(1, '2024-08-01 10:30:00', 'Planned', 2, 1, 1, '2024-08-05', 'Coronary artery disease'),
(2, '2024-08-15 02:45:00', 'Emergency', 2, 1, 2, '2024-08-18', 'Acute myocardial infarction'),
(3, '2024-08-20 14:00:00', 'Planned', 4, 3, 3, NULL, 'Pneumonia');

-- Insert Planned Admissions
INSERT INTO PlannedAdmission (admission_id, referring_practitioner, reference_number) VALUES
(1, 'Dr. Peter Anderson', 'REF2024001'),
(3, 'Dr. Mary Thompson', 'REF2024003');

-- Insert Emergency Admissions
INSERT INTO EmergencyAdmission (admission_id, triage_nurse_id, patient_condition, severity_level) VALUES
(2, 2, 'Chest pain and shortness of breath', 'Critical');

-- Insert Billing Statements
INSERT INTO BillingStatement (admission_id, discharge_date, services_description, total_cost, insurance_covered_amount) VALUES
(1, '2024-08-05', 'General consultation, blood tests, 4-day hospital stay', 3500.00, 2800.00),
(2, '2024-08-18', 'Emergency care, ECG, cardiac monitoring, 3-day ICU stay', 8500.00, 7000.00);

-- Insert Invoices
INSERT INTO Invoice (billing_id, issue_date, due_date, amount_due, payment_status) VALUES
(1, '2024-08-06', '2024-09-06', 700.00, 'Paid'),
(2, '2024-08-19', '2024-09-19', 1500.00, 'Paid');

-- Insert Payments (PCI-DSS Compliant - no CVV or full card numbers)
INSERT INTO Payment (invoice_id, payment_method, cardholder_name, card_last_four, card_type, transaction_id, payment_date, payment_amount, payment_status) VALUES
(1, 'Credit Card', 'John Smith', '9012', 'Visa', 'TXN20240810001', '2024-08-10', 700.00, 'Completed'),
(2, 'Credit Card', 'Emma Wilson', '1234', 'Mastercard', 'TXN20240822001', '2024-08-22', 1500.00, 'Completed');

-- Update department headcounts
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'General') WHERE dept_name = 'General';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Emergency Department') WHERE dept_name = 'Emergency Department';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Pediatrics') WHERE dept_name = 'Pediatrics';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Surgery') WHERE dept_name = 'Surgery';


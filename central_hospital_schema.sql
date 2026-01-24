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
    FOREIGN KEY (ward_id) REFERENCES Ward(ward_id) ON DELETE CASCADE
);

-- ========================================
-- STAFF TABLES
-- ========================================

CREATE TABLE Staff (
    staff_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    address VARCHAR(255) NOT NULL,
    salary DECIMAL(10,2) NOT NULL CHECK (salary > 0),
    dept_name VARCHAR(100),
    staff_type VARCHAR(20) NOT NULL CHECK (staff_type IN ('Doctor', 'Nurse', 'Allied Health')),
    FOREIGN KEY (dept_name) REFERENCES Department(dept_name) ON DELETE SET NULL
);

CREATE TABLE Doctor (
    doctor_id INTEGER PRIMARY KEY,
    FOREIGN KEY (doctor_id) REFERENCES Staff(staff_id) ON DELETE CASCADE
);

CREATE TABLE Specialty (
    specialty_name VARCHAR(100) PRIMARY KEY
);

CREATE TABLE DoctorSpecialty (
    doctor_id INTEGER,
    specialty_name VARCHAR(100),
    training_date DATE NOT NULL,
    proficiency_level VARCHAR(50) NOT NULL,
    PRIMARY KEY (doctor_id, specialty_name),
    FOREIGN KEY (doctor_id) REFERENCES Doctor(doctor_id) ON DELETE CASCADE,
    FOREIGN KEY (specialty_name) REFERENCES Specialty(specialty_name) ON DELETE CASCADE
);

CREATE TABLE Nurse (
    nurse_id INTEGER PRIMARY KEY,
    wwcc_clearance BOOLEAN DEFAULT FALSE,
    wwcc_expiry_date DATE,
    FOREIGN KEY (nurse_id) REFERENCES Staff(staff_id) ON DELETE CASCADE,
    CHECK (wwcc_clearance = FALSE OR (wwcc_clearance = TRUE AND wwcc_expiry_date IS NOT NULL))
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
    insurance_number VARCHAR(100) NOT NULL
);

CREATE TABLE Admission (
    admission_id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    admission_date TIMESTAMP NOT NULL,
    admission_type VARCHAR(20) NOT NULL CHECK (admission_type IN ('Planned', 'Emergency')),
    nurse_id INTEGER,
    doctor_id INTEGER,
    discharge_date DATE,
    FOREIGN KEY (patient_id) REFERENCES Patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (nurse_id) REFERENCES Nurse(nurse_id) ON DELETE SET NULL,
    FOREIGN KEY (doctor_id) REFERENCES Doctor(doctor_id) ON DELETE SET NULL
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
    amount_due DECIMAL(10,2) NOT NULL CHECK (amount_due >= 0),
    FOREIGN KEY (billing_id) REFERENCES BillingStatement(billing_id) ON DELETE CASCADE
);

CREATE TABLE Payment (
    payment_id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    cardholder_name VARCHAR(255) NOT NULL,
    card_number VARCHAR(19) NOT NULL,
    expiry_date DATE NOT NULL,
    cvv VARCHAR(4) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_amount DECIMAL(10,2) NOT NULL CHECK (payment_amount > 0),
    FOREIGN KEY (invoice_id) REFERENCES Invoice(invoice_id) ON DELETE CASCADE
);

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
INSERT INTO Ward (ward_name, dept_name, ward_type) VALUES
('General Ward A', 'General', 'General'),
('Pediatric ICU', 'Pediatrics', 'ICU'),
('Emergency Ward', 'Emergency Department', 'General');

-- Insert Beds
INSERT INTO Bed (ward_id, bed_length, bed_width, mattress_thickness, comfort_level, bed_cost) VALUES
(1, 2.00, 1.00, 16.00, 'Standard', 50.00),
(2, 2.10, 1.20, 17.50, 'Premium', 150.00),
(3, 2.05, 1.10, 16.50, 'Standard', 75.00);

-- Insert Staff
INSERT INTO Staff (full_name, mobile, address, salary, dept_name, staff_type) VALUES
('Dr. Sarah Johnson', '0412345678', '123 Medical St, Sydney NSW 2000', 180000.00, 'General', 'Doctor'),
('Nurse Emily Chen', '0423456789', '456 Care Ave, Sydney NSW 2000', 85000.00, 'Emergency Department', 'Nurse'),
('Dr. Michael Wong', '0434567890', '789 Health Rd, Sydney NSW 2000', 195000.00, 'Pediatrics', 'Doctor'),
('Nurse Lisa Brown', '0445678901', '321 Nurse Lane, Sydney NSW 2000', 88000.00, 'Pediatrics', 'Nurse');

-- Insert Doctors
INSERT INTO Doctor (doctor_id) VALUES (1), (3);

-- Insert Specialties
INSERT INTO Specialty (specialty_name) VALUES
('General Medicine'),
('Pediatrics'),
('Emergency Medicine');

-- Insert Doctor Specialties
INSERT INTO DoctorSpecialty (doctor_id, specialty_name, training_date, proficiency_level) VALUES
(1, 'General Medicine', '2015-06-15', 'Expert'),
(3, 'Pediatrics', '2016-08-20', 'Expert');

-- Insert Nurses
INSERT INTO Nurse (nurse_id, wwcc_clearance, wwcc_expiry_date) VALUES
(2, FALSE, NULL),
(4, TRUE, '2026-12-31');

-- Insert Patients
INSERT INTO Patient (full_name, email, address, date_of_birth, mobile, emergency_contact_name, emergency_contact_phone, insurance_number) VALUES
('John Smith', 'john.smith@email.com', '10 Patient St, Sydney NSW 2000', '1985-03-15', '0456789012', 'Jane Smith', '0467890123', 'INS123456'),
('Emma Wilson', 'emma.wilson@email.com', '20 Family Ave, Sydney NSW 2000', '1990-07-22', '0478901234', 'Robert Wilson', '0489012345', 'INS789012'),
('Oliver Taylor', 'oliver.taylor@email.com', '30 Child Rd, Sydney NSW 2000', '2015-11-10', '0490123456', 'Sophie Taylor', '0401234567', 'INS345678');

-- Insert Admissions
INSERT INTO Admission (patient_id, admission_date, admission_type, nurse_id, doctor_id, discharge_date) VALUES
(1, '2024-08-01 10:30:00', 'Planned', 2, 1, '2024-08-05'),
(2, '2024-08-15 02:45:00', 'Emergency', 2, 1, '2024-08-18'),
(3, '2024-08-20 14:00:00', 'Planned', 4, 3, NULL);

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
INSERT INTO Invoice (billing_id, issue_date, amount_due) VALUES
(1, '2024-08-06', 700.00),
(2, '2024-08-19', 1500.00);

-- Insert Payments
INSERT INTO Payment (invoice_id, cardholder_name, card_number, expiry_date, cvv, payment_date, payment_amount) VALUES
(1, 'John Smith', '4532123456789012', '2026-12-31', '123', '2024-08-10', 700.00),
(2, 'Emma Wilson', '5412345678901234', '2027-06-30', '456', '2024-08-22', 1500.00);

-- Update department headcounts
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'General') WHERE dept_name = 'General';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Emergency Department') WHERE dept_name = 'Emergency Department';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Pediatrics') WHERE dept_name = 'Pediatrics';
UPDATE Department SET staff_headcount = (SELECT COUNT(*) FROM Staff WHERE dept_name = 'Surgery') WHERE dept_name = 'Surgery';
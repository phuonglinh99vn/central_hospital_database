### Staff Management

-- Find all doctors with their specialties
SELECT s.full_name, ds.specialty_name, ds.proficiency_level, ds.training_date
FROM Staff s
JOIN Doctor d ON s.staff_id = d.doctor_id
JOIN DoctorSpecialty ds ON d.doctor_id = ds.doctor_id
ORDER BY s.full_name, ds.specialty_name;

-- Check nurses with expiring WWCC (within 90 days)
SELECT s.full_name, s.dept_name, n.wwcc_expiry_date,
       n.wwcc_expiry_date - CURRENT_DATE as days_remaining
FROM Staff s
JOIN Nurse n ON s.staff_id = n.nurse_id
WHERE n.wwcc_clearance = TRUE 
  AND n.wwcc_expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
ORDER BY n.wwcc_expiry_date;

-- Department staffing summary
SELECT dept_name, staff_headcount,
       COUNT(staff_id) as actual_count,
       staff_headcount - COUNT(staff_id) as difference
FROM Department d
LEFT JOIN Staff s USING (dept_name)
GROUP BY dept_name, staff_headcount;

### Patient Care

-- Current admissions (not discharged)
SELECT p.full_name, p.mobile, a.admission_date, a.admission_type,
       s_doctor.full_name as doctor, s_nurse.full_name as nurse
FROM Patient p
JOIN Admission a ON p.patient_id = a.patient_id
LEFT JOIN Staff s_doctor ON a.doctor_id = s_doctor.staff_id
LEFT JOIN Staff s_nurse ON a.nurse_id = s_nurse.staff_id
WHERE a.discharge_date IS NULL
ORDER BY a.admission_date;

-- Emergency admissions by severity
SELECT ea.severity_level, COUNT(*) as admission_count,
       AVG(EXTRACT(EPOCH FROM (a.discharge_date - a.admission_date))/86400) as avg_stay_days
FROM EmergencyAdmission ea
JOIN Admission a ON ea.admission_id = a.admission_id
WHERE a.discharge_date IS NOT NULL
GROUP BY ea.severity_level
ORDER BY 
  CASE ea.severity_level
    WHEN 'Critical' THEN 1
    WHEN 'High' THEN 2
    WHEN 'Medium' THEN 3
    WHEN 'Low' THEN 4
  END;

-- Patient admission history
SELECT p.full_name, a.admission_date, a.discharge_date, a.admission_type,
       COALESCE(a.discharge_date - a.admission_date::date, 
                CURRENT_DATE - a.admission_date::date) as length_of_stay
FROM Patient p
JOIN Admission a ON p.patient_id = a.patient_id
ORDER BY p.full_name, a.admission_date DESC;


### Financial Reporting

-- Revenue summary
SELECT 
    COUNT(DISTINCT bs.billing_id) as total_bills,
    SUM(bs.total_cost) as gross_revenue,
    SUM(bs.insurance_covered_amount) as insurance_revenue,
    SUM(bs.remaining_balance) as patient_revenue,
    ROUND(AVG(bs.total_cost), 2) as avg_bill_amount
FROM BillingStatement bs;

-- Outstanding invoices
SELECT i.invoice_id, p.full_name, i.issue_date, i.amount_due,
       COALESCE(SUM(pay.payment_amount), 0) as amount_paid,
       i.amount_due - COALESCE(SUM(pay.payment_amount), 0) as balance_remaining
FROM Invoice i
JOIN BillingStatement bs ON i.billing_id = bs.billing_id
JOIN Admission a ON bs.admission_id = a.admission_id
JOIN Patient p ON a.patient_id = p.patient_id
LEFT JOIN Payment pay ON i.invoice_id = pay.invoice_id
GROUP BY i.invoice_id, p.full_name, i.issue_date, i.amount_due
HAVING i.amount_due - COALESCE(SUM(pay.payment_amount), 0) > 0
ORDER BY i.issue_date;

-- Payment method analysis
SELECT 
    DATE_TRUNC('month', payment_date) as payment_month,
    COUNT(*) as transaction_count,
    SUM(payment_amount) as total_collected,
    ROUND(AVG(payment_amount), 2) as avg_payment
FROM Payment
GROUP BY DATE_TRUNC('month', payment_date)
ORDER BY payment_month DESC;


### Facility Management


-- Bed utilization by ward
SELECT w.ward_name, w.ward_type, d.dept_name,
       COUNT(b.bed_id) as total_beds,
       ROUND(AVG(b.bed_cost), 2) as avg_bed_cost,
       MIN(b.comfort_level) as comfort_range
FROM Ward w
JOIN Department d ON w.dept_name = d.dept_name
JOIN Bed b ON w.ward_id = b.ward_id
GROUP BY w.ward_name, w.ward_type, d.dept_name
ORDER BY d.dept_name, w.ward_name;

-- Bed inventory with specifications
SELECT w.ward_name, b.bed_id, b.comfort_level,
       b.bed_length || 'm x ' || b.bed_width || 'm' as dimensions,
       b.mattress_thickness || 'cm' as mattress,
       '$' || b.bed_cost || '/day' as cost
FROM Bed b
JOIN Ward w ON b.ward_id = w.ward_id
ORDER BY w.ward_name, b.bed_id;


## Testing & Validation

### Schema Validation Tests


-- Test 1: Verify all tables created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
-- Expected: 13 tables

-- Test 2: Check primary keys
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE constraint_type = 'PRIMARY KEY'
  AND table_schema = 'public'
ORDER BY table_name;
-- Expected: 13 primary keys

-- Test 3: Check foreign keys
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, kcu.column_name;
-- Expected: Multiple foreign key relationships

-- Test 4: Verify check constraints
SELECT constraint_name, table_name
FROM information_schema.table_constraints
WHERE constraint_type = 'CHECK'
  AND table_schema = 'public'
ORDER BY table_name;
-- Expected: Multiple check constraints


### Data Integrity Tests


-- Test 5: Verify generated column calculation
SELECT billing_id, total_cost, insurance_covered_amount, remaining_balance,
       (total_cost - insurance_covered_amount) as calculated_balance,
       CASE 
         WHEN remaining_balance = (total_cost - insurance_covered_amount) 
         THEN 'PASS' 
         ELSE 'FAIL' 
       END as test_result
FROM BillingStatement;
-- Expected: All PASS

-- Test 6: Verify constraint enforcement - bed dimensions
-- This should FAIL (exceeds max length):
-- INSERT INTO Bed (ward_id, bed_length, bed_width, mattress_thickness, bed_cost)
-- VALUES (1, 2.50, 1.00, 16.00, 50.00);

-- Test 7: Verify WWCC constraint
-- This should FAIL (clearance TRUE but no expiry):
-- INSERT INTO Nurse (nurse_id, wwcc_clearance, wwcc_expiry_date)
-- VALUES (999, TRUE, NULL);

-- Test 8: Verify referential integrity
SELECT 
    a.admission_id,
    p.full_name as patient,
    s_n.full_name as nurse,
    s_d.full_name as doctor
FROM Admission a
JOIN Patient p ON a.patient_id = p.patient_id
LEFT JOIN Staff s_n ON a.nurse_id = s_n.staff_id
LEFT JOIN Staff s_d ON a.doctor_id = s_d.staff_id;
-- Expected: All records with valid relationships

-- Query 1: Rank doctors by salary within their department
-- Demonstrates: DENSE_RANK(), PARTITION BY
SELECT 
    s.full_name AS doctor_name,
    s.dept_name,
    s.salary,
    DENSE_RANK() OVER (PARTITION BY s.dept_name ORDER BY s.salary DESC) AS salary_rank_in_dept,
    RANK() OVER (ORDER BY s.salary DESC) AS overall_salary_rank,
    ROUND(AVG(s.salary) OVER (PARTITION BY s.dept_name), 2) AS dept_avg_salary,
    s.salary - AVG(s.salary) OVER (PARTITION BY s.dept_name) AS salary_vs_dept_avg
FROM Staff s
INNER JOIN Doctor d ON s.staff_id = d.doctor_id
ORDER BY s.dept_name, salary_rank_in_dept;

-- Query 2: Calculate running total of admissions by month
-- Demonstrates: DATE_TRUNC, SUM() OVER with ROWS BETWEEN
SELECT 
    DATE_TRUNC('month', admission_date) AS month,
    COUNT(*) AS admissions_this_month,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', admission_date) 
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_admissions,
    AVG(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', admission_date) 
                        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS three_month_moving_avg
FROM Admission
GROUP BY DATE_TRUNC('month', admission_date)
ORDER BY month;

-- Query 3: Calculate bed occupancy rate with rolling 7-day average
-- Demonstrates: Window functions for time-series analysis
WITH daily_occupancy AS (
    SELECT 
        a.admission_date::date AS date,
        COUNT(*) AS admissions,
        (SELECT COUNT(*) FROM Bed) AS total_beds,
        ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM Bed) * 100, 2) AS occupancy_rate
    FROM Admission a
    WHERE a.discharge_date IS NULL OR a.discharge_date >= a.admission_date::date
    GROUP BY a.admission_date::date
)
SELECT 
    date,
    admissions,
    total_beds,
    occupancy_rate,
    ROUND(AVG(occupancy_rate) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7day_avg
FROM daily_occupancy
ORDER BY date DESC;

-- =====================================================
-- SECTION 2: COMMON TABLE EXPRESSIONS (CTEs)
-- =====================================================

-- Query 4: Multi-level CTE for comprehensive hospital statistics
-- Demonstrates: Multiple CTEs, complex aggregations
WITH doctor_stats AS (
    SELECT 
        d.doctor_id,
        s.full_name,
        s.dept_name,
        COUNT(DISTINCT ds.specialty_name) AS specialty_count,
        COUNT(DISTINCT a.admission_id) AS total_admissions,
        COUNT(DISTINCT CASE WHEN a.discharge_date IS NULL THEN a.admission_id END) AS active_patients
    FROM Doctor d
    JOIN Staff s ON d.doctor_id = s.staff_id
    LEFT JOIN DoctorSpecialty ds ON d.doctor_id = ds.doctor_id
    LEFT JOIN Admission a ON d.doctor_id = a.doctor_id
    GROUP BY d.doctor_id, s.full_name, s.dept_name
),
dept_summary AS (
    SELECT 
        dept_name,
        COUNT(*) AS doctor_count,
        AVG(specialty_count) AS avg_specialties_per_doctor,
        SUM(total_admissions) AS dept_total_admissions,
        SUM(active_patients) AS dept_active_patients
    FROM doctor_stats
    GROUP BY dept_name
)
SELECT 
    ds.doctor_id,
    ds.full_name,
    ds.dept_name,
    ds.specialty_count,
    ds.total_admissions,
    ds.active_patients,
    dept.avg_specialties_per_doctor AS dept_avg_specialties,
    dept.dept_total_admissions,
    ROUND(ds.total_admissions::numeric / NULLIF(dept.dept_total_admissions, 0) * 100, 2) AS pct_of_dept_admissions
FROM doctor_stats ds
JOIN dept_summary dept ON ds.dept_name = dept.dept_name
ORDER BY ds.dept_name, ds.total_admissions DESC;

-- Query 5: Recursive CTE for organizational hierarchy (if departments had hierarchy)
-- Demonstrates: Recursive CTEs
WITH RECURSIVE dept_hierarchy AS (
    -- Base case: top-level departments
    SELECT 
        dept_name,
        dept_name AS root_dept,
        0 AS level,
        dept_name AS path
    FROM Department
    WHERE operating_hours = '24 Hours'  -- Emergency as root
    
    UNION ALL
    
    -- Recursive case: would add child departments if hierarchy existed
    SELECT 
        d.dept_name,
        dh.root_dept,
        dh.level + 1,
        dh.path || ' > ' || d.dept_name
    FROM Department d
    CROSS JOIN dept_hierarchy dh
    WHERE dh.level < 1  -- Limit recursion depth for this example
    AND d.dept_name != dh.dept_name
)
SELECT * FROM dept_hierarchy;

-- =====================================================
-- SECTION 3: AGGREGATIONS & GROUPING
-- =====================================================

-- Query 6: ROLLUP and CUBE for multi-dimensional analysis
-- Demonstrates: ROLLUP, CUBE, GROUPING SETS
SELECT 
    COALESCE(s.dept_name, 'ALL DEPARTMENTS') AS department,
    COALESCE(a.admission_type, 'ALL TYPES') AS admission_type,
    COUNT(a.admission_id) AS total_admissions,
    ROUND(AVG(bs.total_cost), 2) AS avg_cost,
    SUM(bs.total_cost) AS total_revenue,
    GROUPING(s.dept_name) AS dept_grouping_level,
    GROUPING(a.admission_type) AS type_grouping_level
FROM Admission a
JOIN Doctor d ON a.doctor_id = d.doctor_id
JOIN Staff s ON d.doctor_id = s.staff_id
LEFT JOIN BillingStatement bs ON a.admission_id = bs.admission_id
GROUP BY ROLLUP(s.dept_name, a.admission_type)
ORDER BY dept_grouping_level, type_grouping_level, department, admission_type;

-- Query 7: Advanced pivot using FILTER clause
-- Demonstrates: FILTER, multiple aggregations
SELECT 
    p.patient_id,
    p.full_name,
    COUNT(*) FILTER (WHERE a.admission_type = 'Emergency') AS emergency_admissions,
    COUNT(*) FILTER (WHERE a.admission_type = 'Planned') AS planned_admissions,
    COUNT(*) AS total_admissions,
    SUM(bs.total_cost) FILTER (WHERE a.admission_type = 'Emergency') AS emergency_costs,
    SUM(bs.total_cost) FILTER (WHERE a.admission_type = 'Planned') AS planned_costs,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.discharge_date - a.admission_date::date))/86400) 
          FILTER (WHERE a.discharge_date IS NOT NULL), 1) AS avg_length_of_stay_days
FROM Patient p
JOIN Admission a ON p.patient_id = a.patient_id
LEFT JOIN BillingStatement bs ON a.admission_id = bs.admission_id
GROUP BY p.patient_id, p.full_name
HAVING COUNT(*) > 1
ORDER BY total_admissions DESC;

-- =====================================================
-- SECTION 4: SUBQUERIES & CORRELATED QUERIES
-- =====================================================

-- Query 8: Find doctors treating more patients than department average
-- Demonstrates: Correlated subquery
SELECT 
    s.full_name,
    s.dept_name,
    COUNT(DISTINCT a.patient_id) AS patients_treated,
    (
        SELECT ROUND(AVG(patient_count), 2)
        FROM (
            SELECT COUNT(DISTINCT a2.patient_id) AS patient_count
            FROM Admission a2
            JOIN Doctor d2 ON a2.doctor_id = d2.doctor_id
            JOIN Staff s2 ON d2.doctor_id = s2.staff_id
            WHERE s2.dept_name = s.dept_name
            GROUP BY d2.doctor_id
        ) dept_avg
    ) AS dept_avg_patients
FROM Staff s
JOIN Doctor d ON s.staff_id = d.doctor_id
LEFT JOIN Admission a ON d.doctor_id = a.doctor_id
GROUP BY s.staff_id, s.full_name, s.dept_name
HAVING COUNT(DISTINCT a.patient_id) > (
    SELECT AVG(patient_count)
    FROM (
        SELECT COUNT(DISTINCT a2.patient_id) AS patient_count
        FROM Admission a2
        JOIN Doctor d2 ON a2.doctor_id = d2.doctor_id
        JOIN Staff s2 ON d2.doctor_id = s2.staff_id
        WHERE s2.dept_name = s.dept_name
        GROUP BY d2.doctor_id
    ) dept_avg
)
ORDER BY patients_treated DESC;

-- Query 9: Lateral join for top 3 most recent admissions per doctor
-- Demonstrates: LATERAL JOIN (PostgreSQL feature)
SELECT 
    s.full_name AS doctor_name,
    recent.patient_name,
    recent.admission_date,
    recent.admission_type,
    recent.primary_diagnosis
FROM Staff s
JOIN Doctor d ON s.staff_id = d.doctor_id
CROSS JOIN LATERAL (
    SELECT 
        p.full_name AS patient_name,
        a.admission_date,
        a.admission_type,
        a.primary_diagnosis
    FROM Admission a
    JOIN Patient p ON a.patient_id = p.patient_id
    WHERE a.doctor_id = d.doctor_id
    ORDER BY a.admission_date DESC
    LIMIT 3
) recent
ORDER BY s.full_name, recent.admission_date DESC;

-- =====================================================
-- SECTION 5: JSON AGGREGATION & ADVANCED FUNCTIONS
-- =====================================================

-- Query 10: Create JSON summary of doctor profiles
-- Demonstrates: JSON aggregation functions
SELECT 
    s.full_name AS doctor_name,
    s.dept_name,
    s.salary,
    d.medical_license_number,
    JSON_BUILD_OBJECT(
        'specialties', JSON_AGG(
            DISTINCT JSON_BUILD_OBJECT(
                'name', ds.specialty_name,
                'proficiency', ds.proficiency_level,
                'is_primary', ds.is_primary_specialty
            ) ORDER BY ds.is_primary_specialty DESC
        ),
        'active_patients', COUNT(DISTINCT CASE WHEN a.discharge_date IS NULL THEN a.admission_id END),
        'total_patients_treated', COUNT(DISTINCT a.patient_id),
        'contact', JSON_BUILD_OBJECT(
            'email', s.email,
            'mobile', s.mobile
        )
    ) AS doctor_profile
FROM Staff s
JOIN Doctor d ON s.staff_id = d.doctor_id
LEFT JOIN DoctorSpecialty ds ON d.doctor_id = ds.doctor_id
LEFT JOIN Admission a ON d.doctor_id = a.doctor_id
GROUP BY s.staff_id, s.full_name, s.dept_name, s.salary, s.email, s.mobile, d.medical_license_number
ORDER BY s.full_name;

-- Query 11: Complex patient summary with array aggregation
-- Demonstrates: ARRAY_AGG, STRING_AGG with complex expressions
SELECT 
    p.patient_id,
    p.full_name,
    p.blood_type,
    p.allergies,
    ARRAY_AGG(DISTINCT a.admission_type ORDER BY a.admission_type) AS admission_types,
    STRING_AGG(DISTINCT s.full_name, ', ' ORDER BY s.full_name) AS doctors_seen,
    COUNT(DISTINCT a.admission_id) AS total_visits,
    COALESCE(SUM(bs.total_cost), 0) AS lifetime_charges,
    COALESCE(SUM(bs.insurance_covered_amount), 0) AS insurance_paid,
    COALESCE(SUM(bs.remaining_balance), 0) AS patient_owes,
    JSON_AGG(
        JSON_BUILD_OBJECT(
            'admission_date', a.admission_date,
            'type', a.admission_type,
            'diagnosis', a.primary_diagnosis,
            'doctor', s.full_name,
            'length_of_stay', EXTRACT(DAY FROM (COALESCE(a.discharge_date, CURRENT_DATE) - a.admission_date::date))
        ) ORDER BY a.admission_date DESC
    ) FILTER (WHERE a.admission_id IS NOT NULL) AS admission_history
FROM Patient p
LEFT JOIN Admission a ON p.patient_id = a.patient_id
LEFT JOIN Doctor d ON a.doctor_id = d.doctor_id
LEFT JOIN Staff s ON d.doctor_id = s.staff_id
LEFT JOIN BillingStatement bs ON a.admission_id = bs.admission_id
GROUP BY p.patient_id, p.full_name, p.blood_type, p.allergies
ORDER BY total_visits DESC, p.full_name;

-- =====================================================
-- SECTION 6: STATISTICAL & ANALYTICAL QUERIES
-- =====================================================

-- Query 12: Percentile analysis of costs and length of stay
-- Demonstrates: PERCENTILE_CONT, statistical functions
WITH admission_metrics AS (
    SELECT 
        a.admission_id,
        a.admission_type,
        bs.total_cost,
        EXTRACT(DAY FROM (a.discharge_date - a.admission_date::date)) AS length_of_stay
    FROM Admission a
    LEFT JOIN BillingStatement bs ON a.admission_id = bs.admission_id
    WHERE a.discharge_date IS NOT NULL
)
SELECT 
    admission_type,
    COUNT(*) AS total_admissions,
    ROUND(AVG(total_cost), 2) AS avg_cost,
    ROUND(STDDEV(total_cost), 2) AS stddev_cost,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_cost), 2) AS cost_25th_percentile,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_cost), 2) AS cost_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_cost), 2) AS cost_75th_percentile,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_cost), 2) AS cost_90th_percentile,
    ROUND(AVG(length_of_stay), 1) AS avg_length_of_stay,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY length_of_stay), 1) AS median_length_of_stay
FROM admission_metrics
GROUP BY admission_type;

-- Query 13: Cohort analysis - patient readmission rates
-- Demonstrates: Self-join, complex date logic
WITH patient_admissions AS (
    SELECT 
        a1.patient_id,
        a1.admission_id AS first_admission,
        a1.discharge_date AS first_discharge,
        a2.admission_id AS next_admission,
        a2.admission_date AS next_admission_date,
        EXTRACT(DAY FROM (a2.admission_date - a1.discharge_date)) AS days_until_readmission,
        ROW_NUMBER() OVER (PARTITION BY a1.admission_id ORDER BY a2.admission_date) AS readmission_sequence
    FROM Admission a1
    LEFT JOIN Admission a2 ON a1.patient_id = a2.patient_id 
        AND a2.admission_date > a1.discharge_date
        AND a2.admission_date <= a1.discharge_date + INTERVAL '30 days'
    WHERE a1.discharge_date IS NOT NULL
)
SELECT 
    CASE 
        WHEN days_until_readmission IS NULL THEN 'No readmission within 30 days'
        WHEN days_until_readmission <= 7 THEN 'Readmitted within 7 days'
        WHEN days_until_readmission <= 14 THEN 'Readmitted within 14 days'
        ELSE 'Readmitted within 30 days'
    END AS readmission_timeframe,
    COUNT(DISTINCT patient_id) AS patient_count,
    COUNT(DISTINCT first_admission) AS total_discharges,
    ROUND(COUNT(DISTINCT patient_id)::numeric / COUNT(DISTINCT first_admission) * 100, 2) AS readmission_rate
FROM patient_admissions
WHERE readmission_sequence = 1 OR readmission_sequence IS NULL
GROUP BY 
    CASE 
        WHEN days_until_readmission IS NULL THEN 'No readmission within 30 days'
        WHEN days_until_readmission <= 7 THEN 'Readmitted within 7 days'
        WHEN days_until_readmission <= 14 THEN 'Readmitted within 14 days'
        ELSE 'Readmitted within 30 days'
    END
ORDER BY 
    CASE 
        WHEN days_until_readmission IS NULL THEN 4
        WHEN days_until_readmission <= 7 THEN 1
        WHEN days_until_readmission <= 14 THEN 2
        ELSE 3
    END;

-- =====================================================
-- SECTION 7: COMPLEX BUSINESS LOGIC QUERIES
-- =====================================================

-- Query 14: Doctor workload balancing analysis
-- Demonstrates: Multiple CTEs, complex calculations
WITH doctor_workload AS (
    SELECT 
        d.doctor_id,
        s.full_name,
        s.dept_name,
        COUNT(DISTINCT CASE WHEN a.discharge_date IS NULL THEN a.patient_id END) AS current_patients,
        COUNT(DISTINCT a.patient_id) AS total_patients_treated,
        COALESCE(SUM(CASE WHEN a.discharge_date IS NULL 
            THEN EXTRACT(DAY FROM (CURRENT_DATE - a.admission_date::date)) END), 0) AS total_active_patient_days,
        COUNT(DISTINCT ds.specialty_name) AS specialty_count
    FROM Doctor d
    JOIN Staff s ON d.doctor_id = s.staff_id
    LEFT JOIN Admission a ON d.doctor_id = a.doctor_id
    LEFT JOIN DoctorSpecialty ds ON d.doctor_id = ds.doctor_id
    GROUP BY d.doctor_id, s.full_name, s.dept_name
),
dept_benchmarks AS (
    SELECT 
        dept_name,
        AVG(current_patients) AS avg_current_patients,
        AVG(total_active_patient_days) AS avg_patient_days,
        STDDEV(current_patients) AS stddev_current_patients
    FROM doctor_workload
    GROUP BY dept_name
)
SELECT 
    dw.full_name,
    dw.dept_name,
    dw.current_patients,
    ROUND(db.avg_current_patients, 2) AS dept_avg_patients,
    dw.current_patients - db.avg_current_patients AS variance_from_avg,
    CASE 
        WHEN dw.current_patients > db.avg_current_patients + db.stddev_current_patients 
            THEN 'OVERLOADED'
        WHEN dw.current_patients < db.avg_current_patients - db.stddev_current_patients 
            THEN 'UNDERUTILIZED'
        ELSE 'NORMAL'
    END AS workload_status,
    dw.total_active_patient_days AS active_patient_days,
    ROUND(dw.total_active_patient_days::numeric / NULLIF(dw.current_patients, 0), 1) AS avg_days_per_patient,
    dw.specialty_count
FROM doctor_workload dw
JOIN dept_benchmarks db ON dw.dept_name = db.dept_name
ORDER BY 
    CASE 
        WHEN dw.current_patients > db.avg_current_patients + db.stddev_current_patients THEN 1
        WHEN dw.current_patients < db.avg_current_patients - db.stddev_current_patients THEN 3
        ELSE 2
    END,
    dw.current_patients DESC;

-- Query 15: Revenue analysis with payment collection rate
-- Demonstrates: Complex financial calculations
WITH billing_summary AS (
    SELECT 
        DATE_TRUNC('month', bs.discharge_date) AS billing_month,
        s.dept_name,
        COUNT(DISTINCT bs.billing_id) AS bills_issued,
        SUM(bs.total_cost) AS total_billed,
        SUM(bs.insurance_covered_amount) AS insurance_collected,
        SUM(bs.remaining_balance) AS patient_owed,
        SUM(i.amount_due) AS invoices_issued,
        COALESCE(SUM(p.payment_amount), 0) AS payments_received
    FROM BillingStatement bs
    JOIN Admission a ON bs.admission_id = a.admission_id
    JOIN Doctor d ON a.doctor_id = d.doctor_id
    JOIN Staff s ON d.doctor_id = s.staff_id
    LEFT JOIN Invoice i ON bs.billing_id = i.billing_id
    LEFT JOIN Payment p ON i.invoice_id = p.invoice_id AND p.payment_status = 'Completed'
    GROUP BY DATE_TRUNC('month', bs.discharge_date), s.dept_name
)
SELECT 
    billing_month,
    dept_name,
    bills_issued,
    total_billed,
    insurance_collected,
    patient_owed,
    payments_received,
    patient_owed - payments_received AS outstanding_balance,
    ROUND(payments_received::numeric / NULLIF(patient_owed, 0) * 100, 2) AS collection_rate_pct,
    ROUND(total_billed::numeric / NULLIF(bills_issued, 0), 2) AS avg_bill_amount,
    LAG(total_billed) OVER (PARTITION BY dept_name ORDER BY billing_month) AS previous_month_revenue,
    total_billed - LAG(total_billed) OVER (PARTITION BY dept_name ORDER BY billing_month) AS month_over_month_change,
    ROUND((total_billed - LAG(total_billed) OVER (PARTITION BY dept_name ORDER BY billing_month))::numeric / 
          NULLIF(LAG(total_billed) OVER (PARTITION BY dept_name ORDER BY billing_month), 0) * 100, 2) AS mom_growth_pct
FROM billing_summary
ORDER BY billing_month DESC, dept_name;

-- Query 16: Advanced resource utilization - beds and staff
-- Demonstrates: Multiple window functions, complex joins
SELECT 
    w.ward_name,
    w.ward_type,
    d.dept_name,
    COUNT(DISTINCT b.bed_id) AS total_beds,
    COUNT(DISTINCT CASE WHEN b.bed_status = 'Occupied' THEN b.bed_id END) AS occupied_beds,
    ROUND(COUNT(DISTINCT CASE WHEN b.bed_status = 'Occupied' THEN b.bed_id END)::numeric / 
          COUNT(DISTINCT b.bed_id) * 100, 2) AS occupancy_rate,
    COUNT(DISTINCT s.staff_id) AS staff_assigned,
    COUNT(DISTINCT a.admission_id) AS current_admissions,
    ROUND(COUNT(DISTINCT a.admission_id)::numeric / 
          NULLIF(COUNT(DISTINCT s.staff_id), 0), 2) AS patients_per_staff_member,
    ROUND(AVG(b.bed_cost), 2) AS avg_bed_cost,
    SUM(b.bed_cost) AS total_bed_inventory_value,
    PERCENT_RANK() OVER (ORDER BY COUNT(DISTINCT CASE WHEN b.bed_status = 'Occupied' THEN b.bed_id END)::numeric / 
                                  COUNT(DISTINCT b.bed_id)) AS occupancy_percentile
FROM Ward w
JOIN Department d ON w.dept_name = d.dept_name
LEFT JOIN Bed b ON w.ward_id = b.ward_id
LEFT JOIN Staff s ON d.dept_name = s.dept_name
LEFT JOIN Admission a ON b.bed_id = a.bed_id AND a.discharge_date IS NULL
GROUP BY w.ward_id, w.ward_name, w.ward_type, d.dept_name
ORDER BY occupancy_rate DESC;

-- =====================================================
-- SECTION 8: DATA QUALITY & AUDIT QUERIES
-- =====================================================

-- Query 17: Data quality checks across all tables
-- Demonstrates: UNION ALL, multiple validation checks
SELECT 'Missing Email' AS issue_type, COUNT(*) AS issue_count, 'Staff' AS table_name
FROM Staff WHERE email IS NULL
UNION ALL
SELECT 'Expired Medical License', COUNT(*), 'Doctor'
FROM Doctor WHERE license_expiry_date < CURRENT_DATE
UNION ALL
SELECT 'Expired WWCC', COUNT(*), 'Nurse'
FROM Nurse WHERE wwcc_clearance = TRUE AND wwcc_expiry_date < CURRENT_DATE
UNION ALL
SELECT 'Admission without Discharge after 30 days', COUNT(*), 'Admission'
FROM Admission WHERE discharge_date IS NULL AND admission_date < CURRENT_DATE - INTERVAL '30 days'
UNION ALL
SELECT 'Bed Occupied but No Active Admission', COUNT(*), 'Bed'
FROM Bed b WHERE b.bed_status = 'Occupied' 
    AND NOT EXISTS (SELECT 1 FROM Admission a WHERE a.bed_id = b.bed_id AND a.discharge_date IS NULL)
UNION ALL
SELECT 'Invoice Overdue >60 days', COUNT(*), 'Invoice'
FROM Invoice WHERE payment_status = 'Unpaid' AND due_date < CURRENT_DATE - INTERVAL '60 days'
UNION ALL
SELECT 'Doctor with No Specialties', COUNT(*), 'Doctor'
FROM Doctor d WHERE NOT EXISTS (SELECT 1 FROM DoctorSpecialty ds WHERE ds.doctor_id = d.doctor_id)
UNION ALL
SELECT 'Doctor with >5 Specialties', COUNT(*), 'Doctor'
FROM Doctor d WHERE (SELECT COUNT(*) FROM DoctorSpecialty ds WHERE ds.doctor_id = d.doctor_id) > 5
ORDER BY issue_count DESC;

-- Query 18: Audit trail - who modified what when (if we had audit columns)
-- Demonstrates: Complex temporal queries
SELECT 
    'Recent Admissions' AS activity,
    a.admission_id AS record_id,
    p.full_name AS related_to,
    a.admission_date AS activity_date,
    'Created' AS action,
    s.full_name AS performed_by
FROM Admission a
JOIN Patient p ON a.patient_id = p.patient_id
JOIN Doctor d ON a.doctor_id = d.doctor_id
JOIN Staff s ON d.doctor_id = s.staff_id
WHERE a.admission_date >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
    'Recent Discharges',
    a.admission_id,
    p.full_name,
    a.discharge_date,
    'Discharged',
    s.full_name
FROM Admission a
JOIN Patient p ON a.patient_id = p.patient_id
JOIN Doctor d ON a.doctor_id = d.doctor_id
JOIN Staff s ON d.doctor_id = s.staff_id
WHERE a.discharge_date >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
    'Recent Payments',
    py.payment_id,
    pt.full_name,
    py.payment_date,
    'Payment Received',
    'System'
FROM Payment py
JOIN Invoice i ON py.invoice_id = i.invoice_id
JOIN BillingStatement bs ON i.billing_id = bs.billing_id
JOIN Admission a ON bs.admission_id = a.admission_id
JOIN Patient pt ON a.patient_id = pt.patient_id
WHERE py.payment_date >= CURRENT_DATE - INTERVAL '7 days'

ORDER BY activity_date DESC
LIMIT 50;

-- =====================================================
-- SECTION 9: PREDICTIVE & FORECASTING QUERIES
-- =====================================================

-- Query 19: Predict bed needs based on historical trends
-- Demonstrates: Time series analysis with linear regression
WITH monthly_admissions AS (
    SELECT 
        DATE_TRUNC('month', admission_date) AS month,
        COUNT(*) AS admission_count,
        EXTRACT(EPOCH FROM DATE_TRUNC('month', admission_date)) AS month_numeric
    FROM Admission
    GROUP BY DATE_TRUNC('month', admission_date)
),
regression_stats AS (
    SELECT 
        REGR_SLOPE(admission_count, month_numeric) AS slope,
        REGR_INTERCEPT(admission_count, month_numeric) AS intercept,
        CORR(admission_count, month_numeric) AS correlation
    FROM monthly_admissions
)
SELECT 
    ma.month,
    ma.admission_count AS actual_admissions,
    ROUND(rs.slope * ma.month_numeric + rs.intercept, 2) AS predicted_admissions,
    ROUND(rs.correlation, 4) AS correlation_coefficient,
    ROUND((rs.slope * EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '1 month')) + rs.intercept), 0) AS next_month_forecast
FROM monthly_admissions ma
CROSS JOIN regression_stats rs
ORDER BY ma.month DESC
LIMIT 12;

-- Query 20: Performance dashboard query
-- Demonstrates: Bringing it all together
WITH department_metrics AS (
    SELECT 
        d.dept_name,
        COUNT(DISTINCT s.staff_id) AS total_staff,
        COUNT(DISTINCT CASE WHEN s.staff_type = 'Doctor' THEN s.staff_id END) AS doctors,
        COUNT(DISTINCT CASE WHEN s.staff_type = 'Nurse' THEN s.staff_id END) AS nurses,
        COUNT(DISTINCT a.admission_id) AS total_admissions,
        COUNT(DISTINCT CASE WHEN a.discharge_date IS NULL THEN a.admission_id END) AS active_admissions,
        COALESCE(SUM(bs.total_cost), 0) AS total_revenue,
        COALESCE(AVG(EXTRACT(DAY FROM (a.discharge_date - a.admission_date::date))), 0) AS avg_los
    FROM Department d
    LEFT JOIN Staff s ON d.dept_name = s.dept_name
    LEFT JOIN Doctor doc ON s.staff_id = doc.doctor_id
    LEFT JOIN Admission a ON doc.doctor_id = a.doctor_id
    LEFT JOIN BillingStatement bs ON a.admission_id = bs.admission_id
    GROUP BY d.dept_name
),
bed_metrics AS (
    SELECT 
        d.dept_name,
        COUNT(b.bed_id) AS total_beds,
        COUNT(CASE WHEN b.bed_status = 'Available' THEN 1 END) AS available_beds,
        ROUND(COUNT(CASE WHEN b.bed_status = 'Occupied' THEN 1 END)::numeric / 
              NULLIF(COUNT(b.bed_id), 0) * 100, 2) AS occupancy_rate
    FROM Department d
    LEFT JOIN Ward w ON d.dept_name = w.dept_name
    LEFT JOIN Bed b ON w.ward_id = b.ward_id
    GROUP BY d.dept_name
)
SELECT 
    dm.dept_name,
    dm.total_staff,
    dm.doctors,
    dm.nurses,
    bm.total_beds,
    bm.available_beds,
    bm.occupancy_rate,
    dm.total_admissions,
    dm.active_admissions,
    ROUND(dm.active_admissions::numeric / NULLIF(dm.doctors, 0), 2) AS patients_per_doctor,
    ROUND(dm.active_admissions::numeric / NULLIF(dm.nurses, 0), 2) AS patients_per_nurse,
    dm.total_revenue,
    ROUND(dm.total_revenue / NULLIF(dm.total_admissions, 0), 2) AS revenue_per_admission,
    ROUND(dm.avg_los, 1) AS avg_length_of_stay,
    CASE 
        WHEN bm.occupancy_rate > 90 THEN 'HIGH UTILIZATION'
        WHEN bm.occupancy_rate > 70 THEN 'OPTIMAL'
        WHEN bm.occupancy_rate > 50 THEN 'MODERATE'
        ELSE 'LOW UTILIZATION'
    END AS utilization_status,
    RANK() OVER (ORDER BY dm.total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY dm.total_admissions DESC) AS admission_rank
FROM department_metrics dm
JOIN bed_metrics bm ON dm.dept_name = bm.dept_name
ORDER BY dm.total_revenue DESC;

CREATE TABLE users (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  
  full_name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  phone_number VARCHAR(15) UNIQUE,
  
  password_hash VARCHAR(255) NOT NULL COMMENT 'Hashed password for authentication',
  user_type ENUM('borrower', 'investor', 'admin') NOT NULL DEFAULT 'borrower' COMMENT 'Type of user',
  
  date_of_birth DATE,
  gender ENUM('Male', 'Female', 'Other') DEFAULT NULL,
  
  address TEXT,
  city VARCHAR(50),
  state VARCHAR(50),
  country VARCHAR(50) DEFAULT 'India',
  pincode VARCHAR(10),

  is_email_verified BOOLEAN DEFAULT FALSE,
  is_phone_verified BOOLEAN DEFAULT FALSE,
  
  kyc_status ENUM('Not Submitted', 'Pending', 'Verified', 'Rejected') DEFAULT 'Not Submitted',
  
  account_status ENUM('Active', 'Suspended', 'Deactivated') DEFAULT 'Active',
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  last_login DATETIME DEFAULT NULL
  
  -- Foreign Key to KYC table (optional)
  -- kyc_id INT, 
  -- FOREIGN KEY (kyc_id) REFERENCES kyc(kyc_id),

  -- COMMENT 'Stores user profile, role, and authentication details'
);


CREATE TABLE loans (
  loan_id INT AUTO_INCREMENT PRIMARY KEY,

  borrower_id INT NOT NULL COMMENT 'Refers to the user requesting the loan',
  amount_requested DECIMAL(12,2) NOT NULL COMMENT 'Total amount borrower wants',
  interest_rate DECIMAL(5,2) NOT NULL COMMENT 'Annual interest rate (in %)',
  duration_months INT NOT NULL COMMENT 'Loan duration in months',
  purpose TEXT NOT NULL COMMENT 'Purpose of the loan as written by borrower',
  
  loan_type ENUM('Personal', 'Education', 'Medical', 'Business', 'Other') DEFAULT 'Personal' COMMENT 'Type of loan',
  risk_rating ENUM('Low', 'Medium', 'High') DEFAULT 'Medium' COMMENT 'Assigned risk category after evaluation',
  
  emi_amount DECIMAL(12,2) GENERATED ALWAYS AS (
    ROUND(
      (amount_requested * (interest_rate/100) / 12) / 
      (1 - POWER(1 + (interest_rate/100)/12, -duration_months)) + 0.00001,
      2
    )
  ) STORED COMMENT 'Monthly EMI (approx. based on formula)',
  
  status ENUM('Open', 'Funded', 'Active', 'Completed', 'Defaulted', 'Cancelled') DEFAULT 'Open' COMMENT 'Loan status',
  
  funded_amount DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Current funded amount (updated via trigger/procedure)',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Loan listing creation time',
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (borrower_id) REFERENCES users(user_id)

  -- COMMENT = 'Stores borrower loan requests, interest, duration, EMI, and status'
);



CREATE TABLE investments (
  investment_id INT AUTO_INCREMENT PRIMARY KEY,

  investor_id INT NOT NULL COMMENT 'User ID of the investor',
  loan_id INT NOT NULL COMMENT 'Loan ID in which the investment is made',
  
  invested_amount DECIMAL(12,2) NOT NULL CHECK (invested_amount > 0) COMMENT 'Amount invested in the loan',
  
  investment_status ENUM('Active', 'Sold', 'Withdrawn') DEFAULT 'Active' COMMENT 'Status of this investment',
  
  ownership_percent DECIMAL(5,2) DEFAULT NULL COMMENT 'Percentage ownership in the loan (updated via trigger/procedure)',

  investment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when investment was made',

  
  is_for_sale BOOLEAN DEFAULT FALSE COMMENT 'If true, investor wants to sell this share',
  listed_price DECIMAL(12,2) DEFAULT NULL COMMENT 'Price at which investment is listed for resale',

  FOREIGN KEY (investor_id) REFERENCES users(user_id),
  FOREIGN KEY (loan_id) REFERENCES loans(loan_id)

  -- COMMENT = 'Tracks all investments by investors into borrower loan listings'
);


CREATE TABLE loan_funding (
  funding_id INT AUTO_INCREMENT PRIMARY KEY,
  loan_id INT NOT NULL UNIQUE COMMENT 'Each loan has one funding tracker row',
  total_required DECIMAL(12,2) NOT NULL COMMENT 'Same as amount_requested from loans',
  total_funded DECIMAL(12,2) DEFAULT 0.00 COMMENT 'Sum of all investments made so far',
  funding_status ENUM('Partial', 'Fully Funded') DEFAULT 'Partial',
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (loan_id) REFERENCES loans(loan_id)

  -- COMMENT = 'Tracks funding progress of each loan listing'
);


CREATE TABLE repayment_schedules (
  schedule_id INT AUTO_INCREMENT PRIMARY KEY,
  loan_id INT NOT NULL,
  due_date DATE NOT NULL,
  installment_number INT NOT NULL COMMENT 'EMI number (1, 2, ...)',
  amount_due DECIMAL(12,2) NOT NULL,
  amount_paid DECIMAL(12,2) DEFAULT 0.00,
  status ENUM('Pending', 'Paid', 'Overdue') DEFAULT 'Pending',
  payment_date DATE DEFAULT NULL,

  FOREIGN KEY (loan_id) REFERENCES loans(loan_id) 
  -- COMMENT = 'Stores repayment EMIs for each funded loan'
);


CREATE TABLE transactions (
  transaction_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  loan_id INT DEFAULT NULL,
  investment_id INT DEFAULT NULL,
  repayment_schedule_id INT DEFAULT NULL,

  transaction_type ENUM('Investment', 'Repayment', 'Payout', 'Withdrawal', 'Penalty') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  remarks VARCHAR(255),

  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (loan_id) REFERENCES loans(loan_id),
  FOREIGN KEY (investment_id) REFERENCES investments(investment_id),
  FOREIGN KEY (repayment_schedule_id) REFERENCES repayment_schedules(schedule_id)

  -- COMMENT = 'Logs all financial transactions in the system'
);


CREATE TABLE loan_status_history (
  history_id INT AUTO_INCREMENT PRIMARY KEY,
  loan_id INT NOT NULL,
  old_status ENUM('Open', 'Funded', 'Active', 'Completed', 'Defaulted', 'Cancelled'),
  new_status ENUM('Open', 'Funded', 'Active', 'Completed', 'Defaulted', 'Cancelled'),
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  changed_by INT NOT NULL COMMENT 'Admin or system user who triggered change',

  FOREIGN KEY (loan_id) REFERENCES loans(loan_id),
  FOREIGN KEY (changed_by) REFERENCES users(user_id)

  -- COMMENT = 'Tracks all status transitions of a loan'
);


CREATE TABLE audit_log (
  audit_id INT AUTO_INCREMENT PRIMARY KEY,
  action ENUM('Loan Created', 'Investment Made', 'Repayment Made', 'Status Changed', 'KYC Updated') NOT NULL,
  entity_type ENUM('loan', 'investment', 'user', 'transaction', 'repayment') NOT NULL,
  entity_id INT NOT NULL,
  action_by INT NOT NULL COMMENT 'User who triggered the action',
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  remarks TEXT,

  FOREIGN KEY (action_by) REFERENCES users(user_id)

  -- COMMENT = 'Generic audit trail for important actions across the platform'
);

-- SAMPLE DATA INSERTION
INSERT INTO users (full_name, email, phone_number, password_hash, user_type, date_of_birth, gender, address, city, state, country, pincode, is_email_verified, is_phone_verified, kyc_status, account_status)
VALUES
('Aarav Sharma', 'aarav.sharma01@example.com', '9876543210', 'hashpass123', 'borrower', '1995-04-15', 'Male', '23 Green St', 'Mumbai', 'Maharashtra', 'India', '400001', TRUE, TRUE, 'Verified', 'Active'),
('Naina Kapoor', 'naina.kapoor98@example.com', '7894561230', 'hashpass456', 'investor', '1988-09-21', 'Female', '78 Sunrise Apt', 'Delhi', 'Delhi', 'India', '110011', TRUE, FALSE, 'Verified', 'Active'),
('Rahul Mehta', 'rahul.mehta77@example.com', '9123456789', 'hashpass789', 'admin', '1990-12-02', 'Male', '45 Lake View', 'Bangalore', 'Karnataka', 'India', '560001', TRUE, TRUE, 'Verified', 'Active');
  
SELECT * from users;

INSERT INTO loans (borrower_id, amount_requested, interest_rate, duration_months, purpose, loan_type, risk_rating, status, funded_amount)
VALUES
(1, 250000.00, 12.5, 24, 'To renovate my home', 'Personal', 'Medium', 'Open', 0.00),
(1, 500000.00, 10.0, 36, 'Start a new retail shop', 'Business', 'High', 'Open', 0.00);

SELECT * from loans;

INSERT INTO investments (investor_id, loan_id, invested_amount, investment_status, ownership_percent, is_for_sale, listed_price)
VALUES
(2, 1, 100000.00, 'Active', 40.00, FALSE, NULL),
(2, 2, 200000.00, 'Active', 40.00, TRUE, 210000.00);

SELECT * from investments;

INSERT INTO loan_funding (loan_id, total_required, total_funded, funding_status)
VALUES
(1, 250000.00, 100000.00, 'Partial'),
(2, 500000.00, 200000.00, 'Partial');

SELECT * from loan_funding;

INSERT INTO repayment_schedules (loan_id, due_date, installment_number, amount_due, amount_paid, status, payment_date)
VALUES
(1, '2025-07-01', 1, 11750.00, 11750.00, 'Paid', '2025-07-01'),
(1, '2025-08-01', 2, 11750.00, 0.00, 'Pending', NULL),
(2, '2025-07-10', 1, 16200.00, 0.00, 'Pending', NULL);

SELECT * from repayment_schedules;
  
INSERT INTO transactions (user_id, loan_id, investment_id, repayment_schedule_id, transaction_type, amount, remarks)
VALUES
(2, 1, 1, NULL, 'Investment', 100000.00, 'Initial investment in home renovation loan'),
(2, 2, 2, NULL, 'Investment', 200000.00, 'Investment for retail shop'),
(1, 1, NULL, 1, 'Repayment', 11750.00, 'EMI 1 paid successfully');
SELECT * from transactions;

INSERT INTO loan_status_history (loan_id, old_status, new_status, changed_by)
VALUES
(1, 'Open', 'Funded', 3),
(1, 'Funded', 'Active', 3),
(2, 'Open', 'Funded', 3);

SELECT * from loan_status_history;

INSERT INTO audit_log (action, entity_type, entity_id, action_by, remarks)
VALUES
('Loan Created', 'loan', 1, 1, 'Borrower created loan for renovation'),
('Investment Made', 'investment', 1, 2, 'Investor contributed ₹1L to loan 1'),
('Repayment Made', 'repayment', 1, 1, 'EMI 1 paid by borrower');

SELECT * from audit_log;

-- SQL Queries
--  1. List All Active Loans 
SELECT * FROM loans 
WHERE status IN ('Open', 'Funded');

-- 2. Show Investor Portfolio 
SELECT 
  i.investment_id,
  i.investor_id,
  i.loan_id,
  l.purpose,
  i.invested_amount,
  i.ownership_percent,
  i.investment_status,
  l.status AS loan_status
FROM investments i
JOIN loans l ON i.loan_id = l.loan_id
WHERE i.investor_id = 2;

-- 3. Borrower’s Active Loans 
SELECT 
  loan_id,
  amount_requested,
  funded_amount,
  status,
  created_at
FROM loans
WHERE borrower_id = 1 AND status IN ('Open', 'Funded', 'Active');

--  Repayment History for a Loan
SELECT 
  installment_number,
  due_date,
  amount_due,
  amount_paid,
  status,
  payment_date
FROM repayment_schedules
WHERE loan_id = 1
ORDER BY installment_number;

-- View All Transactions by a User
SELECT 
  transaction_id,
  transaction_type,
  amount,
  transaction_date,
  remarks
FROM transactions
WHERE user_id = 2
ORDER BY transaction_date DESC;

-- 6. Loan Funding Progress 
SELECT 
  l.loan_id,
  l.purpose,
  f.total_required,
  f.total_funded,
  f.funding_status
FROM loans l
JOIN loan_funding f ON l.loan_id = f.loan_id
WHERE l.status IN ('Open', 'Funded');

-- 7. Loans That Have Been Fully Repaid
SELECT 
  loan_id,
  borrower_id,
  amount_requested,
  status
FROM loans
WHERE status = 'Completed';

-- 8. Audit Log of Platform Actions
SELECT 
  action,
  entity_type,
  entity_id,
  action_by,
  timestamp,
  remarks
FROM audit_log
ORDER BY timestamp DESC;

-- 9: List Overdue Repayments
SELECT 
  r.schedule_id,
  r.loan_id,
  r.installment_number,
  r.due_date,
  r.amount_due,
  r.amount_paid,
  r.status
FROM repayment_schedules r
JOIN loans l ON r.loan_id = l.loan_id
WHERE r.status = 'Overdue'
ORDER BY r.due_date ASC;

-- 10.Loans Created in the Last 30 Days
SELECT 
  loan_id,
  borrower_id,
  amount_requested,
  created_at,
  status
FROM loans
WHERE created_at >= CURDATE() - INTERVAL 30 DAY
ORDER BY created_at DESC;

-- Implement stored procedures:
-- 1. FundLoan – When an investor invests in a loan
DELIMITER $$

CREATE PROCEDURE FundLoan (
  IN p_investor_id INT,
  IN p_loan_id INT,
  IN p_amount DECIMAL(12,2)
)
BEGIN
  DECLARE total_required DECIMAL(12,2);
  DECLARE total_funded DECIMAL(12,2);

  -- Step 1: Add new investment
  INSERT INTO investments (investor_id, loan_id, invested_amount)
  VALUES (p_investor_id, p_loan_id, p_amount);

  -- Step 2: Update funded amount
  UPDATE loan_funding
  SET total_funded = total_funded + p_amount
  WHERE loan_id = p_loan_id;

  -- Step 3: Check if loan is fully funded
  SELECT total_required, total_funded INTO total_required, total_funded
  FROM loan_funding
  WHERE loan_id = p_loan_id;

  -- Step 4: If fully funded, update status
  IF total_funded >= total_required THEN
    UPDATE loans
    SET status = 'Funded'
    WHERE loan_id = p_loan_id;

    UPDATE loan_funding
    SET funding_status = 'Fully Funded'
    WHERE loan_id = p_loan_id;
  END IF;

  -- Step 5: Add entry in audit log
  INSERT INTO audit_log (action, entity_type, entity_id, action_by, remarks)
  VALUES ('Investment Made', 'investment', LAST_INSERT_ID(), p_investor_id, 'Funded via stored procedure');
END$$

DELIMITER ;

CALL FundLoan(2, 1, 50000.00);
select * from investments;

-- 2. MakeRepayment – When a borrower pays EMI
DELIMITER $$

CREATE PROCEDURE MakeRepayment (
  IN p_loan_id INT,
  IN p_schedule_id INT,
  IN p_amount DECIMAL(12,2)
)
BEGIN
  DECLARE due_amount DECIMAL(12,2);
  DECLARE borrower INT;

  -- Step 1: Get amount due
  SELECT amount_due INTO due_amount
  FROM repayment_schedules
  WHERE schedule_id = p_schedule_id;

  -- Step 2: Get borrower ID
  SELECT borrower_id INTO borrower
  FROM loans
  WHERE loan_id = p_loan_id;

  -- Step 3: Update repayment
  UPDATE repayment_schedules
  SET amount_paid = p_amount,
      status = CASE
                WHEN p_amount >= due_amount THEN 'Paid'
                ELSE 'Pending'
              END,
      payment_date = CURDATE()
  WHERE schedule_id = p_schedule_id;

  -- Step 4: Add transaction
  INSERT INTO transactions (
    user_id, loan_id, repayment_schedule_id,
    transaction_type, amount, remarks
  )
  VALUES (
    borrower, p_loan_id, p_schedule_id,
    'Repayment', p_amount, 'EMI paid via procedure'
  );

  -- Step 5: Log the action
  INSERT INTO audit_log (
    action, entity_type, entity_id, action_by, remarks
  )
  VALUES (
    'Repayment Made', 'repayment', p_schedule_id,
    borrower, 'EMI marked as paid via procedure'
  );
END$$

DELIMITER ;

CALL MakeRepayment(1, 1, 11750.00);
select * from repayment_schedules;

-- 3. WithdrawInvestment – Investor withdraws their investment
DELIMITER $$

CREATE PROCEDURE WithdrawInvestment (
  IN p_investment_id INT,
  IN p_investor_id INT
)
BEGIN
  DECLARE v_invested_amount DECIMAL(12,2);
  DECLARE v_loan_id INT;
  DECLARE v_total_funded DECIMAL(12,2);
  DECLARE v_total_required DECIMAL(12,2);

  -- Check if investment exists, belongs to investor, and is active
  IF NOT EXISTS (
    SELECT 1 FROM investments
    WHERE investment_id = p_investment_id
      AND investor_id = p_investor_id
      AND investment_status = 'Active'
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid investment or already withdrawn';
  END IF;

  -- Get invested amount and loan id
  SELECT invested_amount, loan_id INTO v_invested_amount, v_loan_id
  FROM investments
  WHERE investment_id = p_investment_id;

  -- Mark investment as withdrawn and reset amounts
  UPDATE investments
  SET investment_status = 'Withdrawn',
      invested_amount = 0,
      ownership_percent = 0,
      is_for_sale = FALSE,
      listed_price = NULL
  WHERE investment_id = p_investment_id;

  -- Get current total_required and total_funded
  SELECT total_required, total_funded INTO v_total_required, v_total_funded
  FROM loan_funding
  WHERE loan_id = v_loan_id;

  -- Deduct invested amount from total_funded
  SET v_total_funded = v_total_funded - v_invested_amount;

  -- Update loan_funding table
  UPDATE loan_funding
  SET total_funded = v_total_funded,
      funding_status = IF(v_total_funded < v_total_required, 'Partial', 'Fully Funded')
  WHERE loan_id = v_loan_id;

  -- Update loan status based on funding amount
  UPDATE loans
  SET status = IF(v_total_funded < amount_requested, 'Open', status)
  WHERE loan_id = v_loan_id;

  -- Insert audit log
  INSERT INTO audit_log (action, entity_type, entity_id, action_by, remarks)
  VALUES ('Withdrawal', 'investment', p_investment_id, p_investor_id, 'Investment withdrawn via procedure');
END$$

DELIMITER ;


CALL WithdrawInvestment(20, 2);


-- 1. Trigger: Audit Log Insert for Investments
DELIMITER $$

CREATE TRIGGER trg_investment_after_insert
AFTER INSERT ON investments
FOR EACH ROW
BEGIN
  INSERT INTO audit_log (
    action, entity_type, entity_id, action_by, remarks
  ) VALUES (
    'Investment Made',
    'investment',
    NEW.investment_id,
    NEW.investor_id,
    CONCAT('Investment of ', NEW.invested_amount, ' made for loan ', NEW.loan_id)
  );
END$$

DELIMITER ;

-- 2. Trigger: Update Loan Status to "Active" on First Repayment
DELIMITER $$

CREATE TRIGGER trg_repayment_after_update
AFTER UPDATE ON repayment_schedules
FOR EACH ROW
BEGIN
  DECLARE paid_count INT;

  IF NEW.status = 'Paid' AND OLD.status <> 'Paid' THEN
    -- Count how many repayments for this loan are paid
    SELECT COUNT(*) INTO paid_count
    FROM repayment_schedules
    WHERE loan_id = NEW.loan_id AND status = 'Paid';

    -- If this is the first paid repayment, update loan status from 'Funded' to 'Active'
    IF paid_count = 1 THEN
      UPDATE loans SET status = 'Active' WHERE loan_id = NEW.loan_id AND status = 'Funded';
    END IF;

    -- Log repayment in audit_log
    INSERT INTO audit_log (
      action, entity_type, entity_id, action_by, remarks
    ) VALUES (
      'Repayment Made',
      'repayment',
      NEW.schedule_id,
      (SELECT borrower_id FROM loans WHERE loan_id = NEW.loan_id),
      CONCAT('EMI #', NEW.installment_number, ' paid for loan ', NEW.loan_id)
    );
  END IF;
END$$

DELIMITER ;

-- 3. Trigger: Audit Log on Loan Status Change
DELIMITER $$

CREATE TRIGGER trg_loan_status_update
BEFORE UPDATE ON loans
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status THEN
    INSERT INTO loan_status_history (
      loan_id,
      old_status,
      new_status,
      changed_at,
      changed_by
    ) VALUES (
      OLD.loan_id,
      OLD.status,
      NEW.status,
      NOW(),
      NULL -- You can set a user ID if available in session/context
    );

    INSERT INTO audit_log (
      action, entity_type, entity_id, action_by, remarks
    ) VALUES (
      'Status Changed',
      'loan',
      OLD.loan_id,
      NULL, -- Set user id if known
      CONCAT('Loan status changed from ', OLD.status, ' to ', NEW.status)
    );
  END IF;
END$$

DELIMITER ;

INSERT INTO investments (investor_id, loan_id, invested_amount)
VALUES (2, 1, 50000.00);
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 1;







-- ============================================================
--  PROJECT KASHI - Banking Management System
--  File 1 of 3: schema.sql  (tables, views, functions,
--  stored procedures, triggers)
--  Run this FIRST, then sample_data.sql
-- ============================================================

DROP DATABASE IF EXISTS kashi_bank;
CREATE DATABASE kashi_bank;
USE kashi_bank;

-- ------------------------------------------------------------
-- TABLE 1: CUSTOMER
-- ------------------------------------------------------------
CREATE TABLE customer (
    CustomerID       INT AUTO_INCREMENT PRIMARY KEY,
    FirstName        VARCHAR(50)  NOT NULL,
    LastName         VARCHAR(50)  NOT NULL,
    DateOfBirth      DATE         NOT NULL,
    Gender           ENUM('Male','Female','Other') NOT NULL,
    Mobile           VARCHAR(10)  NOT NULL UNIQUE,
    Email            VARCHAR(100) NOT NULL UNIQUE,
    Address          VARCHAR(200) NOT NULL,
    City             VARCHAR(50)  NOT NULL,
    RegistrationDate DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_customer_mobile CHECK (Mobile REGEXP '^[0-9]{10}$')
);

-- ------------------------------------------------------------
-- TABLE 2: BRANCH
-- ------------------------------------------------------------
CREATE TABLE branch (
    BranchID      INT AUTO_INCREMENT PRIMARY KEY,
    BranchName    VARCHAR(80)  NOT NULL,
    IFSCCode      VARCHAR(11)  NOT NULL UNIQUE,
    Address       VARCHAR(200) NOT NULL,
    City          VARCHAR(50)  NOT NULL,
    State         VARCHAR(50)  NOT NULL,
    ContactNumber VARCHAR(15)  NOT NULL
);

-- ------------------------------------------------------------
-- TABLE 3: EMPLOYEE  (works in one branch -> FK to branch)
-- ------------------------------------------------------------
CREATE TABLE employee (
    EmployeeID   INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeName VARCHAR(100) NOT NULL,
    Mobile       VARCHAR(10)  NOT NULL UNIQUE,
    Email        VARCHAR(100) NOT NULL UNIQUE,
    Designation  VARCHAR(50)  NOT NULL,
    Salary       DECIMAL(10,2) NOT NULL CHECK (Salary > 0),
    JoiningDate  DATE NOT NULL,
    BranchID     INT NOT NULL,
    FOREIGN KEY (BranchID) REFERENCES branch(BranchID)
);

-- ------------------------------------------------------------
-- TABLE 4: ACCOUNT  (belongs to one branch)
-- ------------------------------------------------------------
CREATE TABLE account (
    AccountID     INT AUTO_INCREMENT PRIMARY KEY,
    AccountNumber VARCHAR(20) NOT NULL UNIQUE,
    AccountType   ENUM('Saving','Current','Salary') NOT NULL,
    OpeningDate   DATE NOT NULL DEFAULT (CURRENT_DATE),
    Balance       DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    Status        ENUM('Active','Inactive','Close') NOT NULL DEFAULT 'Active',
    BranchID      INT NOT NULL,
    CONSTRAINT chk_balance CHECK (Balance >= 0),
    FOREIGN KEY (BranchID) REFERENCES branch(BranchID)
);

-- ------------------------------------------------------------
-- TABLE 5: ACCOUNT_HOLDER  (links customer <-> account, M:N)
-- Composite primary key = (CustomerID, AccountID)
-- ------------------------------------------------------------
CREATE TABLE account_holder (
    CustomerID  INT NOT NULL,
    AccountID   INT NOT NULL,
    HolderSince DATE NOT NULL DEFAULT (CURRENT_DATE),
    HolderType  ENUM('Primary','Joint') NOT NULL DEFAULT 'Primary',
    PRIMARY KEY (CustomerID, AccountID),
    FOREIGN KEY (CustomerID) REFERENCES customer(CustomerID),
    FOREIGN KEY (AccountID)  REFERENCES account(AccountID)
);

-- ------------------------------------------------------------
-- TABLE 6: TRANSACTIONS  (named "transactions" because
-- TRANSACTION is a SQL keyword)
-- ------------------------------------------------------------
CREATE TABLE transactions (
    TransactionID     INT AUTO_INCREMENT PRIMARY KEY,
    AccountID         INT NOT NULL,
    TransactionType   ENUM('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT') NOT NULL,
    Amount            DECIMAL(15,2) NOT NULL CHECK (Amount > 0),
    TransactionDate   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Description       VARCHAR(255),
    ReferenceNumber   VARCHAR(30) NOT NULL UNIQUE,
    TransactionStatus ENUM('Success','Failed','Pending') NOT NULL DEFAULT 'Success',
    FOREIGN KEY (AccountID) REFERENCES account(AccountID)
);

-- ------------------------------------------------------------
-- TABLE 7: LOAN
-- ------------------------------------------------------------
CREATE TABLE loan (
    LoanID       INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID   INT NOT NULL,
    BranchID     INT NOT NULL,
    LoanType     ENUM('Home Loan','Education Loan','Personal Loan','Vehicle Loan') NOT NULL,
    LoanAmount   DECIMAL(15,2) NOT NULL CHECK (LoanAmount > 0),
    InterestRate DECIMAL(5,2)  NOT NULL CHECK (InterestRate >= 0),
    StartDate    DATE NOT NULL DEFAULT (CURRENT_DATE),
    TenureMonths INT  NOT NULL CHECK (TenureMonths > 0),
    LoanStatus   ENUM('Active','Closed') NOT NULL DEFAULT 'Active',
    FOREIGN KEY (CustomerID) REFERENCES customer(CustomerID),
    FOREIGN KEY (BranchID)   REFERENCES branch(BranchID)
);

-- ------------------------------------------------------------
-- TABLE 8: LOAN_PAYMENT
-- ------------------------------------------------------------
CREATE TABLE loan_payment (
    PaymentID       INT AUTO_INCREMENT PRIMARY KEY,
    LoanID          INT NOT NULL,
    PaymentDate     DATE NOT NULL DEFAULT (CURRENT_DATE),
    Amount          DECIMAL(15,2) NOT NULL CHECK (Amount > 0),
    PaymentMode     ENUM('Cash','UPI','NetBanking','Cheque') NOT NULL,
    ReferenceNumber VARCHAR(30) NOT NULL UNIQUE,
    FOREIGN KEY (LoanID) REFERENCES loan(LoanID)
);

-- ============================================================
--  VIEWS  (saved SELECT queries that behave like tables)
-- ============================================================

-- View 1: every account with its branch and holder names
CREATE VIEW vw_account_summary AS
SELECT a.AccountID, a.AccountNumber, a.AccountType, a.Balance, a.Status,
       b.BranchName,
       GROUP_CONCAT(CONCAT(c.FirstName, ' ', c.LastName) SEPARATOR ', ') AS Holders
FROM account a
JOIN branch b          ON a.BranchID   = b.BranchID
JOIN account_holder ah ON a.AccountID  = ah.AccountID
JOIN customer c        ON ah.CustomerID = c.CustomerID
GROUP BY a.AccountID, a.AccountNumber, a.AccountType, a.Balance, a.Status, b.BranchName;

-- View 2: transaction history with account number
CREATE VIEW vw_transaction_history AS
SELECT t.TransactionID, t.AccountID, a.AccountNumber, t.TransactionType,
       t.Amount, t.TransactionDate, t.Description,
       t.ReferenceNumber, t.TransactionStatus
FROM transactions t
JOIN account a ON t.AccountID = a.AccountID;

-- View 3: loan with total paid and outstanding amount
CREATE VIEW vw_loan_summary AS
SELECT l.LoanID, CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
       l.LoanType, l.LoanAmount, l.InterestRate, l.TenureMonths, l.LoanStatus,
       IFNULL(SUM(p.Amount), 0)                 AS TotalPaid,
       l.LoanAmount - IFNULL(SUM(p.Amount), 0)  AS Outstanding
FROM loan l
JOIN customer c ON l.CustomerID = c.CustomerID
LEFT JOIN loan_payment p ON l.LoanID = p.LoanID
GROUP BY l.LoanID, c.FirstName, c.LastName, l.LoanType, l.LoanAmount,
         l.InterestRate, l.TenureMonths, l.LoanStatus;

-- ============================================================
--  STORED FUNCTIONS
-- ============================================================
DELIMITER $$

-- Function 1: returns the balance of an account
CREATE FUNCTION fn_get_balance(p_account_id INT)
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    SELECT Balance INTO v_balance FROM account WHERE AccountID = p_account_id;
    RETURN IFNULL(v_balance, 0);
END$$

-- Function 2: monthly EMI = P*r*(1+r)^n / ((1+r)^n - 1)
CREATE FUNCTION fn_calculate_emi(p_amount DECIMAL(15,2), p_rate DECIMAL(5,2), p_months INT)
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE r DOUBLE;
    IF p_months <= 0 THEN RETURN 0; END IF;
    IF p_rate = 0 THEN RETURN ROUND(p_amount / p_months, 2); END IF;
    SET r = p_rate / 12 / 100;
    RETURN ROUND(p_amount * r * POW(1 + r, p_months) / (POW(1 + r, p_months) - 1), 2);
END$$

-- ============================================================
--  STORED PROCEDURES  (each one is a TRANSACTION: all or nothing)
-- ============================================================

-- Procedure 1: DEPOSIT
CREATE PROCEDURE sp_deposit(IN p_account_id INT, IN p_amount DECIMAL(15,2), IN p_desc VARCHAR(255))
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;      -- undo everything if any error happens
        RESIGNAL;      -- pass the error to Flask
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than zero';
    END IF;

    START TRANSACTION;
        SELECT Status INTO v_status FROM account WHERE AccountID = p_account_id FOR UPDATE;
        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
        END IF;

        -- the trigger trg_check_account_active also checks the status here
        INSERT INTO transactions (AccountID, TransactionType, Amount, Description, ReferenceNumber)
        VALUES (p_account_id, 'DEPOSIT', p_amount, IFNULL(p_desc, 'Cash deposit'),
                CONCAT('TXN', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12))));

        UPDATE account SET Balance = Balance + p_amount WHERE AccountID = p_account_id;
    COMMIT;
END$$

-- Procedure 2: WITHDRAWAL
CREATE PROCEDURE sp_withdraw(IN p_account_id INT, IN p_amount DECIMAL(15,2), IN p_desc VARCHAR(255))
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_balance DECIMAL(15,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than zero';
    END IF;

    START TRANSACTION;
        SELECT Status, Balance INTO v_status, v_balance
        FROM account WHERE AccountID = p_account_id FOR UPDATE;
        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
        END IF;
        IF v_balance < p_amount THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
        END IF;

        INSERT INTO transactions (AccountID, TransactionType, Amount, Description, ReferenceNumber)
        VALUES (p_account_id, 'WITHDRAWAL', p_amount, IFNULL(p_desc, 'Cash withdrawal'),
                CONCAT('TXN', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12))));

        UPDATE account SET Balance = Balance - p_amount WHERE AccountID = p_account_id;
    COMMIT;
END$$

-- Procedure 3: TRANSFER (money leaves one account and enters another)
CREATE PROCEDURE sp_transfer(IN p_from INT, IN p_to INT, IN p_amount DECIMAL(15,2), IN p_desc VARCHAR(255))
BEGIN
    DECLARE v_from_status VARCHAR(10);
    DECLARE v_to_status VARCHAR(10);
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE v_from_no VARCHAR(20);
    DECLARE v_to_no VARCHAR(20);
    DECLARE v_ref VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than zero';
    END IF;
    IF p_from = p_to THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot transfer to the same account';
    END IF;

    START TRANSACTION;
        SELECT Status, Balance, AccountNumber INTO v_from_status, v_from_balance, v_from_no
        FROM account WHERE AccountID = p_from FOR UPDATE;
        SELECT Status, AccountNumber INTO v_to_status, v_to_no
        FROM account WHERE AccountID = p_to FOR UPDATE;

        IF v_from_status IS NULL OR v_to_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found';
        END IF;
        IF v_from_balance < p_amount THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient balance';
        END IF;

        SET v_ref = CONCAT('TXN', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12)));

        INSERT INTO transactions (AccountID, TransactionType, Amount, Description, ReferenceNumber)
        VALUES (p_from, 'TRANSFER_OUT', p_amount,
                CONCAT('Transfer to ', v_to_no, IFNULL(CONCAT(' - ', p_desc), '')),
                CONCAT(v_ref, 'O'));
        INSERT INTO transactions (AccountID, TransactionType, Amount, Description, ReferenceNumber)
        VALUES (p_to, 'TRANSFER_IN', p_amount,
                CONCAT('Transfer from ', v_from_no, IFNULL(CONCAT(' - ', p_desc), '')),
                CONCAT(v_ref, 'I'));

        UPDATE account SET Balance = Balance - p_amount WHERE AccountID = p_from;
        UPDATE account SET Balance = Balance + p_amount WHERE AccountID = p_to;
    COMMIT;
END$$

-- Procedure 4: LOAN PAYMENT
CREATE PROCEDURE sp_pay_loan(IN p_loan_id INT, IN p_amount DECIMAL(15,2), IN p_mode VARCHAR(20))
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be greater than zero';
    END IF;

    START TRANSACTION;
        SELECT LoanStatus INTO v_status FROM loan WHERE LoanID = p_loan_id FOR UPDATE;
        IF v_status IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Loan not found';
        END IF;
        IF v_status = 'Closed' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This loan is already closed';
        END IF;

        -- trigger trg_close_loan runs after this insert
        INSERT INTO loan_payment (LoanID, Amount, PaymentMode, ReferenceNumber)
        VALUES (p_loan_id, p_amount, p_mode,
                CONCAT('LP', UPPER(SUBSTRING(REPLACE(UUID(), '-', ''), 1, 12))));
    COMMIT;
END$$

-- ============================================================
--  TRIGGERS  (run automatically when data changes)
-- ============================================================

-- Trigger 1: customer must be at least 18 years old
CREATE TRIGGER trg_customer_age_check
BEFORE INSERT ON customer
FOR EACH ROW
BEGIN
    IF TIMESTAMPDIFF(YEAR, NEW.DateOfBirth, CURDATE()) < 18 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer must be at least 18 years old';
    END IF;
END$$

-- Trigger 2: no transaction on an Inactive / Closed account
CREATE TRIGGER trg_check_account_active
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT Status INTO v_status FROM account WHERE AccountID = NEW.AccountID;
    IF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account is not Active - transaction not allowed';
    END IF;
END$$

-- Trigger 3: close the loan automatically when fully paid
CREATE TRIGGER trg_close_loan
AFTER INSERT ON loan_payment
FOR EACH ROW
BEGIN
    DECLARE v_paid DECIMAL(15,2);
    DECLARE v_amount DECIMAL(15,2);
    SELECT SUM(Amount) INTO v_paid FROM loan_payment WHERE LoanID = NEW.LoanID;
    SELECT LoanAmount INTO v_amount FROM loan WHERE LoanID = NEW.LoanID;
    IF v_paid >= v_amount THEN
        UPDATE loan SET LoanStatus = 'Closed' WHERE LoanID = NEW.LoanID;
    END IF;
END$$

DELIMITER ;

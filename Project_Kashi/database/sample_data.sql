-- ============================================================
--  File 2 of 3: sample_data.sql  (run AFTER schema.sql)
-- ============================================================
USE kashi_bank;

INSERT INTO branch (BranchName, IFSCCode, Address, City, State, ContactNumber) VALUES
('Kashi Main Branch',   'KASH0000001', '12 Ratan Road',      'Hubballi',  'Karnataka',   '08362345678'),
('Kashi Market Branch', 'KASH0000002', '45 Market Street',   'Dharwad',   'Karnataka',   '08362456789'),
('Kashi City Branch',   'KASH0000003', '7 MG Road',          'Bengaluru', 'Karnataka',   '08022334455');

INSERT INTO employee (EmployeeName, Mobile, Email, Designation, Salary, JoiningDate, BranchID) VALUES
('Ramesh Kulkarni', '9811111111', 'ramesh@kashibank.com', 'Branch Manager', 90000, '2018-04-01', 1),
('Sunita Patil',    '9822222222', 'sunita@kashibank.com', 'Cashier',        35000, '2020-06-15', 1),
('Anil Joshi',      '9833333333', 'anil@kashibank.com',   'Loan Officer',   55000, '2019-09-10', 2),
('Meena Shetty',    '9844444444', 'meena@kashibank.com',  'Clerk',          28000, '2022-01-20', 2),
('Vikram Rao',      '9855555555', 'vikram@kashibank.com', 'Branch Manager', 85000, '2017-11-05', 3);

INSERT INTO customer (FirstName, LastName, DateOfBirth, Gender, Mobile, Email, Address, City, RegistrationDate) VALUES
('Amit',   'Sharma', '1990-05-14', 'Male',   '9000000001', 'amit@example.com',   '10 Lake View',   'Hubballi',  '2024-01-10'),
('Priya',  'Nair',   '1995-08-22', 'Female', '9000000002', 'priya@example.com',  '22 Green Park',  'Dharwad',   '2024-02-15'),
('Rahul',  'Verma',  '1988-12-01', 'Male',   '9000000003', 'rahul@example.com',  '5 Station Road', 'Bengaluru', '2024-03-20'),
('Sneha',  'Desai',  '1999-03-30', 'Female', '9000000004', 'sneha@example.com',  '88 Temple St',   'Hubballi',  '2025-05-05'),
('Karan',  'Mehta',  '1985-07-17', 'Male',   '9000000005', 'karan@example.com',  '3 Hill Road',    'Dharwad',   '2025-08-12');

-- Accounts start with Balance 0; the procedures below add money.
INSERT INTO account (AccountNumber, AccountType, OpeningDate, Balance, Status, BranchID) VALUES
('100000000001', 'Saving',  '2024-01-10', 0, 'Active',   1),
('100000000002', 'Current', '2024-01-12', 0, 'Active',   1),
('100000000003', 'Saving',  '2024-02-15', 0, 'Active',   2),
('100000000004', 'Salary',  '2024-03-20', 0, 'Active',   3),
('100000000005', 'Saving',  '2025-05-05', 0, 'Active',   1),
('100000000006', 'Saving',  '2025-08-12', 0, 'Inactive', 2);

INSERT INTO account_holder (CustomerID, AccountID, HolderSince, HolderType) VALUES
(1, 1, '2024-01-10', 'Primary'),
(1, 2, '2024-01-12', 'Primary'),
(2, 3, '2024-02-15', 'Primary'),
(3, 4, '2024-03-20', 'Primary'),
(4, 5, '2025-05-05', 'Primary'),
(5, 6, '2025-08-12', 'Primary'),
(2, 1, '2024-06-01', 'Joint');   -- Priya is a joint holder on Amit's account

-- Money movements (these go through the real stored procedures)
CALL sp_deposit (1, 50000, 'Opening deposit');
CALL sp_deposit (2, 120000, 'Business deposit');
CALL sp_deposit (3, 25000, 'Opening deposit');
CALL sp_deposit (4, 60000, 'Salary credit');
CALL sp_deposit (5, 15000, 'Opening deposit');
CALL sp_withdraw(1, 5000,  'ATM withdrawal');
CALL sp_withdraw(4, 8000,  'Cash withdrawal');
CALL sp_transfer(2, 3, 10000, 'Rent');
CALL sp_transfer(4, 1, 5000,  'Gift');
CALL sp_deposit (3, 7500, 'Cash deposit');

-- Account 6 was Inactive from the start, so no transactions for it.

-- Loans
INSERT INTO loan (CustomerID, BranchID, LoanType, LoanAmount, InterestRate, StartDate, TenureMonths) VALUES
(1, 1, 'Home Loan',      2500000, 8.50, '2025-01-01', 240),
(3, 3, 'Vehicle Loan',    600000, 9.25, '2025-06-01',  60),
(4, 1, 'Education Loan',  400000, 7.50, '2025-07-15',  72);

CALL sp_pay_loan(1, 25000, 'NetBanking');
CALL sp_pay_loan(1, 25000, 'UPI');
CALL sp_pay_loan(2, 12500, 'Cash');
CALL sp_pay_loan(3, 400000, 'Cheque');   -- fully paid -> trigger closes this loan

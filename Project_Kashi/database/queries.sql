-- ============================================================
--  File 3 of 3: queries.sql - 12 business problems solved in SQL
-- ============================================================
USE kashi_bank;

-- Q1. Total balance held in each branch (JOIN + GROUP BY)
SELECT b.BranchName, COUNT(a.AccountID) AS TotalAccounts, SUM(a.Balance) AS TotalBalance
FROM branch b LEFT JOIN account a ON b.BranchID = a.BranchID
GROUP BY b.BranchID, b.BranchName;

-- Q2. Top 5 accounts with the highest balance (ORDER BY + LIMIT)
SELECT AccountNumber, AccountType, Balance FROM account ORDER BY Balance DESC LIMIT 5;

-- Q3. Customers who own more than one account (GROUP BY + HAVING)
SELECT c.CustomerID, CONCAT(c.FirstName,' ',c.LastName) AS Customer, COUNT(*) AS Accounts
FROM customer c JOIN account_holder ah ON c.CustomerID = ah.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName
HAVING COUNT(*) > 1;

-- Q4. Customers who have no account yet (LEFT JOIN + IS NULL)
SELECT c.CustomerID, c.FirstName, c.LastName
FROM customer c LEFT JOIN account_holder ah ON c.CustomerID = ah.CustomerID
WHERE ah.AccountID IS NULL;

-- Q5. Total amount of each transaction type (GROUP BY)
SELECT TransactionType, COUNT(*) AS Count, SUM(Amount) AS TotalAmount
FROM transactions GROUP BY TransactionType;

-- Q6. Transactions bigger than the average transaction (SUBQUERY)
SELECT TransactionID, AccountID, TransactionType, Amount
FROM transactions WHERE Amount > (SELECT AVG(Amount) FROM transactions);

-- Q7. Number of employees and average salary per branch (JOIN + AVG)
SELECT b.BranchName, COUNT(e.EmployeeID) AS Employees, ROUND(AVG(e.Salary),2) AS AvgSalary
FROM branch b LEFT JOIN employee e ON b.BranchID = e.BranchID
GROUP BY b.BranchID, b.BranchName;

-- Q8. Outstanding loan amount for every customer (uses VIEW)
SELECT CustomerName, LoanType, LoanAmount, TotalPaid, Outstanding
FROM vw_loan_summary ORDER BY Outstanding DESC;

-- Q9. Accounts that are NOT active (WHERE)
SELECT AccountNumber, AccountType, Status FROM account WHERE Status <> 'Active';

-- Q10. Monthly deposit total (DATE_FORMAT + GROUP BY)
SELECT DATE_FORMAT(TransactionDate, '%Y-%m') AS Month, SUM(Amount) AS TotalDeposits
FROM transactions WHERE TransactionType = 'DEPOSIT'
GROUP BY DATE_FORMAT(TransactionDate, '%Y-%m');

-- Q11. Account list with holders (uses VIEW)
SELECT * FROM vw_account_summary;

-- Q12. Using the stored FUNCTIONS: balance of account 1 and EMI of a 5 lakh loan
SELECT fn_get_balance(1) AS BalanceOfAccount1,
       fn_calculate_emi(500000, 9.5, 36) AS EMI_500000_at_9_5_for_36_months;

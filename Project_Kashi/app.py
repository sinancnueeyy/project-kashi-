"""
PROJECT KASHI - Banking Management System
Backend: Flask (Python)      Database: MySQL      Frontend: HTML + CSS

How the 3 layers talk:
    Browser (HTML form)  ->  Flask route (this file)  ->  MySQL (tables/procedures)
"""
import random
from datetime import date
from decimal import Decimal, InvalidOperation

import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, flash

from config import DB_CONFIG

app = Flask(__name__)
app.secret_key = "kashi-secret-key"   # needed for flash() messages


@app.template_filter("money")
def money(value):
    """Show numbers as Indian rupees, e.g. 50000 -> Rs. 50,000.00"""
    return "\u20b9{:,.2f}".format(float(value or 0))


# ------------------------------------------------------------
# Helper functions to talk to MySQL
# ------------------------------------------------------------
def get_connection():
    """Open a new connection to the MySQL database."""
    return mysql.connector.connect(**DB_CONFIG)


def fetch_all(sql, params=()):
    """Run a SELECT and return all rows as a list of dictionaries."""
    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def fetch_one(sql, params=()):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None


def call_procedure(name, args):
    """
    Call a MySQL stored procedure.
    Returns (True, None) on success or (False, "error message") on failure.
    The procedure itself does COMMIT / ROLLBACK.
    """
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.callproc(name, args)
        conn.commit()
        return True, None
    except mysql.connector.Error as err:
        conn.rollback()
        return False, err.msg
    finally:
        cur.close()
        conn.close()


def to_amount(text):
    """Convert text from a form into a Decimal. Returns None if invalid."""
    try:
        value = Decimal(text)
        return value if value > 0 else None
    except (InvalidOperation, TypeError):
        return None


def active_accounts():
    """Accounts shown in dropdown lists."""
    return fetch_all("SELECT AccountID, AccountNumber, Holders, Balance, Status "
                     "FROM vw_account_summary ORDER BY AccountNumber")


# ------------------------------------------------------------
# HOME / DASHBOARD
# ------------------------------------------------------------
@app.route("/")
def home():
    stats = fetch_one(
        "SELECT (SELECT COUNT(*) FROM customer) AS customers,"
        "       (SELECT COUNT(*) FROM account WHERE Status='Active') AS accounts,"
        "       (SELECT IFNULL(SUM(Balance),0) FROM account) AS total_balance,"
        "       (SELECT COUNT(*) FROM transactions) AS transactions,"
        "       (SELECT COUNT(*) FROM loan WHERE LoanStatus='Active') AS loans")
    recent = fetch_all("SELECT * FROM vw_transaction_history "
                       "ORDER BY TransactionID DESC LIMIT 5")
    return render_template("home.html", stats=stats, recent=recent)


# ------------------------------------------------------------
# CUSTOMERS
# ------------------------------------------------------------
@app.route("/customers")
def customers():
    rows = fetch_all("SELECT * FROM customer ORDER BY CustomerID DESC")
    return render_template("customers.html", customers=rows)


@app.route("/customers/new", methods=["GET", "POST"])
def new_customer():
    if request.method == "POST":
        f = request.form
        conn = get_connection()
        cur = conn.cursor()
        try:
            cur.execute(
                "INSERT INTO customer (FirstName, LastName, DateOfBirth, Gender, "
                "Mobile, Email, Address, City) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
                (f["first_name"].strip(), f["last_name"].strip(), f["dob"], f["gender"],
                 f["mobile"].strip(), f["email"].strip(), f["address"].strip(), f["city"].strip()))
            conn.commit()
            new_id = cur.lastrowid
            flash("Customer registered successfully! Now open an account.", "success")
            return redirect(url_for("new_account", customer_id=new_id))
        except mysql.connector.Error as err:
            conn.rollback()
            if err.errno == 1062:       # duplicate entry
                flash("Mobile number or email is already registered.", "error")
            elif err.errno == 4025 or err.errno == 3819:   # CHECK constraint failed
                flash("Mobile number must be exactly 10 digits.", "error")
            else:
                flash(err.msg, "error")
        finally:
            cur.close()
            conn.close()
    return render_template("customer_form.html", today=date.today())


# ------------------------------------------------------------
# ACCOUNTS
# ------------------------------------------------------------
@app.route("/accounts")
def accounts():
    rows = fetch_all("SELECT * FROM vw_account_summary ORDER BY AccountID DESC")
    return render_template("accounts.html", accounts=rows)


def make_account_number():
    """Create a unique 12-digit account number."""
    while True:
        number = "1" + "".join(str(random.randint(0, 9)) for _ in range(11))
        if not fetch_one("SELECT 1 FROM account WHERE AccountNumber=%s", (number,)):
            return number


@app.route("/accounts/new", methods=["GET", "POST"])
def new_account():
    customers_list = fetch_all("SELECT CustomerID, FirstName, LastName, Mobile FROM customer ORDER BY FirstName")
    branches_list = fetch_all("SELECT BranchID, BranchName, City FROM branch")

    if request.method == "POST":
        f = request.form
        initial = Decimal(f.get("initial_deposit") or "0")
        joint_id = f.get("joint_customer_id") or None
        if initial < 0:
            flash("Initial deposit cannot be negative.", "error")
            return redirect(url_for("new_account"))
        if joint_id and joint_id == f["customer_id"]:
            flash("Joint holder must be a different customer.", "error")
            return redirect(url_for("new_account"))

        # ONE database transaction: either everything is saved or nothing is.
        conn = get_connection()
        cur = conn.cursor()
        try:
            number = make_account_number()
            cur.execute("INSERT INTO account (AccountNumber, AccountType, Balance, BranchID) "
                        "VALUES (%s,%s,%s,%s)", (number, f["account_type"], initial, f["branch_id"]))
            account_id = cur.lastrowid
            cur.execute("INSERT INTO account_holder (CustomerID, AccountID, HolderType) "
                        "VALUES (%s,%s,'Primary')", (f["customer_id"], account_id))
            if joint_id:
                cur.execute("INSERT INTO account_holder (CustomerID, AccountID, HolderType) "
                            "VALUES (%s,%s,'Joint')", (joint_id, account_id))
            if initial > 0:
                cur.execute("INSERT INTO transactions (AccountID, TransactionType, Amount, Description, ReferenceNumber) "
                            "VALUES (%s,'DEPOSIT',%s,'Opening deposit',CONCAT('TXN',UPPER(SUBSTRING(REPLACE(UUID(),'-',''),1,12))))",
                            (account_id, initial))
            conn.commit()
            flash(f"Account opened! Account number: {number}", "success")
            return redirect(url_for("account_detail", account_id=account_id))
        except mysql.connector.Error as err:
            conn.rollback()
            flash("Could not open account: " + err.msg, "error")
        finally:
            cur.close()
            conn.close()

    return render_template("account_form.html", customers=customers_list,
                           branches=branches_list,
                           selected=request.args.get("customer_id", type=int))


@app.route("/accounts/<int:account_id>")
def account_detail(account_id):
    acc = fetch_one("SELECT * FROM vw_account_summary WHERE AccountID=%s", (account_id,))
    if not acc:
        flash("Account not found.", "error")
        return redirect(url_for("accounts"))
    history = fetch_all("SELECT * FROM vw_transaction_history WHERE AccountID=%s "
                        "ORDER BY TransactionID DESC", (account_id,))
    return render_template("account_detail.html", acc=acc, history=history)


@app.route("/accounts/<int:account_id>/status", methods=["POST"])
def change_status(account_id):
    new_status = request.form["status"]
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE account SET Status=%s WHERE AccountID=%s", (new_status, account_id))
    conn.commit()
    cur.close()
    conn.close()
    flash(f"Account status changed to {new_status}.", "success")
    return redirect(url_for("account_detail", account_id=account_id))


# ------------------------------------------------------------
# DEPOSIT / WITHDRAW / TRANSFER  (they call stored procedures)
# ------------------------------------------------------------
@app.route("/deposit", methods=["GET", "POST"])
def deposit():
    if request.method == "POST":
        amount = to_amount(request.form["amount"])
        if amount is None:
            flash("Please enter a valid amount greater than zero.", "error")
        else:
            ok, error = call_procedure("sp_deposit", [int(request.form["account_id"]), amount,
                                                      request.form.get("description") or None])
            flash("Deposit successful!" if ok else error, "success" if ok else "error")
            if ok:
                return redirect(url_for("transactions"))
    return render_template("money_form.html", mode="deposit", accounts=active_accounts())


@app.route("/withdraw", methods=["GET", "POST"])
def withdraw():
    if request.method == "POST":
        amount = to_amount(request.form["amount"])
        if amount is None:
            flash("Please enter a valid amount greater than zero.", "error")
        else:
            ok, error = call_procedure("sp_withdraw", [int(request.form["account_id"]), amount,
                                                       request.form.get("description") or None])
            flash("Withdrawal successful!" if ok else error, "success" if ok else "error")
            if ok:
                return redirect(url_for("transactions"))
    return render_template("money_form.html", mode="withdraw", accounts=active_accounts())


@app.route("/transfer", methods=["GET", "POST"])
def transfer():
    if request.method == "POST":
        amount = to_amount(request.form["amount"])
        if amount is None:
            flash("Please enter a valid amount greater than zero.", "error")
        else:
            ok, error = call_procedure("sp_transfer", [int(request.form["from_account"]),
                                                       int(request.form["to_account"]), amount,
                                                       request.form.get("description") or None])
            flash("Transfer successful!" if ok else error, "success" if ok else "error")
            if ok:
                return redirect(url_for("transactions"))
    return render_template("transfer_form.html", accounts=active_accounts())


# ------------------------------------------------------------
# TRANSACTION HISTORY
# ------------------------------------------------------------
@app.route("/transactions")
def transactions():
    account_id = request.args.get("account_id", type=int)
    if account_id:
        rows = fetch_all("SELECT * FROM vw_transaction_history WHERE AccountID=%s "
                         "ORDER BY TransactionID DESC", (account_id,))
    else:
        rows = fetch_all("SELECT * FROM vw_transaction_history ORDER BY TransactionID DESC LIMIT 100")
    return render_template("transactions.html", rows=rows, accounts=active_accounts(),
                           selected=account_id)


# ------------------------------------------------------------
# BRANCHES AND EMPLOYEES
# ------------------------------------------------------------
@app.route("/branches")
def branches():
    rows = fetch_all("SELECT b.*, (SELECT COUNT(*) FROM employee e WHERE e.BranchID=b.BranchID) AS Employees, "
                     "(SELECT COUNT(*) FROM account a WHERE a.BranchID=b.BranchID) AS Accounts FROM branch b")
    return render_template("branches.html", branches=rows)


@app.route("/employees", methods=["GET", "POST"])
def employees():
    if request.method == "POST":
        f = request.form
        conn = get_connection()
        cur = conn.cursor()
        try:
            cur.execute("INSERT INTO employee (EmployeeName, Mobile, Email, Designation, Salary, JoiningDate, BranchID) "
                        "VALUES (%s,%s,%s,%s,%s,%s,%s)",
                        (f["name"], f["mobile"], f["email"], f["designation"], f["salary"],
                         f["joining_date"], f["branch_id"]))
            conn.commit()
            flash("Employee added.", "success")
        except mysql.connector.Error as err:
            conn.rollback()
            flash("Could not add employee: " + err.msg, "error")
        finally:
            cur.close()
            conn.close()
        return redirect(url_for("employees"))
    rows = fetch_all("SELECT e.*, b.BranchName FROM employee e JOIN branch b ON e.BranchID=b.BranchID "
                     "ORDER BY e.EmployeeID")
    branches_list = fetch_all("SELECT BranchID, BranchName FROM branch")
    return render_template("employees.html", employees=rows, branches=branches_list, today=date.today())


# ------------------------------------------------------------
# LOANS
# ------------------------------------------------------------
@app.route("/loans")
def loans():
    rows = fetch_all("SELECT s.*, fn_calculate_emi(s.LoanAmount, s.InterestRate, s.TenureMonths) AS EMI "
                     "FROM vw_loan_summary s ORDER BY s.LoanID DESC")
    return render_template("loans.html", loans=rows)


@app.route("/loans/new", methods=["GET", "POST"])
def new_loan():
    customers_list = fetch_all("SELECT CustomerID, FirstName, LastName FROM customer ORDER BY FirstName")
    branches_list = fetch_all("SELECT BranchID, BranchName FROM branch")
    if request.method == "POST":
        f = request.form
        conn = get_connection()
        cur = conn.cursor()
        try:
            cur.execute("INSERT INTO loan (CustomerID, BranchID, LoanType, LoanAmount, InterestRate, TenureMonths) "
                        "VALUES (%s,%s,%s,%s,%s,%s)",
                        (f["customer_id"], f["branch_id"], f["loan_type"], f["amount"], f["rate"], f["tenure"]))
            conn.commit()
            flash("Loan created.", "success")
            return redirect(url_for("loans"))
        except mysql.connector.Error as err:
            conn.rollback()
            flash("Could not create loan: " + err.msg, "error")
        finally:
            cur.close()
            conn.close()
    return render_template("loan_form.html", customers=customers_list, branches=branches_list)


@app.route("/loans/<int:loan_id>/pay", methods=["POST"])
def pay_loan(loan_id):
    amount = to_amount(request.form["amount"])
    if amount is None:
        flash("Please enter a valid amount.", "error")
    else:
        ok, error = call_procedure("sp_pay_loan", [loan_id, amount, request.form["mode"]])
        flash("Payment recorded." if ok else error, "success" if ok else "error")
    return redirect(url_for("loans"))


# ------------------------------------------------------------
# REPORTS - the 10 business problems solved with SQL
# ------------------------------------------------------------
REPORTS = [
    ("Total balance in each branch  (JOIN + GROUP BY)",
     "SELECT b.BranchName, COUNT(a.AccountID) AS TotalAccounts, IFNULL(SUM(a.Balance),0) AS TotalBalance "
     "FROM branch b LEFT JOIN account a ON b.BranchID = a.BranchID GROUP BY b.BranchID, b.BranchName"),
    ("Top 5 accounts by balance  (ORDER BY + LIMIT)",
     "SELECT AccountNumber, AccountType, Balance FROM account ORDER BY Balance DESC LIMIT 5"),
    ("Customers with more than one account  (GROUP BY + HAVING)",
     "SELECT CONCAT(c.FirstName,' ',c.LastName) AS Customer, COUNT(*) AS Accounts "
     "FROM customer c JOIN account_holder ah ON c.CustomerID = ah.CustomerID "
     "GROUP BY c.CustomerID, c.FirstName, c.LastName HAVING COUNT(*) > 1"),
    ("Customers who have no account  (LEFT JOIN + IS NULL)",
     "SELECT c.CustomerID, c.FirstName, c.LastName, c.Mobile FROM customer c "
     "LEFT JOIN account_holder ah ON c.CustomerID = ah.CustomerID WHERE ah.AccountID IS NULL"),
    ("Total amount per transaction type  (GROUP BY)",
     "SELECT TransactionType, COUNT(*) AS Count, SUM(Amount) AS TotalAmount FROM transactions GROUP BY TransactionType"),
    ("Transactions above the average amount  (SUBQUERY)",
     "SELECT TransactionID, AccountID, TransactionType, Amount FROM transactions "
     "WHERE Amount > (SELECT AVG(Amount) FROM transactions)"),
    ("Employees and average salary per branch  (JOIN + AVG)",
     "SELECT b.BranchName, COUNT(e.EmployeeID) AS Employees, ROUND(AVG(e.Salary),2) AS AvgSalary "
     "FROM branch b LEFT JOIN employee e ON b.BranchID = e.BranchID GROUP BY b.BranchID, b.BranchName"),
    ("Outstanding loan per customer  (VIEW)",
     "SELECT CustomerName, LoanType, LoanAmount, TotalPaid, Outstanding FROM vw_loan_summary ORDER BY Outstanding DESC"),
    ("Accounts that are not Active  (WHERE)",
     "SELECT AccountNumber, AccountType, Status FROM account WHERE Status <> 'Active'"),
    ("Deposits per month  (DATE_FORMAT + GROUP BY)",
     "SELECT DATE_FORMAT(TransactionDate,'%Y-%m') AS Month, SUM(Amount) AS TotalDeposits FROM transactions "
     "WHERE TransactionType='DEPOSIT' GROUP BY DATE_FORMAT(TransactionDate,'%Y-%m')"),
]


@app.route("/reports")
def reports():
    results = []
    for title, sql in REPORTS:
        rows = fetch_all(sql)
        results.append({"title": title, "sql": sql, "rows": rows,
                        "columns": list(rows[0].keys()) if rows else []})
    return render_template("reports.html", results=results)


if __name__ == "__main__":
    app.run(debug=True)

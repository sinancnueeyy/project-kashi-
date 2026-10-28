# Project Kashi - Banking Management System

A beginner-friendly **Flask + MySQL + HTML/CSS** web app that simulates basic banking:
customer registration, account opening (single and joint), deposit, withdrawal, transfer,
transaction history, loans with EMI, branches, employees, and 10 SQL reports.

Full design documentation (ER diagram, cardinality, definitions, viva questions): **[docs/DOCUMENTATION.md](docs/DOCUMENTATION.md)**

## Project structure

```
Project_Kashi/
|-- app.py                 <- Flask backend (all routes)
|-- config.py              <- MySQL username / password  (EDIT THIS)
|-- requirements.txt       <- Python packages
|-- database/
|   |-- schema.sql         <- tables, views, functions, procedures, triggers  (run 1st)
|   |-- sample_data.sql    <- demo data                                        (run 2nd)
|   `-- queries.sql        <- 12 business SQL queries
|-- templates/             <- HTML pages (Jinja)
|-- static/style.css       <- CSS
`-- docs/DOCUMENTATION.md  <- design document
```

## How to run (step by step)

**1. Install** Python 3.9+ and MySQL Server 8 (with MySQL Workbench).

**2. Create the database.** Choose ONE way:
* *Workbench:* File -> Open SQL Script -> `database/schema.sql` -> click the lightning icon. Then do the same with `database/sample_data.sql`.
* *Command line:*
  ```
  mysql -u root -p < database/schema.sql
  mysql -u root -p < database/sample_data.sql
  ```

**3. Put your MySQL password** in `config.py` (replace `YOUR_MYSQL_PASSWORD`).

**4. Install packages and start the app:**
```
python -m venv venv
venv\Scripts\activate          (Windows)   |   source venv/bin/activate   (Mac/Linux)
pip install -r requirements.txt
python app.py
```

**5. Open** http://127.0.0.1:5000 in your browser.

## Try this in your demo
1. **Customers -> New Customer** -> fill the form -> you are taken to *Open Account*.
2. Open an account with an opening deposit -> see the new row in MySQL Workbench: `SELECT * FROM customer;`
3. **Deposit / Withdraw / Transfer** -> check **History**.
4. Try to withdraw more than the balance -> error from the stored procedure (rollback).
5. Try registering someone under 18 -> error from the trigger.
6. Open **Reports** -> shows the 10 SQL queries and their results.

## Upload to GitHub (repository name: "Project Kashi")
1. On github.com click **New repository**, name it `Project-Kashi` (GitHub shows spaces as dashes), create it empty.
2. In this folder run:
```
git init
git add .
git commit -m "Project Kashi - Banking Management System"
git branch -M main
git remote add origin https://github.com/<your-username>/Project-Kashi.git
git push -u origin main
```
Before pushing, **do not commit your real MySQL password**: change it back to `YOUR_MYSQL_PASSWORD` in `config.py` or remove `config.py` from the commit.

## Common problems
| Problem | Fix |
|---|---|
| `Access denied for user 'root'` | Wrong password in `config.py` |
| `Unknown database 'kashi_bank'` | You have not run `schema.sql` yet |
| `ModuleNotFoundError: flask` | Activate the venv and run `pip install -r requirements.txt` |
| `Can't connect to MySQL server` | Start the MySQL service |
| Want fresh demo data | Run `schema.sql` then `sample_data.sql` again (it drops and recreates the database) |

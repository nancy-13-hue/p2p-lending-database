# 📘 P2P Lending Platform – Database Design

This project contains a relational database schema tailored for a **Peer-to-Peer Lending System**, enabling management of users, loan applications, funding activities, repayment tracking, and system-wide audit logging. The design emphasizes data consistency, automation, and traceability through the use of stored procedures and triggers.

---

## 🔧 Schema Breakdown

- **`users`**: Stores details of all participants—borrowers, investors, and administrators—including KYC, contact, and account status.
- **`loans`**: Represents borrower loan applications with interest rate, EMI calculation, loan type, and status.
- **`investments`**: Records each investor’s contribution to available loans along with ownership percentage and resale options.
- **`loan_funding`**: Tracks the funding progress of each loan to determine whether it is fully funded.
- **`repayment_schedules`**: Defines and updates monthly EMI schedules for each loan.
- **`transactions`**: Central ledger capturing every financial transaction—investments, repayments, penalties, and withdrawals.
- **`loan_status_history`**: Logs every status transition a loan undergoes, ensuring visibility of loan lifecycle changes.
- **`audit_log`**: Provides a unified activity log of all major events for transparency and audit purposes.

---

## 🧠 Functional Highlights

- **Stored Procedures**:
  - `FundLoan`: Automates the process of investing in a loan and updating funding status.
  - `MakeRepayment`: Handles EMI payments and updates repayment and loan status.
  - `WithdrawInvestment`: Allows investors to withdraw funds and adjusts related records.

- **Database Triggers**:
  - Automatically logs investments into the audit system.
  - Activates a loan once its first EMI is paid.
  - Tracks any updates to the loan status in dedicated history tables.

- **EMI Calculation**:
  - EMI is dynamically calculated and stored using a formula, based on principal, interest rate, and loan duration.

---

## ▶️ Execution Guide

1. Ensure **MySQL 8.0 or higher** is installed on your machine.
2. Open your SQL client (e.g., MySQL Workbench, DBeaver, or terminal).
3. Execute the provided SQL file in the following order:
   - Create tables
   - Insert sample data
   - Define stored procedures
   - Add triggers

```bash
mysql -u your_username -p < schema.sql

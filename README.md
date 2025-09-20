# BTC Nexus Credit Protocol

**Revolutionary Bitcoin-native lending infrastructure built on [Stacks](https://stacks.co)**
BTC Nexus Credit Protocol transforms idle sBTC into productive credit opportunities by combining Bitcoin’s security with Stacks’ smart-contract programmability.

---

## 📜 Overview

The BTC Nexus Credit Protocol creates a seamless bridge between Bitcoin holders (lenders) and credit seekers (borrowers).
It uses **intelligent risk assessment**, **dynamic credit scoring**, and **automated liquidity management** to deliver a fully on-chain credit market with zero counterparty risk.

### Key Features

* **Six-tier dynamic credit scoring (0 – 5)** with progressive borrowing limits.
* **AI-driven risk assessment** based on rolling on-chain behavior patterns.
* **Automated yield generation** for liquidity providers.
* **Self-executing smart contracts** ensuring complete transparency and decentralization.
* **Institutional-grade compliance** with auditable data on-chain.

Whether you are a Bitcoin maximalist seeking yield or an entrepreneur needing quick liquidity, BTC Nexus democratizes access to Bitcoin-backed credit markets while preserving user sovereignty.

---

## ⚙️ System Overview

**Actors**

* **Lenders** deposit sBTC into a global liquidity pool and earn yield as funds are borrowed.
* **Borrowers** request short-term sBTC credit lines based on their credit score and on-chain activity.

**Lifecycle**

1. **Deposit** – Lenders supply sBTC to the protocol; funds are locked for a configurable period.
2. **Assessment** – Borrowers’ creditworthiness is calculated from:

   * 3-month rolling sBTC balance
   * On-time vs. late repayment history
3. **Approval & Disbursement** – Eligible borrowers receive sBTC instantly from the pool.
4. **Repayment** – Borrowers repay principal + interest; credit history is updated automatically.
5. **Withdrawal** – Lenders withdraw proportional liquidity plus accrued yield after lock period.

---

## 🏗 Contract Architecture

All logic resides in a **single Clarity smart contract**, simplifying deployment and audits.

### Core Components

| Component               | Purpose                                                                                                  |
| ----------------------- | -------------------------------------------------------------------------------------------------------- |
| **Global Variables**    | Track total liquidity, base interest rate, loan term, and admin address.                                 |
| **Maps**                | `lender_positions`, `active_loans`, and `credit_history` maintain state for lenders and borrowers.       |
| **Error Constants**     | Uniform error codes (e.g., `ERR_INSUFFICIENT_AMOUNT`, `ERR_CREDIT_INELIGIBLE`) for predictable handling. |
| **Utility Functions**   | Time conversions, rolling balance calculation, and scoring algorithms.                                   |
| **Public Entry Points** | Deposit/withdraw liquidity, apply for credit, repay loans, and administrative setters.                   |
| **Read-Only Views**     | Protocol stats, credit assessments, eligibility checks, and lender/borrower summaries.                   |

### Key Data Flow

1. **Liquidity Flow**
   `deposit-liquidity` → updates `lender_positions` & `total_liquidity_pool`
   `withdraw-liquidity` → proportionally releases sBTC back to lender.
2. **Credit Flow**
   `apply-for-credit` → invokes `assess-loan-eligibility` → transfers sBTC to borrower & records `active_loans`.
   `repay-loan` → transfers repayment to contract, clears `active_loans`, and updates `credit_history`.

---

## 📊 Credit Scoring

The composite credit score is derived from:

* **Activity Score**: based on the 3-month rolling sBTC balance.
* **Payment Reliability Score**: weighted by total loans vs. on-time repayments.

This score maps to **six credit tiers**:

| Tier | Limit (sats) | Description   |
| ---- | ------------ | ------------- |
| 0    | 10,000       | Starter       |
| 1    | 50,000       | Basic         |
| 2    | 100,000      | Standard      |
| 3    | 300,000      | Premium       |
| 4    | 500,000      | Elite         |
| 5    | 1,000,000    | Institutional |

---

## 🔑 Administrative Controls

* **`transfer-admin-rights`**: Assign a new protocol admin.
* **`set-loan-term`**: Update the global loan term (min 7 days).
* **`set-lock-period`**: Set lender fund lock duration.
* **`set-base-rate`**: Adjust base interest rate.

These functions require admin verification and enforce strict parameter checks.

---

## 🛠 Deployment & Usage

1. **Compile & Deploy**
   Deploy the contract to the Stacks blockchain using [Clarinet](https://docs.hiro.so/clarinet) or your preferred tool.

2. **Lender Workflow**

   ```clarity
   (contract-call? .btc-nexus deposit-liquidity u10000000) ;; Deposit 0.1 sBTC
   (contract-call? .btc-nexus get-lender-position)
   ```

3. **Borrower Workflow**

   ```clarity
   (contract-call? .btc-nexus apply-for-credit u50000) ;; Request 0.0005 sBTC
   (contract-call? .btc-nexus repay-loan tx-sender)
   ```

4. **Admin Workflow**

   ```clarity
   (contract-call? .btc-nexus set-base-rate u20) ;; Set 20% base interest
   ```

---

## 🧩 Security & Design Considerations

* **Immutable Logic**: All credit scoring and liquidity rules are on-chain and auditable.
* **No Custodial Risk**: Funds remain in the smart contract; no off-chain intermediaries.
* **Deterministic Execution**: Pure Clarity language guarantees predictable, tamper-proof behavior.

---

## 📈 Protocol Insights

Use the provided read-only functions for analytics and monitoring:

* `get-protocol-stats`
* `get-loan-eligibility`
* `get-credit-assessment`
* `get-borrower-summary`

These endpoints facilitate real-time dashboards and third-party integrations.

---

## 🧑‍💻 Contributing

1. Fork the repository.
2. Create feature branches for improvements or bug fixes.
3. Submit a pull request with tests and clear documentation.

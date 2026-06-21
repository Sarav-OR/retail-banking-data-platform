# Retail Banking Data Platform

End-to-end data engineering pipeline simulating a retail banking data platform. Ingests from multiple public APIs, processes through a full medallion architecture on Azure Databricks + Delta Lake, applies AML fraud flagging, and delivers analytics to Power BI.

---

## Architecture

```
[ APIs & Kaggle Dataset ]
         |
         v
[ BRONZE — Raw Ingestion ]
  Raw JSON / CSV as-is. Append-only Delta tables. No transformation.
         |
         v
[ SILVER — Cleaned & Conformed ]
  Deduplicated. SCD Type 2 customers. Standardized schema. Quality checked.
         |
         v
[ GOLD — Business-Ready (via dbt) ]
  Aggregated metrics. Fraud scores. Risk KPIs. Enriched with economic data.
         |
         v
[ Power BI Dashboard ]
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Compute | Azure Databricks |
| Storage | Azure Data Lake Storage Gen2 + Delta Lake |
| Ingestion | Python (requests, pandas) |
| Transformation | PySpark (Bronze → Silver), dbt (Silver → Gold) |
| Data Quality | pytest + Great Expectations |
| CI/CD | GitHub Actions |
| Reporting | Power BI |

---

## Data Sources

| Source | What It Provides |
|---|---|
| [Alpha Vantage API](https://www.alphavantage.co) | Real stock prices, forex rates, economic indicators |
| [Kaggle: Credit Card Fraud Dataset](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud) | 284,000+ anonymized European credit card transactions with fraud labels |
| [FRED API](https://fred.stlouisfed.org) | Interest rates, inflation, GDP — macroeconomic context |
| [UK Open Banking API](https://www.openbanking.org.uk) | Bank branch and product reference data |

---

## dbt Gold Layer Models

| Model | Type | Description |
|---|---|---|
| `stg_transactions` | Staging | Renames columns, casts types, adds surrogate keys |
| `stg_customers` | Staging | Filters SCD Type 2 to current records |
| `stg_market_data` | Staging | Standardizes Alpha Vantage forex fields |
| `int_transactions_enriched` | Intermediate | Joins transactions with customers and FRED indicators |
| `int_fraud_flags` | Intermediate | AML rules: velocity, unusual amounts, high-risk geography |
| `mart_monthly_customer_spend` | Mart | Monthly spend by customer, category, channel |
| `mart_fraud_summary` | Mart | Daily fraud counts, suspicious amounts, detection rate |
| `mart_customer_risk_profile` | Mart | Customer-level risk scoring with economic context |
| `mart_branch_performance` | Mart | Branch-level volumes linked to Open Banking reference data |

---

## Key Design Decisions

| Decision | Reasoning |
|---|---|
| **Medallion Architecture** | Separates ingestion, quality, and aggregation concerns. Failures are isolated to a single layer. |
| **Delta Lake over Parquet** | ACID transactions, time travel, schema enforcement — non-negotiable in banking. |
| **Append-only Bronze** | Raw data is the audit trail. Corrections are captured in Silver, never Bronze. |
| **SCD Type 2 for Customers** | Regulators and fraud investigators need point-in-time customer state, not just today's. |
| **dbt in Gold layer** | SQL aggregations with version control, testing, and lineage. Readable by analysts, not just engineers. |
| **Data quality at Silver** | First layer business logic depends on. Catching bad data here is cheaper than fixing it downstream. |

See [`/docs/architecture_decisions.md`](docs/architecture_decisions.md) for full reasoning.

---

## Project Structure

```
retail-banking-data-platform/
│
├── README.md
├── .github/
│   └── workflows/
│       └── ci.yml                  ← GitHub Actions CI/CD
│
├── data/
│   └── sample/                     ← Small sample data for testing
│
├── ingestion/
│   ├── alpha_vantage.py            ← Alpha Vantage API ingestion
│   ├── fred_api.py                 ← FRED API ingestion
│   ├── open_banking.py             ← UK Open Banking reference data
│   └── kaggle_loader.py            ← Kaggle fraud dataset loader
│
├── notebooks/
│   ├── 01_bronze_ingestion.ipynb   ← Land raw data into Delta
│   ├── 02_silver_cleaning.ipynb    ← Clean, deduplicate, SCD Type 2
│   └── 03_gold_aggregation.ipynb   ← Aggregations before dbt
│
├── dbt_project/
│   ├── dbt_project.yml
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   └── tests/
│
├── tests/
│   └── test_silver_quality.py      ← pytest data quality checks
│
└── docs/
    ├── architecture_decisions.md
    └── architecture.png
```

---

## How to Run

> Setup instructions will be added as each layer is built (Week 1–4).

### Prerequisites
- Python 3.9+
- Azure Databricks workspace (Community Edition works)
- API keys: Alpha Vantage, FRED
- dbt Core installed locally

### Ingestion (Week 1)
```bash
pip install -r requirements.txt
python ingestion/alpha_vantage.py
python ingestion/fred_api.py
```

---

## Build Status

![CI](https://github.com/Sarav-OR/retail-banking-data-platform/actions/workflows/ci.yml/badge.svg)

---

## One-Sentence Summary

> *"I built a retail banking data platform that ingests live data from four public APIs, processes 284,000+ transactions through a full medallion architecture with SCD Type 2 customer tracking and AML fraud flagging, uses dbt for Gold layer transformations, and delivers KPIs to a Power BI dashboard — all with automated data quality checks and a GitHub Actions CI pipeline."*

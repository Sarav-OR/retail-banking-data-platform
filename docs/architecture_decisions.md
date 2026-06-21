# Architecture Decisions

This document explains the reasoning behind every major design choice in the Retail Banking Data Platform. These are interview-ready answers.

---

## Why Medallion Architecture?

Medallion separates concerns clearly — raw ingestion, data quality and conformance, and business aggregation are three different problems. Mixing them in a single layer makes debugging impossible. If something breaks in production, I know exactly which layer to look at:

- **Bronze is the API's fault** — raw data arrived malformed or missing
- **Silver is a quality issue** — business rules weren't applied correctly
- **Gold is a business logic issue** — aggregation or metric definition is wrong

---

## Why Delta Lake instead of Parquet?

Delta gives ACID transactions, which means failed jobs don't leave partial data. It gives time travel, so any table can be queried as it looked last week. And it gives schema enforcement, so a source sending an unexpected column doesn't silently corrupt downstream tables.

Plain Parquet gives none of that. In a banking context, auditability and consistency are non-negotiable.

---

## Why Append-Only Bronze?

Raw data should never be modified. If the source sends a correction, the correction is captured as a new record and resolved in Silver. This preserves the full audit history and means Bronze can always be used as a recovery point if transformation logic has a bug.

---

## Why SCD Type 2 for Customers?

Customer attributes change — risk rating, address, account status. In banking, regulators and fraud investigators need to know what state a customer was in at a specific point in time, not just today's state.

SCD Type 2 preserves that full history with `effective_from` and `effective_to` dates. SCD Type 1 (overwrite) destroys that history and cannot support point-in-time queries.

---

## Why Deduplicate in Silver, not Bronze?

Bronze captures exactly what the source sent, including duplicates. Silver is where business rules are applied. Separating them means deduplication logic can be changed without losing original data.

---

## Why Data Quality Checks at Silver?

Silver is the first layer that business logic depends on. If bad data passes Silver, it corrupts Gold and the dashboard. Catching it at Silver is cheaper than fixing it downstream. Failed records are routed to a quarantine table with a rejection reason — never silently dropped.

---

## Why dbt in the Gold Layer?

Gold is primarily aggregations, joins, and business metric calculations — SQL handles this cleanly. dbt adds version control, automated testing, and documentation on top of SQL.

In a team environment, any analyst can read and understand a dbt model. Spark in the Gold layer would be more powerful but harder to maintain and harder for non-engineers to contribute to. The rule: use Spark where you need distributed compute, use dbt where you need readable, testable SQL.

---

## Why Real APIs Instead of Static CSV Files?

Real pipelines pull data from APIs and third-party systems. Using APIs demonstrates understanding of real ingestion patterns: handling pagination, managing API keys securely, dealing with schema changes, and handling partial failures. Static files simulate nothing.

---

## What Would Be Added in a Production System?

- **Unity Catalog** for data lineage, access control, and governance
- **Autoloader** for continuous streaming ingestion instead of batch
- **Incremental dbt models** with watermark columns instead of full refresh
- **Alerting** on data quality check failures (not just logging)
- **Data contracts** between Bronze and Silver to catch schema drift early

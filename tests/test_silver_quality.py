# tests/test_silver_quality.py
# Data Quality checks for Silver layer
# Databricks Spark Connect compatible version
# Uses existing spark session — no SparkSession.builder

import pytest
from pyspark.sql.functions import col

SILVER_PATH = "abfss://silver@retailbankingdl.dfs.core.windows.net"

@pytest.fixture(scope="session")
def df_transactions():
    return spark.read.format("delta").load(f"{SILVER_PATH}/transactions_cleaned")

@pytest.fixture(scope="session")
def df_customers():
    return spark.read.format("delta").load(f"{SILVER_PATH}/customers_scd2")

class TestSilverTransactions:
    def test_transactions_not_empty(self, df_transactions):
        assert df_transactions.count() > 0
    def test_transactions_minimum_row_count(self, df_transactions):
        count = df_transactions.count()
        assert count >= 280_000, f"Expected >= 280,000 rows, got {count:,}"
    def test_transactions_required_columns_exist(self, df_transactions):
        required = {"transaction_sk","transaction_time_seconds","transaction_amount","is_fraud","dq_passed","dq_amount_valid","dq_fraud_label_valid","silver_ingestion_ts","silver_ingestion_date","silver_source"}
        missing = required - set(df_transactions.columns)
        assert not missing, f"Missing columns: {missing}"
    def test_transactions_no_null_surrogate_keys(self, df_transactions):
        assert df_transactions.filter(col("transaction_sk").isNull()).count() == 0
    def test_transactions_surrogate_keys_unique(self, df_transactions):
        total = df_transactions.count()
        distinct = df_transactions.select("transaction_sk").distinct().count()
        assert total == distinct
    def test_transactions_no_null_amounts(self, df_transactions):
        assert df_transactions.filter(col("transaction_amount").isNull()).count() == 0
    def test_transactions_amounts_positive(self, df_transactions):
        assert df_transactions.filter(col("transaction_amount") <= 0).count() == 0
    def test_transactions_fraud_label_valid(self, df_transactions):
        assert df_transactions.filter(~col("is_fraud").isin(0, 1)).count() == 0
    def test_transactions_dq_passed_rate(self, df_transactions):
        total = df_transactions.count()
        passed = df_transactions.filter(col("dq_passed") == True).count()
        assert passed/total >= 0.99
    def test_transactions_fraud_rate_realistic(self, df_transactions):
        total = df_transactions.count()
        fraud = df_transactions.filter(col("is_fraud") == 1).count()
        assert 0.001 <= fraud/total <= 0.01
    def test_transactions_source_column_populated(self, df_transactions):
        assert df_transactions.filter(col("silver_source").isNull()).count() == 0
    def test_transactions_ingestion_date_populated(self, df_transactions):
        assert df_transactions.filter(col("silver_ingestion_date").isNull()).count() == 0

class TestSilverCustomersSCD2:
    def test_customers_not_empty(self, df_customers):
        assert df_customers.count() > 0
    def test_customers_required_columns_exist(self, df_customers):
        required = {"customer_sk","customer_id","risk_rating","account_status","account_type","country","credit_limit","effective_from","effective_to","is_current","scd_version","silver_ingestion_date"}
        missing = required - set(df_customers.columns)
        assert not missing
    def test_customers_no_null_customer_ids(self, df_customers):
        assert df_customers.filter(col("customer_id").isNull()).count() == 0
    def test_customers_surrogate_keys_unique(self, df_customers):
        total = df_customers.count()
        distinct = df_customers.select("customer_sk").distinct().count()
        assert total == distinct
    def test_customers_one_current_record_per_customer(self, df_customers):
        violations = df_customers.filter(col("is_current")==True).groupBy("customer_id").count().filter(col("count")>1).count()
        assert violations == 0
    def test_customers_effective_dates_valid(self, df_customers):
        assert df_customers.filter(col("effective_from") >= col("effective_to")).count() == 0
    def test_customers_current_records_have_open_end_date(self, df_customers):
        assert df_customers.filter((col("is_current")==True)&(col("effective_to")!="9999-12-31")).count() == 0
    def test_customers_historical_records_not_open(self, df_customers):
        assert df_customers.filter((col("is_current")==False)&(col("effective_to")=="9999-12-31")).count() == 0
    def test_customers_risk_rating_valid_values(self, df_customers):
        assert df_customers.filter(~col("risk_rating").isin("LOW","MEDIUM","HIGH")).count() == 0
    def test_customers_credit_limit_positive(self, df_customers):
        assert df_customers.filter(col("credit_limit") <= 0).count() == 0
    def test_customers_scd_version_valid(self, df_customers):
        assert df_customers.filter(~col("scd_version").isin(1,2)).count() == 0
    def test_customers_point_in_time_query(self, df_customers):
        duplicates = df_customers.filter((col("effective_from")<="2022-06-01")&(col("effective_to")>"2022-06-01")).groupBy("customer_id").count().filter(col("count")>1).count()
        assert duplicates == 0

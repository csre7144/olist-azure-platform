# Databricks notebook source
from pyspark.sql import functions as F

base_b = "abfss://bronze@olistlakechintan01.dfs.core.windows.net/"
base_s = "abfss://silver@olistlakechintan01.dfs.core.windows.net/"

# customers
cust = (spark.read.parquet(base_b + "olist_customers_dataset/")
        .filter(F.col("customer_id").isNotNull())
        .dropDuplicates(["customer_id"])
        .withColumn("customer_city", F.initcap(F.trim("customer_city")))
        .withColumn("customer_state", F.upper(F.trim("customer_state")))
        .withColumn("_ingested_at", F.current_timestamp()))
cust.write.format("delta").mode("overwrite").save(base_s + "customers/")

# products
prod = (spark.read.parquet(base_b + "olist_products_dataset/")
        .filter(F.col("product_id").isNotNull())
        .dropDuplicates(["product_id"])
        .withColumn("product_category_name",
                    F.coalesce(F.trim("product_category_name"), F.lit("unknown")))
        .withColumn("_ingested_at", F.current_timestamp()))
prod.write.format("delta").mode("overwrite").save(base_s + "products/")

# order items
items = (spark.read.parquet(base_b + "olist_order_items_dataset/")
         .filter(F.col("order_id").isNotNull())
         .dropDuplicates(["order_id", "order_item_id"])
         .withColumn("total_price", F.col("price") + F.col("freight_value"))
         .withColumn("_ingested_at", F.current_timestamp()))
items.write.format("delta").mode("overwrite").save(base_s + "order_items/")

for name, d in [("customers", cust), ("products", prod), ("order_items", items)]:
    print(name, d.count())
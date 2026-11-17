# Databricks notebook source
from pyspark.sql import functions as F

bronze_path = "abfss://bronze@olistlakechintan01.dfs.core.windows.net/orders/"
silver_path = "abfss://silver@olistlakechintan01.dfs.core.windows.net/orders/"

df = spark.read.parquet(bronze_path)
print("bronze rows:", df.count())

silver = (
    df.filter(F.col("order_id").isNotNull())
      .dropDuplicates(["order_id"])
      .withColumn("order_status", F.lower(F.trim("order_status")))
      .withColumn("delivery_days",
          F.datediff("order_delivered_customer_date", "order_purchase_timestamp"))
      .withColumn("is_late",
          F.col("order_delivered_customer_date") > F.col("order_estimated_delivery_date"))
      .withColumn("_ingested_at", F.current_timestamp())
)

print("silver rows:", silver.count())

silver.write.format("delta").mode("overwrite").save(silver_path)

spark.read.format("delta").load(silver_path).display()
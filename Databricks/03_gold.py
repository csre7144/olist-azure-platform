# Databricks notebook source
from pyspark.sql import functions as F

s = "abfss://silver@olistlakechintan01.dfs.core.windows.net/"
g = "abfss://gold@olistlakechintan01.dfs.core.windows.net/"

orders = spark.read.format("delta").load(s + "orders/")
cust   = spark.read.format("delta").load(s + "customers/")
prod   = spark.read.format("delta").load(s + "products/")
items  = spark.read.format("delta").load(s + "order_items/")

# dim_customer (customer_id is per order; customer_unique_id is the real person)
dim_customer = (cust.select("customer_id", "customer_unique_id",
                            "customer_city", "customer_state", "customer_zip_code_prefix"))
dim_customer.write.format("delta").mode("overwrite").save(g + "dim_customer/")

# dim_product
dim_product = prod.select("product_id", "product_category_name",
                          "product_weight_g", "product_length_cm",
                          "product_height_cm", "product_width_cm")
dim_product.write.format("delta").mode("overwrite").save(g + "dim_product/")

# dim_date
dim_date = (spark.sql("SELECT explode(sequence(to_date('2016-01-01'), to_date('2018-12-31'), interval 1 day)) AS date")
            .withColumn("date_key", F.date_format("date", "yyyyMMdd").cast("int"))
            .withColumn("year", F.year("date"))
            .withColumn("month", F.month("date"))
            .withColumn("month_name", F.date_format("date", "MMMM"))
            .withColumn("quarter", F.quarter("date"))
            .withColumn("day_of_week", F.date_format("date", "E")))
dim_date.write.format("delta").mode("overwrite").save(g + "dim_date/")

# fact_orders (grain: one row per order item)
fact_orders = (items.join(orders, "order_id", "inner")
    .select("order_id", "order_item_id", "customer_id", "product_id",
            "order_status", "order_purchase_timestamp",
            F.date_format("order_purchase_timestamp", "yyyyMMdd").cast("int").alias("purchase_date_key"),
            "price", "freight_value", "total_price",
            "delivery_days", "is_late"))
fact_orders.write.format("delta").mode("overwrite").save(g + "fact_orders/")

for n, d in [("dim_customer", dim_customer), ("dim_product", dim_product),
             ("dim_date", dim_date), ("fact_orders", fact_orders)]:
    print(n, d.count())
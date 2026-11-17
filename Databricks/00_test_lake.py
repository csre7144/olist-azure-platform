# Databricks notebook source
df = spark.read.parquet("abfss://bronze@olistlakechintan01.dfs.core.windows.net/orders/")
print(df.count())
df.printSchema()
display(df.limit(5))
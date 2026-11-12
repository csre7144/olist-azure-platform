-- ============================================
-- 01_watermark.sql
-- Watermark table for incremental loads (ADF)
-- Database: olist-db
-- ============================================

-- 1. Table to store the last loaded timestamp per source table
CREATE TABLE dbo.watermark (
    table_name      NVARCHAR(100) PRIMARY KEY,
    watermark_value DATETIME NOT NULL
);
GO

-- 2. Initial value (loads everything on the first run)
INSERT INTO dbo.watermark (table_name, watermark_value)
VALUES ('olist_orders_dataset', '1900-01-01');
GO

-- 3. Stored procedure ADF calls after a successful copy
CREATE PROCEDURE dbo.usp_update_watermark
    @table_name NVARCHAR(100),
    @new_value  DATETIME
AS
BEGIN
    UPDATE dbo.watermark
    SET watermark_value = @new_value
    WHERE table_name = @table_name;
END;
GO

-- 4. Check
SELECT * FROM dbo.watermark;
GO
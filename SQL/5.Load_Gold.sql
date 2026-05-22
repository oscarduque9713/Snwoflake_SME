
USE ROLE DEVELOPER ;
USE WAREHOUSE PROJECT ;

/* ============================================================
   01 - MAIN TRANSACTION FACT
   ============================================================ */
   
INSERT INTO &DB_NAME.GOLD.FACT_TRANSACTIONS
SELECT TRANSACTION_ID,  ------------ PRIMARY KEY
    ORDER_ID,   --------------- FOREIGN KETY TO DIM ORDERS AND DIM PAYMENTS
    ORDER_DATE,
    CUSTOMER_ID, ----------- FOREIGN KEY TO DIM CUSTOMER
    SKU,  ------------------ FOREGIN KEY TO DIM PRODUCT
    QUANTITY,
    PAYMENT_AMOUNT
FROM &DB_NAME.SILVER.SLV_TRANSACTIONS
;

/* ============================================================
   02 - CUSTOMER DIMENSION
   ============================================================ */

INSERT INTO &DB_NAME.GOLD.DIM_CUSTOMERS
SELECT * 
FROM &DB_NAME.SILVER.DIM_CUSTOMERS ;

/* ============================================================
   03 - PRODUCT DIMENSION
   ============================================================ */

INSERT INTO &DB_NAME.GOLD.DIM_PRODUCT
SELECT *
FROM &DB_NAME.SILVER.DIM_PRODUCT ;

/* ============================================================
   04 - ORDER DIMENSION
   ============================================================ */
-- Orders and payments are modeled separately, but both are related through ORDER_ID.

INSERT INTO &DB_NAME.GOLD.DIM_ORDER
SELECT ORDER_ID,
    ORDER_DATE,
    ORDER_STATUS,
    CHANNEL
FROM &DB_NAME.SILVER.DIM_ORDER ;

/* ============================================================
   05 - PAYMENT DIMENSION
   ============================================================ */
   
INSERT INTO &DB_NAME.GOLD.DIM_PAYMENT
SELECT 
    PAYMENT_ID,
    ORDER_ID,
    PAYMENT_METHOD,
    CURRENCY,
    STATUS
FROM &DB_NAME.SILVER.DIM_PAYMENTS 
;


/* ============================================================
   06 - REJECTION / GAP TABLE
   Orders without related transactions
   ============================================================ 

## Rejection Handling

Some orders exist in the order source data but do not have a matching transaction record. These records are not inserted into the main transaction fact table because they do not represent completed transaction lines.

Instead, they are stored in `FACT_ORDER_GAPS` with the gap type `NO_TRANSACTION`. This preserves the information for audit and reconciliation without contaminating the main analytical fact table.*/

INSERT INTO &DB_NAME.GOLD.FACT_ORDER_GAPS
SELECT
    DO.ORDER_ID,
    DO.CUSTOMER_ID,
    DO.ORDER_DATE,
    'NO_TRANSACTION' AS GAP_TYPE,
    COALESCE(SUM(DP.AMOUNT), 0) AS PAYMENT_AMOUNT
FROM &DB_NAME.SILVER.DIM_ORDER DO
LEFT JOIN &DB_NAME.SILVER.SLV_TRANSACTIONS F
    ON DO.ORDER_ID = F.ORDER_ID
LEFT JOIN &DB_NAME.SILVER.DIM_PAYMENTS DP
    ON DO.ORDER_ID = DP.ORDER_ID
WHERE F.ORDER_ID IS NULL
GROUP BY 
    DO.ORDER_ID,
    DO.CUSTOMER_ID,
    DO.ORDER_DATE;
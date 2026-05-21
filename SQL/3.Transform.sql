USE ROLE DEVELOPER ;
USE WAREHOUSE PROJECT ;

/* ============================================================
   01 - CSV NORMALIZATION
   ============================================================ */

CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS AS 
WITH FLATTEN_INICIAL AS (
    SELECT 
        'col' || (f.index + 1) AS key,
        REPLACE(f.value::STRING, '""', '') AS value,
        LENGTH( VALUE) KEY_COLUMN_NULL, 
        t.file_name,
        t.file_row_number
    FROM PROJECT_SEMESTRUCTURED.BRONZE.CSV_RAW_CONTENT t,
    LATERAL FLATTEN(input => SPLIT(t.RAW_CONTENT, ',')) f
    WHERE 
        t.RAW_CONTENT NOT ILIKE '----- START OF FILE%'
        AND t.RAW_CONTENT NOT ILIKE '----- END OF FILE%'
)
SELECT KEY,
(CASE WHEN KEY_COLUMN_NULL = 0 THEN NULL ELSE VALUE END) VALUE,
FILE_NAME,
FILE_ROW_NUMBER
FROM FLATTEN_INICIAL;

/* ============================================================
   02 - CUSTOMER DIMENSION TRANSFORMATION
   ============================================================ */

--The customer data is sourced from two different CSV files with inconsistent schemas and column ordering.
--To standardize the structure, I implemented separate transformation views for each source, mapping positional columns into a unified schema.


CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.TRANSFROM_IN_CUSTOMER_CB AS
WITH AGGREGATED_INITIAL_CUSTOMER_B AS (
        SELECT 
        FILE_NAME,
        FILE_ROW_NUMBER,
        MAX( CASE WHEN KEY = 'col1' THEN VALUE END) AS CUSTOMER_ID,
        MAX( CASE WHEN KEY = 'col2' THEN VALUE END) AS CUSTOMER_NAME,
        MAX( CASE WHEN KEY = 'col3' THEN VALUE END) AS EMAIL,
        MAX( CASE WHEN KEY = 'col4' THEN VALUE END) AS SEGMENT,
        MAX( CASE WHEN KEY = 'col5' THEN VALUE END) AS ISACTIVE
        FROM PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS
        WHERE FILE_NAME = 'CLIENT_B/Customer.CSV' AND 
        FILE_ROW_NUMBER <> 2
        GROUP BY FILE_NAME, FILE_ROW_NUMBER
    )
SELECT
CUSTOMER_ID,
IFNULL( CUSTOMER_NAME, 'UNKNOWN') CUSTOMER_NAME,
( CASE WHEN ISACTIVE LIKE '%missing email%' OR ISACTIVE LIKE '%invalid email%'
    THEN 'UNKNOWN'
    ELSE EMAIL END) EMAIL,
IFNULL( SEGMENT, 'UNKNOWN') SEGMENT,
SPLIT_PART(ISACTIVE, ' ', 1) IS_ACTIVE
FROM (
      SELECT * FROM AGGREGATED_INITIAL_CUSTOMER_B
      WHERE CUSTOMER_ID LIKE 'C%'
    )
QUALIFY ROW_NUMBER() OVER( PARTITION BY CUSTOMER_ID ORDER BY FILE_ROW_NUMBER DESC, CUSTOMER_NAME NULLS LAST) = 1 and
ISACTIVE NOT LIKE '%null-heavy%'  ---- Email quality issues are inferred from source flags embedded in the ISACTIVE field.
;

---CLIENT A 

CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.TRANSFROM_IN_CUSTOMER_CA AS
WITH AGGREGATED_INITIAL_CUSTOMER_A AS (
        SELECT 
        FILE_NAME,
        FILE_ROW_NUMBER,
        MAX( CASE WHEN KEY = 'col1' THEN VALUE END) AS CUSTOMER_ID,
        MAX( CASE WHEN KEY = 'col2' THEN VALUE END) AS FIRST_NAME,
        MAX( CASE WHEN KEY = 'col3' THEN VALUE END) AS LAST_NAME,
        MAX( CASE WHEN KEY = 'col4' THEN VALUE END) AS EMAIL,
        MAX( CASE WHEN KEY = 'col5' THEN VALUE END) AS LOYALTY_TIER,
        MAX( CASE WHEN KEY = 'col6' THEN VALUE END) AS SIGNUP_SOURCE,
        MAX( CASE WHEN KEY = 'col7' THEN VALUE END) AS ISACTIVE
        FROM PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS
        WHERE FILE_NAME = 'Customer.csv' AND
        FILE_ROW_NUMBER <> 2
        GROUP BY FILE_NAME, FILE_ROW_NUMBER
        )
SELECT 
CUSTOMER_ID,
IFNULL( CONCAT( LAST_NAME, ' ', FIRST_NAME), 'UNKNOWN') CUSTOMER_NAME,
IFNULL( EMAIL, 'UNKNOWN') EMAIL,
IFNULL( LOYALTY_TIER, 'UNKNOWN') LOYALTY_TIER,
IFNULL( SIGNUP_SOURCE, 'UNKNOWN') SIGNUP_SOURCE,
SPLIT_PART(ISACTIVE, ' ', 1) IS_ACTIVE
FROM (
    SELECT * FROM AGGREGATED_INITIAL_CUSTOMER_A
    WHERE CUSTOMER_ID LIKE 'C%'
    )
QUALIFY ROW_NUMBER() OVER( PARTITION BY CUSTOMER_ID ORDER BY FILE_ROW_NUMBER DESC, CUSTOMER_NAME NULLS LAST) = 1 and
    ISACTIVE NOT LIKE '%null-heavy%'  ---Email quality issues are inferred from source flags embedded in the ISACTIVE field.
;


----- TABLE UNIFIED IN SILVER 

INSERT INTO PROJECT_SEMESTRUCTURED.SILVER.DIM_CUSTOMERS
SELECT CUSTOMER_ID,
    CUSTOMER_NAME,
    EMAIL,
    SEGMENT,
    'UNKNOWN' LOYALTY_TIER,
    'UNKNOWN' SIGNUP_SOURCE,
    IS_ACTIVE
FROM PROJECT_SEMESTRUCTURED.SILVER.TRANSFROM_IN_CUSTOMER_CB 
UNION
SELECT CUSTOMER_ID,
    CUSTOMER_NAME,
    EMAIL,
    'UNKNOWN' SEGMENT,
    LOYALTY_TIER,
    SIGNUP_SOURCE,
    IS_ACTIVE
FROM PROJECT_SEMESTRUCTURED.SILVER.TRANSFROM_IN_CUSTOMER_CA
;

/* ============================================================
   03 - PRODUCT, ORDER AND PAYMENT DIMENSIONS
   ============================================================ */

---- two files have the same format and columns, the duplicate values are removed and the anomalys that indicates in is_active col are removed, sku-0-999 and C-SKU-999

INSERT INTO PROJECT_SEMESTRUCTURED.SILVER.DIM_PRODUCT
WITH AGGREGATED_INITIAL_PRODUCTS AS (
        SELECT 
        FILE_NAME,
        FILE_ROW_NUMBER,
        MAX( CASE WHEN KEY = 'col1' THEN VALUE END) AS SKU,
        MAX( CASE WHEN KEY = 'col2' THEN VALUE END) AS PRODUCT_NAME,
        MAX( CASE WHEN KEY = 'col3' THEN VALUE END) AS CATEGORY,
        MAX( CASE WHEN KEY = 'col4' THEN VALUE END)::FLOAT AS UNIT_PRICE,
        MAX( CASE WHEN KEY = 'col5' THEN VALUE END) AS CURRENCY,
        MAX( CASE WHEN KEY = 'col6' THEN VALUE END) AS ISACTIVE
        FROM PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS
        WHERE FILE_NAME LIKE '%Product%.csv%' AND
        FILE_ROW_NUMBER <> 2
        GROUP BY FILE_NAME, FILE_ROW_NUMBER
        )
SELECT 
SKU,   ------------------- PRIMARY KEY
PRODUCT_NAME,
CATEGORY,
UNIT_PRICE,
CURRENCY,
SPLIT_PART(ISACTIVE, ' ', 1) IS_ACTIVE
FROM AGGREGATED_INITIAL_PRODUCTS
QUALIFY ROW_NUMBER() OVER( PARTITION BY SKU ORDER BY FILE_ROW_NUMBER DESC, PRODUCT_NAME NULLS LAST) = 1 AND 
ISACTIVE NOT LIKE '%anomaly%'  
;

------------------ DIM ORDERS -------------------------------------------------------

--al tener dos archivos con solo una columna adicional en uno y el mismo orden se trabaja en un solo
INSERT INTO PROJECT_SEMESTRUCTURED.SILVER.DIM_ORDER
WITH AGGREGATED_INITIAL_ORDER_A AS (
        SELECT 
        FILE_NAME,
        FILE_ROW_NUMBER,
        MAX( CASE WHEN KEY = 'col1' THEN VALUE END) AS ORDER_ID,
        MAX( CASE WHEN KEY = 'col2' THEN VALUE END) AS CUSTOMER_ID,
        MAX( CASE WHEN KEY = 'col3' THEN VALUE END)::DATE AS ORDER_DATE,
        MAX( CASE WHEN KEY = 'col4' THEN VALUE END) AS ORDER_STATUS_PRE,
        IFNULL( MAX( CASE WHEN KEY = 'col5' THEN VALUE END), 'UNKNOWN') AS CHANNEL_PRE
        FROM PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS
        WHERE FILE_NAME like '%Order%.csv%' AND
        FILE_ROW_NUMBER <> 2
        GROUP BY FILE_NAME, FILE_ROW_NUMBER
        )
SELECT 
ORDER_ID,   ---------------  PRIMARY KEY
CUSTOMER_ID, ------------------ FOREIGN KEY WITH DIM CUSTOMER
ORDER_DATE,
SPLIT_PART( ORDER_STATUS_PRE, ' ', 1) ORDER_STATUS,
SPLIT_PART( CHANNEL_PRE, ' ', 1) CHANNEL
FROM AGGREGATED_INITIAL_ORDER_A
QUALIFY ROW_NUMBER() OVER( PARTITION BY ORDER_ID ORDER BY FILE_ROW_NUMBER DESC) = 1 and
(ORDER_STATUS_PRE NOT LIKE '%invalid customer' AND CHANNEL_PRE NOT LIKE '%invalid customer') -------------- these rows are removed becaouse it indicates the customer is invalid
;


---- DIM PAYMENTS ------------------------------------
INSERT INTO PROJECT_SEMESTRUCTURED.SILVER.DIM_PAYMENTS
WITH AGGREGATED_INITIAL_PAYMENT AS (
        SELECT 
        FILE_NAME,
        FILE_ROW_NUMBER,
        MAX( CASE WHEN KEY = 'col1' THEN VALUE END) AS PAYMENT_ID,
        MAX( CASE WHEN KEY = 'col2' THEN VALUE END) AS ORDER_ID,
        MAX( CASE WHEN KEY = 'col3' THEN VALUE END) AS PAYMENT_METHOD,
        MAX( CASE WHEN KEY = 'col4' THEN VALUE END)::FLOAT AS AMOUNT,
        MAX( CASE WHEN KEY = 'col5' THEN VALUE END) AS CURRENCY,
        MAX( CASE WHEN KEY = 'col6' THEN VALUE END) AS STATUS
        FROM PROJECT_SEMESTRUCTURED.SILVER.DIN_CSV_COLS
        WHERE FILE_NAME like '%Payments.csv%' AND
        FILE_ROW_NUMBER <> 2
        GROUP BY FILE_NAME, FILE_ROW_NUMBER
        )
SELECT 
PAYMENT_ID,   ---------------  PRIMARY KEY
ORDER_ID, ------------------ FOREIGN KEY WITH DIM ORDER
PAYMENT_METHOD,
( CASE WHEN STATUS LIKE 'REFUNDED%' THEN ABS( AMOUNT) ELSE AMOUNT END) AMOUNT,
CURRENCY,
SPLIT_PART( STATUS, ' ', 1) STATUS
FROM AGGREGATED_INITIAL_PAYMENT
QUALIFY ROW_NUMBER() OVER( PARTITION BY PAYMENT_ID ORDER BY FILE_ROW_NUMBER DESC) = 1 
;


/* ============================================================
   04 - XML TRANSACTION TRANSFORMATION
   ============================================================ */

------ INITIALLY TO PARSE THE FILE, I CREATE A VIEW INITIAL
CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_XML_PARSE AS 
WITH fixed AS (
    ----- to clean the trush of the file ------ start and end, rebuild the xml with list_agg
    SELECT 
        LISTAGG(
            REGEXP_REPLACE(xml_content, '-----[\\s\\S]*?-----', ''), 
            ''
        ) WITHIN GROUP (ORDER BY FILE_ROW_NUMBER) AS xml_full,
        FILE_NAME
    FROM PROJECT_SEMESTRUCTURED.BRONZE.RAW_XML_INGESTION
    GROUP BY FILE_NAME
),
cleaned AS (
    ------- clean all variantas in the files
    SELECT 
        REGEXP_REPLACE(xml_full, '<\\/?SalesData[^>]*>', '') AS no_root,
        FILE_NAME
    FROM fixed
),
normalized AS (
  --- rebuild the root and the xml valido
  SELECT 
        '<SalesData>' || no_root || '</SalesData>' AS xml_fixed,
        FILE_NAME
    FROM cleaned
)
--- transfrom string in xml type
SELECT PARSE_XML(xml_fixed) XML_CONTENT, FILE_NAME
FROM normalized
;

--- TRANSFORM STANDAR FORMAT

CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_CLIENT_XML AS 
WITH EXTRACTION_XML AS (
    SELECT 
        xmlget( t.value, 'TransactionID'):"$"::STRING AS TRANSACTION_ID,
        -- ORDER
        XMLGET(o.value, 'OrderID'):"$"::STRING AS ORDER_ID,
        XMLGET(o.value, 'OrderDate'):"$"::STRING AS ORDER_DATE,
        -- CUSTOMER
        XMLGET(c.value, 'CustomerID'):"$"::STRING AS CUSTOMER_ID,
        XMLGET(n.value, 'FirstName'):"$"::STRING AS CUSTOMER_NAME,
        XMLGET(n.value, 'LastName'):"$"::STRING AS CUSTOMER_LASTNAME,
        XMLGET(c.value, 'Email'):"$"::STRING AS CUSTOMER_EMAIL,
        -- ITEMS 
        XMLGET(i.value, 'SKU'):"$"::STRING AS SKU,
        XMLGET(i.value, 'Description'):"$"::STRING AS DESCRIPTION,
        XMLGET(i.value, 'Quantity'):"$"::STRING AS QUANTITY,
        XMLGET(i.value, 'UnitPrice'):"$"::STRING AS UNIT_PRICE,
        XMLGET(i.value, 'UnitPrice'):"@currency"::STRING AS CURRENCY,
        -- PAYMENT
        XMLGET(p.value,  'Method'):"$"::STRING AS PAYMENT_METHOD,
        XMLGET(p.value,  'Amount'):"$"::STRING AS PAYMENT_AMOUNT,
        FILE_NAME AS FILENAME
        FROM PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_XML_PARSE ,
        LATERAL FLATTEN( INPUT => xml_content:"$") t, -- 🔹 Level Transaction
        LATERAL ( SELECT XMLGET(t.value, 'Order') AS value) o, -- 🔹 Level Order
        LATERAL ( SELECT XMLGET(o.value, 'Customer') AS value) c, -- 🔹 Level Customer
        LATERAL ( SELECT XMLGET(c.value, 'Name') AS value) n, -- Name
        LATERAL FLATTEN(INPUT => XMLGET(t.value, 'Items')) i, -- Items 
        LATERAL (SELECT XMLGET(t.value, 'Payment') AS value) p -- 🔥 Payment 
        WHERE t.value:"@" = 'Transaction' AND 
        i.value:"@" = 'Item'
)
SELECT
    NULLIF(TRIM(TRANSACTION_ID), '') AS TRANSACTION_ID,
    NULLIF(TRIM(ORDER_ID), '') AS ORDER_ID,
    NULLIF(TRIM(ORDER_DATE), '')::DATE AS ORDER_DATE,
    NULLIF(TRIM(CUSTOMER_ID), '') AS CUSTOMER_ID,
    TRIM(CONCAT_WS(' ',
        NULLIF(TRIM(CUSTOMER_LASTNAME), ''),
        NULLIF(TRIM(CUSTOMER_NAME), '')
    )) AS CUSTOMER_NAME,
    NULLIF(TRIM(CUSTOMER_EMAIL), '') AS CUSTOMER_EMAIL,
    NULLIF(TRIM(SKU), '') AS SKU,
    NULLIF(TRIM(DESCRIPTION), '') AS DESCRIPTION,
    CASE 
        WHEN LENGTH(TRIM(QUANTITY)) = 0 THEN 0
        ELSE ABS(QUANTITY::FLOAT)
    END AS QUANTITY,
    CURRENCY,
    NULLIF(TRIM(PAYMENT_METHOD), '') AS PAYMENT_METHOD,
    CASE 
        WHEN LENGTH(TRIM(PAYMENT_AMOUNT)) = 0 THEN 0
        ELSE ABS(PAYMENT_AMOUNT::FLOAT)
    END AS PAYMENT_AMOUNT,
    FILENAME
FROM EXTRACTION_XML
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY TRANSACTION_ID
    ORDER BY ORDER_DATE DESC
) = 1
;


/* ============================================================
   05 - JSON TRANSACTION TRANSFORMATION
   ============================================================ */


CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.JSON_FIX AS
WITH dedup AS (
    SELECT *
    FROM PROJECT_SEMESTRUCTURED.BRONZE.RAW_JSON_INGESTION
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY FILE_NAME, FILE_ROW_NUMBER, JSON_CONTENT
        ORDER BY LOAD_DT DESC
    ) = 1
),
full_file AS (
    SELECT 
        LISTAGG(JSON_CONTENT, '\n') 
            WITHIN GROUP (ORDER BY FILE_ROW_NUMBER::INT) AS content,
        FILE_NAME
    FROM dedup
    GROUP BY FILE_NAME
),
cleaned AS (
    SELECT 
        REGEXP_REPLACE(content, '^-{2,}.*$', '', 1, 0, 'm') AS step1,
        FILE_NAME
    FROM full_file
),
no_comments AS (
    SELECT 
        REGEXP_REPLACE(step1, '//.*\\n', '\n') AS step2,
        FILE_NAME
    FROM cleaned
),
no_block_comments AS (
    SELECT 
        REGEXP_REPLACE(step2, '/\\*[\\s\\S]*?\\*/', '') AS step3,
        FILE_NAME
    FROM no_comments
),
fixed AS (
    SELECT 
        REPLACE(step3, ';', '') AS valid_json,
        FILE_NAME
    FROM no_block_comments
)
SELECT 
    TRY_PARSE_JSON(valid_json) AS JSON_CONTENT,
    FILE_NAME
FROM fixed;



--Flatten Json

CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_CLIENT_JSON AS
SELECT 
    T.value:id::STRING AS TRANSACTION_ID,
    T.value:order:id::STRING AS ORDER_ID,
    T.value:order:date::DATE AS ORDER_DATE,
    T.value:order:customer:id::STRING AS CUSTOMER_ID,
    NULLIF( TRIM( T.value:order:customer:name::STRING), '') AS CUSTOMER_NAME,
    T.value:order:customer:email::STRING AS CUSTOMER_EMAIL,
    I.value:sku::STRING AS SKU,
    I.value:description::STRING AS DESCRIPTION,
    I.value:qty::FLOAT AS QUANTITY,
    I.value:price:amount::FLOAT AS PRICE_AMOUNT,
    I.value:price:currency::STRING AS CURRENCY,
    T.value:payment:method::STRING as PAYMENT_METHOD,
    T.value:payment:total::FLOAT as PAYMENT_AMOUNT
FROM PROJECT_SEMESTRUCTURED.SILVER.JSON_FIX,
LATERAL FLATTEN(input => JSON_CONTENT:transactions) T,
LATERAL FLATTEN(input => T.value:items) I;


-- UNION Facts in an unified view

CREATE OR REPLACE VIEW PROJECT_SEMESTRUCTURED.SILVER.SLV_TRANSACTIONS AS 
SELECT 
    IFNULL( TRANSACTION_ID, 'UNKNOWN') TRANSACTION_ID,  ------ PRIMARY KEY
    IFNULL( ORDER_ID, 'UNKNOWN') ORDER_ID,   ----- FOREIGN KEY DIM ORDERS
    ORDER_DATE,
    IFNULL( CUSTOMER_ID, 'UNKNOWN') CUSTOMER_ID, ---- FOREING KEY DIM CUSTOMERS
    IFNULL( CUSTOMER_NAME, 'UNKNOWN') CUSTOMER_NAME,
    IFNULL( CUSTOMER_EMAIL, 'UNKNOWN') CUSTOMER_EMAIL,
    IFNULL( SKU, 'UNKNOWN') SKU,  ------------- FOREIGN KEY DIM PRODUCTS
    IFNULL( DESCRIPTION, 'UNKNOWN') DESCRIPTION,
    QUANTITY,
    CURRENCY,
    IFNULL( PAYMENT_METHOD, 'UNKNOWN') PAYMENT_METHOD,
    PAYMENT_AMOUNT
FROM (
        SELECT TRANSACTION_ID,
                ORDER_ID,
                ORDER_DATE,
                CUSTOMER_ID,
                CUSTOMER_NAME,
                CUSTOMER_EMAIL,
                SKU,
                DESCRIPTION,
                QUANTITY,
                CURRENCY,
                PAYMENT_METHOD,
                PAYMENT_AMOUNT
        FROM PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_CLIENT_XML
        UNION ALL 
        SELECT TRANSACTION_ID,
                ORDER_ID,
                ORDER_DATE,
                CUSTOMER_ID,
                CUSTOMER_NAME,
                CUSTOMER_EMAIL,
                SKU,
                DESCRIPTION,
                QUANTITY,
                CURRENCY,
                PAYMENT_METHOD,
                PAYMENT_AMOUNT
        FROM PROJECT_SEMESTRUCTURED.SILVER.TRANSFORM_TRANSACTION_CLIENT_JSON
    );

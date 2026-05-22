

USE ROLE DEVELOPER ;
USE WAREHOUSE PROJECT ;

SELECT
    BATCH_ID,
    CSV_ROWS,
    JSON_ROWS,
    XML_ROWS,
    TOTAL_ROWS,
    STATUS
FROM &DB_NAME.BRONZE.PIPELINE_BATCH_CONTROL
WHERE BATCH_ID = '&{BATCH_ID}';

EXECUTE IMMEDIATE $$
DECLARE
    v_total_rows NUMBER;
    no_rows_loaded EXCEPTION (-20001, 'Pipeline detenido: no se cargaron registros para este batch.');
BEGIN
    SELECT COALESCE(TOTAL_ROWS, 0)
    INTO :v_total_rows
    FROM &DB_NAME.BRONZE.PIPELINE_BATCH_CONTROL
    WHERE BATCH_ID = '&{BATCH_ID}';

    IF (v_total_rows = 0) THEN
        RAISE no_rows_loaded;
    END IF;

    RETURN 'OK: el batch tiene registros cargados.';
END;
$$;
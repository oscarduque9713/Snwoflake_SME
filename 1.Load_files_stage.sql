----- CSV 
PUT 'file://C:/Users/GJX/Downloads/newfiles/*.csv'
@PROJECT_SEMESTRUCTURED.BRONZE.RAW/
AUTO_COMPRESS=TRUE;

PUT 'file://C:/Users/GJX/Downloads/newfiles/Client B/*.csv'
@PROJECT_SEMESTRUCTURED.BRONZE.RAW/Client_B/
AUTO_COMPRESS=TRUE;

------ XML 
PUT 'file://C:/Users/GJX/Downloads/newfiles/*.xml'
@PROJECT_SEMESTRUCTURED.BRONZE.RAW/
AUTO_COMPRESS=TRUE;

------TXT 
PUT 'file://C:/Users/GJX/Downloads/newfiles/*.txt'
@PROJECT_SEMESTRUCTURED.BRONZE.RAW/
AUTO_COMPRESS=TRUE;

----- JSON 
PUT 'file://C:/Users/GJX/Downloads/newfiles/Client B/*.json'
@PROJECT_SEMESTRUCTURED.BRONZE.RAW/Cliente_B/
AUTO_COMPRESS=TRUE;

LIST @PROJECT_SEMESTRUCTURED.BRONZE.RAW;
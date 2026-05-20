# Snowflake Semi-Structured Data Ingestion Pipeline

This project implements a data ingestion pipeline using **Snowflake**, **SnowSQL**, **PowerShell**, and **GitHub**.

The pipeline loads local files into a Snowflake internal stage, ingests the data into a Bronze layer, applies transformations and business rules, and prepares enriched data for a Gold layer.

The project works with multiple file formats, including **CSV, TXT, XML, and JSON**. All files are initially ingested using a semi-structured/raw approach, preserving the original content and technical metadata before applying transformations.

---

## Project Overview

The main goal of this project is to build a repeatable and auditable data pipeline using Snowflake and command-line automation.

The pipeline covers:

- Local file ingestion
- Uploading files to a Snowflake internal stage
- Processing CSV, TXT, XML, and JSON files
- Treating all source files as raw or semi-structured input
- Batch-based processing
- Raw data storage in the Bronze layer
- Metadata capture
- Transformation logic
- Business rule application
- Final curated output in the Gold layer
- Git-based version control

---

## Data Approach

This project uses a raw ingestion strategy for different file types.

The source data includes:

```text
CSV
TXT
XML
JSON
```

Even though CSV files are structured by nature, they are initially loaded as raw text lines in the Bronze layer. This allows the pipeline to preserve the original file content and defer parsing rules to later transformation steps.

JSON, XML, and TXT files are also loaded as raw or semi-structured content, allowing flexible processing and schema evolution.

This approach is useful when:

* Source files may have different structures.
* File schemas may change over time.
* Raw data needs to be preserved for auditability.
* Parsing logic should be separated from ingestion logic.
* Metadata such as file name, row number, and batch ID must be captured.


## Technologies Used

* Snowflake
* SnowSQL
* PowerShell
* SQL
* Git
* GitHub
* Snowflake Internal Stages
* Snowflake Git Repository


## Architecture

```Local CSV / TXT / XML / JSON Files
   |
   v
PowerShell / SnowSQL
   |
   v
Snowflake Internal Stage
   |
   v
Bronze Raw / Semi-Structured Layer
   |
   v
Transformation Layer
   |
   v
Business Rules
   |
   v
Gold Layer
   |
   v
Batch Control / Audit Table
```

```
snowflake-semi-structured-pipeline/
│
├── README.md
│
├── SQL/
│   ├── 0.Prep_Env.sql
│   ├── 0.1.Start_Batch.sql
│   ├── 1.Load_files_stage.sql
│   ├── 2.Ingest.sql
│   ├── 2.1.Update_Batch_Counts.sql
│   ├── 2.2.Validate_Batch_Load.sql
│   ├── 3.Transform.sql
│   ├── 4.Business_Rules.sql
│   └── 5.Load_Gold.sql
│   └── 6.End_Batch_Success.sql
│
├── scripts/
│   └── run_pipeline.ps1
│
├── docs/
│   └── architecture.md
│
└── sample_data/
    └── README.md
```

## Pipeline Flow
1. Environment Preparation

Creates the required Snowflake objects such as databases, schemas, stages, file formats, and tables.

2. Batch Initialization

Creates a new batch record to track the pipeline execution.

Each run receives a unique batch identifier that is used to monitor row counts, status, and execution metadata.

3. File Upload

Uploads local files into a Snowflake internal stage.

Supported file types:

CSV
TXT
XML
JSON

Files can be organized by batch, source system, file type, or business domain.

4. Raw Data Ingestion

Loads staged files into Bronze tables using a raw/semi-structured strategy.

The ingestion process stores:

Raw file content
File name
File row number
Load timestamp
Batch identifier
5. Batch Metrics Update

Updates the batch control table with row counts by file type:

CSV rows
TXT rows
XML rows
JSON rows
Total rows
6. Load Validation

Validates that the current batch loaded data successfully.

If the batch does not contain valid records, the process can be stopped before running downstream transformations.

7. Data Transformation

Applies parsing and transformation logic to convert raw/semi-structured data into curated datasets.

Examples of transformation logic may include:

Parsing CSV raw lines into columns
Extracting fields from JSON
Parsing XML elements
Standardizing TXT content
Applying data type conversions
Creating business-ready attributes

8. Business Rules

Applies business logic, enrichment rules, mappings, or derived calculations.

9. Gold Layer Load

Loads the final curated and enriched data into the Gold layer for reporting, analytics, or downstream consumption.

## How to Run the Pipeline

From PowerShell, navigate to the project folder:

```cd path\to\project```

Run the pipeline script:

```powershell -ExecutionPolicy Bypass -File .\scripts\run_pipeline.ps1```

The PowerShell script executes the SQL files in order using SnowSQL.

## SnowSQL Connection

The pipeline uses a named SnowSQL connection.

Example:

```snowsql -c my_connection -f "SQL/0.Prep_Env.sql"```

The connection should be configured locally in the SnowSQL configuration file.


## Snowflake Git Integration

Snowflake can connect to a Git repository and fetch branches, tags, and commits.

The following commands are neccesary to connect snwoflake with GitHub and bring all branchoes onto snowflake.

```
CREATE GIT REPOSITORY PROJECT_SEMESTRUCTURED.BRONZE.Snwoflake_SME 
	ORIGIN = 'https://github.com/oscarduque9713/Snwoflake_SME' 
	API_INTEGRATION = 'GITHUB_PUBLIC_API_INTEGRATION';


SHOW GIT REPOSITORIES;

SHOW GIT BRANCHES IN GIT REPOSITORY Snwoflake_SME;

ALTER GIT REPOSITORY PROJECT_SEMESTRUCTURED.BRONZE.Snwoflake_SME FETCH;

LIST @PROJECT_SEMESTRUCTURED.BRONZE.SNWOFLAKE_SME/branches/Developer/;
```

Execute a SQL file:

```EXECUTE IMMEDIATE FROM @PROJECT_SEMESTRUCTURED.BRONZE.SNWOFLAKE_SME/branches/Developer/SQL/0.Prep_Env.sql;```

Important note:

Scripts that upload local files using PUT file://... must be executed from the local machine using SnowSQL or Snowflake CLI, because Snowflake cannot access local files directly from a Git repository.

## Author

Oscar Eduardo Duque Ospina
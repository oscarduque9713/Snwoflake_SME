# Snowflake Data Ingestion Pipeline

This project implements a data ingestion pipeline using **Snowflake**, **SnowSQL**, **PowerShell**, and **GitHub**.

The pipeline loads local files into a Snowflake internal stage, ingests raw data into a Bronze layer, applies transformations and business rules, and prepares enriched data for a Gold layer.

---

## Project Overview

The main goal of this project is to build a repeatable and auditable data pipeline using Snowflake and command-line automation.

The pipeline covers:

- Local file ingestion
- Uploading files to a Snowflake internal stage
- Batch-based processing
- Raw data storage
- Metadata capture
- Transformation logic
- Business rule application
- Final curated output
- Git-based version control

---

## Technologies Used

- Snowflake
- SnowSQL
- PowerShell
- SQL
- Git
- GitHub
- Snowflake Internal Stages
- Snowflake Git Repository

---

## Architecture

```text
Local Files
   |
   v
PowerShell / SnowSQL
   |
   v
Snowflake Internal Stage
   |
   v
Bronze Layer
   |
   v
Transformation Layer
   |
   v
Gold Layer
   |
   v
Batch Control / Audit Table
```

```
snowflake-data-pipeline/
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

Files can be organized by batch, source system, file type, or business domain.

4. Raw Data Ingestion

Loads staged files into raw tables.

The ingestion layer stores the original content and technical metadata such as:

File name
File row number
Load timestamp
Batch identifier
5. Batch Metrics Update

Updates the batch control table with row counts and processing metrics.

Typical metrics include:

Number of CSV rows loaded
Number of JSON rows loaded
Number of XML or TXT rows loaded
Total rows loaded
6. Load Validation

Validates that the current batch loaded data successfully.

If the batch does not contain valid records, the process can be stopped before running downstream transformations.

7. Data Transformation

Applies transformation logic to convert raw data into structured and curated datasets.

8. Business Rules

Applies business logic, enrichment rules, mappings, or derived calculations.

9. Gold Layer Load

Loads the final curated and enriched data into the Gold layer for reporting, analytics, or downstream consumption.
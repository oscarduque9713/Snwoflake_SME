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
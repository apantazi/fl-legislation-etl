# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an ETL pipeline for the **Legislative Compass** dashboard. It extracts Florida legislative voting data from LegiScan and census/demographics data from Dave's Redistricting App, transforms it through three database layers (raw → processed → app), and loads it into a PostgreSQL database.

## Common Commands

### Running the ETL Pipeline

1. Start RStudio and open `scripts/etl_main.R`
2. Run the script - you will be prompted to select:
   - Environment: `staging` (port 5433) or `production` (port 5432)
   - Whether to use Docker for PostgreSQL management

### Initial Setup

```r
# Install required packages (run once)
source("scripts/00_install_packages.R")
```

### Configuration

Copy `config.template.yml` to `config.yml` and add:
- `api_key_legiscan`: Your LegiScan API key (free single-state key from legiscan.com)
- `postgres_pwd`: Your PostgreSQL password

### Python Scraper (for legislator IDs)

```bash
# Requires playwright and beautifulsoup4
python scripts/scrape_legislature.py
```

## Architecture

### Three-Layer Database Design

| Layer | Prefix | Purpose |
|-------|--------|---------|
| **Raw** | `t_`, `user_` | Data parsed directly from sources (LegiScan JSON, CSVs) |
| **Processed** | `p_`, `hist_`, `jct_` | Cleaned, organized data with calculated fields |
| **App** | `qry_`, `app_`, `viz_`, `qa_` | Data prepared for web apps and visualizations |

### ETL Script Sequence

The main script `etl_main.R` executes these in order:

1. `01_request_api_legiscan.R` - Fetch data from LegiScan API
2. `02a_raw_parse_legiscan.R` - Parse LegiScan JSON
3. `02b_raw_read_csvs.R` - Read CSV files (Dave's Redistricting App, user data)
4. `02z_raw_load.R` - Load raw layer to Postgres
5. `03a_process.R` - Transform and calculate metrics
6. `03z_process_load.R` - Load processed layer to Postgres
7. `04a_app_settings.R` - Apply app settings
8. `04b_app_prep.R` - Prepare app data
9. `04z_app_load.R` - Export to Postgres and CSV
10. `qa_checks.R` - Quality assurance (writes to `qa/qa_checks.log`)

### Key Data Tables

- `t_bills`, `t_roll_calls`, `t_legislator_votes`, `t_legislator_sessions` - Raw LegiScan data
- `p_legislators`, `p_roll_calls`, `p_legislator_votes` - Processed with partisan vote classification
- `app01_vote_patterns.csv`, `app03_district_context.csv` - App layer exports in `data-app/`

### Key Metrics

- **Party loyalty**: Legislator's tendency to vote with their party (1=most loyal, 0=least loyal)
- **Partisan lean**: District electorate's partisanship (D vs R percentage point difference)
- **Party unity**: Roll-call-level measure of voting alignment within parties

### Database Connections

- Staging: `fl_leg_staging` on port 5433 (Docker container: `compass_staging`)
- Production: `fl_leg_votes` on port 5432 (Docker container: `compass_postgres`)

## External Dependencies

- LegiScan API for legislative data
- Dave's Redistricting App for district demographics/elections
- Google Sheets for user-entered bill categories and legislator events

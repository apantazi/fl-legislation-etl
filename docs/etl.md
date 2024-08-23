# Running the ETL Script
8/23/24

The following instructions describe the process of running the ETL scripts. The last step includes CSV export(s) to [data-app](data-app/), to facilitate creation of apps and data visualizations for those who don't want to interact with our Postgres database.

### Initial Setup
Prior to running these scripts, you'll need to:
* acquire a free single-state [API key from LegiScan](https://legiscan.com/legiscan) 
* set up two local Docker containers and Postgres databases- one for staging and one for production. See also [ETL and Web App Development procedures](https://docs.google.com/document/d/1MyGv2wjyfbNeb2WDrN0YXwZ2sJWINx0Oii3WKnUMDkA/edit) (MORE GUIDANCE NEEDED HERE)
* copy [config.template.yml](../config.template.yml) into config.yml, and store your API key and Postgres database passwords in this local file

### Developing the pipeline.
See [ETL and Web App Development procedures](https://docs.google.com/document/d/1MyGv2wjyfbNeb2WDrN0YXwZ2sJWINx0Oii3WKnUMDkA/edit) for more guidance:
1) Switch to the appropriate branch (feature/*, develop, staging, production)
2) Configure setting_env in [functions_database.R](../scripts/functions_database.R) to specify whether you're developing the staging or ETL pipeline

### Running the pipeline
1) Configure setting_env in [functions_database.R](../scripts/functions_database.R) to specify whether you're developing the staging or ETL pipeline
2) run [scripts/etl_main.R](../scripts/etl_main.R), which calls the following scripts in sequence:

 | script                   | description              |
|--------------------------|--------------------------|
| [functions_database.R](../scripts/functions_database.R)|scripts to connect to Postgres, write tables, and test inputs | 
| [01_request_api_legiscan.R](../scripts/01_request_api_legiscan.R)|requests data from LegiScan via API |
| [02a_raw_parse_legiscan.R](../scripts/02a_raw_parse_legiscan.R)|parses LegiScan JSON data|
| [02b_raw_read_csvs.R](../scripts/02b_raw_read_csvs.R)|reads csv files including user-entered data and exported Dave's Redistricting data|
| [02z_raw_load.R](../scripts/02z_raw_load.R)|saves all acquired data into Postgres as the raw layer|
| [03a_process.R](../scripts/03a_process.R)|organizes and adds calculations to parsed and user-entered data|
| [03z_process_load.R](../scripts/03z_process_load.R)|writes organized data frames (processed layer) to Postgres|
| [04a_app_settings.R](../scripts/04a_app_settings.R)|creates views based on settings|
| [04b_app_prep.R](../scripts/04b_app_prep.R)|prepares and filters data for web apps|
| [04z_app_load.R](../scripts/04z_app_load.R)|writes app data to Postgres, and exports data to CSV|
| [qa_checks.R](../scripts/qa_checks.R)|Reviews raw and processed data frames for missing records and other anomalies|
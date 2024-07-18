# Running the ETL Script
7/15/24

The following instructions describe the process of running the ETL scripts. The last step includes CSV export(s) to [data-app](data-app/), to facilitate app development for those who don't want to interact with our Postgres database.

To run these scripts, you'll need to know two passwords:
* password for the Postgres database
* API key for Legiscan

 Prior to running the ETL scripts, you'll need to set up and open a Docker container with the database. Then, from the command line you'll need to start the Docker container, open an interactive postgres terminal, and start the database fl_leg_votes.


 ```
 docker start my_postgres
 docker exec -it my_postgres bash
 psql -U postgres -d fl_leg_votes
```

 Then, you'll need to run [scripts/etl_main.R](scripts/etl_main.R), which calls the following scripts in sequence:

 | script                   | description              |
|--------------------------|--------------------------|
| [functions_database.R](scripts/functions_database.R)|scripts to connect to Postgres, write tables, and test inputs | 
| [01_request_api_legiscan.R](scripts/01_request_api_legiscan.R)|requests data from LegiScan via API |
| [02a_raw_parse_legiscan.R](scripts/02a_raw_parse_legiscan.R)|parses LegiScan JSON data|
| [02b_raw_read_csvs.R](scripts/02b_raw_read_csvs.R)|reads csv files including user-entered data and exported Dave's Redistricting data|
| [02z_raw_load.R](scripts/02z_raw_load.R)|saves all acquired data into Postgres as the raw layer|
| [03a_process.R](scripts/03a_process.R)|organizes and adds calculations to parsed and user-entered data|
| [03z_process_load.R](scripts/03z_process_load.R)|writes organized data frames (processed layer) to Postgres|
| [04a_app_settings.R](scripts/04a_app_settings.R)|creates views based on settings|
| [04b_app_prep.R](scripts/04b_app_prep.R)|prepares and filters data for web apps|
| [04z_app_load.R](scripts/04z_app_load.R)|writes app data to Postgres, and exports data to CSV|
| [qa_checks.R](scripts/qa_checks.R)|Reviews raw and processed data frames for missing records and other anomalies|
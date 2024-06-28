# Florida Legislative Voting Database
6/27/24
 This repo creates a data pipeline supporting the [Jacksonville Tributary's](https://jaxtrib.org/) legislative voting dashboard (see [prior version of demo app](https://shiny.jaxtrib.org/)). The ETL scripts are adapted from an [R script originally created by apantazi](https://github.com/apantazi/legislator_dashboard/blob/main/pull-in-process-all-legiscan.R). My intent is to make it easier for others to maintain/develop the app, quickly adapt it to different jurisdictions, and create new apps from the same processed data using any programming language.
 
 Part of this work has involved reshaping nested lists (from API-acquired JSONs) into relational database format, which enables storage in Postgres as well as easy export to csv or (theoretically) SQLite. The Postgres database is currently managed locally on my Windows machine, with intent to deploy to the Tributary's Azure platform.

 See also my repo for front-end application development **[legislator dashboard](https://github.com/reliablerascal/fl-legislation-app-postgres)**.

## Overview of the database
<img src="./diagrams/etl-schematic.png" width=100%>

Note that the database currently integrates data from only LegiScan, supporting a single Shiny app.

|Layer|Purpose|
|---|---|
|**Raw**|Raw data retrieved via API and parsed into tables.|
|**Processed**|Cleaned and organized data including calculated fields. My intent is to also align data definitions between similar formats (e.g. LegiScan and LegiStar).|
|**Application**|Data prepared for specific applications such as the Jacksonville Tributary's legislator dashboard (see [previous version](https://shiny.jaxtrib.org/)).|

ETL in the context of the legislative dashboard database means:
* **Extract** data via API from Legiscan, and parse it
* **Transform** data by cleaning, organizing, calculating, and aligning data so it's more useful and easier to understand
* **Load** the transformed data into the Postgres database



<br><br>
## Naming Conventions
Clear and consistent naming conventions are essential to code maintainability. Following are naming conventions used within this data pipline. Following are naming conventions for dataframes in the R script.

|Prefix|Saved in<br>Schema|Purpose|
|---|---|---|
|t_|raw|**T**ables of raw data kept intact in their original source format.|
|calc_|Performs intermediate **calc**ulations (e.g., partisanship metrics).|---|
|p_|proc|**P**rocessed data, which has been cleaned and organized from original tables. This includes newly introduced calculated fields.|
|app_|app|**App**lication data, which has been filtered and organized from processed data. It's intended to support specific web applications but could also support data visualizations.|



<br><br>
## Data Dictionaries by Schema (work in progress)
The following data dictionaries describe all data elements in each database table. This is intended to help ETL developers align new data sources to a common data model, and help app developers understand the data elements they can use.

* [raw_legiscan](diagrams/data-dictionary-raw-legiscan.xlsx)
* proc
* app_voting_patterns



<br><br>
## Running the ETL Script
The following instructions describe the process of running the ETL scripts. If it's useful, I may develop a simple SQLite and/or folder-of-csvs exports to facilitate app development without relying on our Postgres database.

To run these scripts, you'll need to know two passwords:
* password for the Postgres database
* API key for Legiscan

 Prior to running the ETL scripts, you'll need to set up and open a Docker container with the database. Then, from the command line you'll need to start the Docker container, open an interactive postgres terminal, and start the database fl_leg_votes.


 ```
 docker start my_postgres
 docker exec -it my_postgres
 psql -U postgres -d fl_leg_votes
```

 Then, you'll need to run etl_main.R, which calls the following scripts in sequence:

 | script                   | description              |
|--------------------------|--------------------------|
| [01_request_api_legiscan.R](scripts/01_request_api_legiscan.R)|requests data from LegiScan via API |
| [02_parse_legiscan.R](scripts/02_parse_legiscan.R)|parses LegiScan JSON data |
| [03_load_raw_tables.R](scripts/03_load_raw_tables.R)|saves parsed LegiScan data into Postgres as the View layer|
| [04_transform.R](scripts/04_transform.R)|prepares parsed data for deployment to the web app |
| [05_load_views_and_app_layer.R](scripts/05_load_views_and_app_layer.R)|writes app queries to Postgres |
| [00_install_packages.R](scripts/00_install_packages.R)|installation script which should later be repackaged as requirements |
| [functions_database.R](scripts/functions_database.R)|scripts to connect to Postgres, write tables, and test inputs |



<br><br>
## Development workplan
Following are some key goals for developing this data pipeline.
* Incorporate LegiStar voting data for Jacksonville and align this with state data, so it can be visualized with existing web apps
* Incorporate district data (e.g. census demographics and partisan leanings of the electorate) to provide context
* Develop automated CSV and SQLite exports to support non-Postgres access for data visualization and web app development
* Automate API requests via Github actions to keep legislative voting data up-to-date
* Deploy Postgres app on Azure to enable online connectivity
# Florida Legislative Voting Database
6/27/24
 This repo creates a data pipeline for Florida legislative votes. The database is currently managed locally on my Windows machine, with intent to deploy to Azure in support of the Jacksonville Tributary's [Legislative Voting dashboard](https://shiny.jaxtrib.org/).

## Overview of the database
<img src="./diagrams/etl-schematic.png" width=100%>

|Layer|Purpose|
|---|---|
|**Raw**|Raw data retrieved via API and parsed into tables.|
|**Processed**|Cleaned and organized data including calculated fields. My intent is to also align data definitions between similar formats (e.g. LegiScan and LegiStar).|
|**Application**|Data prepared for specific applications such as the Jacksonville Tributary's legislator dashboard (see [previous version](https://shiny.jaxtrib.org/)).|

ETL in the context of the legislative dashboard database means:
* **Extract** data via API from Legiscan, and parse it
* **Transform** data by cleaning, organizing, calculating, and aligning data so it's more useful and easier to understand
* **Load** the transformed data into the Postgres database

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
| 01_request_api_legiscan.R|requests data from LegiScan via API |
| 02_parse_legiscan.R      |parses LegiScan JSON data |
| 03_load_views.R      |saves parsed LegiScan data into Postgres as the View layer|
| 04_transform.R       |prepares parsed data for deployment to the web app |
| 05_load_app_layer.R      |writes app queries to Postgres |
| 00_install_packages.R      |installation script which should later be repackaged as requirements |
| functions_database.R      |scripts to connect to Postgres, write tables, and test inputs |

## Development workplan
* Incorporate voting data for cities (e.g. Legistar data) and district data for context (e.g. Census data) 
* Develop automated CSV and SQLite exports to support non-Postgres data access options
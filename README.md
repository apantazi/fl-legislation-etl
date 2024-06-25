# Florida Legislative Voting Database
6/12/14
 This repo creates a data pipeline for Florida legislative votes. The database is currently managed locally on my Windows machine, with intent to deploy to Azure in support of the Jacksonville Tributary's [Legislative Voting dashboard](https://shiny.jaxtrib.org/).

 ## Running the ETL Script
ETL in the context of the legislative dashboard database is:
* Extract: Retrieve data via API from Legiscan (and soon to be additional sources)
* Transform: A.k.a. "mutate" in R, organize data and add calculations so it's more useful and easier to understand
* Load: Writing the transformed data into the Postgres database

 You'll need to know the Postgres database password to complete this write operation. Prior to running the script, you also need to start the database server:


 ```
 docker start my_postgres
 docker exec -it my_postgres psql -U postgres -d fl_leg_votes
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

 ## Debugging Notes
 This repo is currently being debugged. Some notes:

**parse-data-legiscan.R**  
hack to ensure two-year session (e.g. 2023-2024, vs. 2023-2023). not sure why i had to do this
bill_vote_all$session <- bill_vote_all$session_string

**write-to-postgres.R**  
removed some columns from heatmap_data- e.g. lists and factors, which aren't intended for Postgres

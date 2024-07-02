# Florida Legislative Voting Database
7/1/24

 This repo creates a data pipeline supporting the ongoing development of the [Jacksonville Tributary's](https://jaxtrib.org/) legislative voting dashboard (see [prior version of demo app](https://shiny.jaxtrib.org/)). The purpose of the dashboard is to highlight voting patterns of Florida legislators, which can help answer questions about:
* actual voting records of legislators as a tangible measure of their political leanings (compared to campaign rhetoric)
* partisan/party-line voting
* disparities between legislators and the demographics/political leanings of the districts they represent

My role specific to the Tributary's project is to develop the [Shiny app and data pipeline originally created by apantazi](https://github.com/apantazi/legislator_dashboard/blob/main/pull-in-process-all-legiscan.R) to improve its maintainability and scalability. I'm improving data integrity and reliability by re-shaping nested lists (from API-acquired JSONs and R scripts) into relational database format and creating curated views of processed data. My intent is to make it easier for web app developers and data visualization specialists to:
* adapt existing reporting tools to different jurisdictions besides the state of Florida- for example, Jacksonville via LegiStar data
* create new visualizations using any programming language (not just R) and connecting via Postgres/SQL or loading CSV files
* highlight contextual data (e.g. demographics and district electoral preferences) related to voting records
* have greater control over the presentation of data by handling app logic such as sorting, hover text formatting, and filtering (i.e. I'm separating this logic from the ETL pipeline)

## Overview of the database
<img src="./docs/etl-schematic.png" width=100%>

Note that the database currently integrates data from only LegiScan, supporting a single Shiny app.

|Layer|Purpose|
|---|---|
|**Raw**|Raw data retrieved as JSON via API, then parsed into tables. Data elements are retained without modification.|
|**Processed**|Cleaned and organized data including calculated fields. My intent is to also to align and integrate data between similar formats (e.g. LegiScan and LegiStar).|
|**Application**|Data prepared for specific applications such as the legislator dashboard.|

ETL in the context of this legislative dashboard database means:
* **Extract** data via API from Legiscan, then parse it into tables in the raw layer.
* **Transform** data by cleaning, organizing, calculating, and aligning data so it's more useful and easier to understand
* **Load** the transformed data into the Postgres database

<br>

## Raw Layer
### Raw_LegiScan schema ###
* [Data Dictionary for raw_legiscan](docs/data-dictionary-raw-legiscan.xlsx)

This database acquires only a portion of LegiScan data (see LegiScan's [entity relationship diagram](https://api.legiscan.com/dl/Database_ERD.png) and [API user manual](https://legiscan.com/misc/LegiScan_API_User_Manual.pdf) for info on all available data). LegiScan's data is provided as three folders of JSON files- votes (which are really roll calls, with individual votes nested within), people (i.e. legislators), and bills (with lots of related info nested within).

The raw data schema of this database stores data parsed from the original JSON files but otherwise unaltered from the source format. It's organized as follows, with one row of data per unique combination of the primary key listed below.

|Table|Primary Key|Description and Notes|
|---|---|---|
|t_bills|bill_id|One record per bill. Note that bills can persist across multiple legislative sessions.|
|t_legislator_sessions|person_id, session|Because legislators can change roles (i.e. move from the House to the Senate), one record is tracked per legislator per legislative session.|
|t_roll_calls|roll_call_id|One record per roll call. Includes summary data on roll calls (e.g. how many voted aye vs. nay, etc.)|
|t_legislator_votes|person_id, roll_call_id|One record per legislator per roll call vote. Including data on how the legislator voted (aye, nay, absent, no vote).|

### Other raw data schema to be developed
* raw_demographics - block-level census data from Census and American Community Survey
* raw_election_results - election results by district
* raw_legistar - legislative voting data acquired from LegiStar API

<br>

## Processed Layer (work in progress)
The processed layer tracks data transformed from LegiScan, but is intended to eventually align data from multiple sources. Following is a blueprint of this layer.

|Table|Primary Key|Origin Data Sources|Notes|
|---|---|---|---|
|p_bills|bill_id|LegiScan (state), LegiStar (cities)|Cleans up and aligns bill data from LegiScan and LegiStar|
|p_legislator_sessions|person_id,<br>session_year|LegiScan (state), LegiStar (cities)|Session_year is part of key because legislators can change roles (i.e. move from the House to the Senate) over time|
|p_roll_calls|roll_call_id|LegiScan (state), LegiStar (cities)|Includes summary data on roll calls (e.g. how many voted aye vs. nay, etc.)|
|p_legislator_votes|person_id,<br>roll_call_id|LegiScan (state), LegiStar (cities)|Includes data on how the legislator voted (aye, nay, absent, no vote) and calculated partisan metrics (with their party, against their party, against both parties, etc.).|
|p_legislators|person_id|Summary info about legislators, which arbitrarily takes the first record for each|
|p_districts|district_id,<br>year|Census demographics, electoral results, etc.|One record per legislative district (Senate, House, City Council, etc.)|
|jct_bill_categories|bill_id, category|Manual data entry (for now)|Includes data on how the legislator voted (aye, nay, absent, no vote) and calculated partisan metrics (with their party, against their party, against both parties, etc.).|


<br>

## App Layer
This repo currently supports the legislative voting patterns Shiny app (see [prior version of demo app](https://shiny.jaxtrib.org/)).

Data is prepared to facilitate non-Shiny app development, and includes three types of fields:
* plot data (x = legislator_name, y= roll_call_id, values = partisan metric)
* context data (bill number, title, url, and description; roll call description and date, roll call vote and overall vote summary) currently rendered as a pop-up box when hovering over individual legislator votes
* app filter data (party, chamber, session year, plus a binary inclusion flag for Democrat vs. Republican roll calls)

The two key metrics in this data are as follows:
* **partisan_metric** describes each legislator vote by partisanship
    * 0 = vote with party
    * 1 = vote against both parties
    * 2 = vote against party
* **mean_partisan_metric** describes the legislators' average partisan_metric across all their votes on contested bills, where lower numbers (0) indicate voting in lock-step with their party

See [Data Dictionary for app_voting_patterns](docs/data-dictionary-app-voting-patterns.csv).


<br><br>

# Guide to the Repository
Following is an overview of files in this repository:

* **[data-app](data-app/)**- data supporting web applications, in csv format
* **data-raw**- raw data in JSON format, as bulk downloaded from LegiScan's API
* **[docs](docs/)**- data dictionaries and diagrams
* **[notebooks](notebooks/)**- API exploration using Jupyter Notebook and Python
* **[scripts](scripts/)**- ETL scripts

## Naming Conventions
Clear and consistent naming conventions are essential to code maintainability. Following are naming conventions used within this data pipeline.

|Prefix|Saved in Schema|Purpose|
|---|---|---|
|t_|raw|**T**ables of raw data kept intact in their original source format.|
|calc_|---|Performs intermediate **calc**ulations (e.g., partisanship metrics).|
|p_|proc|**P**rocessed data, which has been cleaned and organized from original tables. This includes newly-introduced calculated fields.|
|jct_|proc|**J**unction table, for example jct_bill_categories cross-references which categories (e.g. education, environment) each bill belongs to.|
|app_|app|**App**lication data, which has been filtered and organized from processed data. It's intended to support specific web applications but could also support data visualizations.|

## Running the ETL Script
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
| [01_request_api_legiscan.R](scripts/01_request_api_legiscan.R)|requests data from LegiScan via API |
| [02_parse_legiscan.R](scripts/02_parse_legiscan.R)|parses LegiScan JSON data |
| [02z_load_raw.R](scripts/02z_load_raw.R)|saves parsed LegiScan data into Postgres as the raw layer|
| [03_transform.R](scripts/03_transform.R)|organizes parsed data and adds calculations, then prepares data for web apps |
| [03a_categorize_bills.R](scripts/03a_categorize_bills.R)|placeholder for categorizing bills in a junction table |
| [03z_load_processed.R](scripts/03z_load_processed.R)|writes organized data frames (processed layer) to Postgres |
| [04_prep_app.R](scripts/04_prep_app.R)|prepares and filters data for web apps |
| [04z_load_app.R](scripts/04z_load_app.R)|writes app data to Postgres, and exports data to CSV |
| [00_install_packages.R](scripts/00_install_packages.R)|installation script which should later be repackaged as requirements |
| [functions_database.R](scripts/functions_database.R)|scripts to connect to Postgres, write tables, and test inputs |

<br><br>
# Development workplan
Following are some key goals for developing this data pipeline.
* Incorporate LegiStar voting data for Jacksonville and align this with state data, so it can be visualized with existing web apps
* Incorporate district data (e.g. census demographics and partisan leanings of the electorate) to provide context
* Automate API requests via Github actions to keep legislative voting data up-to-date
* Deploy Postgres app on Azure to enable online connectivity
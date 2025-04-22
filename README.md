# Florida Legislative Voting Database
8/23/24

## Documentation Table of Contents
Detailed documentation is provided in the following sections:
- **Overview**- this page
- **[Database Architecture](docs/db_architecture.md)**- technical overview of data structures within the database's three layers (raw, processed, app)
- **[Web App and Data Visualization Guide](docs/app_dev_guide.md)**- specific details about data prepared for web applications and ad-hoc data visualizations (work in progress)
- **[ETL Script](docs/etl.md)**- overview of the ETL script and how to run it

### External Resources (Google Docs)
* [Procedures for ETL and Web App Development](https://docs.google.com/document/d/1MyGv2wjyfbNeb2WDrN0YXwZ2sJWINx0Oii3WKnUMDkA/edit?usp=drive_link)
* [Wishlist and Developer Notes](https://docs.google.com/document/d/1OGiJH7B_0j3B38gEtgt_FDhkxzL84ZtGistdup2yYHI/edit?usp=drive_link)
* [Development Workplan](https://docs.google.com/document/d/1_NQg5lxmVDvXwF4sC3GRQvMK21GZHCJhVurMgibe0eI/edit?usp=sharing)


<br><br>

## Project Overview
The Jacksonville Tributary's **[Legislative Compass](https://data.jaxtrib.org/dev/legislative-compass)** analyzes and visualizes roll call voting patterns of Florida state legislators. Key metrics include legislators' **party loyalty** and congressional district electorates' **partisan lean** and demographics. This dashboard is intended to support development of a voter guide, reporting on party polarization, and disparities between legislators and the districts they represent.

This repo contains a data pipeline which:
* extracts [legislative voting data from LegiScan](https://legiscan.com/FL/datasets), and census and demographics data from [Daves Redistricting Maps](https://davesredistricting.org/maps#state::FL).
* transforms data by organizing and integrating data sources
* [reviews data quality](qa/qa_checks.log) to identify and explain anomalies
* loads data into a Postgres database while exporting key tables as [.csv files](data-app/)
* prepares data for use by the legislator dashboard web app (see [web app repo](https://github.com/reliablerascal/fl-legislation-app-postgres)):
    * [production web app](https://data.jaxtrib.org/dev/legislative-compass)
    * [staging web app](https://mockingbird.shinyapps.io/fl-leg-staging/)- currently hosted on Rob's ShinyApps.io account, but may need a new home

### Project Status
This project is a work in progress, with the following work underway as of August 2024:
* superuser journalists at partner outlets review and beta test
* publish the web app for public use
* document data definitions for web app data sources

See [changelog.md](docs/changelog.md) for info on most recent updates.

### Key Terminology
Following are definitions of key terminology used throughout this project:
* **Party loyalty** is a legislator’s tendency to vote with or against their party. 1 = most loyal, 0 = least loyal. 
* **Partisan lean** is a legislative electorate’s partisanship as measured by percentage point difference between voting for Democrats vs. Republicans.
* **Party unity** is a roll-call-level measure, by party, of how unified roll calls are *within* parties

```
    (# votes aligned with legislator's own party)
    -----------------------------------------
    (# votes aligned with either one party or the other)
```

Calculations for **party loyalty** are based on classifying and weighing each present (yea or nay) vote. Each vote is filed into one of six categories.
|vote type| descriptino| loyalty weight
|---|---|---|
|**party line bipartisan** | voting with the same party's majority in roll calls supported by both parties | N/A |
|**party line partisan** | voting with the same party's majority in roll calls split on party lines | 1 |
|**cross party** | voting against the same party's majority in roll calls split on party lines | 0 |
|**against both parties** | voting against both party majorities | N/A |
|**absent nv** | absent or no vote | N/A |
|**other** | legislator's party is split evenly, etc. | N/A |

<br><br>

## Guide to this Repository
Following is an overview of files in this repository:

* **[data-app](data-app/)**- data supporting web applications, in csv format
* **[data-raw](data-raw/)**- raw data in JSON format, as bulk downloaded from LegiScan's API
* **[docs](docs/)**- data dictionaries, diagrams, and documentation
* **[docs](notebooks/)**- data explorations in Python, informing development of this pipeline
* **[qa](qa/)**- includes [quality assurance log](https://github.com/reliablerascal/fl-legislation-etl/blob/main/qa/qa_checks.log) and tables of data anomalies. See QA script at [scripts/qa_checks.R](scripts/qa_checks.R).
* **[scripts](scripts/)**- ETL scripts


<br><br>

## Appendix A- ETL Schematic
<img src="docs/etl-schematic.png" width = 800><br>

*Figure 1: Overview of ETL pipeline, as described in [Database Architecture](docs/db_architecture.md)*
<br><br>

## Appendix B- Sample Visualizations
For more info about all apps and visualizations, see [Web App and Data Visualization Guide](docs/app_dev_guide.md).

<div align = "left">

### Voting Patterns Dashboard

<div style = "padding-left: 20px;">
<img src="viz/screenshot_voting_patterns.png" width = 800 style="border: 2px solid black;">

*Figure 2: Dashboard view of **Voting Patterns** web app of Senate Democrats during 2024 legislative session*
</div>

<br><br>

### District Context Web App
<div style = "padding-left: 20px;">
<img src="viz/screenshot_district_context.png" width = 800 style="border: 2px solid black;">

*Figure 3: **District Context** web app comparing a legislator's voting record with their electorate's partisan leaning*
</div>

<br><br>

<!---
### Ad-Hoc Data Visualization from District Context Data
<div style = " padding-left: 20px;">
<img src="viz/viz_leg_v_electorate_dem_senate.png" width = 800 style="border: 2px solid black;">

*Figure 4: Ad-hoc Senate Democrat party loyalty vs. district electorate visualization, based on data from the **District Context** web app*
</div>
--->

</div>




```
fl-legislation-etl-
├─ .git
│  ├─ COMMIT_EDITMSG
│  ├─ config
│  ├─ description
│  ├─ HEAD
│  ├─ hooks
│  │  ├─ applypatch-msg.sample
│  │  ├─ commit-msg.sample
│  │  ├─ fsmonitor-watchman.sample
│  │  ├─ post-update.sample
│  │  ├─ pre-applypatch.sample
│  │  ├─ pre-commit.sample
│  │  ├─ pre-merge-commit.sample
│  │  ├─ pre-push.sample
│  │  ├─ pre-rebase.sample
│  │  ├─ pre-receive.sample
│  │  ├─ prepare-commit-msg.sample
│  │  ├─ push-to-checkout.sample
│  │  └─ update.sample
│  ├─ index
│  ├─ info
│  │  └─ exclude
│  ├─ logs
│  │  ├─ HEAD
│  │  └─ refs
│  │     ├─ heads
│  │     │  └─ main
│  │     └─ remotes
│  │        └─ origin
│  │           └─ HEAD
│  ├─ objects
│  │  ├─ 00
│  │  │  └─ 58971d761855168ebc93d8e928b77f4f1da962
│  │  ├─ 0e
│  │  │  ├─ 516676a48d165eac6f8cd50eea98d3f3df8b0c
│  │  │  └─ 846e43577395486738f8705d2a299c1778a62c
│  │  ├─ 0f
│  │  │  └─ 100e25f6f15f4b53aaf02216bbc83f6ab46dc2
│  │  ├─ 12
│  │  │  └─ 74f85eefb4091c7bdf7ab6247ae89eb65ecaf8
│  │  ├─ 17
│  │  │  └─ 3fe0ef216ea1b15417bd1c7f5d9627614664de
│  │  ├─ 26
│  │  │  └─ b57490486beef5c3e5e13fd67596e17e71afb8
│  │  ├─ 32
│  │  │  └─ 93b6a1c445ebee09fbf0bf356d15f1f758c061
│  │  ├─ 33
│  │  │  └─ a3ca39343d5413699a2ff6928c82d45cdcf2ac
│  │  ├─ 3d
│  │  │  └─ e663bb60de4fc671a8106f347bf5dfdd29980b
│  │  ├─ 3f
│  │  │  └─ 36ae03515f49a1ffa9c30a101cc5abdbe2785b
│  │  ├─ 4b
│  │  │  └─ c14b86f31d754d2f37ca6d9da3e8bf52c3ceba
│  │  ├─ 83
│  │  │  └─ 0339d83ed5982e26d9cac45dea40edfb670e9a
│  │  ├─ 8c
│  │  │  └─ 504e05af43724875962553c7b3bc45b6709dc0
│  │  ├─ 8d
│  │  │  └─ 6ac817ee8eabe26bf0e538bf3727f6369bb5f6
│  │  ├─ 8e
│  │  │  └─ 66a09f85e11338805caa89b6c9b9be31289789
│  │  ├─ 90
│  │  │  └─ ac0e267b9a63c18eab4e2c8960a5d648a2689d
│  │  ├─ 92
│  │  │  └─ ad143d908a3adf3ee1ccd81a19708641c84ff4
│  │  ├─ ac
│  │  │  └─ 8a2b7996a780faaab3bbf63c1ca02ba09bd9dc
│  │  ├─ ae
│  │  │  └─ 41d67773e9584cb57c651f190edeb72a97c9e0
│  │  ├─ af
│  │  │  └─ 401ecb9d43446f662a9048f028dfee5b17cd52
│  │  ├─ b9
│  │  │  └─ ec7c6e3b84d7f6cee3b876040188f8ae587b69
│  │  ├─ c5
│  │  │  └─ 191c7fa91a384d6b3ff6a800a6e039a2faa4a6
│  │  ├─ ca
│  │  │  └─ af320fc2c65d38de9391c0339bad022a262975
│  │  ├─ d6
│  │  │  └─ ddf65e979999e49236bc4b4ff92d370219f738
│  │  ├─ e0
│  │  │  └─ 2ebd00be251f9ff4d4e485affed4cc8cc965cd
│  │  ├─ e2
│  │  │  └─ 1d6d2adca2fed008d9bb48130727c94134ea4d
│  │  ├─ e3
│  │  │  └─ 039375d9b424cb7f2b002b2b7cc2d3104e51df
│  │  ├─ e9
│  │  │  └─ 4cad4f99d5fd708f6c311cdeb054b707f689e9
│  │  ├─ f2
│  │  │  └─ 556a0fa522c0e51db76ff6e85717824322e4ab
│  │  ├─ f8
│  │  │  └─ c07b00dbd490ddad1a3cee734f22d6173cdbfd
│  │  ├─ info
│  │  └─ pack
│  │     ├─ pack-c291221d93c5255dec746a08442446ea9758699f.idx
│  │     └─ pack-c291221d93c5255dec746a08442446ea9758699f.pack
│  ├─ packed-refs
│  └─ refs
│     ├─ heads
│     │  └─ main
│     ├─ remotes
│     │  └─ origin
│     │     └─ HEAD
│     └─ tags
├─ .gitattributes
├─ .gitignore
├─ data-app
│  ├─ app01_vote_patterns.csv
│  ├─ app03_district_context.csv
│  ├─ app03_district_context_state.csv
│  ├─ calc_elections_weighted.csv
│  ├─ qa_loyalty_ranks.csv
│  ├─ qry_bills.csv
│  ├─ qry_districts.csv
│  ├─ qry_legislators_incumbent.csv
│  ├─ qry_leg_votes.csv
│  ├─ qry_roll_calls.csv
│  ├─ qry_state_summary.csv
│  ├─ viz_partisanship.csv
│  ├─ viz_partisan_senate_d.csv
│  └─ viz_partisan_senate_r.csv
├─ docs
│  ├─ app_dev_guide.md
│  ├─ data_dictionaries
│  │  ├─ data-dictionary-app-voting-patterns.csv
│  │  ├─ data-dictionary-p_roll_calls.csv
│  │  └─ data-dictionary-raw-legiscan.xlsx
│  ├─ db_architecture.md
│  ├─ dev_workplan.md
│  ├─ etl-schematic.png
│  └─ etl.md
├─ fl-legislation-etl-.Rproj
├─ notebooks
│  ├─ .ipynb_checkpoints
│  │  └─ import-legiscan-fl-2024-checkpoint.ipynb
│  ├─ 2024_05 explore-legistar-jacksonville.ipynb
│  ├─ explore-legistar-jacksonville.ipynb
│  └─ import-legiscan-fl-2024.ipynb
├─ qa
│  ├─ qa_checks.log
│  ├─ qa_leg_votes_other.csv
│  ├─ qa_loyalty_ranks.csv
│  └─ qa_rc_party_none_present.csv
├─ README.md
├─ scripts
│  ├─ 00_install_packages.R
│  ├─ 01_request_api_legiscan.R
│  ├─ 02a_raw_parse_legiscan.R
│  ├─ 02b_raw_read_csvs.R
│  ├─ 02z_raw_load.R
│  ├─ 03a_process.R
│  ├─ 03z_process_load.R
│  ├─ 04a_app_settings.R
│  ├─ 04b_app_prep.R
│  ├─ 04z_app_load.R
│  ├─ document-architecture.R
│  ├─ etl_main.R
│  ├─ functions_database.R
│  ├─ qa_checks.R
│  └─ scrape_fl_member_ids.R
└─ viz
   ├─ screenshot_district_context.png
   ├─ screenshot_voting_patterns.png
   ├─ viz_leg_v_electorate_dem_senate.png
   ├─ viz_partisan_dem_senate.png
   └─ viz_partisan_repub_senate.png

```
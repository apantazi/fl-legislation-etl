# Change Log (alpha)

## 8-23 August 2024
### General Changes
* remove all password and key prompts. API key and postgres password stored in secure local config.yml file
* facilitate running scripts independently by setting working directory  
* normalize line endings for compatibility across OS development platforms
* scrape legislator member ids from myfloridahouse.gov, to add to raw data

### functions_database.R
* add settings to toggle database connection between staging and production

### 02a_raw_parse_legiscan.R
* add settings to configure parse date range (setting_parse_start_year, setting_parse_end_year)
    * setting_parse_start_year
    * setting_parse_end_year
* parse from folder where API requests save (fixed bug)

### 03a_process.R
* rename p_leg_vote fields for consistency with partisan_vote_type
    * vote_against_both = vote_with_neither
    * vote_cross_party = maverick_votes
    * vote_party_line = vote_with_same
* add fields to p_leg_votes to faciliate reporting (vote_against_both, vote_with_dem_majority, vote_with_gop_majority, vote_cross_party, vote_party_line, voted_at_all)

### 04_app_prep
* adapt app02_leg_activity to updated ETL while retaining existing field names
* app03_district_context now includes mfh_member_id for linking to resources from myfloridahouse.gov
* rc_mean_partisanship disaggregated by party: rc_unity_R, rc_unity_D
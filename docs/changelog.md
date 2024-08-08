# Change Log (alpha)

## 8 August 2024
### General Changes
* remove all password and key prompts. API key and postgres password stored in secure local config.yml file
* facilitate running scripts independently by setting working directory  
* normalize line endings for compatibility across OS development platforms

### 02 Parse
* add settings to configure parse date range (setting_parse_start_year, setting_parse_end_year)
    * setting_parse_start_year
    * setting_parse_end_year
* parse from folder where API requests save (fixed bug)

### 03 Transform
* rename p_leg_vote fields for consistency with partisan_vote_type
    * vote_against_both = vote_with_neither
    * vote_cross_party = maverick_votes
    * vote_party_line = vote_with_same
* add fields to p_leg_votes to faciliate reporting (vote_against_both, vote_with_dem_majority, vote_with_gop_majority, vote_cross_party, vote_party_line, voted_at_all)

### 04 App Prep
* adapt app02_leg_activity to updated ETL while retaining existing field names
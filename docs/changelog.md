# Change Log (alpha)

## 8 August 2024
### 02 Parse
* added settings to configure parse date range (setting_parse_start_year, setting_parse_end_year)
    * setting_parse_start_year
    * setting_parse_end_year
* parse from folder where API requests save (fixed bug)

### 03 Transform
* renamed p_leg_vote fields for consistency with partisan_vote_type
    * vote_against_both = vote_with_neither
    * vote_cross_party = maverick_votes
    * vote_party_line = vote_with_same
* p_leg_votes added fields for convenience (vote_against_both, vote_with_dem_majority, vote_with_gop_majority, vote_cross_party, vote_party_line, voted_at_all)

### 04 App Prep
* app02_leg_activity adapted to updated ETL while retaining existing field names
#################################
#                               #  
# 04_APP_QUERIES.R              #
#                               #
#################################
# 7/11/24
# This section added to enable configurable app settings without needing to modify code

###########################
#                         #  
# configure app settings  #
#                         #
###########################
#I may want to move this to a settings.yaml file, to separate settings from the script code

#choices include CVAP 2022 and ACS 2022
setting_demo_src <- "CVAP"
setting_demo_year <- 2022

#choices include:
# for_against- weighs 0 with party, 1 against. excludes against both
# for_against_indy. similar to for_against, but votes against both weighed as 0.5
# nominate. to be added later? https://en.wikipedia.org/wiki/NOMINATE_(scaling_method)
setting_party_loyalty <- "for_against"

#choices TBD
setting_district_lean <- "16_20_comp" #2016-2020 composite results of governor and presidential election results

###########################################
#                                         #  
# 0a) base queries supporting all apps    #
#                                         #
###########################################

# filter for incumbent legislators
qry_legislators <- p_legislators %>%
  filter(
    is.na(termination_date)
  )

# create qry_districts based on settings for prefered source of demographic data and election results
# also link to incumbent legislators
qry_districts <- hist_district_demo %>%
  filter(source_demo==setting_demo_src,year_demo==setting_demo_year) %>%
  inner_join(hist_district_elections, by=c('chamber','district_number')) %>%
  inner_join(
    qry_legislators %>%
      select (people_id, chamber, district_number),
    by = c('chamber','district_number')
  ) %>%
  rename(incumb_people_id = people_id)

qry_state_summary <- qry_districts %>%
  summarise(
    sum_white = sum(n_white, na.rm = TRUE),
    sum_hispanic = sum(n_hispanic, na.rm = TRUE),
    sum_black = sum(n_black, na.rm = TRUE),
    sum_asian = sum(n_asian, na.rm = TRUE),
    sum_pacific = sum(n_pacific, na.rm = TRUE),
    sum_native = sum(n_native, na.rm = TRUE),
    sum_total_demo = sum(n_total_demo, na.rm = TRUE),
    sum_D = sum(n_Dem, na.rm = TRUE),
    sum_R = sum(n_Rep, na.rm = TRUE),
    sum_Total_Elec = sum(n_Total_Elec, na.rm = TRUE)
  ) %>%
  mutate(
    pct_white = sum_white / sum_total_demo,
    pct_hispanic = sum_hispanic / sum_total_demo,
    pct_black = sum_black / sum_total_demo,
    pct_asian = sum_asian / sum_total_demo,
    pct_napi = (sum_pacific + sum_native) / sum_total_demo,
    pct_D = sum_D / sum_Total_Elec,
    pct_R = sum_R / sum_Total_Elec,
    source_elec = setting_district_lean
  )

qry_leg_votes <- p_legislator_votes %>%
  mutate(
    partisan_vote_weight = case_when(
      setting_party_loyalty == "for_against" ~ ifelse(partisan_vote_type == 99, NA_real_, as.numeric(partisan_vote_type)),
      setting_party_loyalty == "for_against_indy" ~ case_when(
        partisan_vote_type == 99 ~ 0.5,
        partisan_vote_type == 0 ~ 0,
        partisan_vote_type == 1 ~ 1,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "for_against_indy"
      ),
      TRUE ~ NA_real_  # Default case for unmatched setting_party_loyalty
    )
  )

# save unchanged views to qry_* upfront to avoid downstream confusion about layers
qry_roll_calls <- p_roll_calls
qry_bills <- p_bills

#####################################
#                                   #  
# 0b) base queries 2- partisanship  #
#                                   #
#####################################

# calculate mean legislator-level partisan vote weight for ALL their votes
# filters for dates >= 11/10/12 (data has some issues prior to that, per Andrew)
calc_mean_partisan_leg <- qry_leg_votes %>%
  group_by(legislator_name) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    leg_mean_partisanship=mean(partisan_vote_weight, na.rm = TRUE),
    leg_n_votes_denominator = sum(!is.na(partisan_vote_weight)),
    leg_n_votes_with_party = sum(partisan_vote_type==0),
    leg_n_votes_against_party= sum(partisan_vote_type==1),
    leg_n_votes_against_both = sum(partisan_vote_type==99)
  )

# legislator mean partisanship
qry_legislators <- qry_legislators %>%
  left_join(calc_mean_partisan_leg, by='legislator_name')


# calculate mean roll-call-level partisan vote weight
calc_mean_partisan_rc <- qry_leg_votes %>%
  group_by(roll_call_id) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    rc_mean_partisanship=mean(partisan_vote_weight, na.rm = TRUE),
    rc_n_votes_denominator = sum(!is.na(partisan_vote_weight)),
    rc_n_votes_with_party = sum(partisan_vote_type==0),
    rc_n_votes_against_party= sum(partisan_vote_type==1),
    rc_n_votes_against_both = sum(partisan_vote_type==99)
  )

# roll call summaries, 6271
qry_roll_calls <- qry_roll_calls %>%
  left_join(calc_mean_partisan_rc,
            by = 'roll_call_id'
  )

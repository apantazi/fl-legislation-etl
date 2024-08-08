#################################
#                               #  
# 04A_APP_QUERIES.R             #
#                               #
#################################
# 7/11/24
# This script builds on processed data (p_* and hist_*,), responds to settings,
# then prepares queries (qry_*) for web applications and visualizations

##############################
#                            #  
# 1a) configure app settings #
#                            #
##############################
#I may want to move this to a settings.yaml file, to separate settings from the script code

# Setting 1: Select source of demographic data (choices include CVAP 2022 and ACS 2022)
setting_demo_src <- "CVAP"
setting_demo_year <- 2022

# Setting 2: Select party loyalty metric. Choices include:
# a) for_against- weighs 0 with party, 1 against. excludes against both
# b) for_against_indy. similar to for_against, but votes against both weighed as 0.5
# c) nominate. to be added later? https://en.wikipedia.org/wiki/NOMINATE_(scaling_method)
# d) partisan_cross: 0 party line partisan, 1 cross party. excludes party line bipartisan
setting_party_loyalty <- "partisan_cross"

# Setting 3: Select election result for calculating district partisan lean. Should be a dataframe with elections and weights, chosen from:
# 16_PRES
# 18_GOV
# 20_PRES
# 22_GOV
# see 03a_process.R to make more election results available
setting_district_lean <- data.frame(
  source = c("16_PRES", "18_GOV", "20_PRES", "22_GOV"),
  weight = c(0.10,0.10,0.5,0.3),
  stringsAsFactors = FALSE
)

#####################################
#                                   #  
# 2) calculate partisanship stats   #
#                                   #
#####################################
# calculate party loyalty based on setting_party_loyalty
# and fold into qry_leg_votes
qry_leg_votes <- p_legislator_votes %>%
  mutate(
    party_loyalty_weight = case_when(
      setting_party_loyalty == "partisan_cross" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "partisan_cross"
      ),
      setting_party_loyalty == "for_against" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Party Line Bipartisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "for_against"
      ),
      setting_party_loyalty == "for_against_indy" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Party Line Bipartisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        partisan_vote_type == "Against Both Parties" ~ 0.5,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "for_against_indy"
      )
    )
  )

# calculate mean legislator-level partisan vote weight for ALL their votes
# filters for dates >= 11/10/12 (data has some issues prior to that, per Andrew)
calc_mean_partisan_leg <- qry_leg_votes %>%
  group_by(legislator_name) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    leg_party_loyalty=mean(party_loyalty_weight, na.rm = TRUE),
    leg_n_votes_denom_loyalty = sum(!is.na(party_loyalty_weight)),
    leg_n_votes_party_line_partisan = sum(partisan_vote_type == "Party Line Partisan", na.rm = TRUE),
    leg_n_votes_party_line_bipartisan = sum(partisan_vote_type == "Party Line Bipartisan", na.rm = TRUE),
    leg_n_votes_cross_party = sum(partisan_vote_type == "Cross Party", na.rm = TRUE),
    leg_n_votes_absent_nv = sum(partisan_vote_type == "Absent/NV", na.rm = TRUE),
    leg_n_votes_independent = sum(partisan_vote_type == "Against Both Parties", na.rm = TRUE),
    leg_n_votes_other = sum(partisan_vote_type == "Other", na.rm = TRUE),
    leg_n_votes_missing = sum(is.na(partisan_vote_type))
  )

# calculate mean roll-call-level partisan vote weight
calc_mean_partisan_rc <- qry_leg_votes %>%
  group_by(roll_call_id) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    #rc_mean_partisanship=mean(party_loyalty_weight, na.rm = TRUE),
    #rc_n_votes_denominator = sum(!is.na(party_loyalty_weight)),
    rc_n_votes_party_line_partisan = sum(partisan_vote_type=="Party Line Partisan", na.rm = TRUE),
    rc_n_votes_party_line_bipartisan = sum(partisan_vote_type=="Party Line Bipartisan", na.rm = TRUE),
    rc_n_votes_cross_party= sum(partisan_vote_type=="Cross Party", na.rm = TRUE),
    rc_n_votes_absent_nv = sum(partisan_vote_type == "Absent/NV", na.rm = TRUE),
    rc_n_votes_independent = sum(partisan_vote_type=="Against Both Parties", na.rm = TRUE),
    rc_n_votes_other= sum(partisan_vote_type=="Other", na.rm = TRUE)
  ) %>%
  mutate(
    rc_with_party = (rc_n_votes_party_line_partisan + rc_n_votes_party_line_bipartisan),
    rc_against_party = (rc_n_votes_cross_party + rc_n_votes_independent),
    rc_mean_partisanship = rc_with_party/(rc_with_party + rc_against_party)
  )

# roll call summaries, 6271
qry_roll_calls <- p_roll_calls %>%
  left_join(calc_mean_partisan_rc,
            by = 'roll_call_id'
  )

###########################
#                         #  
# 3a) create districts query  #
#                         #
###########################

# initial filtering for incumbent legislators
qry_legislators_incumbent <- p_legislators %>%
  filter(
    is.na(termination_date)
  )

# create qry_districts based on setting_demo_src, setting_demo_year, setting_district_lean
# and incorporating partisanship metrics
calc_elections_weighted <- hist_district_elections %>%
  inner_join(setting_district_lean, by = c("source_elec" = "source"))

calc_elections_avg <- calc_elections_weighted %>%
  group_by(chamber, district_number) %>%
  summarize(
    avg_pct_D = sum(pct_D * weight) / sum(weight),
    avg_pct_R = sum(pct_R * weight) / sum(weight)
  ) %>%
  mutate(
    avg_party_lean = ifelse(avg_pct_D > avg_pct_R, 'D', 'R'),
    avg_party_lean_points_abs = round(abs(avg_pct_R - avg_pct_D) * 100, 1),
    avg_party_lean_points_R = round((avg_pct_R - avg_pct_D) * 100, 1)
  )



qry_districts <- hist_district_demo %>%
  filter(source_demo==setting_demo_src,year_demo==setting_demo_year) %>%
  inner_join(
    calc_elections_avg,
    by=c('chamber','district_number')) %>%
  inner_join(
    qry_legislators_incumbent %>%
      select (people_id, chamber, district_number),
    by = c('chamber','district_number')
  ) %>%
  rename(incumb_people_id = people_id)

#rank senate partisanship
calc_dist_house_ranks <- qry_districts %>%
  filter(
    chamber == "House"
  ) %>%
  arrange(desc(avg_party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(avg_party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)

#rank house partisanship
calc_dist_senate_ranks <- qry_districts %>%
  filter(
    chamber == "Senate"
  ) %>%
  arrange(desc(avg_party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(avg_party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)  

calc_dist_ranks <- rbind(calc_dist_senate_ranks,calc_dist_house_ranks)

qry_districts <- qry_districts %>%
  left_join(calc_dist_ranks, by = c('district_number','chamber'))

# summarize statewide
qry_state_summary <- qry_districts %>%
  summarise(
    sum_white = sum(n_white, na.rm = TRUE),
    sum_hispanic = sum(n_hispanic, na.rm = TRUE),
    sum_black = sum(n_black, na.rm = TRUE),
    sum_asian = sum(n_asian, na.rm = TRUE),
    sum_pacific = sum(n_pacific, na.rm = TRUE),
    sum_native = sum(n_native, na.rm = TRUE),
    sum_total_demo = sum(n_total_demo, na.rm = TRUE)
    # sum_D = sum(n_Dem, na.rm = TRUE),
    # sum_R = sum(n_Rep, na.rm = TRUE),
    # sum_Total_Elec = sum(n_Total_Elec, na.rm = TRUE)
  ) %>%
  mutate(
    pct_white = sum_white / sum_total_demo,
    pct_hispanic = sum_hispanic / sum_total_demo,
    pct_black = sum_black / sum_total_demo,
    pct_asian = sum_asian / sum_total_demo,
    pct_napi = (sum_pacific + sum_native) / sum_total_demo,
    # pct_D = sum_D / sum_Total_Elec,
    # pct_R = sum_R / sum_Total_Elec
    #source_elec = setting_district_lean
  )

#############################
#                           #  
# 3b) create legislators query  #
#                           #
#############################

# continue building out incumbent legislators query
qry_legislators_incumbent <- qry_legislators_incumbent %>%
  left_join(calc_mean_partisan_leg, by='legislator_name') %>%
  mutate(
    setting_party_loyalty = setting_party_loyalty # add setting in here for future reference
  )

# calculate legislator ranks for each party and for each chamber
calculate_leg_ranks <- function(data, chamber, party, rank_column) {
  data %>%
    filter(chamber == !!chamber, party == !!party) %>%
    arrange(desc(leg_party_loyalty), desc(leg_n_votes_denom_loyalty)) %>%
    mutate(!!rank_column := row_number()) %>%
    select(district_number, chamber, !!rank_column)
}
calc_leg_house_R_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "House", "R", "rank_partisan_leg_R")
calc_leg_house_D_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "House", "D", "rank_partisan_leg_D")
calc_leg_senate_R_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "Senate", "R", "rank_partisan_leg_R")
calc_leg_senate_D_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "Senate", "D", "rank_partisan_leg_D")

# Bind the House and Senate R ranks together
calc_leg_R_ranks <- bind_rows(calc_leg_house_R_ranks, calc_leg_senate_R_ranks)
calc_leg_D_ranks <- bind_rows(calc_leg_house_D_ranks, calc_leg_senate_D_ranks)
calc_leg_ranks <- bind_rows(calc_leg_R_ranks, calc_leg_D_ranks)

qry_legislators_incumbent <- qry_legislators_incumbent %>%
  left_join(calc_leg_ranks, by = c('district_number','chamber')) 

###########################
#                         #  
# 3c) create bills query  #
#                         #
###########################

# create simple queries with unaltered views of processed data
qry_bills <- p_bills
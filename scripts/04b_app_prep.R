#################################
#                               #  
# 04A_APP_PREP.R                #
#                               #
#################################
# 7/14/24 RR
# This script builds on the query/settings layer in 04a_app_settings,
# then prepares data (app_*) for web apps and ad-hoc data visualizations

#################################
#                               #  
# 1) app_vote_patterns          #
#                               #
#################################
# initial dataframe setup is identical to app 2
app01_vote_patterns <- qry_leg_votes %>%
  filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay") &
      !is.na(partisan_vote_type)
  )%>%
  left_join(qry_bills %>% select('bill_id','bill_desc'), by='bill_id') %>%
  left_join(qry_legislators_incumbent %>% select('people_id','district_number','chamber', 'last_name', 'ballotpedia', 'rank_partisan_leg_D', 'rank_partisan_leg_R')) %>%
  left_join(qry_roll_calls %>% select('roll_call_id','D_pct_of_present','R_pct_of_present')) %>%
  select(roll_call_id, legislator_name, last_name, chamber, partisan_vote_type, session_year, final_vote, party, bill_number, roll_call_desc, bill_title, roll_call_date, bill_desc, bill_url, pct_of_total, pct_of_present, vote_text, legislator_name, bill_id, district_number, D_pct_of_present,R_pct_of_present, ballotpedia, 'rank_partisan_leg_D', 'rank_partisan_leg_R') %>%
  filter(pct_of_present != 0 & pct_of_present != 1)

#determine which roll calls had dissension within Republicans or Democrats. These will be displayed on the heatmap.
calc_d_partisan_rc <- qry_leg_votes %>%
  filter(party == "D") %>%  # Filter for Democratic votes and non-NA partisan_vote_type
  filter(partisan_vote_type %in% c("Cross Party", "Against Both Parties"))%>%
  distinct (roll_call_id)
calc_r_partisan_rc <- qry_leg_votes %>%
  filter(party == "R") %>%  # Filter for Democratic votes and non-NA partisan_vote_type
  filter(partisan_vote_type %in% c("Cross Party", "Against Both Parties"))%>%
  distinct (roll_call_id)

# this step determines which roll calls are displayed for each party, based on when one or more legislator voted against their party or against both parties
app01_vote_patterns <- app01_vote_patterns %>%
  left_join(qry_legislators_incumbent %>%
              select(legislator_name, leg_party_loyalty), by = "legislator_name") %>%
  left_join(qry_roll_calls %>%
              select(roll_call_id, rc_mean_partisanship, rc_unity_R, rc_unity_D), by = "roll_call_id") %>%
  mutate(
    is_include_d = roll_call_id %in% calc_d_partisan_rc$roll_call_id,
    is_include_r = roll_call_id %in% calc_r_partisan_rc$roll_call_id
  )

app01_vote_patterns <- app01_vote_patterns %>%
  left_join(qry_districts %>%
              select(district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D), by = c("district_number", "chamber"))

# speed up ggplot scalefillgradient2 method by assigning numeric values
app01_vote_patterns$partisan_vote_plot <- case_when(
  app01_vote_patterns$partisan_vote_type == "Against Both Parties" ~ 2,
  app01_vote_patterns$partisan_vote_type == "Cross Party" ~ 1,
  app01_vote_patterns$partisan_vote_type == "Party Line Partisan" ~ 0,
  app01_vote_patterns$partisan_vote_type == "Party Line Bipartisan" ~ 0
)


#################################
#                               #  
# 2)     app_leg_activity       #
#                               #
#################################
# filter this to just include incumbent legislators
# to confirm whether this should be identical with first section of app 1  
app02_leg_activity <- qry_leg_votes %>%
  filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay") &
      !is.na(partisan_vote_type)
  ) %>% 
  left_join(
    qry_bills %>%
      select(bill_id, bill_desc, state_link), 
    by = 'bill_id'
  ) %>%
  left_join(
    qry_legislators_incumbent %>%
      select(people_id, district_number, chamber, last_name, ballotpedia), 
    by = 'people_id'
  ) %>%
  left_join(qry_roll_calls %>% select(roll_call_id, D_pct_of_present, R_pct_of_present), by = 'roll_call_id') %>% 
  mutate( # renames field names used in app02 as of 8/7/24 while retaining original fields
    D = D_pct_of_present,
    R = R_pct_of_present,
    maverick_votes = vote_cross_party,
    vote_with_same = vote_party_line,
    vote_with_neither = vote_against_both
  ) %>%
  select(
    people_id, vote_id, vote_text, roll_call_id, session, party, legislator_name,
    bill_id, roll_call_date, roll_call_desc, yea, nay, nv, absent, n_total,
    passed, roll_call_chamber, bill_title, bill_number, session_year, bill_url,
    pct_of_total, n_present, pct_of_present, final_vote, termination_date,
    partisan_vote_type, R, D, bill_desc, district_number,
    chamber, last_name, ballotpedia, 
    vote_with_dem_majority, vote_with_gop_majority, vote_with_neither,
    voted_at_all, maverick_votes, vote_with_same, state_link,D_pct_of_present,R_pct_of_present,party_loyalty_weight
  ) %>% 
  mutate(roll_call_date = lubridate::ymd(roll_call_date))

#################################
#                               #  
# 3)     app_district_context   #
#                               #
#################################

app03_district_context <- qry_legislators_incumbent %>%
  select (
    people_id,party,legislator_name,last_name,ballotpedia,district_number,chamber,termination_date, setting_party_loyalty,leg_party_loyalty,leg_n_votes_denom_loyalty,
    leg_n_votes_party_line_partisan,leg_n_votes_party_line_bipartisan,leg_n_votes_cross_party,leg_n_votes_absent_nv,leg_n_votes_independent, leg_n_votes_other,
    rank_partisan_leg_R, rank_partisan_leg_D,
    mfh_member_id
  ) %>%
  left_join(qry_districts)

app03_district_context_state <- qry_state_summary

#################################
#                               #  
# create viz_partisanship       #
#                               #
#################################
# recreating Yuriko Schumacher's partisanship visual from https://www.texastribune.org/2023/12/18/mark-jones-texas-senate-special-2023-liberal-conservative-scores/
# first iteration: intent is to emulate the visual, though "partisanship" metric isn't identical
qry_leg_colnames <- colnames(qry_legislators_incumbent)

qry_leg_votes_for_partisanship <- left_join(qry_legislators_incumbent,qry_leg_votes,by='legislator_name')%>%
  select(-ends_with(".y")) %>%
  rename_with(~ sub("\\.x$", "", .), ends_with(".x")) %>% 
  select(qry_leg_colnames)

# 1. Calculate SD per legislator FIRST
#    Filters data and calculates standard deviation only for legislators with > 1 qualifying vote.
#    *** Replace 'party_loyalty_weight' below if that's not the correct column from qry_leg_votes ***
sd_per_legislator <- qry_leg_votes %>%
  filter(
    !is.na(partisan_vote_type),
    # **CRITICAL**: Review 'is.na(termination_date)' filter logic
    is.na(termination_date),
    partisan_vote_type != "Against Both Parties",
    # Ensure roll_call_date is Date type
    as.Date(roll_call_date) >= as.Date("2012-11-10")
  ) %>%
  group_by(legislator_name) %>%
  # Only calculate sd if there are multiple relevant votes
  filter(n() > 1) %>%
  summarize(
    # *** Use the CORRECT column name for sd() from qry_leg_votes! ***
    # Calculate SD based on individual votes
    sd_partisan_vote = sd(party_loyalty_weight, na.rm = TRUE),
    .groups = 'drop'
  )
# NOTE: sd_per_legislator now only contains legislator_name and sd_partisan_vote

# 2. LEFT JOIN the calculated SDs onto the existing qry_legislators_incumbent
viz_partisanship <- qry_legislators_incumbent %>%
  # Select only necessary columns from incumbents BEFORE the join
  # Includes the loyalty/vote counts already joined from calc_mean_partisan_leg
  select(
    legislator_name, party, chamber, district_number,
    leg_n_votes_denom_loyalty, # Already present
    leg_party_loyalty          # Already present
  ) %>%
  # Use left_join to merge ONLY sd_partisan_vote. No .x/.y issues.
  left_join(sd_per_legislator, by = "legislator_name") %>%
  # 3. MUTATE safely using existing and joined columns
  mutate(
    # Calculate Standard Error using existing leg_n_votes_denom_loyalty
    # and newly joined sd_partisan_vote
    se_partisan_vote = ifelse(
      is.na(sd_partisan_vote) | leg_n_votes_denom_loyalty <= 1,
      NA_real_,
      sd_partisan_vote / sqrt(leg_n_votes_denom_loyalty)
    ),
    # Calculate bounds using existing leg_party_loyalty and new se_partisan_vote
    lower_bound = ifelse(is.na(se_partisan_vote), NA_real_, leg_party_loyalty - se_partisan_vote),
    upper_bound = ifelse(is.na(se_partisan_vote), NA_real_, leg_party_loyalty + se_partisan_vote),
    # Label calculation
    leg_label = paste0(legislator_name, " (", substr(party, 1, 1), "-", district_number, ")")
  ) %>%
  # Optional: Final column selection
  select(
    legislator_name, party, chamber, district_number, leg_party_loyalty,
    sd_partisan_vote, se_partisan_vote, lower_bound, upper_bound, leg_label
  )
# --- End revised logic ---

viz_partisan_senate_d <- viz_partisanship %>%
  filter(party == 'D', chamber == 'Senate')

viz_partisan_senate_r <- viz_partisanship %>%
  filter(party == 'R', chamber == 'Senate')


## the below plot works. it shows loyalty of a given chamber/party with error bars. not currently using it in the app, but helpful for analysis sake ##
# loyalty_plot <- ggplot(viz_partisan_senate_r, aes(x = leg_party_loyalty, y = reorder(leg_label, leg_party_loyalty))) +
#   geom_point(color = "red", size = 3) +
#   geom_errorbarh(aes(xmin = lower_bound, xmax = upper_bound), height = 0.2, color = "gray") +
#   geom_vline(xintercept = 0.5, linetype = "solid") +
#   theme_minimal() +
#   labs(x = "Party Loyalty", y = "", title = "Legislator Party Loyalty") +
#   theme(
#     panel.grid.major.y = element_blank(),
#     panel.grid.minor.y = element_blank()
#   )+
#   annotate("text", x = min(viz_partisan_senate_d$leg_party_loyalty)*.8, y = 1, label = "<--- Less Loyal", hjust = 0) +
#   annotate("text", x = 0.9, y = 1, label = "More Loyal --->", hjust = 1)

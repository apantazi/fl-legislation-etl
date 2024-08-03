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
  select(roll_call_id, legislator_name, last_name, chamber, partisan_vote_type, session_year, final_vote, party, bill_number, roll_call_desc, bill_title, roll_call_date, bill_desc, bill_url, pct_of_total, pct_of_present, vote_text, legislator_name, bill_id, district_number, D_pct_of_present,R_pct_of_present, ballotpedia, 'rank_partisan_leg_D', 'rank_partisan_leg_R')

#filter out votes from unanimous roll calls
app01_vote_patterns <- app01_vote_patterns %>%
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
              select(roll_call_id, rc_mean_partisanship), by = "roll_call_id") %>%
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
app02_leg_activity <- calc_votes03_categorized %>%
  filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay") &
      !is.na(partisan_vote_type)
  ) %>%
  left_join(qry_leg_votes %>%   filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay") &
      !is.na(partisan_vote_type)
  )) %>% 
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
    rank_partisan_leg_R, rank_partisan_leg_D
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

viz_partisanship <- qry_legislators_incumbent %>%
      select(legislator_name, party, chamber, district_number, leg_n_votes_denom_loyalty, leg_party_loyalty) %>%
  mutate(
    sd_partisan_vote = qry_leg_votes %>%
      filter(!is.na(partisan_vote_type), is.na(termination_date), partisan_vote_type != "Against Both Parties",
      roll_call_date >= as.Date("2012-11-10")) %>%  # Combined filters
      group_by(legislator_name) %>%
      summarize(sd_partisan_vote = sd(leg_party_loyalty , na.rm = TRUE)) %>%
      pull(sd_partisan_vote),
    se_partisan_vote = sd_partisan_vote / sqrt(leg_n_votes_denom_loyalty),
    lower_bound = leg_party_loyalty - se_partisan_vote,
    upper_bound = leg_party_loyalty + se_partisan_vote,
    leg_label = paste0(legislator_name, " (", substr(party,1,1), "-", district_number,")")
  )

viz_partisan_senate_d <- viz_partisanship %>%
  filter(party == 'D', chamber == 'Senate')

viz_partisan_senate_r <- viz_partisanship %>%
  filter(party == 'R', chamber == 'Senate')


## the below plot works. it shows loyalty of a given chamber/party with error bars ##
# loyalty_plot <- ggplot(viz_partisan_senate_d, aes(x = leg_party_loyalty, y = reorder(leg_label, leg_party_loyalty))) +
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

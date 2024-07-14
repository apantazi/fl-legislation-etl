#################################
#                               #  
# 04_APP_PREP.R                 #
#                               #
#################################

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
  left_join(qry_legislators %>% select('people_id','district_number','chamber', 'last_name', 'ballotpedia')) %>%
  left_join(qry_roll_calls %>% select('roll_call_id','D_pct_of_present','R_pct_of_present'))

#filter out unanimous votes
app01_vote_patterns <- app01_vote_patterns %>%
  filter(pct_of_present != 0 & pct_of_present != 1) %>%
  select(roll_call_id, legislator_name, last_name, chamber, partisan_vote_type, session_year, final_vote, party, bill_number, roll_call_desc, bill_title, roll_call_date, bill_desc, bill_url, pct_of_total, vote_text, legislator_name, bill_id, district_number, D_pct_of_present,R_pct_of_present, ballotpedia)

# filter for votes that had some party-line dissension; exclude 0 = with party; include 99 = against both parties and 1 = against party 
calc_d_partisan_votes <- app01_vote_patterns %>% filter(party=="D") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_vote_type)) %>% filter(max>=1)
calc_r_partisan_votes <- app01_vote_patterns %>% filter(party=="R") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_vote_type)) %>% filter(max>=1)

# filter for roll calls that had some intra-party dissension
calc_d_votes <- app01_vote_patterns %>% filter(party=="D") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_d_partisan_votes$roll_call_id))
calc_r_votes <- app01_vote_patterns %>% filter(party=="R") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_r_partisan_votes$roll_call_id))

app01_vote_patterns <- app01_vote_patterns %>%
  left_join(qry_legislators %>%
              select(legislator_name, leg_mean_partisanship), by = "legislator_name") %>%
  left_join(qry_roll_calls %>%
              select(roll_call_id, rc_mean_partisanship), by = "roll_call_id") %>%
  mutate(
    is_include_d = roll_call_id %in% calc_d_votes$roll_call_id,
    is_include_r = roll_call_id %in% calc_r_votes$roll_call_id
  )

app01_vote_patterns <- app01_vote_patterns %>%
  left_join(qry_districts %>%
              select(district_number, chamber), by = c("district_number", "chamber"))



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
      select(bill_id, bill_desc), by = 'bill_id'
  ) %>%
  left_join(
    qry_legislators %>%
      select(people_id, district_number, chamber, last_name, ballotpedia), 
    by = 'people_id'
  ) %>%
  left_join(
    qry_roll_calls %>%
      select(roll_call_id, D_pct_of_present, R_pct_of_present),
    by = 'roll_call_id'
  )





#################################
#                               #  
# 3)     app_district_context   #
#                               #
#################################

app03_district_context <- qry_legislators %>%
  select (
    people_id,party,legislator_name,last_name,ballotpedia,district_number,chamber,termination_date,leg_mean_partisanship,
    leg_n_votes_denominator, leg_n_votes_against_both,leg_n_votes_against_party,leg_n_votes_with_party) %>%
  left_join(qry_districts) %>%
  mutate (
    setting_party_loyalty = setting_party_loyalty
    )

#rank senate partisanship
calc_dist_senate_ranks <- app03_district_context %>%
  filter(
    chamber == "House"
  ) %>%
  arrange(desc(party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)

#rank house partisanship
calc_dist_house_ranks <- app03_district_context %>%
  filter(
    chamber == "Senate"
  ) %>%
  arrange(desc(party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)  

calc_dist_ranks <- rbind(calc_dist_senate_ranks,calc_dist_house_ranks)

# calculate legislator ranks for each party and for each chamber
calculate_leg_ranks <- function(data, chamber, party, rank_column) {
  data %>%
    filter(chamber == !!chamber, party == !!party) %>%
    arrange(leg_mean_partisanship) %>%
    mutate(!!rank_column := row_number()) %>%
    select(district_number, chamber, !!rank_column)
}
calc_leg_house_R_ranks <- calculate_leg_ranks(app03_district_context, "House", "R", "rank_partisan_leg_R")
calc_leg_house_D_ranks <- calculate_leg_ranks(app03_district_context, "House", "D", "rank_partisan_leg_D")
calc_leg_senate_R_ranks <- calculate_leg_ranks(app03_district_context, "Senate", "R", "rank_partisan_leg_R")
calc_leg_senate_D_ranks <- calculate_leg_ranks(app03_district_context, "Senate", "D", "rank_partisan_leg_D")

# Bind the House and Senate R ranks together
calc_leg_R_ranks <- bind_rows(calc_leg_house_R_ranks, calc_leg_senate_R_ranks)
calc_leg_D_ranks <- bind_rows(calc_leg_house_D_ranks, calc_leg_senate_D_ranks)
calc_leg_ranks <- bind_rows(calc_leg_R_ranks, calc_leg_D_ranks)


app03_district_context <- app03_district_context %>%
  left_join(calc_dist_ranks, by = c('district_number','chamber')) %>%
  left_join(calc_leg_ranks, by = c('district_number','chamber')) 

app03_district_context_state <- qry_state_summary

#################################
#                               #  
# create viz_partisanship       #
#                               #
#################################
# recreating Yuriko Schumacher's partisanship visual from https://www.texastribune.org/2023/12/18/mark-jones-texas-senate-special-2023-liberal-conservative-scores/
# first iteration: intent is to emulate the visual, though "partisanship" metric isn't identical

viz_partisanship <- qry_legislators %>%
      select(legislator_name, party, chamber, district_number, leg_n_votes_denominator, leg_mean_partisanship) %>%
  mutate(
    sd_partisan_vote = qry_leg_votes %>%
      filter(!is.na(partisan_vote_type), is.na(termination_date), partisan_vote_type != 99, roll_call_date >= as.Date("2012-11-10")) %>%  # Combined filters
      group_by(legislator_name) %>%
      summarize(sd_partisan_vote = sd(partisan_vote_type, na.rm = TRUE)) %>%
      pull(sd_partisan_vote),
    se_partisan_vote = sd_partisan_vote / sqrt(leg_n_votes_denominator),
    lower_bound = leg_mean_partisanship - se_partisan_vote,
    upper_bound = leg_mean_partisanship + se_partisan_vote,
    leg_label = paste0(legislator_name, " (", substr(party,1,1), "-", district_number,")")
  )

viz_partisan_senate_d <- viz_partisanship %>%
  filter(party == 'D', chamber == 'Senate')

viz_partisan_senate_r <- viz_partisanship %>%
  filter(party == 'R', chamber == 'Senate')

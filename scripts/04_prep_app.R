#################################
#                               #  
# 04_PREP_APP.R                 #
#                               #
#################################

# this data frame was originally created to support voting patterns and legislative activity apps
app_data <- p_legislator_votes %>%
  filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay") &
      !is.na(partisan_vote_type)
   )%>%
  left_join(p_bills %>% select('bill_id','bill_desc'), by='bill_id') %>%
  left_join(p_legislators %>% select('people_id','district_number','chamber', 'last_name', 'ballotpedia')) %>%
  left_join(p_roll_calls %>% select('roll_call_id','D_pct_of_present','R_pct_of_present'))


# filter for party-line (or against both parties) legislator-votes
# partisan metric: 0 = with party, 1 = against both parties, 2 = against party 
calc_d_partisan_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_vote_type)) %>% filter(max>=1)
calc_r_partisan_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_vote_type)) %>% filter(max>=1)

# filter for votes that had some intra-party dissension
calc_d_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_d_partisan_votes$roll_call_id))
calc_r_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_r_partisan_votes$roll_call_id))



#################################
#                               #  
# create app_vote_patterns      #
#                               #
#################################
# get subset of bills that had non-unanimous votes

app_vote_patterns <- app_data %>%
  filter(pct_of_present != 0 & pct_of_present != 1) %>%
  select(roll_call_id, legislator_name, last_name, chamber, partisan_vote_type, session_year, final_vote, party, bill_number, roll_call_desc, bill_title, roll_call_date, bill_desc, bill_url, pct_of_total, vote_text, legislator_name, bill_id, district_number, D_pct_of_present,R_pct_of_present, ballotpedia)

app_vote_patterns <- app_vote_patterns %>%
  left_join(p_legislators %>%
              select(legislator_name, mean_partisanship), by = "legislator_name") %>%
  left_join(p_roll_calls %>%
              select(roll_call_id, rc_mean_partisanship), by = "roll_call_id") %>%
  mutate(
    is_include_d = roll_call_id %in% calc_d_votes$roll_call_id,
    is_include_r = roll_call_id %in% calc_r_votes$roll_call_id
  )

app_vote_patterns <- app_vote_patterns %>%
  left_join(p_districts %>%
              select(district_number, chamber, is_incumbent_primaried), by = c("district_number", "chamber"))
  
#################################
#                               #  
# create viz_partisanship       #
#                               #
#################################
# recreating Yuriko Schumacher's partisanship visual from https://www.texastribune.org/2023/12/18/mark-jones-texas-senate-special-2023-liberal-conservative-scores/
# first iteration: intent is to emulate the visual, though "partisanship" metric isn't identical

viz_partisanship <- p_legislators %>%
      select(legislator_name, party, chamber, district_number, n_votes_partisan, mean_partisanship) %>%
  mutate(
    sd_partisan_vote = p_legislator_votes %>%
      filter(!is.na(partisan_vote_type), partisan_vote_type != 99, roll_call_date >= as.Date("2012-11-10")) %>%  # Combined filters
      group_by(legislator_name) %>%
      summarize(sd_partisan_vote = sd(partisan_vote_type, na.rm = TRUE)) %>%
      pull(sd_partisan_vote),
    se_partisan_vote = sd_partisan_vote / sqrt(n_votes_partisan),
    lower_bound = mean_partisanship - se_partisan_vote,
    upper_bound = mean_partisanship + se_partisan_vote,
    leg_label = paste0(legislator_name, " (", substr(party,1,1), "-", district_number,")")
  )

viz_partisan_senate_d <- viz_partisanship %>%
  filter(party == 'D', chamber == 'Senate')

viz_partisan_senate_r <- viz_partisanship %>%
  filter(party == 'R', chamber == 'Senate')

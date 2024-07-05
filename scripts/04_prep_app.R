#################################
#                               #  
# 04_PREP_APP.R                 #
#                               #
#################################
# first filter for legislator dashboard.
# This includes some fields which are later removed from the app_vote_patterns view, but will be included in legislator activity app
app_data <- calc_leg_votes_partisan %>%
  left_join(p_bills %>% select('bill_id','bill_desc'), by='bill_id') %>%
  left_join(p_legislators %>% select('people_id','district_number'))

# filter for party-line (or against both parties) legislator-votes
# partisan metric: 0 = with party, 1 = against both parties, 2 = against party 
calc_d_partisan_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric)) %>% filter(max>=1)
calc_r_partisan_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric)) %>% filter(max>=1)

# filter for votes that had some intra-party dissension
calc_d_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_d_partisan_votes$roll_call_id))
calc_r_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(calc_r_partisan_votes$roll_call_id))

calc_rc_to_bill <- app_data %>%
  select(roll_call_id, year=session_year,bill_number) %>%
  distinct() %>%
  arrange(desc(year),bill_number,roll_call_id)

calc_rc_to_bill$label_bill_year <- paste(calc_rc_to_bill$bill_number,"-",calc_rc_to_bill$year)



#################################
#                               #  
# create app_vote_patterns      #
#                               #
#################################
# get subset of bills that had non-unanimous votes

app_vote_patterns <- app_data %>%
  filter(pct_of_present != 0 & pct_of_present != 1) %>%
  select(roll_call_id, legislator_name, partisan_metric, session_year, chamber, final_vote, party, bill_number, roll_call_desc, bill_title, roll_call_date, bill_desc, bill_url, pct_voted_for, vote_text, legislator_name, bill_id, district_number)

app_vote_patterns <- app_vote_patterns %>%
  left_join(calc_leg_mean_partisan %>%
              select(legislator_name, mean_partisan_metric), by = "legislator_name") %>%
  mutate(
    is_include_d = ifelse(roll_call_id %in% calc_d_votes$roll_call_id, 1, 0),
    is_include_r = ifelse(roll_call_id %in% calc_r_votes$roll_call_id, 1, 0),
  )

app_vote_patterns <- app_vote_patterns %>%
  left_join(p_districts %>%
              select(district_number, chamber, is_incumbent_challenged), by = "district_number, chamber")
  
#################################
#                               #  
# create viz_partisanship       #
#                               #
#################################
# recreating Yuriko Schumacher's partisanship visual from https://www.texastribune.org/2023/12/18/mark-jones-texas-senate-special-2023-liberal-conservative-scores/
# first iteration: intent is to emulate the visual, though "partisanship" metric isn't identical

viz_partisanship <- p_legislators %>%
      select(legislator_name, party, role, district, n_votes, mean_partisan_metric) %>%
  mutate(
    sd_partisan_metric = p_legislator_votes %>%
      filter(!is.na(partisan_metric), roll_call_date >= as.Date("2012-11-10")) %>%  # Combined filters
      group_by(legislator_name) %>%
      summarize(sd_partisan_metric = sd(partisan_metric, na.rm = TRUE)) %>%
      pull(sd_partisan_metric),
    se_partisan_metric = sd_partisan_metric / sqrt(n_votes),
    lower_bound = mean_partisan_metric - se_partisan_metric,
    upper_bound = mean_partisan_metric + se_partisan_metric,
    leg_label = paste0(legislator_name, " (", district,")")
  )

viz_partisan_senate_d <- viz_partisanship %>%
  filter(party == 'D', role == 'Sen')

viz_partisan_senate_r <- viz_partisanship %>%
  filter(party == 'R', role == 'Sen')
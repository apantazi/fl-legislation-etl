# QA_CHECKS.R
#7/18/24 working on this data quality check "in earnest," as they say



cat ("\n############################################")
cat ("\n#")
cat ("\nReviewing processed dataframes for anomalies")
cat ("\n#")
cat ("\n############################################")
cat ("\n")

# roll calls: no problems with missing date or no votes
qa_roll_calls <- p_roll_calls %>%
  filter(
    is.na(roll_call_date) |
      n_total == 0 |
      is.na(n_total)
  )
print(paste0(nrow(qa_roll_calls)," roll calls with missing date or no votes"))

# legislator votes: 
qa_legislator_votes <- p_legislator_votes %>%
  mutate(
    n_present=sum(yea,nay)
  ) %>% 
  filter(n_present ==0)
print(paste0('Of ', nrow(p_legislator_votes)," legislator-votes,"))
print(paste0(nrow(qa_legislator_votes)," legislator-votes with no present votes"))



cat ("\n############################################")
cat ("\n#")
cat ("\nReviewing partisan_vote_type edge cases")
cat ("\n#")
cat ("\n############################################")
cat ("\n")

qa_leg_votes_other <- calc_leg_votes_partisan %>%
  filter(partisan_vote_type == "Other") %>%
  select (party, vote_text, dem_majority, gop_majority, partisan_vote_type)
print(paste0(nrow(qa_leg_votes_other)," legislator-votes categorized as 'other'"))

qa_leg_votes_absent_nv <- qa_leg_votes_other %>%
  filter(vote_text %in% c('Absent','NV') )
print(paste0(nrow(qa_leg_votes_absent_nv)," of the 'other' votes are absent or NV"))

qa_leg_votes_other_other <- qa_leg_votes_other %>%
  filter(!vote_text %in% c('Absent','NV') )
print(paste0(nrow(qa_leg_votes_other_other)," of the 'other' votes are something else...here's a sample"))
print(qa_leg_votes_other_other, n = 10)

cat ("\n############################################")
cat ("\n#")
cat ("\nReviewing assignment of incumbent legislators to districts")
cat ("\n#")
cat ("\n############################################")
cat ("\n")

# validate number of legislators
qa_n_legislators <- nrow(p_legislators)
qa_n_legislators_incumbent <- nrow(qry_legislators_incumbent %>% 
                                     filter(is.na(termination_date)))
print(paste0("\n",qa_n_legislators," legislators and ", qa_n_legislators_incumbent, " incumbent legislators in p_legislators."))

qa_n_districts <- nrow(qry_districts)
qa_n_districts_w_leg <- nrow(qry_districts %>%
                               filter(!is.na(incumb_people_id)))
print(paste0("\n",qa_n_districts," districts in p_districts, of which ", qa_n_districts_w_leg, " have an incumbent legislator."))







cat ("\n############################################")
cat ("\n#")
cat ("\nReviewing party loyalty rankings")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\nNote that total number of votes is used as a tiebreaker for legislators with identical party loyalty")

# review partisan ranks by chamber
qa_loyalty_ranks <- qry_legislators_incumbent %>%
  arrange(chamber, party, rank_partisan_leg_R, rank_partisan_leg_D, leg_party_loyalty, leg_n_votes_denom_loyalty) %>%
  select(chamber, party, rank_partisan_leg_R, rank_partisan_leg_D, leg_party_loyalty, leg_n_votes_denom_loyalty)
print(qa_loyalty_ranks, n = 160)



cat ("\n############################################")
cat ("\n#")
cat ("\nReconciling legislator vote counts")
cat ("\n#")
cat ("\n############################################")
cat ("\n")



cat ("\n############################################")
cat ("\n#")
cat ("\nReconciling roll call partisanship calculations")
cat ("\n#")
cat ("\n############################################")
cat ("\n")

n_rc = nrow(qry_roll_calls)
n_rc01 = nrow(calc_rc01_by_party)
n_rc01_expected = n_rc * 2
n_rc01_diff = n_rc01_expected - n_rc01 
n_rc02 = nrow(calc_rc02_partisanship)
n_rc03 = nrow(calc_rc03_party_majority)
print(paste0(n_rc," roll calls."))
print(paste0(n_rc01," roll calls by party in calc_rc01_by_party (we'd expect double)"))
if (n_rc01_diff == 0) {
  print("as expected")
} else {
  print(paste0("but ", n_rc01_diff, " records were dropped."))
}
print(paste0(n_rc02," roll calls by party in calc_rc02_partisanship"))
print(paste0(n_rc03," roll calls by party in calc_rc03_party_majority"))

# QA_CHECKS.R
#7/18/24 working on this data quality check "in earnest," as they say



cat ("\n############################################")
cat ("\n#")
cat ("\n# Review processed dataframes for anomalies")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\n")

# roll calls: no problems with missing date or no votes
qa_roll_calls <- p_roll_calls %>%
  filter(
    is.na(roll_call_date) |
      n_total == 0 |
      is.na(n_total)
  )
print(paste0('Of ', nrow(p_roll_calls)," roll calls,"))
print(paste0(nrow(qa_roll_calls)," roll calls with missing date or no votes"))
cat ("\n")

# legislator votes: 
qa_legislator_votes <- p_legislator_votes %>%
  mutate(
    n_present=sum(yea,nay)
  ) %>% 
  filter(n_present ==0)
print(paste0('Of ', nrow(p_legislator_votes)," legislator-votes,"))
print(paste0(nrow(qa_legislator_votes)," legislator-votes are tied to roll calls with zero 'present' (aye or nay) votes"))



cat ("\n############################################")
cat ("\n#")
cat ("\n# Review partisan_vote_type edge cases")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\n")

qa_leg_votes_other <- calc_votes03_categorized %>%
  filter(partisan_vote_type == "Other") %>%
  select (party, vote_text, dem_majority, gop_majority, partisan_vote_type) %>%
  mutate(
    vote_type_other = case_when(
      vote_text == "NV" ~ "No Vote",
      vote_text == "Absent" ~ "Absent",
      (party == 'D' & dem_majority == "Equal") | (party == 'R' & (gop_majority == "Equal")) ~ "Same Party Split",
      (party == 'R' & dem_majority == "Equal") | (party == 'D' & (gop_majority == "Equal")) ~ "Oppo Party Split",
      TRUE ~ "Unexplained"
    )
  )

n_leg_votes = format(nrow(qry_leg_votes), big.mark= ",", scientific = FALSE)
n_leg_votes_other = format(nrow(qa_leg_votes_other), big.mark = ",", scientific = FALSE)
n_other_absent <- qa_leg_votes_other %>%
  filter(vote_type_other == "Absent") %>%
  nrow()
n_other_absent <- format(n_other_absent, big.mark= ",", scientific = FALSE)
n_other_no_vote <- qa_leg_votes_other %>%
  filter(vote_type_other == "No Vote") %>%
  nrow()
n_other_no_vote <- format(n_other_no_vote, big.mark= ",", scientific = FALSE)
n_other_same_split <- qa_leg_votes_other %>%
  filter(vote_type_other == "Same Party Split") %>%
  nrow()
n_other_same_split <- format(n_other_same_split, big.mark= ",", scientific = FALSE)
n_other_oppo_split <- qa_leg_votes_other %>%
  filter(vote_type_other == "Oppo Party Split") %>%
  nrow()
n_other_oppo_split <- format(n_other_oppo_split, big.mark= ",", scientific = FALSE)
n_other_unexplained <- qa_leg_votes_other %>%
  filter(vote_type_other == "Unexplained") %>%
  nrow()
n_other_unexplained <- format(n_other_unexplained, big.mark= ",", scientific = FALSE)
print(paste0("Of " , n_leg_votes, " legislator-votes"))
print(paste0(n_leg_votes_other, " were categorized as 'Other.' Of these:"))
print(paste0(n_other_absent, " absent"))
print(paste0(n_other_no_vote, " no vote"))
print(paste0(n_other_dems_split, " undefined because legislator's own party split their vote equally"))
print(paste0(n_other_unexplained, " unexplained"))


cat ("\n############################################")
cat ("\n#")
cat ("\n# Review assignment of incumbent legislators to districts")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\n")

# validate number of legislators
qa_n_legislators <- nrow(p_legislators)
qa_n_legislators_incumbent <- nrow(qry_legislators_incumbent %>% 
                                     filter(is.na(termination_date)))
print(paste0(qa_n_legislators," legislators and ", qa_n_legislators_incumbent, " incumbent legislators in p_legislators."))

qa_n_districts <- nrow(qry_districts)
qa_n_districts_w_leg <- nrow(qry_districts %>%
                               filter(!is.na(incumb_people_id)))
print(paste0(qa_n_districts," districts in p_districts, of which ", qa_n_districts_w_leg, " have an incumbent legislator."))







cat ("\n############################################")
cat ("\n#")
cat ("\n# Review party loyalty rankings")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\nFor party loyalty tiebreakers, legislators are ranked based on number of votes counted in party loyalty metric.")
cat ("\n")

# review partisan ranks by chamber
qa_loyalty_ranks <- qry_legislators_incumbent %>%
  arrange(chamber, party, rank_partisan_leg_R, rank_partisan_leg_D, leg_party_loyalty, leg_n_votes_denom_loyalty) %>%
  select(chamber, party, rank_partisan_leg_D, rank_partisan_leg_R, legislator_name, district_number, leg_party_loyalty, leg_n_votes_denom_loyalty)
cat('To review loyalty ranks, see')
cat('\nhttps://github.com/reliablerascal/fl-legislation-etl/blob/main/data-app/qa_loyalty_ranks.csv')
cat ("\n")


cat ("\n############################################")
cat ("\n#")
cat ("\n# Reconcile legislator vote counts")
cat ("\n#")
cat ("\n############################################")
cat ("\n\n")

n_lv = format(nrow(qry_leg_votes), big.mark = ",", scientific = FALSE)
n_lv01 = format(nrow(calc_votes01_both_parties_present), big.mark = ",", scientific = FALSE)
n_lv02 = format(nrow(calc_votes02_w_partisan_stats), big.mark = ",", scientific = FALSE)
n_lv03 = format(nrow(calc_votes03_categorized), big.mark = ",", scientific = FALSE)
print(paste0(n_lv," legislator votes."))
print(paste0(n_lv01," legislator votes in calc_votes01_both_parties_present."))
print(paste0(n_lv02," legislator votes in calc_votes02_w_partisan_stats."))
print(paste0(n_lv03," legislator votes in calc_votes03_categorized."))

qa_roll_calls_missing_party_total <- calc_rc02_partisanship %>%
  filter(is.na(D) | is.na(R)) %>%
  left_join (p_roll_calls, by = "roll_call_id")

n_rc_missing_party = nrow(qa_roll_calls_missing_party_total)
n_rc_missing_party_votes = sum(qa_roll_calls_missing_party_total$n_total, na.rm = TRUE)
print(paste0(n_rc_missing_party," roll calls had no votes for one or both parties"))
print(paste0("So ", n_rc_missing_party_votes," votes were removed"))

cat ("\n############################################")
cat ("\n#")
cat ("\n# Reconcile roll call partisanship calculations")
cat ("\n#")
cat ("\n############################################")
cat ("\n\n")

n_rc = nrow(qry_roll_calls)
n_rc01a = nrow(calc_rc01a_by_party_valid)
n_rc01a_expected = n_rc * 2
n_rc01a_diff = n_rc01_expected - n_rc01 
n_rc02 = nrow(calc_rc02_partisanship)
n_rc03 = nrow(calc_rc03_party_majority)
print(paste0(n_rc," roll calls."))
print(paste0(n_rc01a," roll calls by party in calc_rc01_by_party. We'd expect two records per roll call, or ", n_rc01a_expected, " records."))
if (n_rc01a_diff == 0) {
  print("Expectations matched.")
} else {
  print(paste0("This means that ", n_rc01a_diff, " records were dropped. See qa_rc_no_present_votes for those records."))
}

qa_rc_no_present_votes <- calc_rc01_by_party %>%
  anti_join(calc_rc01a_by_party_valid, by = c("roll_call_id","party"))

print(paste0(n_rc02," roll calls by party in calc_rc02_partisanship"))
print(paste0(n_rc03," roll calls by party in calc_rc03_party_majority"))

qa_rc_no_present_votes <- calc_rc01_by_party %>%
  anti_join(calc_rc01a_by_party_valid, by = "roll_call_id")

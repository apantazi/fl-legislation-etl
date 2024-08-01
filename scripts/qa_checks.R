# QA_CHECKS.R
#7/19/24 working on this data quality check "in earnest," as they say

cat ("\n############################################")
cat ("\n#")
cat ("\n# Quality Assurance Check")
cat ("\n#")
cat ("\n############################################")
cat ("\n")
cat ("\n")
print("To manually review edge cases that explain record count disparities, refer to the following folder:")
print("https://github.com/reliablerascal/fl-legislation-etl/tree/main/qa")

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
print(paste0(nrow(p_roll_calls)," roll calls in raw parsed data,"))
print(paste0(nrow(qa_roll_calls)," of these with missing date or no votes"))
cat ("\n")

# legislator votes: 
qa_legislator_votes_none_present <- p_legislator_votes %>%
  filter(n_present ==0 | is.na(n_present))
print(paste0(nrow(p_legislator_votes)," legislator-votes in raw parsed data,"))
print(paste0(nrow(qa_legislator_votes_none_present)," of these are tied to roll calls with no 'present' (aye or nay) votes from either party."))





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
print(paste0("Of " , n_leg_votes, " legislator-votes in raw parsed data:"))
print(paste0(n_leg_votes_other, " were categorized as 'Other.' Of these:"))
print(paste0(n_other_absent, " absent"))
print(paste0(n_other_no_vote, " no vote"))
print(paste0(n_other_same_split, " undefined because legislator's own party split their vote equally"))
print(paste0(n_other_oppo_split, " undefined because opposition party split their vote equally"))
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
cat('To review all loyalty ranks, see qa_loyalty_ranks.csv. Here are the first five:')
cat ("\n")
print.data.frame(head(qa_loyalty_ranks))





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

qa_rc_missing_party <- calc_rc02_partisan_pivot %>%
  filter(is.na(D) | is.na(R)) %>%
  left_join (p_roll_calls, by = "roll_call_id")

qa_rc_missing_party_both <- calc_rc02_partisan_pivot %>%
  filter(is.na(D) & is.na(R)) %>%
  left_join (p_roll_calls, by = "roll_call_id")

n_rc_missing_party = nrow(qa_rc_missing_party)
n_rc_missing_party_votes = sum(qa_rc_missing_party$n_total, na.rm = TRUE)
n_rc_missing_party_both = nrow(qa_rc_missing_party_both)
n_rc_missing_party_both_votes = sum(qa_rc_missing_party_both$n_total, na.rm = TRUE)
print(paste0(n_rc_missing_party," roll calls had no votes for one or both parties"))
print(paste0("This accounts for ", n_rc_missing_party_votes," legislator-votes removed, because they couldn't be weighted for partisan alignment."))
print(paste0("Including ", n_rc_missing_party_both_votes," legislator-votes removed, because neither party voted."))
print("See qa_rc_missing_party.csv to review those roll calls.")

cat ("\n############################################")
cat ("\n#")
cat ("\n# Reconcile roll call partisanship calculations")
cat ("\n#")
cat ("\n############################################")
cat ("\n\n")

n_rc = nrow(qry_roll_calls)
n_rc01 = nrow(calc_rc01_by_party)
n_rc01a_expected = n_rc * 2
qa_rc_party_none_present <- calc_rc01_by_party %>%
  filter(n_present==0)
n_rc01_invalid = nrow(qa_rc_party_none_present)
n_rc02 = nrow(calc_rc02_partisan_pivot)
# n_rc03 = nrow(calc_rc03_party_majority)
print(paste0(n_rc," roll calls."))
print(paste0(n_rc01," roll calls by party in calc_rc01_by_party. We'd expect two records per roll call, or ", n_rc01a_expected, " records."))
print(paste0(n_rc01_invalid, " records where no party members are present for a given roll call."))
print("See qa_rc_party_none_present.csv to review those records.")
cat("\n")

print(paste0(n_rc02," roll calls in calc_rc02_partisanship"))
# print(paste0(n_rc03," roll calls by party in calc_rc03_party_majority"))

# qa_party_majority_probs <- calc_rc02_partisan_pivot %>%
#   anti_join(calc_rc03_party_majority, by = "roll_call_id")









#######################
#                     #  
# Review Districts    #
#                     #
#######################
#7/10/24 just started building this section

# validate number of legislators
qa_n_legislators <- nrow(p_legislators)
qa_n_legislators_incumbent <- nrow(qry_legislators %>% 
                                     filter(is.na(termination_date)))
print(paste0(qa_n_legislators," legislators and ", qa_n_legislators_incumbent, " incumbent legislators in p_legislators."))

qa_n_districts <- nrow(qry_districts)
qa_n_districts_w_leg <- nrow(qry_districts %>%
                               filter(!is.na(incumb_people_id)))
print(paste0(qa_n_districts," districts in p_districts, of which ", qa_n_districts_w_leg, " have an incumbent legislator."))

###############################
#                             #  
# Review partisan_vote_types  #
#                             #
###############################
# 7/17/24

qa_leg_votes_partisan <- calc_leg_votes_partisan %>%
  select (party, vote_text, dem_majority, gop_majority, partisan_vote_type)

qa_leg_votes_unclear <- qa_leg_votes_partisan %>%
  filter(
    partisan_vote_type == "Unclear"
  )
nrow(qa_leg_votes_unclear)

qa_leg_votes_unclear_absent_nv <- qa_leg_votes_partisan %>%
  filter(
    partisan_vote_type == "Unclear" & vote_text %in% c('Absent','NV') 
  )
nrow(qa_leg_votes_unclear_absent_nv)

qa_leg_votes_unclear_present <- qa_leg_votes_partisan %>%
  filter(
    partisan_vote_type == "Unclear" & !vote_text %in% c('Absent','NV')  
  )
nrow(qa_leg_votes_unclear_present)

###############################
#                             #  
# Review party loyalty ranks  #
#                             #
###############################
# 7/17/24
# rankings now incorporate n_leg_votes_denominator as tiebreaker for legislators with identical party loyalty

# review partisan ranks by chamber
qa_loyalty_ranks <- qry_legislators_incumbent %>%
  arrange(chamber, party, rank_partisan_leg_R, rank_partisan_leg_D, leg_party_loyalty, leg_n_votes_denom_loyalty) %>%
  select(chamber, party, rank_partisan_leg_R, rank_partisan_leg_D, leg_party_loyalty, leg_n_votes_denom_loyalty)

votes_all <- left_join(bill_detailed$votes,bill_detailed$bill_info_df) %>% mutate(pct = yea/total)

bill_vote_all <- inner_join(bills,OLD_votes_all,by=c("bill_id","number","title","session_id","session_name"
),suffix=c("","_vote")) %>% mutate(total_vote = (yea+nay),true_pct = yea/total_vote) %>% arrange(true_pct) #bill_id is unique and not duplicated across sessions



# Summarize the data to get the count of votes with majority for each legislator
# this code is presently not used
legislator_majority_votes <- leg_votes_with2 %>%
  group_by(party,role,session_id) %>%
  summarize(votes_with_dem_majority = sum(vote_with_dem_majority, na.rm = TRUE),
            votes_with_gop_majority = sum(vote_with_gop_majority, na.rm = TRUE),
            independent_votes = sum(vote_with_neither,na.rm=TRUE),
            total_votes = n(),
            .groups = 'drop') %>% 
  mutate(d_pct = votes_with_dem_majority/total_votes,
         r_pct=votes_with_gop_majority/total_votes,
         margin=d_pct-r_pct,
         ind_pct=independent_votes/total_votes)

#####
# helper function to extract legislator-votes for parse_votes
# extract_votes <- function(input_vote_json_path) {
#   pb$tick()
#   
#   # Extract session from the file path
#   session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
#   session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
#   
#   vote_data <- jsonlite::fromJSON(input_vote_json_path)
#   roll_call <- vote_data[["roll_call"]]
#   person_vote <- roll_call[["votes"]]
#   person_vote$roll_call_id <- roll_call[["roll_call_id"]]
#   person_vote$session <- session_info
#   
#   return(person_vote)
# }


# priority_votes <- app_data %>% filter(priority_bills=="Y") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1)


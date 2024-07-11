#######################
#                     #  
# 03y_QA_CHECKS.R     #
#                     #
#######################
#7/10/24 just started building this section

# validate number of legislators
qa_n_legislators <- nrow(p_legislators)
qa_n_legislators_incumbent <- nrow(p_legislators %>% 
                                     filter(is.na(termination_date)))
print(paste0(qa_n_legislators," legislators and ", qa_n_legislators_incumbent, " incumbent legislators in p_legislator."))

qa_n_districts <- nrow(p_districts)
qa_n_districts_w_leg <- nrow(p_districts %>%
                               filter(!is.na(incumb_people_id)))
print(paste0(qa_n_districts," districts in p_districts, of which ", qa_n_districts_w_leg, " have an incumbent legislator."))

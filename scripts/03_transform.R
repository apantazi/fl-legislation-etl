#################################
#                               #  
# 03_TRANFORM.R                 #
#                               #
#################################

########################################
#                                      #  
# 0) read tables from postgres         #
#                                      #
########################################
# placeholder- could add a SQL read operation here
# but tables (e.g. t_roll_calls) are already in memory if I'm running these scripts in sequence from etl_main.R (i.e I've just run 02_parse_legiscan.R)

########################################
#                                      #  
# 1B) create views version 2           #
#                                      #
########################################
p_roll_calls_w_calc <- t_roll_calls %>%
  left_join(t_bills %>% select(bill_id, title, number, session_year, description, url), by = "bill_id") %>%
  mutate(
    pct_of_total = yea/total,
    n_present = yea+nay,
    pct_of_present = yea/n_present
  ) %>%
  rename(
    bill_desc = description,
    bill_number = number,
    bill_title = title,
    bill_url = url,
    roll_call_date = date,
    roll_call_desc = desc,
  ) %>%
  arrange(pct_of_present)

p_legislator_sessions <- t_legislator_sessions %>%
  rename(
    legislator_name = name
  )

p_legislators <- p_legislator_sessions %>%
  group_by(legislator_name) %>%
  slice(1) %>%
  ungroup()

#convert roll call id to character (not sure why)
t_legislator_votes <- t_legislator_votes %>% mutate(roll_call_id = as.character(roll_call_id))
p_roll_calls_w_calc <- p_roll_calls_w_calc %>% mutate(roll_call_id = as.character(roll_call_id))

calc_legislator_votes <- t_legislator_votes %>%
  inner_join(t_legislator_sessions %>% select(people_id, session, party, name, ballotpedia, role), by = c("people_id", "session")) %>%
  inner_join(p_roll_calls_w_calc, by = c("roll_call_id", "session")) %>%
  rename(
    legislator_name = name
  )

################################
#                              #  
# 2) analyze and prep data     #
#                              #
################################

# primary key should at least be roll_call_id and party, so 2x the number of roll_calls minus anything filtered out
#temp_analyze_bill <- temp_legislator_votes_detailed %>% group_by(party,roll_call_id,title,vote_text,number) %>% summarize(n=n()) %>% arrange(desc(n)) %>% pivot_wider(values_from = n,names_from = vote_text,values_fill = 0) %>% mutate(total=sum(Yea,NV,Absent,Nay,na.rm = TRUE),total2=sum(Yea,Nay)) %>% filter(total>0 & total2 >0) %>% mutate(y_pct = Yea/total,n_pct=Nay/total,nv_pct=NV/total, absent_pct=Absent/total,NV_A=(NV+Absent)/total,y_pct2 = Yea/(Yea+Nay),n_pct2 = Nay/(Yea+Nay),margin=y_pct2-n_pct2)

calc_analyze_bill <- calc_legislator_votes %>% group_by(party,roll_call_id,bill_title,vote_text,bill_number) %>% summarize(n=n()) %>% arrange(desc(n)) %>% pivot_wider(values_from = n,names_from = vote_text,values_fill = 0) %>% mutate(total=sum(Yea,NV,Absent,Nay,na.rm = TRUE),total2=sum(Yea,Nay)) %>% filter(total>0 & total2 >0) %>% mutate(y_pct = Yea/total,n_pct=Nay/total,nv_pct=NV/total, absent_pct=Absent/total,NV_A=(NV+Absent)/total,y_pct2 = Yea/(Yea+Nay),n_pct2 = Nay/(Yea+Nay),margin=y_pct2-n_pct2)

# create partisanship variables 
calc_partisanbillvotes <- calc_analyze_bill %>%   select(party,roll_call_id,bill_title,y_pct2,bill_number) %>% 
  pivot_wider(names_from = party,values_from=y_pct2,values_fill = NA,id_cols = c(roll_call_id,bill_title,bill_number)) %>% 
  mutate(
    DminusR = D - R,
    Partisan = NA_character_,
    GOP = NA_character_,
    DEM = NA_character_
    )

calc_partisanbillvotes <- calc_partisanbillvotes %>%
  mutate(
    Partisan = case_when(
      is.na(DminusR) ~ "Unclear",
      DminusR < -0.75 ~ "Very GOP",
      DminusR < -0.25 ~ "GOP",
      DminusR < 0 ~ "Somewhat GOP",
      DminusR == 0 ~ "Split",
      DminusR > 0.75 ~ "Very DEM",
      DminusR > 0.25 ~ "DEM",
      DminusR > 0 ~ "Somewhat DEM",
      TRUE ~ Partisan
    ),
    GOP = case_when(
      R == 1 ~ "GOP Unanimously Support",
      R > 0.9 ~ "GOP Very Strongly Support",
      R > 0.75 ~ "GOP Moderately Support",
      R > 0.5 ~ "GOP Support",
      R == 0.5 ~ "GOP Split",
      R < 0.1 ~ "GOP Very Strongly Oppose",
      R < 0.25 ~ "GOP Moderately Oppose",
      R < 0.5 ~ "GOP Oppose",
      R == 0 ~ "GOP Unanimously Oppose",
      TRUE ~ GOP
    ),
    DEM = case_when(
      D == 1 ~ "DEM Unanimously Support",
      D > 0.9 ~ "DEM Very Strongly Support",
      D > 0.75 ~ "DEM Strongly Support",
      D > 0.5 ~ "DEM Support",
      D == 0.5 ~ "DEM Split",
      D < 0.1 ~ "DEM Very Strongly Oppose",
      D < 0.25 ~ "DEM Moderately Oppose",
      D < 0.5 ~ "DEM Oppose",
      D == 0 ~ "DEM Unanimously Oppose",
      is.na(D) ~ "DEM No Votes",
      TRUE ~ DEM
    )
  )

###########################################
#                                         #  
# 2b) partisanship analysis               #
#                                         #
###########################################
# join detailed legislative votes with partisanship analysis, removing nulls, initialize and set defaults for calculated fields
calc_votes_partisanship <- calc_legislator_votes %>%
  filter(!is.na(roll_call_date)&total>0)
# %>% # select(roll_call_id, R, D, DminusR, Partisan, GOP, DEM), 
calc_votes_partisanship <- calc_votes_partisanship %>%
  left_join(
    calc_partisanbillvotes,
    by = 'roll_call_id'
  ) %>%
  filter(!is.na(D) & !is.na(R) & !is.na(DminusR))
calc_votes_partisanship <- calc_votes_partisanship %>% arrange(desc(abs(DminusR)))
calc_votes_partisanship <- calc_votes_partisanship %>%
  mutate(
    dem_majority = NA_character_,
    gop_majority = NA_character_,
    bill_alignment = NA_character_,
    priority_bills = "N"
  )

calc_votes_partisanship <- calc_votes_partisanship %>%
  mutate(
    dem_majority = case_when(
      D > 0.5 ~ "Y",
      D < 0.5 ~ "N",
      D == 0.5 ~ "Equal",
      TRUE ~ dem_majority
    ),
    gop_majority = case_when(
      R > 0.5 ~ "Y",
      R < 0.5 ~ "N",
      R == 0.5 ~ "Equal",
      TRUE ~ gop_majority
    )
  )

calc_votes_partisanship$priority_bills[abs(calc_votes_partisanship$DminusR)>.85] <- "Y"

calc_votes_partisanship <- calc_votes_partisanship %>%
  mutate(vote_with_dem_majority = ifelse(dem_majority == "Y" & vote_text=="Yea", 1, 0),
         vote_with_gop_majority = ifelse(gop_majority == "Y" & vote_text=="Yea", 1, 0),
         vote_with_neither = ifelse((dem_majority == "Y" & gop_majority == "Y" & vote_text=="Nay") |
                                      (dem_majority=="N" & gop_majority == "N" & vote_text=="Yea"),1,0),
         vote_with_dem_majority = ifelse((dem_majority == "Y" & vote_text == "Yea")|dem_majority=="N" & vote_text=="Nay", 1, 0),
         vote_with_gop_majority = ifelse((gop_majority == "Y" & vote_text == "Yea")|gop_majority=="N" & vote_text=="Nay", 1, 0),
         vote_with_neither = ifelse(
           (dem_majority == "Y" & gop_majority == "Y" & vote_text == "Nay") | (dem_majority == "N" & gop_majority == "N" & vote_text == "Yea"), 1, 0),
         voted_at_all = vote_with_dem_majority+vote_with_gop_majority+vote_with_neither,
         maverick_votes=ifelse((party=="D" & vote_text=="Yea" & dem_majority=="N" & gop_majority=="Y") |
                                 (party=="D" & vote_text=="Nay" & dem_majority=="Y" & gop_majority=="N") |
                                 (party=="R" & vote_text=="Yea" & gop_majority=="N" & dem_majority=="Y") |
                                 (party=="R" & vote_text=="Nay" & gop_majority=="Y" & dem_majority=="N"),1,0 ))

calc_votes_partisanship <- calc_votes_partisanship %>%
  mutate(
    bill_alignment = case_when(
      D == 0.5 | R == 0.5 ~ "at least one party even",
      D > 0.5 & R < 0.5 ~ "DEM",
      D < 0.5 & R > 0.5 ~ "GOP",
      D < 0.5 & R < 0.5 ~ "Both",
      D > 0.5 & R > 0.5 ~ "Both",
      TRUE ~ bill_alignment
    )
  )

calc_party_majority_votes <- calc_votes_partisanship %>% filter(party!=""& !is.na(party)) %>% 
  group_by(roll_call_id, party) %>%
  summarize(majority_vote = if_else(sum(vote_text == "Yea") > sum(vote_text == "Nay"), "Yea", "Nay"), .groups = 'drop') %>% 
  pivot_wider(names_from = party,values_from = majority_vote,id_cols = roll_call_id,values_fill = "NA",names_prefix = "vote_")

# workaround 6/27/24 replaced session_name with session, twice in the first filter below
p_partisanship <- calc_votes_partisanship %>%
  left_join(calc_party_majority_votes, by = c("roll_call_id")) %>%
  filter(!is.na(party)&party!="" & !grepl("2010",session,ignore.case=TRUE)& !is.na(session)) %>% 
  filter(vote_text=="Yea"|vote_text=="Nay") %>% 
  mutate(diff_party_vote_d = if_else(vote_text != vote_D, 1, 0),diff_party_vote_r = if_else(vote_text != vote_R, 1, 0),
         diff_both_parties = if_else(diff_party_vote_d == 1 & diff_party_vote_r == 1,1,0),
         diff_d_not_r=if_else(diff_party_vote_d==1 & diff_party_vote_r==0,1,0),
         diff_r_not_d=if_else(diff_party_vote_d==0&diff_party_vote_r==1,1,0),
         partisan_metric = ifelse(party=="R",diff_r_not_d,ifelse(party=="D",diff_d_not_r,NA)),
         pct_voted_for = scales::percent(pct_of_total)) %>% arrange(desc(partisan_metric)) %>% distinct()

# re-order data for better visualization
p_partisanship$roll_call_id = with(p_partisanship, reorder(roll_call_id, partisan_metric, sum))
p_partisanship$legislator_name = with(p_partisanship, reorder(legislator_name, partisan_metric, sum))

# creates an overall partisanship metric for each legislator, filters for dates >= 11/10/12?
# this is used later to sort the dataframe
calc_legislator_mean_partisanship <- p_partisanship %>%
  group_by(legislator_name) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    mean_partisan_metric=mean(partisan_metric, na.rm = TRUE),
    n_votes = n()
    ) %>%
  arrange(mean_partisan_metric,legislator_name) #create the sort based on partisan metric

###########################################
#                                         #  
# 3) STOPGAP HARDCODING                   #
#                                         #
###########################################
#6/28/24 this works fine, but should debug and find the problem upstream
p_partisanship$bill_number = p_partisanship$bill_number.x
p_partisanship$bill_title = p_partisanship$bill_title.x
p_partisanship <- p_partisanship %>%
 select(-bill_title.x,-bill_title.y,-bill_number.x,-bill_number.y)

#################################
#                               #  
# 04_TRANFORM.R                 #
#                               #
#################################

########################################
#                                      #  
# 1) create views                      #
#                                      #
########################################
# not sure this is used- there is no function parse_bill_sponsor?!
# bills_all_sponsor <- parse_bill_sponsor(text_paths_bills)
# primary_sponsors <- bills_all_sponsor %>% filter(sponsor_type_id == 1 & committee_sponsor == 0)

# trying to get rid of bill_detailed
# renamed votes_all to roll_calls_w_bill_info
roll_calls_detailed <- left_join(roll_calls,bills, by = "bill_id")
roll_calls_detailed <- roll_calls_detailed %>% mutate(
  pct_of_total = yea/total,
  n_present = yea+nay,
  pct_of_present = yea/n_present
)
roll_calls_detailed <- roll_calls_detailed %>% arrange(pct_of_present)

#TRY A NEW APPROACH XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
roll_calls_w_calc <- roll_calls %>% mutate(
  pct_of_total = yea/total,
  n_present = yea+nay,
  pct_of_present = yea/n_present
)
roll_calls_w_calc <- roll_calls_w_calc %>% arrange(pct_of_present)

#convert roll call id to character (not sure why)
legislator_votes <- legislator_votes %>% mutate(roll_call_id = as.character(roll_call_id))
roll_calls_w_calc <- roll_calls_w_calc %>% mutate(roll_call_id = as.character(roll_call_id))
roll_calls_detailed <- roll_calls_detailed %>% mutate(roll_call_id = as.character(roll_call_id))

#broke this 3-way join into two steps- first join legislator-votes with legislator details, then join with roll call details
temp_legislator_votes_detailed <- legislator_votes %>%
  inner_join(legislator_sessions, by = c("people_id", "session"))
temp_legislator_votes_detailed <- temp_legislator_votes_detailed %>%
  inner_join(roll_calls_detailed, by = c("roll_call_id", "session"))

################################
#                              #  
# 2) analyze and prep data     #
#                              #
################################

# primary key should at least be roll_call_id and party, so 2x the number of roll_calls minus anything filtered out
temp_analyze_bill <- temp_legislator_votes_detailed %>% group_by(party,roll_call_id,title,vote_text,number) %>% summarize(n=n()) %>% arrange(desc(n)) %>% pivot_wider(values_from = n,names_from = vote_text,values_fill = 0) %>% mutate(total=sum(Yea,NV,Absent,Nay,na.rm = TRUE),total2=sum(Yea,Nay)) %>% filter(total>0 & total2 >0) %>% mutate(y_pct = Yea/total,n_pct=Nay/total,nv_pct=NV/total, absent_pct=Absent/total,NV_A=(NV+Absent)/total,y_pct2 = Yea/(Yea+Nay),n_pct2 = Nay/(Yea+Nay),margin=y_pct2-n_pct2)

# create partisanship variables 
partisanbillvotes <- temp_analyze_bill %>%   select(party,roll_call_id,title,y_pct2,number) %>% 
  pivot_wider(names_from = party,values_from=y_pct2,values_fill = NA,id_cols = c(roll_call_id,title,number)) %>% 
  mutate(
    `D-R`=D-R,
    Partisan = NA_character_,
    GOP = NA_character_,
    DEM = NA_character_
    )

partisanbillvotes <- partisanbillvotes %>%
  mutate(
    Partisan = case_when(
      is.na(`D-R`) ~ "Unclear",
      `D-R` < -0.75 ~ "Very GOP",
      `D-R` < -0.25 ~ "GOP",
      `D-R` < 0 ~ "Somewhat GOP",
      `D-R` == 0 ~ "Split",
      `D-R` > 0.75 ~ "Very DEM",
      `D-R` > 0.25 ~ "DEM",
      `D-R` > 0 ~ "Somewhat DEM",
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
# 2b) leg_votes_partisanship analysis     #
#                                         #
###########################################
# join detailed legislative votes with partisanship analysis, removing nulls, initialize and set defaults for calculated fields
leg_votes_partisanship <- temp_legislator_votes_detailed %>% filter(!is.na(date)&total>0)
leg_votes_partisanship <- left_join(leg_votes_partisanship,partisanbillvotes, by = 'roll_call_id') %>% filter(!is.na(D)&!is.na(R)&!is.na(`D-R`))
leg_votes_partisanship <- leg_votes_partisanship %>% arrange(desc(abs(`D-R`)))
leg_votes_partisanship <- leg_votes_partisanship %>%
  mutate(
    dem_majority = NA_character_,
    gop_majority = NA_character_,
    bill_alignment = NA_character_,
    priority_bills = "N"
  )

leg_votes_partisanship <- leg_votes_partisanship %>%
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

leg_votes_partisanship$priority_bills[abs(leg_votes_partisanship$`D-R`)>.85] <- "Y"

leg_votes_partisanship <- leg_votes_partisanship %>%
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

leg_votes_partisanship <- leg_votes_partisanship %>%
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

temp_party_majority_votes <- leg_votes_partisanship %>% filter(party!=""& !is.na(party)) %>% 
  group_by(roll_call_id, party) %>%
  summarize(majority_vote = if_else(sum(vote_text == "Yea") > sum(vote_text == "Nay"), "Yea", "Nay"), .groups = 'drop') %>% 
  pivot_wider(names_from = party,values_from = majority_vote,id_cols = roll_call_id,values_fill = "NA",names_prefix = "vote_")

app_data <- leg_votes_partisanship %>%
  left_join(temp_party_majority_votes, by = c("roll_call_id")) %>%
  filter(!is.na(party)&party!="" & !grepl("2010",session_name,ignore.case=TRUE)& !is.na(session_name)) %>% 
  filter(vote_text=="Yea"|vote_text=="Nay") %>% 
  mutate(diff_party_vote_d = if_else(vote_text != vote_D, 1, 0),diff_party_vote_r = if_else(vote_text != vote_R, 1, 0),
         diff_both_parties = if_else(diff_party_vote_d == 1 & diff_party_vote_r == 1,1,0),
         diff_d_not_r=if_else(diff_party_vote_d==1 & diff_party_vote_r==0,1,0),
         diff_r_not_d=if_else(diff_party_vote_d==0&diff_party_vote_r==1,1,0),
         partisan_metric = ifelse(party=="R",diff_r_not_d,ifelse(party=="D",diff_d_not_r,NA)),
         pct_format = scales::percent(pct_of_total)) %>% arrange(desc(partisan_metric)) %>% distinct()

# re-order data for better visualization
app_data$roll_call_id = with(app_data, reorder(roll_call_id, partisan_metric, sum))
app_data$name = with(app_data, reorder(name, partisan_metric, sum))

# creates an overall partisanship metric for each legislator, filters for dates >= 11/10/12?
legislator_mean_partisanship <- app_data %>% group_by(name) %>% filter(date >= as.Date("11/10/2012")) %>% summarize(partisan_metric=mean(partisan_metric)) %>% arrange(partisan_metric,name) #create the sort based on partisan metric


### create the text to be displayed in the javascript interactive when hovering over votes ####
createHoverText <- function(numbers, descriptions, urls, pcts, vote_texts,descs,title,date, names, width = 100) {
  # Wrap the description text at the specified width
  wrapped_descriptions <- sapply(descriptions, function(desc) paste(strwrap(desc, width = width), collapse = "<br>"))
  
  # Combine the elements into a single string
  paste(
    names, " voted ", vote_texts, " on ", descs, " for bill ",numbers," - ",title," on ",date,"<br>",
    "Description: ", wrapped_descriptions, "<br>",
    "URL: ", urls, "<br>",
    pcts, " voted for this bill",
    sep = ""
  )
}

app_data$hover_text <- mapply(
  createHoverText,
  numbers = app_data$number,
  descs = app_data$desc,
  title=app_data$title,date=app_data$date,
  descriptions = app_data$description,
  urls = app_data$url,
  pcts = app_data$pct_format,
  vote_texts = app_data$vote_text,
  names = app_data$name,
  SIMPLIFY = FALSE  # Keep it as a list
)
app_data$hover_text <- sapply(app_data$hover_text, paste, collapse = " ")  # Collapse the list into a single string

app_data$partisan_metric2 <- ifelse(app_data$vote_with_neither == 1, 1,
                                        ifelse(app_data$maverick_votes == 1, 2, 0))

app_data$partisan_metric3 <- factor(app_data$partisan_metric2,
                                        levels = c(0, 1, 2),
                                        labels = c("With Party", "Independent Vote", "Maverick Vote"))
d_partisan_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric2)) %>% filter(max>=1)
r_partisan_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric2)) %>% filter(max>=1)

d_votes <- app_data %>% filter(party=="D") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(d_partisan_votes$roll_call_id))

r_votes <- app_data %>% filter(party=="R") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(r_partisan_votes$roll_call_id))

priority_votes <- app_data %>% filter(priority_bills=="Y") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1)

roll_call_to_number <- app_data %>%
  select(roll_call_id, year=session_year,number) %>%
  distinct() %>%
  arrange(desc(year),number,roll_call_id)

roll_call_to_number$number_year <- paste(roll_call_to_number$number,"-",roll_call_to_number$year)

app_data$roll_call_id <- factor(app_data$roll_call_id, levels = roll_call_to_number$roll_call_id)
app_data$name <- factor(app_data$name, levels = legislator_mean_partisanship$name)

y_labels <- setNames(roll_call_to_number$number_year, roll_call_to_number$roll_call_id)

app_data$final <- "N"
app_data$final[grepl("third",app_data$desc,ignore.case=TRUE)] <- "Y"

app_data$ballotpedia2 <- paste0("http://ballotpedia.org/",app_data$ballotpedia)

###########################################
#                                         #  
# 4) create and save views for Shiny app  #
#                                         #
###########################################
#this view will be saved in app_shiny.vote_patterns, for use by the Shiny app Voting Patterns
app_vote_patterns <- app_data %>%
  # Step 1: Calculate max partisan_metric2 for Democratic votes
  group_by(roll_call_id) %>%
  mutate(max_partisan_metric2 = if_else(party == "D", max(partisan_metric2, na.rm = TRUE), NA_real_)) %>%
  ungroup() %>%
  # Step 2: Mark roll_call_ids that meet the criteria for d_partisan_votes
  mutate(in_d_partisan_votes = !is.na(max_partisan_metric2) & max_partisan_metric2 >= 1) %>%
  # Step 3: Calculate y_pct and n_pct for Democratic votes
  group_by(roll_call_id, vote_text) %>%
  summarize(n = n(), .groups = 'drop') %>%
  tidyr::pivot_wider(names_from = vote_text, values_from = n, values_fill = 0) %>%
  mutate(
    y_pct = Yea / (Yea + Nay),
    n_pct = Nay / (Nay + Yea)
  ) %>%
  ungroup() %>%
  # Step 4: Filter based on y_pct and n_pct, and add d_vote column
  mutate(
    d_vote = if_else(
      party == "D" & in_d_partisan_votes & y_pct != 0 & y_pct != 1,
      1, 0
    )
  )

app_vote_patterns <- app_vote_patterns %>%
  filter(pct_of_present != 0 & pct_of_present != 1)
app_vote_patterns <- app_vote_patterns[,c("roll_call_id","partisan_metric2","hover_text","pct_of_present","year","role","final","party","name")]



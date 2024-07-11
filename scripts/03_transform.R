#################################
#                               #  
# 03_TRANFORM.R                 #
#                               #
#################################

########################################
#                                      #  
# create initial processed frames      #
#                                      #
########################################
p_bills <- t_bills %>%
  rename(
    bill_desc = description,
    bill_number = number,
    bill_title = title,
    bill_url = url
  )

p_sessions <- p_bills %>%
  select(session_id,session_name,session_string) %>%
  distinct() %>%
  mutate(
    session_year = as.numeric(substr(session_name,1,4)),
    session_biennium = paste(
      if_else(session_year %% 2 == 0, session_year - 1, session_year),
      if_else(session_year %% 2 == 0, session_year, session_year + 1),
      sep = "-"
    )
  )

p_roll_calls <- t_roll_calls %>%
  left_join(p_bills %>% select(bill_id, bill_title, bill_number, session_year, bill_url), by = "bill_id") %>%
  rename(
    roll_call_date = date,
    roll_call_desc = desc,
    roll_call_chamber = chamber,
    n_total = total,
  ) %>%
  mutate(
    pct_of_total = yea/n_total,
    n_present = yea+nay,
    pct_of_present = yea/n_present,
    roll_call_id = as.character(roll_call_id),
    final_vote = ifelse(grepl("third", roll_call_desc, ignore.case = TRUE), "Y", "N")
    ) %>%
  select(-chamber_id)

##############################
#                            #  
# create history tables      #
#                            #
##############################
# remove all non-legislators
hist_leg_sessions <- t_legislator_sessions %>%
  filter (party =='D' | party =='R') %>%
  rename(
    legislator_name = name
  ) %>%
  mutate(
    ballotpedia = paste0("http://ballotpedia.org/",ballotpedia),
    district_number = as.integer(str_extract(district, "\\d+")),
    chamber = case_when(
      role == "Sen" ~ "Senate",
      role == "Rep" ~ "House",
      TRUE ~ role
    ))
    
#convert roll call id to character (not sure why)
p_legislator_votes <- t_legislator_votes %>%
  mutate(roll_call_id = as.character(roll_call_id))  %>%
  inner_join(hist_leg_sessions %>% select(people_id, session, party, legislator_name), by = c("people_id", "session")) %>%
  inner_join(p_roll_calls, by = c("roll_call_id", "session"))

jct_bill_categories <- user_bill_categories %>%
  inner_join(p_sessions %>% select(session_year,session_id), by = 'session_year') %>%
  inner_join(p_bills %>% select(bill_number,session_id,bill_id), by=c('bill_number','session_id'))

user_incumbents_challenged <- user_incumbents_challenged %>%
  mutate(is_incumbent_primaried = TRUE)

t_districts_house$chamber= 'House'
t_districts_senate$chamber= 'Senate'

# add 2022 CVAP demographics (citizen voting age population)
calc_hist_district_demo_cvap <- rbind(t_districts_house, t_districts_senate) %>%
  rename(
    district_number=ID
  )  %>%
  mutate(
    pct_white= V_22_CVAP_White/V_22_CVAP_Total,
    pct_hispanic= V_22_CVAP_Hispanic/V_22_CVAP_Total,
    pct_black= V_22_CVAP_Black/V_22_CVAP_Total,
    pct_asian= V_22_CVAP_Asian/V_22_CVAP_Total,
    pct_napi = V_22_CVAP_Pacific/V_22_CVAP_Total,
    source_demo = 'CVAP',
    year_demo = 2022
  ) %>%
  select(chamber,district_number,pct_white, pct_hispanic, pct_black, pct_asian, pct_napi, source_demo, year_demo)

# add 2022 ACS demographics (American Community Survey)
calc_hist_district_demo_acs <- rbind(t_districts_house, t_districts_senate) %>%
  rename(
    district_number=ID
  )  %>%
  mutate(
    pct_white= T_22_ACS_White/T_22_ACS_Total,
    pct_hispanic= T_22_ACS_Hispanic/T_22_ACS_Total,
    pct_black= T_22_ACS_Black/T_22_ACS_Total,
    pct_asian= T_22_ACS_Asian/T_22_ACS_Total,
    pct_napi = (T_22_ACS_Pacific+T_22_ACS_Native)/T_22_ACS_Total,
    source_demo = 'ACS',
    year_demo = 2022
  ) %>%
  select(chamber,district_number,pct_white, pct_hispanic, pct_black, pct_asian, pct_napi, source_demo, year_demo)

hist_district_demo <- rbind(calc_hist_district_demo_acs,calc_hist_district_demo_cvap)

hist_district_elections <- rbind(t_districts_house, t_districts_senate) %>%
  rename(
    district_number=ID
  )  %>%
  left_join(user_incumbents_challenged %>%
              select(chamber, district_number, is_incumbent_primaried), by = c('chamber','district_number')) %>%
  replace_na(list(is_incumbent_primaried = FALSE)) %>%
  mutate(
    pct_D = E_16_20_COMP_Dem/E_16_20_COMP_Total,
    pct_R = E_16_20_COMP_Rep/E_16_20_COMP_Total,
    source_elec = 'Daves 2016-2020 composite'
  ) %>%
  select(chamber,district_number,pct_D,pct_R,source_elec,is_incumbent_primaried)

################################################
#                                              #  
# roll up history tables and statewide summary #
#                                              #
################################################
p_legislators <- hist_leg_sessions %>%
  group_by(legislator_name) %>%
  slice(1) %>%
  ungroup() %>%
  select(-role,-role_id,-party_id,-district, -committee_id, -committee_sponsor, -state_federal, -session)

# manually terminated two legislators
# Hawkings (House 35) who resigned on 6/30/23, people_id = 21981
# Fernandez-Barquin (House 118) who resigned on 6/16/23, people_id = 20023
temp_legislators_terminated <- data.frame(
  people_id = c(21981, 20023),
  termination_date = as.Date(c("2023-06-30", "2023-06-16"))
)

p_legislators <- p_legislators %>%
  left_join(temp_legislators_terminated, by="people_id")

# create p_districts based on demographic data and legislators
p_districts <- hist_district_demo %>%
  filter(source_demo=='CVAP',year_demo==2022) %>%
  inner_join(hist_district_elections, by=c('chamber','district_number')) %>%
  inner_join(
    p_legislators %>%
      filter (is.na(termination_date)) %>%
      select (people_id, chamber, district_number),
    by = c('chamber','district_number')
  ) %>%
  rename(incumb_people_id = people_id)

p_state_summary <- rbind(t_districts_house, t_districts_senate) %>%
  select(chamber,ID,E_16_20_COMP_Total, E_16_20_COMP_Dem, E_16_20_COMP_Rep, V_22_CVAP_Total, V_22_CVAP_White, V_22_CVAP_Hispanic, V_22_CVAP_Black, V_22_CVAP_Asian, V_22_CVAP_Native, V_22_CVAP_Pacific,
  ) %>%
  summarise(
    sum_white = sum(V_22_CVAP_White, na.rm = TRUE),
    sum_hispanic = sum(V_22_CVAP_Hispanic, na.rm = TRUE),
    sum_black = sum(V_22_CVAP_Black, na.rm = TRUE),
    sum_asian = sum(V_22_CVAP_Asian, na.rm = TRUE),
    sum_napi = sum(V_22_CVAP_Pacific, na.rm = TRUE),
    sum_total = sum(V_22_CVAP_Total, na.rm = TRUE),
    sum_D = sum(E_16_20_COMP_Dem, na.rm = TRUE),
    sum_R = sum(E_16_20_COMP_Rep, na.rm = TRUE),
    sum_E_total = sum(E_16_20_COMP_Total, na.rm = TRUE)
  ) %>%
  mutate(
    pct_white = sum_white / sum_total,
    pct_hispanic = sum_hispanic / sum_total,
    pct_black = sum_black / sum_total,
    pct_asian = sum_asian / sum_total,
    pct_napi = sum_napi / sum_total,
    pct_D = sum_D / sum_E_total,
    pct_R = sum_R / sum_E_total,
    source_elec = "Daves 2016-2020 composite"
  ) %>%
  select(pct_white, pct_hispanic, pct_black, pct_asian, pct_napi)
  


######################################
#                                    #  
# 2a) roll call partisanship analysis #
#                                    #
######################################

# primary key is roll_call_id, party
calc_rc_party_sum <- p_legislator_votes %>%
  group_by(party,roll_call_id,vote_text) %>%
  summarize(n=n()) %>% arrange(desc(n)) %>% 
  pivot_wider(values_from = n,names_from = vote_text,values_fill = 0) %>% 
  mutate(
    n_total=sum(Yea,Nay,NV,Absent,na.rm = TRUE),
    n_present=sum(Yea,Nay)
    ) %>% 
  filter(n_present >0) %>% 
  mutate(
    party_pct_of_present = Yea/(n_present),
    party_pct_of_present_nay = Nay/(n_present),
    #party_pct_of_total = Yea/(n_total),
    margin=party_pct_of_present-party_pct_of_present_nay,
    )

# primary key is roll_call_id. party counts are summarized
# create partisanship variables 
calc_rc_partisan <- calc_rc_party_sum %>%   select(party,roll_call_id,party_pct_of_present) %>% 
  pivot_wider(names_from = party,values_from=party_pct_of_present,values_fill = NA,id_cols = c(roll_call_id)) %>% 
  mutate(
    DminusR = D - R,
    Partisan = NA_character_,
    GOP = NA_character_,
    DEM = NA_character_
    )

calc_rc_partisan <- calc_rc_partisan %>%
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

#############################################
#                                           #  
# 2b) legislator vote partisanship analysis #
#                                           #
#############################################
# join detailed legislative votes with partisanship analysis, removing nulls, initialize and set defaults for calculated fields
calc_votes_partisan <- p_legislator_votes %>%
  filter(!is.na(roll_call_date)&n_total>0) 
#select(roll_call_id, R, D, DminusR, Partisan, GOP, DEM) 

calc_votes_partisan <- calc_votes_partisan %>%
  left_join(
    calc_rc_partisan,
    by = 'roll_call_id'
  ) %>%
  filter(!is.na(D) & !is.na(R) & !is.na(DminusR)) %>%
  arrange(desc(abs(DminusR))) %>%
  mutate(
    dem_majority = NA_character_,
    gop_majority = NA_character_,
    bill_alignment = NA_character_,
    priority_bills = "N"
  )

calc_votes_partisan <- calc_votes_partisan %>%
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

calc_votes_partisan$priority_bills[abs(calc_votes_partisan$DminusR)>.85] <- "Y"

calc_votes_partisan <- calc_votes_partisan %>%
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

calc_votes_partisan <- calc_votes_partisan %>%
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

######################################
#                                    #  
# 2c) roll call partisanship stats   #
#                                    #
######################################
calc_rc_party_majority <- calc_votes_partisan %>% filter(party!=""& !is.na(party)) %>% 
  group_by(roll_call_id, party) %>%
  summarize(majority_vote = if_else(sum(vote_text == "Yea") > sum(vote_text == "Nay"), "Yea", "Nay"), .groups = 'drop') %>% 
  pivot_wider(names_from = party,values_from = majority_vote,id_cols = roll_call_id,values_fill = "NA",names_prefix = "vote_")

# note that these can be calculated for yea/nay votes only, so I'm creating a new temp dataframe
# partisan vote type:
# 0 = with party
# 1 = against party
# 99 = against both parties (exclude from weighted count of partisanship)
calc_leg_votes_partisan <- calc_votes_partisan %>%
  left_join(calc_rc_party_majority, by = c("roll_call_id")) %>%
  filter(
    !is.na(party) & party != "" & 
      !grepl("2010", session, ignore.case = TRUE) & 
      !is.na(session) & 
      (vote_text == "Yea" | vote_text == "Nay")
  ) %>%
  mutate(diff_party_vote_d = if_else(vote_text != vote_D, 1, 0),diff_party_vote_r = if_else(vote_text != vote_R, 1, 0),
         diff_both_parties = if_else(diff_party_vote_d == 1 & diff_party_vote_r == 1,1,0),
         diff_d_not_r=if_else(diff_party_vote_d==1 & diff_party_vote_r==0,1,0),
         diff_r_not_d=if_else(diff_party_vote_d==0&diff_party_vote_r==1,1,0),
         #partisan_metric_a = ifelse(party=="R",diff_r_not_d,ifelse(party=="D",diff_d_not_r,NA)), #old defunct metric
         #partisan_metric_b = ifelse(vote_with_neither == 1, 1,ifelse(maverick_votes == 1, 2, 0)),
         partisan_vote_type = case_when(
           vote_with_neither == 1 ~ 99,
           maverick_votes == 1 ~ 1,
           TRUE ~ 0
         ),
         partisan_vote_weight = ifelse(partisan_vote_type == 99, NA,partisan_vote_type)
  )

calc_leg_votes_partisan <- calc_leg_votes_partisan %>%
  mutate(
    #pct_of_total = scales::percent(pct_of_total), # converts to percent format
    partisan_vote_desc = factor(partisan_vote_type,levels = c(0, 1, 99),labels = c("With Party", "Against Party", "Against Both Parties"))
)





####################################################
#                                                  #  
# calc mean partisanship for bills and legislators #
#                                                  #
####################################################
# creates an overall partisanship metric for each legislator, filters for dates >= 11/10/12 (data has some issues prior to that, per Andy)
# this is used later to sort the dataframe
calc_leg_mean_partisan <- calc_leg_votes_partisan %>%
  group_by(legislator_name) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    mean_partisanship=mean(partisan_vote_weight, na.rm = TRUE),
    n_votes_partisan = sum(!is.na(partisan_vote_weight))
    )

# could prolly clean up code by incorporating this calculation elsewhere
calc_roll_call_mean_partisan <- calc_leg_votes_partisan %>%
  group_by(roll_call_id) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    rc_mean_partisanship=mean(partisan_vote_weight, na.rm = TRUE),
    rc_n_votes_partisan = sum(!is.na(partisan_vote_weight))
  )
#################################################
#                                               #  
# add calculated fields to processed dataframes #
#                                               #
#################################################
# legislator mean partisanship
p_legislators <- p_legislators %>%
  left_join(calc_leg_mean_partisan, by='legislator_name')


# partisan votes
p_legislator_votes <- p_legislator_votes %>%
  left_join(calc_leg_votes_partisan %>%
              select(people_id,roll_call_id,partisan_vote_type),
            by = c('people_id','roll_call_id')
  )

# roll call summaries, 6271
p_roll_calls <- p_roll_calls %>%
  left_join(calc_rc_partisan %>%
              select(roll_call_id,R,D),
            by = 'roll_call_id'
  ) %>%
  left_join(calc_roll_call_mean_partisan %>%
              select(roll_call_id,rc_mean_partisanship,rc_n_votes_partisan),
            by = 'roll_call_id'
  ) %>%
  rename (
    R_pct_of_present = R,
    D_pct_of_present = D
  )

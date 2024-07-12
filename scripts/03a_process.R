#################################
#                               #  
# 03_TRANSFORM.R                 #
#                               #
#################################

########################################
#                                      #  
# create initial processed frames      #
#                                      #
########################################
# hist_leg_sessions, jct_bill_categories, p_bills, pl_legislator_votes, p_legislators, p_roll_calls, p_sessions, 

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

# manually terminated two legislators
# Hawkings (House 35) who resigned on 6/30/23, people_id = 21981
# Fernandez-Barquin (House 118) who resigned on 6/16/23, people_id = 20023
temp_legislators_terminated <- data.frame(
  people_id = c(21981, 20023),
  termination_date = as.Date(c("2023-06-30", "2023-06-16"))
)

p_legislators <- hist_leg_sessions %>%
  group_by(legislator_name) %>%
  slice(1) %>%
  ungroup() %>%
  left_join(temp_legislators_terminated, by="people_id") %>%
  select(-role,-role_id,-party_id,-district, -committee_id, -committee_sponsor, -state_federal, -session)

#not clear why roll call id was converted to character here, should be able to revert to integer
p_legislator_votes <- t_legislator_votes %>%
  mutate(roll_call_id = as.character(roll_call_id))  %>%
  inner_join(hist_leg_sessions %>%
               select(people_id, session, party, legislator_name), by = c("people_id", "session")) %>%
  inner_join(p_roll_calls, by = c("roll_call_id", "session"))  %>%
  inner_join(p_legislators %>%
               select (people_id, termination_date), by = "people_id")

jct_bill_categories <- user_bill_categories %>%
  inner_join(p_sessions %>% select(session_year,session_id), by = 'session_year') %>%
  inner_join(p_bills %>% select(bill_number,session_id,bill_id), by=c('bill_number','session_id'))

# user_incumbents_challenged <- user_incumbents_challenged %>%
#   mutate(is_incumbent_primaried = TRUE)

###################################
#                                 #  
# create history of demographics  #
#                                 #
###################################
# combine daves redistricting tables into one districts table
t_daves_districts_house$chamber= 'House'
t_daves_districts_senate$chamber= 'Senate'
calc_daves_districts_combined <- rbind(t_daves_districts_house, t_daves_districts_senate)

#define function to pull demographic group data based on field name prefix
get_demographics <- function(prefix, source_label, year) {
  calc_daves_districts_combined %>%
    rename(
      district_number = ID
    ) %>%
    mutate(
      n_white = !!sym(paste0(prefix, "White")),
      n_hispanic = !!sym(paste0(prefix, "Hispanic")),
      n_black = !!sym(paste0(prefix, "Black")),
      n_asian = !!sym(paste0(prefix, "Asian")),
      n_native = !!sym(paste0(prefix, "Native")),
      n_pacific = !!sym(paste0(prefix, "Pacific")),
      n_total_demo = !!sym(paste0(prefix, "Total")),
      pct_white = n_white / n_total_demo,
      pct_hispanic = n_hispanic / n_total_demo,
      pct_black = n_black / n_total_demo,
      pct_asian = n_asian / n_total_demo,
      pct_napi = (n_native + n_pacific) / n_total_demo,
      source_demo = source_label,
      year_demo = year
    ) %>%
    select(chamber, district_number, n_white, n_hispanic, n_black, n_asian, n_native, n_pacific, n_total_demo, pct_white, pct_hispanic, pct_black, pct_asian, pct_napi, source_demo, year_demo)
}

# get 2022 CVAP and 2022 ACS, then bind into one table
calc_hist_district_demo_cvap <- get_demographics("V_22_CVAP_", "CVAP", 2022)
calc_hist_district_demo_acs <- get_demographics("T_22_ACS_", "ACS", 2022)
hist_district_demo <- rbind(calc_hist_district_demo_cvap, calc_hist_district_demo_acs)

#######################################
#                                     #  
# create history of election results  #
#                                     #
#######################################
#define function to pull demographic group data based on field name prefix
get_election_results <- function(prefix, source_label, year) {
  calc_daves_districts_combined %>%
    rename(
      district_number = ID
    ) %>%
    mutate(
      n_Dem  = !!sym(paste0(prefix, "Dem")),
      n_Rep = !!sym(paste0(prefix, "Dem")),
      n_Total_Elec = !!sym(paste0(prefix, "Dem")),
      pct_D = n_Dem / n_Total_Elec,
      pct_R = n_Rep / n_Total_Elec,
      source_elec = source_label,
    ) %>%
    select(chamber,district_number,n_Dem, n_Rep, n_Total_Elec,pct_D,pct_R,source_elec)
}

# get election results, then bind into one table if necessary
hist_district_elections <- get_election_results("E_16_20_COMP_", "16_20_COMP")


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
# 2c) track vote partisan alignment  #
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
         #partisan_metric_b = ifelse(vote_with_neither == 1, 1,ifelse(maverick_votes == 1, 2, 0)), #this is really a weighting measure which could still be applied downstream
         partisan_vote_type = case_when(
           vote_with_neither == 1 ~ 99,
           maverick_votes == 1 ~ 1,
           TRUE ~ 0
         ),
         partisan_vote_desc = factor(partisan_vote_type,levels = c(0, 1, 99),labels = c("With Party", "Against Party", "Against Both Parties"))
  )

########################################################
#                                                      #  
# 2c) fold partisan vote alignment back into p frames  #
#                                                      #
########################################################
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
  rename (
    R_pct_of_present = R,
    D_pct_of_present = D
  )
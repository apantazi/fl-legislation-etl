#################################
#                               #  
# 04A_APP_settings.R             #
#                               #
#################################
# 5/19/25
# This script builds on processed data (p_* and hist_*,), responds to settings,
# then prepares queries (qry_*) for web applications and visualizations

##############################
#                            #  
# 1a) configure app settings #
#                            #
##############################
#I may want to move this to a settings.yaml file, to separate settings from the script code
available_demo_sources <- sort(unique(hist_district_demo$source_demo))
available_demo_years   <- sort(unique(hist_district_demo$year_demo))

cat("Available demographic sources:", paste(available_demo_sources, collapse = ", "), "\n")
default_src <- if ("CVAP" %in% available_demo_sources) "CVAP" else tail(available_demo_sources, 1)
src_prompt  <- paste0("Choose demographic source [", paste(available_demo_sources, collapse = "/"), "] (default: ", default_src, "): ")

user_src <- readline(src_prompt)
if (!(user_src %in% available_demo_sources)) user_src <- default_src
setting_demo_src <- user_src

cat("Available years for", setting_demo_src, ":", 
    paste(sort(unique(hist_district_demo$year_demo[hist_district_demo$source_demo == setting_demo_src])), collapse = ", "), "\n")

default_year <- if (2022 %in% available_demo_years) 2022 else max(available_demo_years)
year_prompt  <- paste0("Choose year (default: ", default_year, "): ")
user_year <- as.integer(readline(year_prompt))
if (is.na(user_year) || !(user_year %in% available_demo_years)) user_year <- default_year
setting_demo_year <- user_year

cat("Selected demographic source:", setting_demo_src, "| year:", setting_demo_year, "\n")


available_elections <- sort(unique(hist_district_elections$source_elec))
default_elections <- c("20_PRES", "22_GOV", "24_PRES")
default_elections <- default_elections[default_elections %in% available_elections]

cat("Available elections for district lean:", paste(available_elections, collapse = ", "), "\n")
cat("Default: ", paste(default_elections, collapse = ", "), "\n")

election_prompt <- paste0("Enter election codes to use (comma-separated, default: ", paste(default_elections, collapse = ", "), "): ")
user_elections_raw <- readline(election_prompt)
user_elections <- trimws(strsplit(user_elections_raw, ",")[[1]])
if (length(user_elections_raw) == 0 || all(!user_elections %in% available_elections)) user_elections <- default_elections

cat("\nYou selected the following elections:\n")
print(user_elections)
weights <- numeric(length(user_elections))
default_weights <- if (length(user_elections) == 3 && all(user_elections == c("20_PRES","22_GOV","24_PRES"))) {
  c(0.25, 0.25, 0.5)
} else {
  rep(1/length(user_elections), length(user_elections))
}

for (i in seq_along(user_elections)) {
  repeat {
    prompt <- paste0("Enter weight for ", user_elections[i], " (default: ", default_weights[i], "): ")
    user_weight <- readline(prompt)
    if (user_weight == "") {
      weight_val <- default_weights[i]
      break
    }
    weight_val <- suppressWarnings(as.numeric(user_weight))
    if (!is.na(weight_val) && weight_val >= 0) {
      break
    } else {
      cat("  Please enter a valid non-negative number (or press Enter for default).\n")
    }
  }
  weights[i] <- weight_val
}

# Normalize weights to sum to 1
if (sum(weights) > 0) {
  weights <- weights / sum(weights)
}

setting_district_lean <- data.frame(
  source = user_elections,
  weight = weights,
  stringsAsFactors = FALSE
)
cat("\nSelected elections:", paste(setting_district_lean$source, collapse = ", "), "\n")
cat("Weights (normalized to sum to 1):", paste(round(setting_district_lean$weight, 3), collapse = ", "), "\n")


available_loyalty_metrics <- c("partisan_cross", "for_against", "for_against_indy")
cat("Available party loyalty metrics:", paste(available_loyalty_metrics, collapse = ", "), "\n")
loyalty_prompt <- paste0("Choose party loyalty metric (default: partisan_cross): ")
user_loyalty <- readline(loyalty_prompt)
if (!(user_loyalty %in% available_loyalty_metrics)) user_loyalty <- "partisan_cross"
setting_party_loyalty <- user_loyalty
cat("Selected party loyalty metric:", setting_party_loyalty, "\n")


#####################################
#                                   #  
# 2) calculate partisanship stats   #
#                                   #
#####################################
# calculate party loyalty based on setting_party_loyalty
# and fold into qry_leg_votes
qry_leg_votes <- p_legislator_votes %>%
  mutate(
    party_loyalty_weight = case_when(
      setting_party_loyalty == "partisan_cross" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "partisan_cross"
      ),
      setting_party_loyalty == "for_against" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Party Line Bipartisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "for_against"
      ),
      setting_party_loyalty == "for_against_indy" ~ case_when(
        partisan_vote_type == "Party Line Partisan" ~ 1,
        partisan_vote_type == "Party Line Bipartisan" ~ 1,
        partisan_vote_type == "Cross Party" ~ 0,
        partisan_vote_type == "Against Both Parties" ~ 0.5,
        TRUE ~ NA_real_  # Default case for unmatched conditions within "for_against_indy"
      )
    )
  )

# calculate mean legislator-level partisan vote weight for ALL their votes
# filters for dates >= 11/10/12 (data has some issues prior to that, per Andrew)
calc_mean_partisan_leg <- qry_leg_votes %>%
  group_by(legislator_name) %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  summarize(
    leg_party_loyalty=mean(party_loyalty_weight, na.rm = TRUE),
    leg_party_independence=mean(vote_against_both,na.rm=TRUE),
    leg_n_votes_denom_loyalty = sum(!is.na(party_loyalty_weight)),
    leg_n_votes_party_line_partisan = sum(partisan_vote_type == "Party Line Partisan", na.rm = TRUE),
    leg_n_votes_party_line_bipartisan = sum(partisan_vote_type == "Party Line Bipartisan", na.rm = TRUE),
    leg_n_votes_cross_party = sum(partisan_vote_type == "Cross Party", na.rm = TRUE),
    leg_n_votes_absent_nv = sum(partisan_vote_type == "Absent/NV", na.rm = TRUE),
    leg_n_votes_independent = sum(partisan_vote_type == "Against Both Parties", na.rm = TRUE),
    leg_n_votes_other = sum(partisan_vote_type == "Other", na.rm = TRUE),
    leg_n_votes_missing = sum(is.na(partisan_vote_type))
  )

# old method, ungrouped. to delete after app01 is no longer dependent on rc_mean_partisanship
calc_rc_unity_ungrouped_OLD <- qry_leg_votes %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  group_by(roll_call_id) %>%
  summarize(
    rc_n_votes_party_line_partisan = sum(partisan_vote_type=="Party Line Partisan", na.rm = TRUE),
    rc_n_votes_party_line_bipartisan = sum(partisan_vote_type=="Party Line Bipartisan", na.rm = TRUE),
    rc_n_votes_cross_party= sum(partisan_vote_type=="Cross Party", na.rm = TRUE),
    rc_n_votes_absent_nv = sum(partisan_vote_type == "Absent/NV", na.rm = TRUE),
    rc_n_votes_independent = sum(partisan_vote_type=="Against Both Parties", na.rm = TRUE),
    rc_n_votes_other= sum(partisan_vote_type=="Other", na.rm = TRUE),
    .groups = 'drop'  # To avoid grouping on output if not needed
  ) %>%
  mutate(
    rc_with_party = (rc_n_votes_party_line_partisan + rc_n_votes_party_line_bipartisan),
    rc_against_party = (rc_n_votes_cross_party + rc_n_votes_independent),
    rc_mean_partisanship = rc_with_party/(rc_with_party + rc_against_party)
  ) %>%
  select(roll_call_id,rc_mean_partisanship)

# calculate mean roll-call-level partisan vote weight by party
calc_mean_partisan_rc_by_party <- qry_leg_votes %>%
  filter(roll_call_date >= as.Date("11/10/2012")) %>%
  group_by(roll_call_id, party) %>%
  summarize(
    rc_n_votes_party_line_partisan = sum(partisan_vote_type=="Party Line Partisan", na.rm = TRUE),
    rc_n_votes_party_line_bipartisan = sum(partisan_vote_type=="Party Line Bipartisan", na.rm = TRUE),
    rc_n_votes_cross_party= sum(partisan_vote_type=="Cross Party", na.rm = TRUE),
    rc_n_votes_absent_nv = sum(partisan_vote_type == "Absent/NV", na.rm = TRUE),
    rc_n_votes_independent = sum(partisan_vote_type=="Against Both Parties", na.rm = TRUE),
    rc_n_votes_other= sum(partisan_vote_type=="Other", na.rm = TRUE),
    .groups = 'drop'  # To avoid grouping on output if not needed
  ) %>%
  mutate(
    rc_with_party = (rc_n_votes_party_line_partisan + rc_n_votes_party_line_bipartisan),
    rc_against_party = (rc_n_votes_cross_party + rc_n_votes_independent),
    rc_mean_partisanship = rc_with_party/(rc_with_party + rc_against_party)
  ) %>%
  select(roll_call_id,party,rc_mean_partisanship)

calc_rc_party_unity <- calc_mean_partisan_rc_by_party %>%
  pivot_wider(
    names_from = party,
    values_from = rc_mean_partisanship,
    names_prefix = "rc_unity_"
  )

# roll call summaries
qry_roll_calls <- p_roll_calls %>%
  left_join(calc_rc_party_unity,
            by = 'roll_call_id'
  ) %>%
  left_join(calc_rc_unity_ungrouped_OLD,
            by = 'roll_call_id'
  )

###########################
#                         #  
# 3a) create districts query  #
#                         #
###########################


# create qry_districts based on setting_demo_src, setting_demo_year, setting_district_lean
# and incorporating partisanship metrics
elections_wide <- hist_district_elections %>%
  filter(source_elec %in% setting_district_lean$source) %>%
  select(chamber, district_number, source_elec, pct_D, pct_R) %>%
  pivot_wider(
    names_from = source_elec,
    values_from = c(pct_D, pct_R),
    names_sep = "_"
  )

calc_elections_weighted <- hist_district_elections %>%
  inner_join(setting_district_lean, by = c("source_elec" = "source"))

calc_elections_avg <- calc_elections_weighted %>%
  group_by(chamber, district_number) %>%
  summarize(
    avg_pct_D = sum(pct_D * weight) / sum(weight),
    avg_pct_R = sum(pct_R * weight) / sum(weight)
  ) %>%
  mutate(
    avg_party_lean = ifelse(avg_pct_D > avg_pct_R, 'D', 'R'),
    avg_party_lean_points_abs = round(abs(avg_pct_R - avg_pct_D) * 100, 1),
    avg_party_lean_points_R = round((avg_pct_R - avg_pct_D) * 100, 1)
  )


# initial filtering for incumbent legislators
qry_legislators_incumbent <- p_legislators %>%
  filter(is.na(termination_date)) %>%
  arrange(people_id, desc(session_id)) %>%
  distinct(people_id, chamber, session_id, .keep_all = TRUE)

duplicates_in_incumbents <- qry_legislators_incumbent %>%
  dplyr::group_by(chamber, district_number) %>%
  dplyr::filter(n() > 1) %>%
  dplyr::ungroup()

senate_dupes <- qry_legislators_incumbent %>%
  filter(chamber == "Senate") %>%
  group_by(district_number) %>%
  filter(n() > 1) %>%
  ungroup()

if (nrow(senate_dupes) > 0) {
  cat("Deduplicating Senate districts (keeping only the latest by session)...\n")
  # Keep only the most recent session_id for each senator
  senate_clean <- qry_legislators_incumbent %>%
    filter(chamber == "Senate") %>%
    arrange(desc(session_id)) %>%
    group_by(district_number) %>%
    slice(1) %>%
    ungroup()
  # Keep all House members (no deduplication)
  house_clean <- qry_legislators_incumbent %>%
    filter(chamber == "House")
  # Bind together
  qry_legislators_incumbent <- bind_rows(senate_clean, house_clean)
} else {
  # No deduplication needed; keep as is
}

qry_districts <- hist_district_demo %>%
  filter(source_demo==setting_demo_src,year_demo==setting_demo_year) %>%
  inner_join(
    calc_elections_avg,
    by=c('chamber','district_number')) %>%
  inner_join(
    elections_wide,
    by = c('chamber', 'district_number')
  ) %>%
  inner_join(
    qry_legislators_incumbent %>%
      select (people_id, chamber, district_number),
    by = c('chamber','district_number')
  ) %>%
  rename(incumb_people_id = people_id) %>% 
  distinct(district_number, chamber, .keep_all = TRUE)


duplicate_districts <- qry_districts %>%
  dplyr::group_by(chamber, district_number,source_demo) %>%
  dplyr::filter(n() > 1) %>%
  dplyr::ungroup()


#rank senate partisanship
calc_dist_house_ranks <- qry_districts %>%
  filter(
    chamber == "House"
  ) %>%
  arrange(desc(avg_party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(avg_party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)


#rank house partisanship
calc_dist_senate_ranks <- qry_districts %>%
  filter(
    chamber == "Senate"
  ) %>%
  arrange(desc(avg_party_lean_points_R)) %>%
  mutate(rank_partisan_dist_R = row_number()) %>%
  arrange(avg_party_lean_points_R) %>%
  mutate(rank_partisan_dist_D = row_number()) %>%
  select (district_number, chamber, rank_partisan_dist_R, rank_partisan_dist_D)

calc_dist_ranks <- rbind(calc_dist_senate_ranks,calc_dist_house_ranks)

qry_districts <- qry_districts %>%
  left_join(calc_dist_ranks, by = c('district_number','chamber'))

# summarize statewide
qry_state_summary <- qry_districts %>%
  summarise(
    sum_white = sum(n_white, na.rm = TRUE),
    sum_hispanic = sum(n_hispanic, na.rm = TRUE),
    sum_black = sum(n_black, na.rm = TRUE),
    sum_asian = sum(n_asian, na.rm = TRUE),
    sum_pacific = sum(n_pacific, na.rm = TRUE),
    sum_native = sum(n_native, na.rm = TRUE),
    sum_total_demo = sum(n_total_demo, na.rm = TRUE)
    # sum_D = sum(n_Dem, na.rm = TRUE),
    # sum_R = sum(n_Rep, na.rm = TRUE),
    # sum_Total_Elec = sum(n_Total_Elec, na.rm = TRUE)
  ) %>%
  mutate(
    pct_white = sum_white / sum_total_demo,
    pct_hispanic = sum_hispanic / sum_total_demo,
    pct_black = sum_black / sum_total_demo,
    pct_asian = sum_asian / sum_total_demo,
    pct_napi = (sum_pacific + sum_native) / sum_total_demo,
    # pct_D = sum_D / sum_Total_Elec,
    # pct_R = sum_R / sum_Total_Elec
    #source_elec = setting_district_lean
  )

#############################
#                           #  
# 3b) create legislators query  #
#                           #
#############################

# continue building out incumbent legislators query
qry_legislators_incumbent <- qry_legislators_incumbent %>%
  left_join(calc_mean_partisan_leg, by='legislator_name') %>%
  mutate(
    setting_party_loyalty = setting_party_loyalty # add setting in here for future reference
  )

# calculate legislator ranks for each party and for each chamber
calculate_leg_ranks <- function(data, chamber, party, rank_column) {
  data %>%
    filter(chamber == !!chamber, party == !!party) %>%
    arrange(desc(leg_party_loyalty), desc(leg_n_votes_denom_loyalty)) %>%
    mutate(!!rank_column := row_number()) %>%
    select(people_id, district_number, chamber, party, !!rank_column)
}
rank_independence <- function(data, chamber, party_filter = NULL,
                              rank_col = "rank_independent_all") {
  d <- data %>% filter(chamber == !!chamber)
  if (!is.null(party_filter)) {d <- d %>% filter(party == !!party_filter)}
  d %>%                                   # higher share ⇒ higher rank number (1 = most independent)
    arrange(desc(leg_party_independence), desc(leg_n_votes_denom_loyalty)) %>% mutate(!!rank_col := row_number()) %>% select(people_id, !!rank_col)
}

calc_leg_house_R_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "House", "R", "rank_partisan_leg_R")
calc_leg_house_D_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "House", "D", "rank_partisan_leg_D")
calc_leg_senate_R_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "Senate", "R", "rank_partisan_leg_R")
calc_leg_senate_D_ranks <- calculate_leg_ranks(qry_legislators_incumbent, "Senate", "D", "rank_partisan_leg_D")

ind_house_all  <- rank_independence(qry_legislators_incumbent, "House")
ind_senate_all <- rank_independence(qry_legislators_incumbent, "Senate")
ind_house_R <- rank_independence(qry_legislators_incumbent, "House", "R","rank_independent_R")
ind_house_D <- rank_independence(qry_legislators_incumbent, "House", "D","rank_independent_D")
ind_senate_R <- rank_independence(qry_legislators_incumbent, "Senate", "R","rank_independent_R")
ind_senate_D <- rank_independence(qry_legislators_incumbent, "Senate", "D","rank_independent_D")
calc_indep_ranks <- bind_rows(
  ind_house_all,  ind_senate_all,
  ind_house_R,    ind_house_D,
  ind_senate_R,   ind_senate_D
) %>%
  group_by(people_id) %>%
  summarise(
    rank_independent_all = {v <- max(as.double(rank_independent_all), na.rm=TRUE); if(is.finite(v)) as.integer(v) else NA_integer_},
    rank_independent_R   = {v <- max(as.double(rank_independent_R),   na.rm=TRUE); if(is.finite(v)) as.integer(v) else NA_integer_},
    rank_independent_D   = {v <- max(as.double(rank_independent_D),   na.rm=TRUE); if(is.finite(v)) as.integer(v) else NA_integer_},
    .groups = "drop"
  )

qry_legislators_incumbent <- qry_legislators_incumbent %>%
  left_join(calc_indep_ranks, by = "people_id")

# Bind the House and Senate R ranks together
calc_leg_R_ranks <- bind_rows(calc_leg_house_R_ranks, calc_leg_senate_R_ranks)
calc_leg_D_ranks <- bind_rows(calc_leg_house_D_ranks, calc_leg_senate_D_ranks)
calc_leg_ranks <- bind_rows(calc_leg_R_ranks, calc_leg_D_ranks)

qry_legislators_incumbent <- qry_legislators_incumbent %>%
  left_join(calc_leg_ranks, by = c('people_id','district_number','chamber','party')) %>% 
  distinct(people_id, session_id,chamber, .keep_all = TRUE)

###########################
#                         #  
# 3c) create bills query  #
#                         #
###########################

# create simple queries with unaltered views of processed data
qry_bills <- p_bills

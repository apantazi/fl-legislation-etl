#' Process Legislation Data
#'
#' Cleans and processes parsed LegiScan data, optionally enriching with external datasets.
#'
#' @param parsed_data List containing `bills`, `legislators`, `roll_calls`, `votes` (output of `parse_legiscan_json`).
#' @param legislator_events Optional dataframe containing legislator termination/event data.
#' @param district_demographics Optional processed dataframe of district demographics.
#' @param election_results Optional processed dataframe of election results.
#' @importFrom dplyr rename select distinct mutate if_else left_join filter group_by summarize ungroup slice arrange case_when inner_join desc bind_rows pivot_wider n
#' @importFrom stringr str_extract
#' @export
process_legislation_data <- function(parsed_data, 
                                     legislator_events = NULL, 
                                     district_demographics = NULL,
                                     election_results = NULL) {
  
  t_bills <- parsed_data$bills
  t_legislator_sessions <- parsed_data$legislators
  t_roll_calls <- parsed_data$roll_calls
  t_legislator_votes <- parsed_data$votes
  
  message("Processing bills and sessions...")
  # 1. Process Bills
  p_bills <- t_bills %>%
    dplyr::rename(
      bill_desc = description,
      bill_number = number,
      bill_title = title,
      bill_url = url
    )
  
  # 2. Process Sessions
  p_sessions <- p_bills %>%
    dplyr::select(session_id, session_name, session, two_year_period) %>%
    dplyr::distinct() %>%
    dplyr::mutate(
      session_year = as.numeric(stringr::str_extract(session_name, "\\d{4}")),
      session_biennium = paste(
        dplyr::if_else(session_year %% 2 == 0, session_year - 1, session_year),
        dplyr::if_else(session_year %% 2 == 0, session_year, session_year + 1),
        sep = "-"
      )
    )
  
  message("Processing roll calls...")
  # 3. Process Roll Calls
  # roll_call_id should remain as an integer
  p_roll_calls <- t_roll_calls %>%
    dplyr::left_join(p_bills %>% dplyr::select(bill_id, bill_title, bill_number, session_year, bill_url), by = "bill_id") %>%
    dplyr::rename(
      roll_call_date = date,
      roll_call_desc = desc,
      roll_call_chamber = chamber,
      n_total = total
    ) %>%
    dplyr::mutate(
      pct_of_total = yea/n_total,
      n_present = yea+nay,
      pct_of_present = yea/n_present,
      final_vote = ifelse(grepl("third", roll_call_desc, ignore.case = TRUE), "Y", "N")
    ) %>%
    dplyr::select(-chamber_id)
  
  message("Processing legislators...")
  # 4. Process Legislators
  # remove all non-legislators (D/R only for now, can expand later)
  hist_leg_sessions <- t_legislator_sessions %>%
    dplyr::filter(party %in% c('D', 'R')) %>%
    dplyr::rename(legislator_name = name) %>%
    dplyr::mutate(
      district_number = as.integer(stringr::str_extract(district, "\\d+")),
      chamber = dplyr::case_when(
        role == "Sen" ~ "Senate",
        role == "Rep" ~ "House",
        TRUE ~ role
      )) %>%
    dplyr::distinct(people_id, session, .keep_all = TRUE)
  
  # Handle termination if events provided
  if (!is.null(legislator_events) && nrow(legislator_events) > 0) {
    # Expects columns: event, chamber, district_number, last_name, date, temp_name
    # This is adhering to the specific USER google sheet structure.
    # We might want to generalize this or rely on user to pass a cleaner termination df.
    # For now, we assume user passes the raw sheet data.
    
    if (all(c("event", "chamber", "district_number", "last_name", "date") %in% names(legislator_events))) {
       calc_leg_terminated <- legislator_events %>% 
        dplyr::filter(event == "terminated") %>%
        dplyr::left_join(hist_leg_sessions, by = c('chamber', 'district_number', 'last_name')) %>%
        dplyr::mutate(termination_date = date, temp_name = last_name) %>%
        dplyr::select(people_id, termination_date, temp_name) %>%
        dplyr::group_by(people_id) %>%
        dplyr::summarize(
          termination_date = max(termination_date, na.rm = TRUE),
          temp_name = dplyr::first(temp_name)
        ) %>%
        dplyr::ungroup()
       
       # Join back
       # Note: This join logic in original script was a bit specific.
       # We'll just left join termination_date.
    } else {
      warning("legislator_events provided but missing required columns. Skipping termination processing.")
      calc_leg_terminated <- data.frame(people_id = integer(), termination_date = as.Date(character()))
    }
  } else {
    calc_leg_terminated <- data.frame(people_id = integer(), termination_date = as.Date(character()))
  }

  p_legislators <- hist_leg_sessions %>%
    dplyr::left_join(p_sessions %>% dplyr::select(session, session_id), by = "session") %>%
    dplyr::arrange(people_id, dplyr::desc(session_id)) %>% 
    dplyr::group_by(people_id) %>%
    dplyr::slice(1) %>%
    dplyr::ungroup() %>%
    dplyr::select(-role, -role_id, -party_id, -district, -committee_id, -committee_sponsor, -state_federal, -session)
  
  if (nrow(calc_leg_terminated) > 0) {
    p_legislators <- p_legislators %>%
      dplyr::left_join(calc_leg_terminated, by = "people_id") 
  } else {
    p_legislators$termination_date <- NA
  }

  message("Processing votes and partisanship...")
  # 5. Process Legislator Votes & Partisanship
  p_legislator_votes <- t_legislator_votes %>%
    dplyr::inner_join(hist_leg_sessions %>%
                        dplyr::select(people_id, session, party, legislator_name), by = c("people_id", "session")) %>%
    dplyr::inner_join(p_roll_calls, by = c("roll_call_id", "session"))
    
    # Note: original script joined p_legislators termination_date here too.
    # We can skip for now unless needed for partisanship.
  
  # Partisanship Analysis
  # primary key is roll_call_id, party
  calc_rc01_by_party <- p_legislator_votes %>%
    dplyr::group_by(party, roll_call_id, vote_text) %>%
    dplyr::summarize(n = dplyr::n(), .groups = "drop") %>% 
    dplyr::arrange(dplyr::desc(n)) %>% 
    tidyr::pivot_wider(values_from = n, names_from = vote_text, values_fill = 0) 
  
  # Ensure all columns exist
  for(col in c("Yea", "Nay", "NV", "Absent")) {
    if (!col %in% names(calc_rc01_by_party)) calc_rc01_by_party[[col]] <- 0
  }

  calc_rc01_by_party <- calc_rc01_by_party %>%
    dplyr::mutate(
      n_total = sum(Yea, Nay, NV, Absent, na.rm = TRUE),
      n_present = sum(Yea, Nay)
    ) %>%
    dplyr::mutate(
      party_pct_of_present = Yea/(n_present),
    ) %>%
    dplyr::select(party, roll_call_id, party_pct_of_present, n_present)

  calc_rc02_partisan_pivot <- calc_rc01_by_party %>%
    tidyr::pivot_wider(names_from = party, values_from = party_pct_of_present, values_fill = NA, id_cols = c(roll_call_id)) %>% 
    dplyr::mutate(
      dem_majority = dplyr::case_when(
        D > 0.5 ~ "Y",
        D < 0.5 ~ "N",
        D == 0.5 ~ "Equal",
        TRUE ~ NA_character_
      ),
      gop_majority = dplyr::case_when(
        R > 0.5 ~ "Y",
        R < 0.5 ~ "N",
        R == 0.5 ~ "Equal",
        TRUE ~ NA_character_
      )
    )
  
  # Join partisanship to votes
  calc_votes01 <- p_legislator_votes %>%
    dplyr::left_join(calc_rc02_partisan_pivot, by = 'roll_call_id') %>%
    dplyr::filter(!is.na(D) & !is.na(R))

  calc_votes02 <- calc_votes01 %>%
    dplyr::mutate(
      vote_with_dem_majority = ifelse((dem_majority == "Y" & vote_text == "Yea")|dem_majority=="N" & vote_text=="Nay", 1, 0),
      vote_with_gop_majority = ifelse((gop_majority == "Y" & vote_text == "Yea")|gop_majority=="N" & vote_text=="Nay", 1, 0),
      vote_against_both = ifelse(
        (dem_majority == "Y" & gop_majority == "Y" & vote_text == "Nay") | (dem_majority == "N" & gop_majority == "N" & vote_text == "Yea"), 1, 0),
      voted_at_all = (vote_with_dem_majority+vote_with_gop_majority+vote_against_both)>=1,
      vote_cross_party=ifelse(
        (party=="D" & vote_text=="Yea" & dem_majority=="N" & gop_majority=="Y") |
          (party=="D" & vote_text=="Nay" & dem_majority=="Y" & gop_majority=="N") |
          (party=="R" & vote_text=="Yea" & gop_majority=="N" & dem_majority=="Y") |
          (party=="R" & vote_text=="Nay" & gop_majority=="Y" & dem_majority=="N"),
        1,0 ),
      vote_party_line = ifelse(
        (vote_with_dem_majority & party == "D")|
          (vote_with_gop_majority & party == "R")
        , 1, 0)
    )

  calc_votes03 <- calc_votes02 %>%
    dplyr::mutate(
      partisan_vote_type = dplyr::case_when(
        vote_against_both == 1 ~ "Against Both Parties",
        vote_cross_party == 1 ~ "Cross Party",
        party=="D" & vote_with_dem_majority == 1 & vote_with_gop_majority == 0 ~ "Party Line Partisan",
        party=="R" & vote_with_dem_majority == 0 & vote_with_gop_majority == 1 ~ "Party Line Partisan",
        vote_party_line == 1 ~ "Party Line Bipartisan",
        vote_text == "NV" ~ "Absent/NV",
        vote_text == "Absent" ~ "Absent/NV",
        TRUE ~ "Other"
      ) %>% 
        factor(levels = c("Against Both Parties", "Cross Party", "Party Line Partisan", "Party Line Bipartisan", "Absent/NV", "Other"))
    )

  # Finalize p_legislator_votes
  p_legislator_votes <- p_legislator_votes %>%
    dplyr::left_join(calc_votes03 %>%
                       dplyr::select(people_id, roll_call_id, partisan_vote_type, vote_against_both, vote_with_dem_majority, vote_with_gop_majority, vote_cross_party, vote_party_line, voted_at_all),
                     by = c('people_id','roll_call_id')
    ) %>% dplyr::distinct()

  # Finalize roll calls with partisan stats
  p_roll_calls <- p_roll_calls %>%
    dplyr::left_join(calc_rc02_partisan_pivot %>%
                       dplyr::select(roll_call_id, R, D),
                     by = 'roll_call_id'
    ) %>%
    dplyr::rename(
      R_pct_of_present = R,
      D_pct_of_present = D
    )

  return(list(
    bills = p_bills,
    sessions = p_sessions,
    roll_calls = p_roll_calls,
    legislators = p_legislators,
    legislator_votes = p_legislator_votes,
    hist_leg_sessions = hist_leg_sessions
  ))
}

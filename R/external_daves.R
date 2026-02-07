#' Parse Dave's Redistricting Data
#'
#' Cleaning functions for Dave's Redistricting App (DRA) export data.
#'
#' @param combined_df Dataframe containing combined House and Senate district data (raw from DRA).
#' @importFrom dplyr rename mutate select
#' @importFrom rlang sym !!
#' @export
parse_daves_demographics <- function(combined_df) {
  
  # Identify prefixes like T_22_ACS_ or V_22_CVAP_
  demo_prefixes <- grep("^(T|V)_\\d{2}_(ACS|CVAP|CENS)_Total$", names(combined_df), value = TRUE)
  demo_prefixes <- gsub("Total$", "", demo_prefixes)
  
  list_df_demos <- lapply(demo_prefixes, function(prefix) {
    # Extract year and source from prefix
    # e.g. T_22_ACS_ -> 22 -> 2022
    parts <- unlist(strsplit(gsub("_$", "", prefix), "_"))
    year_short <- as.integer(parts[2])
    year <- ifelse(year_short < 100, 2000 + year_short, year_short) # Assumption
    source_label <- parts[3]
    
    get_demographics(combined_df, prefix, source_label, year)
  })
  
  do.call(rbind, list_df_demos)
}

#' @export
parse_daves_elections <- function(combined_df) {
  
  election_prefixes <- grep("^E_.*_Dem$", names(combined_df), value = TRUE)
  list_str_elections <- gsub("^E_(.*)_Dem$", "\\1", election_prefixes)
  
  list_df_elections <- lapply(list_str_elections, function(type_year) {
    prefix <- paste0("E_", type_year, "_")
    get_election_results(combined_df, prefix, type_year)
  })
  
  do.call(rbind, list_df_elections)
}


get_demographics <- function(df, prefix, source_label, year) {
  df %>%
    dplyr::rename(district_number = ID) %>%
    dplyr::mutate(
      n_white = !!rlang::sym(paste0(prefix, "White")),
      n_hispanic = !!rlang::sym(paste0(prefix, "Hispanic")),
      n_black = !!rlang::sym(paste0(prefix, "Black")),
      n_asian = !!rlang::sym(paste0(prefix, "Asian")),
      n_native = !!rlang::sym(paste0(prefix, "Native")),
      n_pacific = !!rlang::sym(paste0(prefix, "Pacific")),
      n_total_demo = !!rlang::sym(paste0(prefix, "Total")),
      pct_white = n_white / n_total_demo,
      pct_hispanic = n_hispanic / n_total_demo,
      pct_black = n_black / n_total_demo,
      pct_asian = n_asian / n_total_demo,
      pct_napi = (n_native + n_pacific) / n_total_demo,
      source_demo = source_label,
      year_demo = year
    ) %>%
    dplyr::select(chamber, district_number, n_white, n_hispanic, n_black, n_asian, n_native, n_pacific, n_total_demo, pct_white, pct_hispanic, pct_black, pct_asian, pct_napi, source_demo, year_demo)
}

get_election_results <- function(df, prefix, source_label) {
  df %>%
    dplyr::rename(district_number = ID) %>%
    dplyr::mutate(
      n_Dem  = !!rlang::sym(paste0(prefix, "Dem")),
      n_Rep = !!rlang::sym(paste0(prefix, "Rep")),
      n_Total_Elec = !!rlang::sym(paste0(prefix, "Total")),
      pct_D = n_Dem / n_Total_Elec,
      pct_R = n_Rep / n_Total_Elec,
      source_elec = source_label
    ) %>%
    dplyr::select(chamber, district_number, n_Dem, n_Rep, n_Total_Elec, pct_D, pct_R, source_elec)
}

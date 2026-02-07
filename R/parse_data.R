#' Parse LegiScan JSON Data
#'
#' Parses local JSON files downloaded from LegiScan into structured dataframes.
#'
#' @param data_dir Path to the directory containing state data (e.g., "data-raw/legiscan/FL").
#' @param start_year Integer. Start year to filter files. If NULL, starts from earliest.
#' @param end_year Integer. End year to filter files. If NULL, goes to latest.
#' @importFrom dplyr bind_rows mutate case_when
#' @importFrom stringr str_extract
#' @importFrom data.table rbindlist setDF
#' @importFrom tibble as_tibble
#' @importFrom jsonlite fromJSON
#' @importFrom progress progress_bar
#' @importFrom purrr map_dfr
#' @export
parse_legiscan_json <- function(data_dir, start_year = NULL, end_year = NULL) {
  
  if (!dir.exists(data_dir)) {
    stop(paste("Directory not found:", data_dir))
  }
  
  # Detect available years if not specified
  session_folders <- list.dirs(data_dir, recursive = FALSE, full.names = FALSE)
  # Expected format: YEAR-SESSION_NAME or similar.
  # The original script did: as.integer(sub("-.*", "", session_folders))
  available_years <- suppressWarnings(as.integer(sub("-.*", "", session_folders)))
  available_years <- sort(unique(available_years[!is.na(available_years)]))
  
  if (length(available_years) == 0) {
    # If standard naming fails, try to look at all json files? 
    # Or just warn and proceed with whatever is found if years are NULL
    warning("Could not detect years from folder names. Proceeding without year filtering if not provided.")
    if (is.null(start_year)) start_year <- 0
    if (is.null(end_year)) end_year <- 9999
  } else {
    if (is.null(start_year)) start_year <- min(available_years)
    if (is.null(end_year)) end_year <- max(available_years)
  }
  
  message(paste("Parsing data for years:", start_year, "to", end_year))
  
  # Filter files
  parse_years <- as.character(start_year:end_year)
  parse_pattern <- paste0("/(", paste(parse_years, collapse = "|"), ")")
  
  all_json_paths <- list.files(path = data_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)
  filtered_json_paths <- grep(parse_pattern, all_json_paths, value = TRUE)
  
  if (length(filtered_json_paths) == 0) {
    warning("No JSON files found matching the criteria.")
    return(list())
  }
  
  text_paths_bills <- filtered_json_paths[grepl("/bill/", filtered_json_paths, ignore.case = TRUE)]
  text_paths_legislators <- filtered_json_paths[grepl("/people/", filtered_json_paths, ignore.case = TRUE)]
  text_paths_votes <- filtered_json_paths[grepl("/vote/", filtered_json_paths, ignore.case = TRUE)]
  
  message(paste("Found", length(text_paths_bills), "bill files,", 
                length(text_paths_legislators), "legislator files,", 
                length(text_paths_votes), "vote files."))
  
  # Parse Bills
  message("Parsing bills...")
  bills_parsed <- parse_bills(text_paths_bills)$meta
  
  # Add session_year logic from original script
  if (nrow(bills_parsed) > 0) {
    bills_parsed <- bills_parsed %>%
      dplyr::mutate(
        session_year = as.numeric(stringr::str_extract(session_name, "\\d{4}")),
        two_year_period = dplyr::case_when(
          session_year < 2011 ~ "2010 or earlier",
          session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep = "-"),
          TRUE ~ paste(session_year, session_year + 1, sep = "-")
        )
      )
  }
  
  # Parse Legislators
  message("Parsing legislators...")
  legislators_parsed <- parse_legislator_sessions(text_paths_legislators)
  # Helper cleanup from original script
  if (nrow(legislators_parsed) > 0 && "bio" %in% names(legislators_parsed)) {
      legislators_parsed$bio <- sapply(legislators_parsed$bio, function(x) {
        if (is.null(x) || length(x) == 0) return(NA_character_)
        return(as.character(x[1])) 
      })
  }

  # Parse Roll Calls
  message("Parsing roll calls...")
  roll_calls_parsed <- parse_roll_calls(text_paths_votes)
  
  return(list(
    bills = bills_parsed,
    legislators = legislators_parsed,
    roll_calls = roll_calls_parsed$meta,
    votes = roll_calls_parsed$votes
  ))
}

# ---------------- INTERNAL PARSING FUNCTIONS ----------------

parse_bills <- function(bill_json_paths) {
  if (length(bill_json_paths) == 0) return(list(meta = data.frame(), xx = data.frame()))
  
  pb <- progress::progress_bar$new(
    format = "  parsing bills [:bar] :percent in :elapsed",
    total = length(bill_json_paths), clear = FALSE, width = 60
  )
  
  output_list <- lapply(bill_json_paths, extract_bill, pb)
  
  meta_list <- lapply(output_list, `[[`, "meta")
  # xx_list logic was present in original but not returned directly in the final output of the script?
  # script returned returns list(meta = meta_df, xx = xx_df)
  
  meta_df <- tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE))
  
  return(list(meta = meta_df))
}

extract_bill <- function(input_bill_path, pb) {
  pb$tick()
  
  bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
  bill <- bill_data$bill
  
  safe_get <- function(x, default = NA) ifelse(is.null(x), default, x)
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_bill_path, regexpr(session_regex, input_bill_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)
  
  bill_meta <- list(
    number = safe_get(bill$bill_number),
    bill_id = safe_get(bill$bill_id),
    session_id = safe_get(bill$session_id),
    session = session_info,
    session_name = safe_get(bill$session$session_name),
    url = safe_get(bill$url),
    state_link = safe_get(bill$state_link),
    title = safe_get(bill$title),
    type = safe_get(bill$type),
    description = safe_get(bill$description),
    status = safe_get(bill$status),
    status_date = safe_get(bill$status_date)
  )
  
  return(list(meta = bill_meta))
}

parse_legislator_sessions <- function(people_json_paths) {
  if (length(people_json_paths) == 0) return(data.frame())
    
  pb <- progress::progress_bar$new(
    format = "  parsing legislators [:bar] :percent in :elapsed",
    total = length(people_json_paths), clear = FALSE, width = 60
  )
  
  output_list <- lapply(people_json_paths, extract_people, pb)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  
  return(output_df)
}

extract_people <- function(input_people_json_path, pb) {
  pb$tick()
  
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_people_json_path, regexpr(session_regex, input_people_json_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)
  
  people_data <- jsonlite::fromJSON(input_people_json_path)
  people <- people_data[["person"]]
  people$session <- session_info
  
  return(people)
}

parse_roll_calls <- function(vote_json_paths) {
  if (length(vote_json_paths) == 0) return(list(meta = data.frame(), votes = data.frame()))
  
  pb <- progress::progress_bar$new(
    format = "  parsing roll calls [:bar] :percent in :elapsed",
    total = length(vote_json_paths), clear = FALSE, width = 60
  )
  
  output_list <- lapply(vote_json_paths, extract_roll_call, pb)
  
  meta_list <- lapply(output_list, `[[`, "meta")
  votes_list <- lapply(output_list, `[[`, "votes")
  
  meta_df <- tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE))
  votes_df <- tibble::as_tibble(data.table::rbindlist(votes_list, fill = TRUE))
  
  return(list(meta = meta_df, votes = votes_df))
}

extract_roll_call <- function(input_vote_path, pb) {
  pb$tick()
  
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_vote_path, regexpr(session_regex, input_vote_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)
  
  roll_call_data <- jsonlite::fromJSON(input_vote_path, simplifyVector = FALSE)
  roll_call <- roll_call_data$roll_call
  
  safe_get <- function(x, default = NA) ifelse(is.null(x), default, x)
  
  roll_call_meta_df <- list(
    roll_call_id = safe_get(roll_call$roll_call_id),
    bill_id = safe_get(roll_call$bill_id),
    session = session_info,
    date = safe_get(roll_call$date),
    desc = safe_get(roll_call$desc),
    yea = safe_get(roll_call$yea),
    nay = safe_get(roll_call$nay),
    nv = safe_get(roll_call$nv),
    absent = safe_get(roll_call$absent),
    total = safe_get(roll_call$total),
    passed = safe_get(roll_call$passed),
    chamber = safe_get(roll_call$chamber),
    chamber_id = safe_get(roll_call$chamber_id)
  )
  
  votes_df <- extract_votes(roll_call$votes, roll_call$roll_call_id, session_info)
  
  return(list(meta = roll_call_meta_df, votes = votes_df))
}

extract_votes <- function(votes, roll_call_id, session_info) {
  if (is.null(votes)) return(NULL)
  
  # Using do.call rbind or map_dfr is okay, but for performance data.table::rbindlist is used in parent.
  # Here we are inside one roll call.
  
  # The original used lapply -> as.data.frame -> do.call(rbind)
  
  vote_list <- lapply(votes, function(vote) {
    v <- as.data.frame(vote, stringsAsFactors = FALSE)
    v$roll_call_id <- roll_call_id
    v$session <- session_info
    return(v)
  })
  
  do.call(rbind, vote_list)
}

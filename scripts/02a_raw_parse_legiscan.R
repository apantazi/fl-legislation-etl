################################
#                              #  
# 02_parse_legiscan.R          #
#                              #
################################
# parses JSON data requested from LegiScan
# adapted from code originally written by Andrew Pantazi
# June 2024

#for testing phase only? set working directory to the location of current script
setwd(script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path))

################################
#                              #  
# 1) define parsing functions  #
#                              #
################################

# unpacks Legiscan's ls_bill table from JSON into bills$meta
# adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname input_bill_path
# this is set up to return a list, in case I later want to unpack the many related tables for bills (amendments, sasts, etc.)
parse_bills <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing bill jsons [:bar] :percent in :elapsed.",
    total = length(bill_json_paths), clear = FALSE, width = 100
  )
  pb$tick(0)
  
  output_list <- lapply(bill_json_paths, extract_bill, pb)
  
  meta_list <- lapply(output_list, `[[`, "meta")
  xx_list <- lapply(output_list, `[[`, "xx")
  
  meta_df <- tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE))
  xx_df <- tibble::as_tibble(data.table::rbindlist(xx_list, fill = TRUE))
  
  return(list(meta = meta_df, xx = xx_df))
}

#####
# helper function to extract bill metadata and votes for parse_bills
extract_bill <- function(input_bill_path, pb) {
  pb$tick()
  
  session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
  session_info <- regmatches(input_bill_path, regexpr(session_regex, input_bill_path))
  
  bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
  bill <- bill_data$bill
  
  # Handle missing fields with NA using `ifelse` and `is.null`
  safe_get <- function(x, default = NA) ifelse(is.null(x), default, x)
  
  bill_meta <- list(
    number = safe_get(bill$bill_number),
    bill_id = safe_get(bill$bill_id),
    session_id = safe_get(bill$session_id),
    session_string = session_info,
    session_name = safe_get(bill$session$session_name),
    url = safe_get(bill$url),
    state_link = safe_get(bill$state_link), #RR added b/c it's not tracked in votes JSON
    title = safe_get(bill$title),
    type = safe_get(bill$type),
    description = safe_get(bill$description),
    status = safe_get(bill$status),
    status_date = safe_get(bill$status_date)
  )
  
  return (list(meta = bill_meta))
}



#######################################################################################
#unpacks Legiscan's ls_people table from JSON into a dataframe
#adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname
#note that legislators$session tracks a once-per-session snapshot as accessed via jsons in API, but it's possible that some legislator info such as roles can change continuously
parse_legislator_sessions <- function (people_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing legislator-sessions from people jsons [:bar] :percent in :elapsed.",
    total = length(people_json_paths), clear = FALSE, width = 100
    )
  pb$tick(0)
  
  # run extract_people_meta for each file, combine results into output_df, then return output_df
  output_list <- lapply(people_json_paths, extract_people, pb)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  
  return(output_df)
}

#####
# helper function to extract people-sessions data and votes for parse_legislator_sessions
extract_people <- function(input_people_json_path, pb) {
  pb$tick()
  
  # Extract session info from file path using a defined regex
  session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
  matches <- regmatches(input_people_json_path, regexpr(session_regex, input_people_json_path))
  session_info <- ifelse(length(matches) > 0, matches, NA)
  
  people_data <- jsonlite::fromJSON(input_people_json_path)
  people <- people_data[["person"]]
  
  # Append session info as a new column
  people$session <- session_info
  
  return (people) # return people_meta
}



#######################################################################################
#unpacks Legiscan's votes info from JSON into two dataframes
# 1) votes$meta
# 2) votes$legislators
#adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname
parse_roll_calls <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing roll calls and leg-votes from vote jsons [:bar] :percent in :elapsed.",
    total = length(vote_json_paths), clear = FALSE, width = 100
  )
  pb$tick(0)
  
  output_list <- lapply(vote_json_paths, extract_roll_call, pb)
  
  meta_list <- lapply(output_list, `[[`, "meta")
  votes_list <- lapply(output_list, `[[`, "votes")
  
  meta_df <- tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE))
  votes_df <- tibble::as_tibble(data.table::rbindlist(votes_list, fill = TRUE))
  
  return(list(meta = meta_df, votes = votes_df))
}

#####
# helper function to extract roll call metadata and votes for parse_roll_calls
extract_roll_call <- function(input_vote_path, pb) {
  pb$tick()
  
  session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
  session_info <- regmatches(input_vote_path, regexpr(session_regex, input_vote_path))
  
  roll_call_data <- jsonlite::fromJSON(input_vote_path, simplifyVector = FALSE)
  roll_call <- roll_call_data$roll_call
  
  # Handle missing fields with NA using `ifelse` and `is.null`
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
  
  # Convert the date field to a proper date format
  #roll_call_meta_df$date <- as.Date(roll_call_meta_df$date, format="%Y-%m-%d")
  
  votes_df <- extract_votes(roll_call$votes, roll_call$roll_call_id, session_info, pb)
  
  return(list(meta = roll_call_meta_df, votes = votes_df))
}

#####
# sub-helper function to extract bill-votes for extract_bill
extract_votes <- function(votes, roll_call_id, session_info, pb) {
  if (is.null(votes)) return(NULL)
  do.call(rbind, lapply(votes, function(vote) {
    # Convert the vote list to a data frame
    vote_df <- as.data.frame(vote, stringsAsFactors = FALSE)
    
    # Add roll-call-level info
    vote_df$roll_call_id <- roll_call_id
    vote_df$session <- session_info
    
    return(vote_df)
  }))
}



###################################
#                                 #  
# 2) set options and local vars   #
#                                 #
###################################

options(scipen = 999) # numeric values in precise format

# For now, only working with folder data-raw/legiscan/2023-2024
# To look at all years:
# base_dir <- "../data-raw/legiscan/2010-2024/
base_dir <- "../data-raw/legiscan/2023-2024/"
all_json_paths <- list.files(path = base_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)
text_paths_bills <- all_json_paths[grepl("/bill/", all_json_paths, ignore.case = TRUE)]
text_paths_legislators <- all_json_paths[grepl("/people/", all_json_paths, ignore.case = TRUE)]
text_paths_votes <- all_json_paths[grepl("/vote/", all_json_paths, ignore.case = TRUE)]



########################################
#                                      #  
# 3) parse json files into dataframes  #
#                                      #
########################################

# parse bill jsons as "bills" (pk = bill_id)
#need to get session_year in a subsequent stage AFTER session_name has already been determined
t_bills <- parse_bills(text_paths_bills)$meta %>%
  mutate(
    session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
    two_year_period = case_when(
      session_year < 2011 ~ "2010 or earlier",
      session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
      TRUE ~ paste(session_year, session_year + 1, sep="-")
    )
  )

# parse people jsons as "legislator_sessions" (pk = people_id, session)
t_legislator_sessions <- parse_legislator_sessions(text_paths_legislators) # one record per legislator per session, to reflect potentially changing roles

# parse vote jsons as "roll calls" (pk = roll_call_id) and "legislator votes" (pk = roll_call_id, people_id)
temp_roll_calls_parsed <- parse_roll_calls(text_paths_votes)
t_roll_calls <- temp_roll_calls_parsed$meta
t_legislator_votes <- temp_roll_calls_parsed$votes
rm("temp_roll_calls_parsed")
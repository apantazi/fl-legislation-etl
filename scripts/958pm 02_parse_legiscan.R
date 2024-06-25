# FUNC-PARSING.R
# 6/10/24
# custom functions to parse JSON data requested from LegiScan
# all code written by Andrew Pantazi, then modularized/adapted by RR


################################
#                              #  
# 0) for testing only          #
#                              #
################################
#set working directory to the location of current script
setwd(script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path))

################################
#                              #  
# 1) define parsing functions  #
#                              #
################################

#######################################################################################
#unpacks Legiscan's ls_people table from JSON into a dataframe
# using jsonlite::fromJSON(input_people_json_path)
#adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname
parse_legislator_history <- function (people_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing_legislator history [:bar] :percent in :elapsed.", 
                                   total = length(people_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  
  extract_people_meta <- function(input_people_json_path) {
    pb$tick()
    # Define a regex to match the session pattern in the file path
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    # Extract session from the file path using the defined regex
    matches <- regmatches(input_people_json_path, regexpr(session_regex, input_people_json_path))
    session_info <- ifelse(length(matches) > 0, matches, NA)
    
    input_people_json <- jsonlite::fromJSON(input_people_json_path)
    people_meta <- input_people_json[["person"]]
    # Append session info as a new column
    people_meta$session <- session_info
    people_meta
  }
  
  output_list <- lapply(people_json_paths, extract_people_meta)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
}


#######################################################################################
#unpacks Legiscan's ls_bill_vote_detail from JSON into a dataframe
#adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname
#?adds "roll call id" for each vote record?
#?? Extracts vote information and session details from JSON file paths.
parse_legislator_votes <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing legislator_votes [:bar] :percent in :elapsed.", 
                                   total = length(vote_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  extract_vote <- function(input_vote_json_path) {
    pb$tick()
    # Extract session from the file path
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
    input_vote <- jsonlite::fromJSON(input_vote_json_path)
    input_vote <- input_vote[["roll_call"]]
    person_vote <- input_vote[["votes"]]
    person_vote$roll_call_id <- input_vote[["roll_call_id"]]
    # Append session info as a new column
    person_vote$session <- session_info
    person_vote
  }
  output_list <- lapply(vote_json_paths, extract_vote)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
} 



#######################################################################################
# unpacks Legiscan's ls_bill table from JSON into a dataframe
# adds "session" field (e.g. "2023-2024_Regular_Session") based on file pathname input_bill_path

#Extracts bill metadata and nested JSON info on votes
parse_bills <- function(bill_json_paths) {
  
  # initialize progress bar
  pb <- progress::progress_bar$new(
    format = "  parsing bill metadata [:bar] :percent in :elapsed.",
    total = length(bill_json_paths), clear = FALSE, width = 60
  )
  
  # helper function to process each individual JSON file
  extract_bill_meta <- function(input_bill_path) {
    pb$tick()
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_matches <- regexpr(session_regex, input_bill_path)
    session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
    
    bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
    bill <- bill_data$bill
    
    # Handle missing fields with NA
    number <- ifelse(is.null(bill$bill_number), NA, bill$bill_number)
    bill_id <- ifelse(is.null(bill$bill_id), NA, bill$bill_id)
    session_id <- ifelse(is.null(bill$session_id), NA, bill$session_id)
    session_name <- ifelse(is.null(bill$session$session_name), NA, bill$session$session_name)
    url <- ifelse(is.null(bill$url), NA, bill$url)
    title <- ifelse(is.null(bill$title), NA, bill$title)
    description <- ifelse(is.null(bill$description), NA, bill$description)
    status <- ifelse(is.null(bill$status), NA, bill$status)
    status_date <- ifelse(is.null(bill$status_date), NA, bill$status_date)
    
    # create data frame for bill metadata
    df_bills <- data.frame(
      number = number,
      bill_id = bill_id,
      session_id = session_id,
      session_string = session_string,
      session_name = session_name,
      url = url,
      title = title,
      description = description,
      status = status,
      status_date = status_date,
      stringsAsFactors = FALSE
    )
    
    # Parse related tables
    df_votes <- dplyr::bind_rows(lapply(bill$votes, tibble::as_tibble)) %>%
      dplyr::mutate(bill_id = bill$bill_id) %>%
      dplyr::select(bill_id, dplyr::everything())
    
    return(list(meta = df_bills, votes = df_votes))
  }
  
  # Use lapply to process each file and combine the results directly
  result_list <- lapply(bill_json_paths, extract_bill_meta)
  
  # Combine the results into data frames
  meta_df <- do.call(rbind, lapply(result_list, `[[`, "meta"))
  votes_df <- do.call(rbind, lapply(result_list, `[[`, "votes"))
  
  return(list(meta = meta_df, votes = votes_df))
}

###################################
#                                 #  
# 2) set options and local vars   #
#                                 #
###################################
options(scipen = 999) # numeric values in precise format


# RR I haven't re-run Andrew's api request (request-api-legiscan) yet
# ...only manually downloaded 2024 session data and renamed folder to 2023-2024_Regular_Session
text_paths <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..", file_type = "vote")
text_paths_bills <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..", file_type = "bill")
text_paths_leg <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..",file_type = "people")

####################################
#                                  #  
# 3) parse from json files         #
#                                  #
####################################

legislator_history <- parse_legislator_history(text_paths_leg) #adds session ID to potentially reflect changing roles
legislator_votes <- parse_legislator_votes(text_paths) #RR separated out this parse from the merge section for clarity

# parse bills json, storing related tables in a list of tables (meta, votes)
bills_parsed <- parse_bills(text_paths_bills)

# create a dataframe for each bill-related table returned in parse_bills
bill_votes <- bills_parsed$votes
# Add session to bills dataframe based on pathname
bills <- bills_parsed$meta %>%
  mutate(
    session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
    two_year_period = case_when(
      session_year < 2011 ~ "2010 or earlier",
      session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
      TRUE ~ paste(session_year, session_year + 1, sep="-")
    )
  )

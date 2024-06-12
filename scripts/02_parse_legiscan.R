# FUNC-PARSING.R
# 6/10/24
# custom functions to parse JSON data requested from LegiScan
# all code written by Andrew Pantazi, then modularized/adapted by RR

################################
#                              #  
# define parsing functions     #
#                              #
################################

#######################################################################################
#Extracts session information and people metadata from given JSON file paths.
#It adds session details to each person's metadata.
parse_people_session <- function (people_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing people [:bar] :percent in :elapsed.", 
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
#Extracts vote information and session details from given JSON file paths.
#It includes session information for each vote record.
parse_person_vote_session <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing person-vote [:bar] :percent in :elapsed.", 
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
#Extracts roll call information and session details from given JSON file paths, including session info for each roll call.
parse_rollcall_vote_session <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing roll call [:bar] :percent in :elapsed.", 
                                   total = length(vote_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  extract_rollcall <- function(input_vote_json_path) {
    pb$tick()
    # Extract session
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
    input_vote <- jsonlite::fromJSON(input_vote_json_path)
    input_vote <- input_vote[["roll_call"]]
    vote_info <- purrr::keep(input_vote, names(input_vote) %in% c("roll_call_id", "bill_id", "date", 
                                                                  "desc", "yea", "nay", "nv", "absent", "total", "passed", 
                                                                  "chamber", "chamber_id"))
    # Append session info
    vote_info$session <- session_info
    vote_info
  }
  output_list <- lapply(vote_json_paths, extract_rollcall)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
} 


#######################################################################################
#Extracts bill metadata including session information, progress, history, sponsors, and other related attributes from given JSON file paths.
parse_bill_session <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing bills [:bar] :percent in :elapsed.",
                                   total = length(bill_json_paths), clear = FALSE, width = 60)
  
  extract_bill_meta <- function(input_bill_path) {
    pb$tick()
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_matches <- regexpr(session_regex, input_bill_path)
    session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
    
    bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
    bill <- bill_data$bill
    
    # Handling missing fields with NA
    number <- ifelse(is.null(bill$bill_number), NA, bill$bill_number)
    bill_id <- ifelse(is.null(bill$bill_id), NA, bill$bill_id)
    session_id <- ifelse(is.null(bill$session_id), NA, bill$session_id)
    session_name <- ifelse(is.null(bill$session$session_name), NA, bill$session$session_name)
    url <- ifelse(is.null(bill$url), NA, bill$url)
    title <- ifelse(is.null(bill$title), NA, bill$title)
    description <- ifelse(is.null(bill$description), NA, bill$description)
    status <- ifelse(is.null(bill$status), NA, bill$status)
    status_date <- ifelse(is.null(bill$status_date), NA, bill$status_date)
    
    progress_list <- lapply(bill$progress, function(x) c(x$date, x$event))
    history_list <- lapply(bill$history, function(x) c(x$date, x$action, x$chamber, x$importance))
    sponsors_list <- lapply(bill$sponsors, function(x) c(x$people_id, x$party, x$role, x$name, x$sponsor_order, x$sponsor_type_id))
    sasts_list <- lapply(bill$sasts, function(x) c(x$type, x$sast_bill_number, x$sast_bill_id))
    texts_list <- lapply(bill$texts, function(x) c(x$date, x$type, x$type_id, x$mime, x$mime_id, x$url, x$state_link, x$text_size))
    
    df <- data.frame(
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
      progress = I(list(progress_list)),
      history = I(list(history_list)),
      sponsors = I(list(sponsors_list)),
      sasts = I(list(sasts_list)),
      texts = I(list(texts_list)),
      stringsAsFactors = FALSE
    )
    
    return(df)
  }
  
  output_list <- lapply(bill_json_paths, extract_bill_meta)
  output_df <- do.call(rbind, output_list)
  
  return(output_df)
} 


#######################################################################################
#A combined approach to parsing bill metadata, including sponsors and progress, from given JSON file paths. This function compiles data into simplified vectors or lists.
parse_bill_combined <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing bills [:bar] :percent in :elapsed.", 
                                   total = length(bill_json_paths), clear = FALSE, width = 60)
  
  extract_combined_meta <- function(input_bill_path) {
    pb$tick()
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_matches <- regexpr(session_regex, input_bill_path)
    session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
    
    if(file.exists(input_bill_path)) {
      bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
    } else {
      warning(paste("File not found:", input_bill_path))
      return(NULL)
    }
    
    bill <- bill_data$bill
    session_name <- bill$session$session_name %||% NA
    
    # Simplify and compile desired attributes into vectors or lists
    sponsors_list <- lapply(bill$sponsors %||% list(), function(x) c(x$people_id, x$party, x$role, x$name, x$sponsor_order, x$sponsor_type_id))
    progress_list <- lapply(bill$progress %||% list(), function(x) c(x$date, x$event))
    
    # Construct the data frame
    df <- data.frame(
      bill_id = bill$bill_id,
      change_hash = bill$change_hash,
      url = bill$url,
      state_link = bill$state_link,
      status = bill$status,
      status_date = bill$status_date,
      state = bill$state,
      state_id = bill$state_id,
      bill_number = bill$bill_number,
      bill_type = bill$bill_type,
      bill_type_id = bill$bill_type_id,
      body = bill$body,
      body_id = bill$body_id,
      current_body = bill$current_body,
      current_body_id = bill$current_body_id,
      title = bill$title,
      description = bill$description,
      pending_committee_id = bill$pending_committee_id,
      session_name = session_name,
      session_string = session_string,
      sponsors = I(sponsors_list),
      progress = I(progress_list),
      stringsAsFactors = FALSE
    )
    
    return(df)
  }
  
  output_list <- lapply(bill_json_paths, extract_combined_meta)
  output_df <- do.call(rbind, output_list)
  
  return(output_df)
} 


#######################################################################################
#Parses multiple JSON paths for bill data, extracting detailed bill information, sponsors, amendments, referrals, history, votes, and supplements. It combines results into a single list.
parse_bill_jsons <- function(json_paths){
  parse_single_json  <- function(json_path) {
    bill_data <- fromJSON(json_path, simplifyVector = FALSE)
    bill <- bill_data$bill
    
    # Extract flat information directly into a data frame
    bill_info_df <- tibble(
      number = bill$bill_number,
      title = bill$title,
      type = bill$bill_type,
      bill_id = bill$bill_id,
      description = bill$description,
      session_id = bill$session$session_id,
      session_name = bill$session$session_name,
      year = bill$session$year_end
      # Add more fields as needed
    )
    
    # Extract sponsors (assuming sponsors are a list of lists)
    sponsors <- bind_rows(lapply(bill$sponsors, as_tibble), .id = bill$sponsor_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    amendments <- bind_rows(lapply(bill$amendments, as_tibble), .id = bill$amendment_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    referrals <- bind_rows(lapply(bill$referrals, as_tibble), .id = bill$committee_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    history <- bind_rows(lapply(bill$history, as_tibble)) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    votes <- bind_rows(lapply(bill$votes, as_tibble), .id = bill$roll_call_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    supplements <- bind_rows(lapply(bill$supplements, as_tibble), .id = bill$supplement_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    # Compile into a single list for this example
    list(bill_info_df = bill_info_df,
         sponsors = sponsors, 
         amendments = amendments,
         supplements=supplements,
         votes=votes,
         history=history,
         referrals=referrals)
  }
  pb <- progress::progress_bar$new(
    format = "  Parsing bills [:bar] :percent in :elapsed",
    total = length(json_paths),
    width = 60
  )
  parsed_results <- lapply(json_paths, function(path) {
    pb$tick()
    parse_single_json(path)
  })
  
  combined_results <- list(
    bill_info_df = bind_rows(lapply(parsed_results, `[[`, "bill_info_df")),
    sponsors = bind_rows(lapply(parsed_results, `[[`, "sponsors")),
    amendments = bind_rows(lapply(parsed_results, `[[`, "amendments")),
    supplements = bind_rows(lapply(parsed_results, `[[`, "supplements")),
    votes = bind_rows(lapply(parsed_results, `[[`, "votes")),
    history = bind_rows(lapply(parsed_results, `[[`, "history")),
    referrals = bind_rows(lapply(parsed_results, `[[`, "referrals"))
  )
  
  return(combined_results)
} 


################################
#                              #  
# set options and local vars   #
#                              #
################################
options(scipen = 999) # numeric values in precise format


# RR I haven't re-run Andrew's api request (request-api-legiscan) yet
# ...only manually downloaded 2024 session data and renamed folder to 2023-2024_Regular_Session
text_paths <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..", file_type = "vote")
text_paths_bills <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..", file_type = "bill")
text_paths_leg <- find_json_path(base_dir = "../data-raw/legiscan/2023-2024_Regular_Session/..",file_type = "people")

####################################
#                                  #  
# 1) parse from json files         #
#                                  #
####################################
#this relies on custom functions defined in func-parsing.R
legislators <- parse_people_session(text_paths_leg) #we use session so we don't have the wrong roles
bills_all_sponsor <- parse_bill_sponsor(text_paths_bills)
primary_sponsors <- bills_all_sponsor %>% filter(sponsor_type_id == 1 & committee_sponsor == 0)
bills_all <- parse_bill_session(text_paths_bills) %>%
  mutate(
    session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
    two_year_period = case_when(
      session_year < 2011 ~ "2010 or earlier",
      session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
      TRUE ~ paste(session_year, session_year + 1, sep="-")
    )
  )
bill_detailed <- parse_bill_jsons(text_paths_bills)

#RR separated out this parse from the merge section, for clarity
votes_by_legislator <- parse_person_vote_session(text_paths)
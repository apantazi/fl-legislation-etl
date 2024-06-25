# 6/24/24
# created this backup just before removing unneeded tables (progress, history, sasts, etc)

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

#Extracts bill metadata including session information, progress, history, sponsors, and other related attributes from given JSON file paths.
parse_bills <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing bill metadata [:bar] :percent in :elapsed.",
    total = length(bill_json_paths), clear = FALSE, width = 60
  )
  
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
    
    # parse related tables
    progress_df <- extract_progress(bill$progress, bill_id)
    history_df <- extract_history(bill$history, bill_id)
    sponsors_df <- extract_sponsors(bill$sponsors, bill_id)
    sasts_df <- extract_sasts(bill$sasts, bill_id)
    texts_df <- extract_texts(bill$texts, bill_id)
    
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
      stringsAsFactors = FALSE
    )
    
    return(list(meta = df, progress = progress_df, history = history_df, sponsors = sponsors_df, sasts = sasts_df, texts = texts_df))
  }
  
  output_list <- lapply(bill_json_paths, extract_bill_meta)
  
  meta_df <- do.call(rbind, lapply(output_list, `[[`, "meta"))
  progress_df <- do.call(rbind, lapply(output_list, `[[`, "progress"))
  history_df <- do.call(rbind, lapply(output_list, `[[`, "history"))
  sponsors_df <- do.call(rbind, lapply(output_list, `[[`, "sponsors"))
  sasts_df <- do.call(rbind, lapply(output_list, `[[`, "sasts"))
  texts_df <- do.call(rbind, lapply(output_list, `[[`, "texts"))
  
  return(list(meta = meta_df, progress = progress_df, history = history_df, sponsors = sponsors_df, sasts = sasts_df, texts = texts_df))
}


#######################################################################################
# helper functions to extract lists from within bills

extract_progress <- function(progress, bill_id) {
  if (is.null(progress)) return(NULL)
  do.call(rbind, lapply(progress, function(x) {
    data.frame(
      bill_id = bill_id,
      date = ifelse(is.null(x$date), NA, x$date),
      event = ifelse(is.null(x$event), NA, x$event),
      stringsAsFactors = FALSE
    )
  }))
}

extract_history <- function(history, bill_id) {
  if (is.null(history)) return(NULL)
  do.call(rbind, lapply(history, function(x) {
    data.frame(
      bill_id = bill_id,
      date = ifelse(is.null(x$date), NA, x$date),
      action = ifelse(is.null(x$action), NA, x$action),
      chamber = ifelse(is.null(x$chamber), NA, x$chamber),
      importance = ifelse(is.null(x$importance), NA, x$importance),
      stringsAsFactors = FALSE
    )
  }))
}

extract_sponsors <- function(sponsors, bill_id) {
  if (is.null(sponsors)) return(NULL)
  do.call(rbind, lapply(sponsors, function(x) {
    data.frame(
      bill_id = bill_id,
      people_id = ifelse(is.null(x$people_id), NA, x$people_id),
      party = ifelse(is.null(x$party), NA, x$party),
      role = ifelse(is.null(x$role), NA, x$role),
      name = ifelse(is.null(x$name), NA, x$name),
      sponsor_order = ifelse(is.null(x$sponsor_order), NA, x$sponsor_order),
      sponsor_type_id = ifelse(is.null(x$sponsor_type_id), NA, x$sponsor_type_id),
      stringsAsFactors = FALSE
    )
  }))
}

extract_sasts <- function(sasts, bill_id) {
  if (is.null(sasts)) return(NULL)
  do.call(rbind, lapply(sasts, function(x) {
    data.frame(
      bill_id = bill_id,
      type = ifelse(is.null(x$type), NA, x$type),
      sast_bill_number = ifelse(is.null(x$sast_bill_number), NA, x$sast_bill_number),
      sast_bill_id = ifelse(is.null(x$sast_bill_id), NA, x$sast_bill_id),
      stringsAsFactors = FALSE
    )
  }))
}

extract_texts <- function(texts, bill_id) {
  if (is.null(texts)) return(NULL)
  do.call(rbind, lapply(texts, function(x) {
    data.frame(
      bill_id = bill_id,
      date = ifelse(is.null(x$date), NA, x$date),
      type = ifelse(is.null(x$type), NA, x$type),
      type_id = ifelse(is.null(x$type_id), NA, x$type_id),
      mime = ifelse(is.null(x$mime), NA, x$mime),
      mime_id = ifelse(is.null(x$mime_id), NA, x$mime_id),
      url = ifelse(is.null(x$url), NA, x$url),
      state_link = ifelse(is.null(x$state_link), NA, x$state_link),
      text_size = ifelse(is.null(x$text_size), NA, x$text_size),
      stringsAsFactors = FALSE
    )
  }))
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
    
    # Compile into a single list
    list(bill_info_df = bill_info_df,
         sponsors = sponsors, 
         amendments = amendments,
         supplements=supplements,
         votes=votes,
         history=history,
         referrals=referrals)
  }
  pb <- progress::progress_bar$new(
    format = "  Parsing bill details [:bar] :percent in :elapsed",
    total = length(json_paths),
    width = 60
  )
  parsed_results <- lapply(json_paths, function(path) {
    pb$tick()
    parse_single_json(path)
  })
  
  combined_results <- list(
    sponsors <- bind_rows(lapply(bill$sponsors, as_tibble), .id = bill$sponsor_id),
    bill_info_df = bind_rows(lapply(parsed_results, `[[`, "bill_info_df")),
    #sponsors = bind_rows(lapply(parsed_results, `[[`, "sponsors")),
    amendments = bind_rows(lapply(parsed_results, `[[`, "amendments")),
    supplements = bind_rows(lapply(parsed_results, `[[`, "supplements")),
    votes = bind_rows(lapply(parsed_results, `[[`, "votes")),
    history = bind_rows(lapply(parsed_results, `[[`, "history")),
    referrals = bind_rows(lapply(parsed_results, `[[`, "referrals"))
  )
  
  return(combined_results)
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
#updated on 6/14/24

legislator_history <- parse_legislator_history(text_paths_leg) #adds session ID to potentially reflect changing roles
legislator_votes <- parse_legislator_votes(text_paths) #RR separated out this parse from the merge section for clarity

#6/17/24 original code no longer needed? 
# bills_meta <- parse_bill_meta(text_paths_bills) %>%
#   mutate(
#     session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
#     two_year_period = case_when(
#       session_year < 2011 ~ "2010 or earlier",
#       session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
#       TRUE ~ paste(session_year, session_year + 1, sep="-")
#     )
#   )

# parse bills json, storing related tables in a list of tables (meta, progress, history, sponsors, sasts, texts)
bills_parsed <- parse_bills(text_paths_bills)

# create a dataframe for each bill-related table returned in parse_bills
bill_progress <- bills_parsed$progress
bill_history <- bills_parsed$history
bill_sponsors <- bills_parsed$sponsors
bill_sasts <- bills_parsed$sasts
bill_texts <- bills_parsed$texts
# Add detail to bills dataframe (meta)
bills <- bills_parsed$meta %>%
  mutate(
    session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
    two_year_period = case_when(
      session_year < 2011 ~ "2010 or earlier",
      session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
      TRUE ~ paste(session_year, session_year + 1, sep="-")
    )
  )

# bill_detailed <- parse_bill_jsons(text_paths_bills)


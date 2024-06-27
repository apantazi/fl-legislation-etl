# 6/17/24
# unused parse code
# to delete after completing database overhaul

#######################################################################################
#Extracts roll call information and session details from given JSON file paths, including session info for each roll call.
#6/14/24 RR- no indication this function is being used
# parse_rollcall_vote_session <- function (vote_json_paths) {
#   pb <- progress::progress_bar$new(format = "  parsing roll call [:bar] :percent in :elapsed.", 
#                                    total = length(vote_json_paths), clear = FALSE, width = 60)
#   pb$tick(0)
#   extract_rollcall <- function(input_vote_json_path) {
#     pb$tick()
#     # Extract session
#     session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
#     session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
#     input_vote <- jsonlite::fromJSON(input_vote_json_path)
#     input_vote <- input_vote[["roll_call"]]
#     vote_info <- purrr::keep(input_vote, names(input_vote) %in% c("roll_call_id", "bill_id", "date", 
#                                                                   "desc", "yea", "nay", "nv", "absent", "total", "passed", 
#                                                                   "chamber", "chamber_id"))
#     # Append session info
#     vote_info$session <- session_info
#     vote_info
#   }
#   output_list <- lapply(vote_json_paths, extract_rollcall)
#   output_df <- data.table::rbindlist(output_list, fill = TRUE)
#   output_df <- tibble::as_tibble(data.table::setDF(output_df))
#   output_df
# } 



#######################################################################################
#A combined approach to parsing bill metadata, including sponsors and progress, from given JSON file paths. This function compiles data into simplified vectors or lists.
#6/14/24 RR- no indication this function is being used
# parse_bill_combined <- function(bill_json_paths) {
#   pb <- progress::progress_bar$new(format = "  parsing bills [:bar] :percent in :elapsed.",
#                                    total = length(bill_json_paths), clear = FALSE, width = 60)
# 
#   extract_combined_meta <- function(input_bill_path) {
#     pb$tick()
#     session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
#     session_matches <- regexpr(session_regex, input_bill_path)
#     session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
# 
#     if(file.exists(input_bill_path)) {
#       bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
#     } else {
#       warning(paste("File not found:", input_bill_path))
#       return(NULL)
#     }
# 
#     bill <- bill_data$bill
#     session_name <- bill$session$session_name %||% NA
# 
#     # Simplify and compile desired attributes into vectors or lists
#     sponsors_list <- lapply(bill$sponsors %||% list(), function(x) c(x$people_id, x$party, x$role, x$name, x$sponsor_order, x$sponsor_type_id))
#     progress_list <- lapply(bill$progress %||% list(), function(x) c(x$date, x$event))
# 
#     # Construct the data frame
#     df <- data.frame(
#       bill_id = bill$bill_id,
#       change_hash = bill$change_hash,
#       url = bill$url,
#       state_link = bill$state_link,
#       status = bill$status,
#       status_date = bill$status_date,
#       state = bill$state,
#       state_id = bill$state_id,
#       bill_number = bill$bill_number,
#       bill_type = bill$bill_type,
#       bill_type_id = bill$bill_type_id,
#       body = bill$body,
#       body_id = bill$body_id,
#       current_body = bill$current_body,
#       current_body_id = bill$current_body_id,
#       title = bill$title,
#       description = bill$description,
#       pending_committee_id = bill$pending_committee_id,
#       session_name = session_name,
#       session_string = session_string,
#       sponsors = I(sponsors_list),
#       progress = I(progress_list),
#       stringsAsFactors = FALSE
#     )
# 
#     return(df)
#   }
# 
#   output_list <- lapply(bill_json_paths, extract_combined_meta)
#   output_df <- do.call(rbind, output_list)
# 
#   return(output_df)
# }



###########################################################################
# OLD_parse_legislator_votes <- function (vote_json_paths) {
#   pb <- progress::progress_bar$new(format = "  parsing legislator votes jsons [:bar] :percent in :elapsed.",
#                                    total = length(vote_json_paths), clear = FALSE, width = 60)
#   pb$tick(0)
#   extract_vote <- function(input_vote_json_path) {
#     pb$tick()
#     # Extract session from the file path
#     session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
#     session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
#     input_vote <- jsonlite::fromJSON(input_vote_json_path)
#     input_vote <- input_vote[["roll_call"]]
#     person_vote <- input_vote[["votes"]]
#     person_vote$roll_call_id <- input_vote[["roll_call_id"]]
#     # Append session info as a new column
#     person_vote$session <- session_info
#     person_vote
#   }
#   output_list <- lapply(vote_json_paths, extract_vote)
#   output_df <- data.table::rbindlist(output_list, fill = TRUE)
#   output_df <- tibble::as_tibble(data.table::setDF(output_df))
#   output_df
# }



####################################################
# OLD_parse_bills <- function(bill_json_paths) {
#   pb <- progress::progress_bar$new(
#     format = "  parsing bill metadata and bill-votes [:bar] :percent in :elapsed.",
#     total = length(bill_json_paths), clear = FALSE, width = 60
#   )
#   
#   extract_bill_meta <- function(input_bill_path) {
#     pb$tick()
#     session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
#     session_matches <- regexpr(session_regex, input_bill_path)
#     session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
#     
#     bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
#     bill <- bill_data$bill
#     
#     # Handle missing fields with NA
#     number <- ifelse(is.null(bill$bill_number), NA, bill$bill_number)
#     bill_id <- ifelse(is.null(bill$bill_id), NA, bill$bill_id)
#     session_id <- ifelse(is.null(bill$session_id), NA, bill$session_id)
#     session_name <- ifelse(is.null(bill$session$session_name), NA, bill$session$session_name)
#     url <- ifelse(is.null(bill$url), NA, bill$url)
#     title <- ifelse(is.null(bill$title), NA, bill$title)
#     type <- ifelse(is.null(bill$type), NA, bill$type)
#     description <- ifelse(is.null(bill$description), NA, bill$description)
#     status <- ifelse(is.null(bill$status), NA, bill$status)
#     status_date <- ifelse(is.null(bill$status_date), NA, bill$status_date)
#     
#     # parse related tables
#     votes_df <- extract_bill_votes(bill$votes, bill_id)
#     
#     df <- data.frame(
#       number = number,
#       bill_id = bill_id,
#       session_id = session_id,
#       session_string = session_string,
#       session_name = session_name,
#       url = url,
#       title = title,
#       type = type,
#       description = description,
#       status = status,
#       status_date = status_date,
#       stringsAsFactors = FALSE
#     )
#     
#     return(list(meta = df, votes = votes_df))
#   }
#   
#   output_list <- lapply(bill_json_paths, extract_bill_meta)
#   
#   meta_df <- do.call(rbind, lapply(output_list, `[[`, "meta"))
#   votes_df <- do.call(rbind, lapply(output_list, `[[`, "votes"))
#   
#   return(list(meta = meta_df, votes = votes_df))
# }

OLD_parse_legislator_votes <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing legislator votes jsons [:bar] :percent in :elapsed.",
    total = length(vote_json_paths), clear = FALSE, width = 60
  )
  pb$tick(0)
  
  extract_vote <- function(input_vote_json_path) {
    pb$tick()
    
    # Extract session from the file path
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
    
    vote_data <- jsonlite::fromJSON(input_vote_json_path)
    roll_call <- vote_data[["roll_call"]]
    person_vote <- roll_call[["votes"]]
    person_vote$roll_call_id <- roll_call[["roll_call_id"]]
    person_vote$session <- session_info
    
    person_vote
  }
  
  output_list <- lapply(vote_json_paths, extract_vote)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  
  output_df
}



#####
# sub-helper function to extract bill-votes for extract_bill
extract_bill_roll_calls <- function(roll_calls, bill_id, pb) {
  if (is.null(roll_calls)) return(NULL)
  do.call(rbind, lapply(roll_calls, function(roll_calls) {
    # Convert the vote list to a data frame
    roll_calls_df <- as.data.frame(roll_calls, stringsAsFactors = FALSE)
    
    # Add the bill_id column
    roll_calls_df$bill_id <- bill_id
    
    return(roll_calls_df)
  }))
}

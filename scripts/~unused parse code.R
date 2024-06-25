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

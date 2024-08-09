#################################
#                               #  
# documentation-utilities.R     #
#                               #
#################################

# 6/23/24 RR utility functions to help document and tidy data


# get column metadata from a data frame
getColumnInfo <- function(df) {
  # Initialize empty vectors to store information
  field_names <- character(length = ncol(df))
  types <- character(length = ncol(df))
  sample_values <- character(length = ncol(df))
  
  # Iterate over each column in the data frame
  for (i in seq_along(df)) {
    field_names[i] <- names(df)[i]
    types[i] <- class(df[[i]])[1]
    sample_values[i] <- if (length(df[[i]]) > 0) as.character(df[[i]][1]) else NA_character_
  }
  
  # Create the data frame
  column_info <- data.frame(
    field_name = field_names,
    type = types,
    sample_value = sample_values,
    stringsAsFactors = FALSE
  )
  
  # Return the data frame
  return(column_info)
}



find_session_fields <- function() {
  df_list_w_session <- Filter(is.data.frame, mget(ls(envir = .GlobalEnv), envir = .GlobalEnv))
  
  # Initialize an empty list to store results
  result_list <- list()
  
  for (df_name in names(df_list_w_session)) {
    #print(df_name)
    session_fields <- names(df_list_w_session[[df_name]])[grepl("session", names(df_list[[df_name]]), ignore.case = TRUE)]
    #print(session_fields)
    if (length(session_fields) > 0) {
      #print("adding one")
      result <- setNames(rep("yes", length(session_fields)), session_fields)
      result_list[[df_name]] <- as.data.frame(as.list(result))
    }
  }
  
  # Combine all results into a single dataframe
  result_df <- bind_rows(result_list, .id = "Dataframe")
  result_df[is.na(result_df)] <- ""
  return(result_df)
}

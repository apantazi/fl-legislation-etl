# 6/23/24 RR created this code to document and understand heatmap_data

# Function to get column information from a data frame
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

# Example usage:
# Assuming 'df' is your data frame
df <- data.frame(
  field1 = c(1, 2, 3),
  field2 = c("A", "B", "C"),
  field3 = c(TRUE, FALSE, TRUE)
)
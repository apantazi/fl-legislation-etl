# LOAD_VIEWS.R
# 6/13/24 RR
# This script takes data that's already been extracted from LegiScan and other sources
# and writes it into the Postgres database VIEW layer (prior to transform)

########################################
#                                      #  
# 1) connect to Postgres server        #
#                                      #
########################################
# Loop until successful connection
repeat {
  con <- attempt_connection()

  if (!is.null(con) && dbIsValid(con)) {
    print("Successfully connected to the database!")
    break
  } else {
    message("Failed to connect to the database. Please try again.")
  }
}



#############################################
#                                           #  
# 2) write dataframes to Postgres and test  #
#                                           #
#############################################

# con <- retry_connect()

schema_name <- "raw_legiscan"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "t_legislator_sessions",
  "t_legislator_votes",
  "t_bills",
  "t_roll_calls"
)

write_tables_in_list(con, schema_name, list_tables)

# Close the connection
dbDisconnect(con)

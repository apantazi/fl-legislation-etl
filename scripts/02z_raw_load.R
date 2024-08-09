# LOAD_RAW.R
# June-July 2024 RR
# This script takes data that's already been extracted from LegiScan and other sources
# and writes it into the Postgres database VIEW layer (prior to transform)

# connect to Postgres database
con <- attempt_connection()

if (!is.null(con) && dbIsValid(con)) {
  print("Successfully connected to the database!")
} else {
  message("Failed to connect to the database. Please try again.")
}

#####################
#                   #  
# save Legiscan     #
#                   #
#####################

schema_name <- "raw_legiscan"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "t_legislator_sessions",
  "t_legislator_votes",
  "t_bills",
  "t_roll_calls"
)
write_tables_in_list(con, schema_name, list_tables)

#####################
#                   #  
# save user-entered #
#                   #
#####################

schema_name <- "raw_user_entry"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "user_legislator_events",
  "user_bill_categories"
)

write_tables_in_list(con, schema_name, list_tables)

###############################
#                             #  
# save Daves District Data    #
#                             #
###############################

schema_name <- "raw_daves"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "t_daves_districts_house",
  "t_daves_districts_senate"
)

write_tables_in_list(con, schema_name, list_tables)



# Close the connection
dbDisconnect(con)
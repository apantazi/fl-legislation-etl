#################################
#                               #  
# 0Z_PROCESS_LOAD.R             #
#                               #
#################################

# 7/14/24 RR
# Write tables to processed layer of postgres database (see database functions in functions_database.R)
# Primary keys are enforced to ensure data integrity- e.g. to catch problems with duplicate records

########################################
#                                      #  
# 1) connect to Postgres server        #
#                                      #
########################################
# connect to Postgres database
con <- attempt_connection()

if (!is.null(con) && dbIsValid(con)) {
  print("Successfully connected to the database!")
} else {
  message("Failed to connect to the database. Please try again.")
}

##################################################
#                                                #  
# 2) write processed tables to Postgres and test #
#                                                #
##################################################
# db schema for processed layer of legislative data app at https://mockingbird.shinyapps.io/fl-leg-app-postgres/
schema_name <- "proc"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "hist_district_demo",
  "hist_district_elections",
  "hist_leg_sessions",
  "jct_bill_categories",
  "p_bills",
  "p_legislator_votes",
  "p_legislators",
  "p_roll_calls",
  "p_sessions"
)

primary_keys <- list(
  hist_district_demo = c('chamber','district_number','source_demo','year_demo'),
  hist_district_elections = c('chamber','district_number','source_elec'),
  hist_leg_sessions = c('people_id','session'),
  p_bills = 'bill_id',
  p_legislator_votes = c('people_id','roll_call_id'),
  p_legislators = 'people_id',
  p_roll_calls = 'roll_call_id',
  p_sessions = 'session_id'
)

write_tables_in_list(con, schema_name, list_tables, primary_keys)

# Close the connection
dbDisconnect(con)

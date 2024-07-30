# WRITE-TO-POSTGRES.R
# 6/11/24 RR
# This script takes data that's already been extracted and transformed from LegiScan and other sources
# and writes it into the Postgres database fl_leg_votes

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
# 2) write app queries to Postgres and test #
#                                           #
#############################################
# db schema for Shiny app legislative dashboard dev site at https://mockingbird.shinyapps.io/fl-leg-app-postgres/.
schema_name <- "app_shiny"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "qry_bills",
  "qry_leg_votes",
  "qry_legislators_incumbent",
  "qry_districts",
  "qry_roll_calls",
  "qry_state_summary",
  "app01_vote_patterns",
  "app02_leg_activity",
  "app03_district_context",
  "app03_district_context_state"
  # "viz_partisanship",
  # "viz_partisan_senate_d",
  # "viz_partisan_senate_r"
)

primary_keys <- list(
  qry_bills = 'bill_id',
  qry_leg_votes = c('people_id','roll_call_id'),
  qry_legislators = c('chamber','district_number'),
  qry_districts = c('chamber','district_number'),
  qry_roll_calls = 'roll_call_id'
)

write_tables_in_list(con, schema_name, list_tables, primary_keys)

# Close the connection
dbDisconnect(con)

#############################################
#                                           #  
# export queries data to CSV                 #
#                                           #
#############################################
# export to CSV for those who don't want to deal with postgres
list_export_df <- list(
  app01_vote_patterns = app01_vote_patterns,
  app02_leg_activity = app02_leg_activity,
  app03_district_context = app03_district_context,
  app03_district_context_state = app03_district_context_state,
  calc_elections_weighted = calc_elections_weighted,
  qry_bills = qry_bills,
  qry_leg_votes = qry_leg_votes,
  qry_legislators_incumbent = qry_legislators_incumbent,
  qry_districts = qry_districts,
  qry_roll_calls = qry_roll_calls,
  qry_state_summary = qry_state_summary
  # viz_partisanship = viz_partisanship,
  # viz_partisan_senate_d = viz_partisan_senate_d,
  # viz_partisan_senate_r = viz_partisan_senate_r
)

# Loop through the list and write each data frame to its respective file
for (name in names(list_export_df)) {
  file_path <- paste0("../data-app/", name, ".csv")
  write.csv(list_export_df[[name]], file_path, row.names = FALSE)
}

##########################################
#                                        #  
# export QA results to csv               #
#                                        #
##########################################
list_export_df <- list(
  qa_leg_votes_other = qa_leg_votes_other,
  qa_loyalty_ranks = qa_loyalty_ranks,
  qa_rc_party_none_present = qa_rc_party_none_present
)

# Loop through the list and write each data frame to its respective file
for (name in names(list_export_df)) {
  file_path <- paste0("../qa/", name, ".csv")
  write.csv(list_export_df[[name]], file_path, row.names = FALSE)
}

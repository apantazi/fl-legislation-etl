# LOAD_VIEWS.R
# 6/13/24 RR
# This script takes data that's already been extracted from LegiScan and other sources
# and writes it into the Postgres database VIEW layer (prior to transform)

########################################
#                                      #  
# debug notes                          #
#                                      #
######################################## 
# haven't yet saved "bills_all", "bills_detailed"
# haven't yet updated later steps to read from Postgres database

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
# db schema for Andrew's Shiny app legislative dashboard currently at https://shiny.jaxtrib.org/.
schema_name <- "views"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "legislators",
  "bills_all_sponsor",
  "primary_sponsors",
  "votes_by_legislator"
)

#"bills_all"
#"bills_detailed"

process_table_list(con, schema_name, list_tables)

# Close the connection
dbDisconnect(con)

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

##################################################
#                                                #  
# 2) write processed tables to Postgres and test #
#                                                #
##################################################
# db schema for Andrew's Shiny app legislative dashboard currently at https://shiny.jaxtrib.org/.
schema_name <- "proc"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

#tables currently in testing

list_tables <- c(
  "hist_district_demo",
  "hist_district_elections",
  "hist_leg_sessions",
  "jct_bill_categories",
  "p_bills",
  "p_districts",
  "p_legislator_votes",
  "p_legislators",
  "p_roll_calls",
  "p_sessions",
  "p_state_summary"
)

write_tables_in_list(con, schema_name, list_tables)

##########################
#                        #  
# 3) create useful views #
#                        #
##########################
# hardcoded the first one, should automate this as a list if it gets complex

dbExecute(con, "
CREATE OR REPLACE VIEW proc.view_legislators_incumbent AS
SELECT * FROM proc.p_legislators
WHERE termination_date IS NULL;
")
view_legislators_incumbent <- dbGetQuery(con, "SELECT * FROM proc.view_legislators_incumbent;")

# Close the connection
dbDisconnect(con)

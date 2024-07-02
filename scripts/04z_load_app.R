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
# db schema for Andrew's Shiny app legislative dashboard currently at https://shiny.jaxtrib.org/.
schema_name <- "app_shiny"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

#tables currently in testing

list_tables <- c(
  "app_vote_patterns",
  "app_data"
)

write_tables_in_list(con, schema_name, list_tables)

# Close the connection
dbDisconnect(con)

#############################################
#                                           #  
# 2) export app data to CSV                 #
#                                           #
#############################################
# for those who don't want to deal with postgres
write.csv(app_vote_patterns, "../data-app/app_vote_patterns.csv", row.names = FALSE)

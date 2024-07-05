# LOAD_USER_ENTERED.R
# 7/5/24 RR
# this script uploads user-entered data, such as bill categorization and info on contested primary races
# Consider updating this to load user-entered tables from Google Sheets

########################################
#                                      #  
# 1) read user-entered                 #
#                                      #
########################################
user_incumbents_challenged <- read.csv("../data-raw/user-entry/user_incumbents_challenged.csv")
user_bill_categories <- read.csv("../data-raw/user-entry/user_bill_categories.csv")

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

schema_name <- "raw_user_entry"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "user_incumbents_challenged",
  "user_bill_categories"
)

write_tables_in_list(con, schema_name, list_tables)

# Close the connection
dbDisconnect(con)

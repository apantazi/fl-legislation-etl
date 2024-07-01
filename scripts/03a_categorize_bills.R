##########################
#                        #
# 0x.categorize-bills.R  #
#                        #
##########################

# following is a basic small scale prototype of a bill categorization table
# this may be developed to incorporate outside data sources
# or use AI to classify bills

educ_bill_numbers <- c('H0001','H0105','H0491','H0791','H0799','H1045','H1065','H7001','S0240','S0664','S2502')

jct_bill_categories <- tibble (
 number = educ_bill_numbers,
 session_id = 1987,
 bill_category = 'education'
)

jct_bill_categories <- jct_bill_categories %>%
  left_join(t_bills %>% select(number, session_id, bill_id), by = c("number", "session_id")
            ) %>%
  rename(
    bill_number = number
    )


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
schema_name <- "proc"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

list_tables <- c(
  "jct_bill_categories"
)

write_tables_in_list(con, schema_name, list_tables)

# Close the connection
dbDisconnect(con)
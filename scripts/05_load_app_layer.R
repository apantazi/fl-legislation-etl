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
# 2) write dataframes to Postgres and test  #
#                                           #
#############################################
# db schema for Andrew's Shiny app legislative dashboard currently at https://shiny.jaxtrib.org/.
schema_name <- "app_shiny"
dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

#tables currently in testing

list_tables <- c(
  "d_partisan_votes",
  "d_votes",
  "priority_votes",
  "r_partisan_votes",
  "r_votes"
)

process_table_list(con, schema_name, list_tables)

#handle heatmap_data separately for now b/c it's problematic
table_name = "heatmap_data"
exclude_cols <- c("roll_call_id", "progress", "history", "sponsors", "sasts", "texts")
cat("\n","---------------------\n",toupper(table_name),"\n","---------------------\n")
df <- get(table_name)
df <- df %>% select(-one_of(exclude_cols))
write_table(df, con, schema_name, table_name)
test_table(con, schema_name, table_name)

# create configuration table, if necessary
# then insert values y_labels into configuration table
dbExecute(con, paste0("
  CREATE TABLE IF NOT EXISTS ", schema_name, ".config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
"))
dbExecute(con, paste0("INSERT INTO ", schema_name, ".config (key, value) VALUES ('y_labels', '", y_labels, "') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value"))



# Close the connection
dbDisconnect(con)

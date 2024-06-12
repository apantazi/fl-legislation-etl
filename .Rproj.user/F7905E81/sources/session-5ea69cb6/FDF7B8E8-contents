# WRITE-TO-POSTGRES.R
# 6/11/24 RR
# This script takes data that's already been extracted and transformed from LegiScan and other sources
# and writes it into the Postgres database fl_leg_votes

########################################
#                                      #  
# 1) define database write functions   #
#                                      #
########################################

# db schema for Andrew's Shiny app legislative dashboard currently at https://shiny.jaxtrib.org/.
schema_name <- "app_shiny"





write_with_progress <- function(df, con, schema_name, table_name, chunk_size = 1000) {
  n <- nrow(df)
  pb <- progress_bar$new(
    format = paste0("  writing ", table_name, " [:bar] :percent in :elapsed"),
    total = n,
    clear = FALSE,
    width = 60
  )
  
  # Initialize the progress bar
  pb$tick(0)
  
  for (i in seq(1, n, by = chunk_size)) {
    end <- min(i + chunk_size - 1, n)
    chunk <- df[i:end, ]
    
    dbWriteTable(con, SQL(paste0(schema_name, ".", table_name)), 
                 as.data.frame(chunk), row.names = FALSE, append = TRUE)
    
    pb$tick(end - i + 1)
  }
  cat("Data successfully written to", paste0(schema_name, ".", table_name), "\n")
}



test_table <- function(con, schema_name, table_name) {
  #display first five records, but it prints the same thing for every table
  print("first five records")
  print(dbGetQuery(con, paste0("SELECT * FROM ", schema_name, ".", table_name, " LIMIT 5")))
  
  # display recordcount
  sql_recordcount <- paste0("SELECT COUNT(*) as num_rows FROM ", schema_name, ".", table_name)
  recordcount_table <- dbGetQuery(con, sql_recordcount)
  n <- as.numeric(recordcount_table$num_rows)
  cat(n, "records in", paste0(schema_name, ".", table_name), "\n")
}
  


########################################
#                                      #  
# 2) connect to Postgres server        #
#                                      #
########################################
attempt_connection <- function() {
  # Prompt for password
  password_db <- readline(
    prompt="Make sure ye've fired up the Postgres server and hooked up to the database.
    Now, what be the secret code to yer treasure chest o' data?: ")
  
  # Attempt to connect to Postgres database
  con <- tryCatch(
    dbConnect(RPostgres::Postgres(), 
              dbname = "fl_leg_votes", 
              host = "localhost", 
              port = 5432, 
              user = "postgres", 
              password = password_db),
    error = function(e) {
      message("Connection failed: ", e$message)
      return(NULL)
    }
  )
  return(con)
}

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
# 3) write dataframes to Postgres and test  #
#                                           #
#############################################

dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema_name))

#tables currently in testing

list_tables <- c(
  "d_partisan_votes",
  "d_votes",
  "priority_votes",
  "r_partisan_votes",
  "r_votes"
)

for (table_name in list_tables) {
  cat("\n","---------------------\n",toupper(table_name),"\n","---------------------\n")
  df <- get(table_name)
  df <- df
  write_with_progress(df, con, schema_name, table_name)
  test_table(con, schema_name, table_name)
}

#handle heatmap_data separately b/c it's problematic
table_name = "heatmap_data"
exclude_cols <- c("roll_call_id", "progress", "history", "sponsors", "sasts", "texts")
cat("\n","---------------------\n",toupper(table_name),"\n","---------------------\n")
df <- get(table_name)
df <- df %>% select(-one_of(exclude_cols))
write_with_progress(df, con, schema_name, table_name)
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

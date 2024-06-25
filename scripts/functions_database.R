# FUNCTIONS_DATABASE.R
# 6/11/24 RR
# separated these functions b/c they're used at both the parse and the transform layers

########################################
#                                      #  
# define database write functions      #
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



write_table <- function(df, con, schema_name, table_name, chunk_size = 1000) {
  n <- nrow(df)
  pb <- progress_bar$new(
    format = paste0("  writing table ", schema_name, ".", table_name, " [:bar] :percent in :elapsed"),
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



# Function to check if the table exists
table_exists <- function(con, schema_name, table_name) {
  query <- paste0(
    "SELECT EXISTS (",
    "SELECT FROM information_schema.tables ",
    "WHERE table_schema = '", schema_name, "' ",
    "AND table_name = '", table_name, "')"
  )
  result <- dbGetQuery(con, query)
  return(result$exists[1])
}



verify_table <- function(con, schema_name, table_name) {
  #display first five records, but it prints the same thing for every table
  print("first five records")
  print(dbGetQuery(con, paste0("SELECT * FROM ", schema_name, ".", table_name, " LIMIT 5")))
  
  # display recordcount
  sql_recordcount <- paste0("SELECT COUNT(*) as num_rows FROM ", schema_name, ".", table_name)
  recordcount_table <- dbGetQuery(con, sql_recordcount)
  n <- as.numeric(recordcount_table$num_rows)
  cat(n, "records in", paste0(schema_name, ".", table_name), "\n")
}
  


write_table_list <- function(con, schema_name, list_tables) {
  for (table_name in list_tables) {
    cat("\n","---------------------\n",toupper(table_name),"\n","---------------------\n")
    df <- get(table_name)
    df <- df
    
    if (table_exists(con, schema_name, table_name)) {
      dbExecute(con, paste0("DROP TABLE IF EXISTS ", schema_name, ".", table_name, " CASCADE"))
      message("Dropping existing table ", schema_name, ".", table_name)
    } else {
      message("Adding new table ", schema_name, ".", table_name)
    }
    
    write_table(df, con, schema_name, table_name)
    verify_table(con, schema_name, table_name)
  }
}
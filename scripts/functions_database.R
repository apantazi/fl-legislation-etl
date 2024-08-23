# FUNCTIONS_DATABASE.R
# June to August 2024 RR
# These functions are used at parse, process, and app creation stages

##############################
#                            #  
# get environment variables  #
#                            #
##############################
# Define the environment: "staging" or "production"
setting_env <- "staging"

print(paste("ETL pipeline is switched to the", setting_env, "environment."))

# Start the appropriate Docker container
if (setting_env == "staging") {
  system("docker start jaxtrib_staging")
  db_name <- "fl_leg_staging"
  db_port <- 5433
  db_container <- "jaxtrib_staging"
} else if (setting_env == "production") {
  system("docker start jaxtrib_postgres")
  db_name <- "fl_leg_votes"
  db_port <- 5432
  db_container <- "jaxtrib_postgres"
}

##############################
#                            #  
# start Docker engine and db #
#                            #
##############################
# start up Docker service. This will work on Mac, on Windows only if you run RStudio as administrator. Otherwise it'll state a warning.
tryCatch({
  system("net start com.docker.service", intern = TRUE)
}, warning = function(w) {
  message("Windows users can ignore this warning if you've already started Docker Desktop prior to running this script.")
  message("Original warning: ", conditionMessage(w))
}, error = function(e) {
  stop(e)  # Re-throw the error if it's not a warning
})

system("docker ps")

# start the Docker container
print(paste("Starting", db_container, "container."))
bash_command <- paste("docker exec -i", db_container, "bash -c")
psql_command <- paste("\"psql -U postgres -d", db_name, "\"")

#start the postgres database
system(paste(bash_command, psql_command))
print(paste("Connected to the", db_name, "database on port", db_port))

# Optionally stop the container after the ETL process is complete
# Uncomment the lines below if you want to stop the container at the end
# if (setting_env == "staging") {
#   system("docker stop jaxtrib_staging")
# } else if (setting_env == "production") {
#   system("docker stop jaxtrib_production")
# }


# remove if not used
# env_db_name <- Sys.getenv("DB_NAME")
# env_db_port <- Sys.getenv("DB_PORT")
# env_name <- Sys.getenv("ENVIRONMENT")
# 
# print(paste("ETL pipeline is switched to the ", env_name, " environment."))
# print(paste("Connecting to ", env_db_name, " on port ", env_db_port))

########################################
#                                      #  
# define database write functions      #
#                                      #
########################################

# Extract the db password from local config
config <- config::get()
password_db <- config::get("postgres_pwd")

attempt_connection <- function() {
  # Prompt for password
  # password_db <- readline(
  #   prompt="Make sure ye've fired up the Postgres server and hooked up to the database.
  #   Now, what be the secret code to yer treasure chest o' data?: ")
  
  con <- tryCatch(
    dbConnect(
              RPostgres::Postgres(),
              dbname = db_name,
              host = "localhost",
              port = as.integer(db_port),
              user = "postgres",
              password = password_db
              ),
    error = function(e) {
      message("Connection failed: ", e$message, " Make sure ye've fired up the Postgres server and hooked up to the database.")
      return(NULL)
    }
  )
  return(con)
}



write_table <- function(df, con, schema_name, table_name, chunk_size = 1000) {
  n <- nrow(df)
  flush.console()  # Ensure immediate output
  pb <- progress_bar$new(
    format = paste0("  writing table ", schema_name, ".", table_name, " [:bar] :percent in :elapsed"),
    total = n,
    clear = FALSE,
    width = 100
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
  flush.console()  # Ensure immediate output
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
  # display recordcount
  sql_recordcount <- paste0("SELECT COUNT(*) as num_rows FROM ", schema_name, ".", table_name)
  recordcount_table <- dbGetQuery(con, sql_recordcount)
  n <- as.numeric(recordcount_table$num_rows)
  cat(n, "records in", paste0(schema_name, ".", table_name), "\n")
}



create_pk <- function(con, schema_name, table_name, primary_keys) {
  pk_columns <- primary_keys[[table_name]]
  if (!is.null(pk_columns)) {
    pk_columns_str <- paste(pk_columns, collapse = ", ")
    dbExecute(con, paste0("ALTER TABLE ", schema_name, ".", table_name, 
                          " ADD PRIMARY KEY (", pk_columns_str, ");"))
    message("Adding primary key(s) (", pk_columns_str, ") to table ", schema_name, ".", table_name)
  }
}



write_tables_in_list <- function(con, schema_name, list_tables, primary_keys= NULL) {
  for (table_name in list_tables) {
    cat("\n","---------------------\n",toupper(table_name),"\n","---------------------\n")
    df <- get(table_name)
    
    if (table_exists(con, schema_name, table_name)) {
      dbExecute(con, paste0("DROP TABLE IF EXISTS ", schema_name, ".", table_name, " CASCADE"))
      message("Dropping table ", schema_name, ".", table_name)
    } else {
      message("Adding new table ", schema_name, ".", table_name)
    }
    
    message("Adding new table ", schema_name, ".", table_name)
    write_table(df, con, schema_name, table_name)
    verify_table(con, schema_name, table_name)
    if (!is.null(primary_keys)) {
      create_pk(con, schema_name, table_name, primary_keys)
    }
  }
}

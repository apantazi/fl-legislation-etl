# FUNCTIONS_DATABASE.R
# Sept 2024 AP
# These functions are used at parse, process, and app creation stages

##############################
#                            #  
# get environment variables  #
#                            #
##############################
# Define the environment: "staging" or "production"
# Extract the db password from local config
config <- config::get()
password_db <- config::get("postgres_pwd")

setting_env <- readline(prompt = "Please select the environment ('staging' or 'production'): ")
while (!(setting_env %in% c("staging", "production"))) {
  setting_env <- readline(prompt = "Invalid input. Please enter 'staging' or 'production': ")
}
print(paste("ETL pipeline is switched to the", setting_env, "environment."))

use_docker <- readline(prompt = "Do you want to use Docker to manage your Postgres database? (Y/N): ")
if (toupper(use_docker) == "Y") {
  # If user chooses to use Docker
  print("Using Docker to manage the Postgres database.")
  
  # Start the appropriate Docker container
  if (setting_env == "staging") {
    db_name <- "fl_leg_staging"
    db_port <- 5433
    db_container <- "compass_staging"
  } else if (setting_env == "production") {
    db_name <- "fl_leg_votes"
    db_port <- 5432
    db_container <- "compass_postgres"
  }
  
  ##############################
  #                            #  
  # start Docker engine and db #
  #                            #
  ##############################
  # start up Docker service. This will work on Mac, on Windows only if you run RStudio as administrator. Otherwise it'll state a warning.
  tryCatch({
    if (.Platform$OS.type == "windows") {
      system("net start com.docker.service")
    } else {
      # Check if Docker is running
      docker_status <- system("docker info > /dev/null 2>&1", intern = FALSE)
      
      if (docker_status != 0) {
        # Docker is not running; attempt to start Docker
        if (.Platform$OS.type == "unix" && Sys.info()["sysname"] == "Darwin") {
          # Mac
          message("Attempting to start Docker Desktop on macOS")
          system("open /Applications/Docker.app", wait = FALSE)
          Sys.sleep(5)  # Give Docker some time to start
        } else {
          # Linux
          message("Attempting to start Docker service on Linux")
          system("sudo systemctl start docker")
          Sys.sleep(5)
        }
      } else {
        message("Docker is already running.")
      }
    }
  }, warning = function(w) {
    message("Windows users can ignore this warning if you've already started Docker Desktop prior to running this script.")
    message("Original warning: ", conditionMessage(w))
  }, error = function(e) {
    stop(e)  # Re-throw the error if it's not a warning
  })
  
  container_exists <- tryCatch({
    system("docker ps -a --format '{{.Names}}'", intern = TRUE)
  }, error = function(e) {
    message("Error checking container existence: ", e$message)
    return(character(0))
  })
  if (length(container_exists) == 0) {
    stop("Failed to retrieve Docker containers. Ensure Docker is running and accessible.")
  }
  
  if (db_container %in% container_exists) {
    print(paste("Container", db_container, "already exists."))
  } else {
    # Container does not exist
    print(paste("Container", db_container, "does not exist. Creating it now..."))
    
    # Run the Docker container
    run_container_cmd <- paste(
      "docker run -d",
      "--name", db_container,
      "-e", paste0("POSTGRES_PASSWORD=", shQuote(password_db)),
      "-p", paste0(db_port, ":5432"),
      "postgres"  # Ensure this is in quotes
    )
    system(run_container_cmd)
    
    Sys.sleep(5)  # Give the container some time to start
  }
  
  container_status <- system(paste0("docker ps --format '{{.Names}}'"), intern = TRUE)
  
  if (!(db_container %in% container_status)) {
    # If the container is not running, start it
    print(paste("Container", db_container, "is not running. Starting it now..."))
    system(paste("docker start", db_container))
    Sys.sleep(5)
  } else {
    print(paste("Container", db_container, "is already running."))
  }
  
  tryCatch({
    
    system("docker ps")
    
    # start the Docker container
    print(paste("Starting", db_container, "container."))
    check_db_cmd <- paste0(
      "docker exec -i -u postgres ", db_container, 
      " psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname = '", db_name, "'\""
      
    )
    print(paste("Checking if the database exists with command:", check_db_cmd))  # Debugging
    
    db_exists <- tryCatch({
      system(check_db_cmd, intern = TRUE)
    }, error = function(e) {
      message("Error while checking the database: ", e$message)
      return(NULL)
    })
    
    # Debugging: Print the result of the check
    
    if (length(db_exists) > 0 && trimws(db_exists[1]) == "1") {
      print(paste("Database", db_name, "already exists."))
      } else {
        print(paste("Database", db_name, "does not exist. Creating database..."))
        create_db_cmd <- paste0(
          "docker exec -i -u postgres ", db_container,
          " psql -U postgres -c \"CREATE DATABASE ", db_name, ";\""
          )
        system(create_db_cmd)
        Sys.sleep(2) # Give Postgres a moment
        }
    
    psql_command <- paste0(
      "docker exec -i -u postgres ", db_container,
      " psql -U postgres -d ", db_name,
      " -c \"SELECT 1;\""
    )
    print(paste("Running psql command:", psql_command))  # Debugging: Print the command being run
    
    # Attempt to connect using Docker
    result <- tryCatch({
      system(psql_command, intern = TRUE)
    }, error = function(e) {
      message("Error while running psql command: ", e$message)
      return(NULL)  # Return NULL in case of an error
    })
    
    # Check the result and handle the connection status
    if (!is.null(result) && length(result) > 0) {
      print(paste("Connected to the", db_name, "database on port", db_port))
    } else {
      stop("Failed to connect to the Docker container or database. Please ensure Docker is running and the database exists.")
    }
    
    
    # Optionally stop the container after the ETL process is complete
    # Uncomment the lines below if you want to stop the container at the end
    # if (setting_env == "staging") {
    #   system("docker stop compass_staging")
    # } else if (setting_env == "production") {
    #   system("docker stop compass_production")
    # }
  }, error = function(e) {
    stop("Error occurred while interacting with Docker: ", conditionMessage(e))
  })
} else if (toupper(use_docker) == "N") {
  
  # If user chooses not to use Docker
  
  print("Skipping Docker. Connecting directly to Postgres.")
  if (setting_env == "staging") {
    
    db_name <- "fl_leg_staging"
    
    db_port <- 5433
    
  } else if (setting_env == "production") {
    
    db_name <- "fl_leg_votes"
    
    db_port <- 5432
    
  }
}

########################################
#                                      #  
# define database write functions      #
#                                      #
########################################


attempt_connection <- function() {
  # Prompt for password
  if (is.null(password_db)) { password_db <- readline(
    prompt="Make sure ye've fired up the Postgres server and hooked up to the database.
     Now, what be the secret code to yer treasure chest o' data?: ")
  }
  
  
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
  if (n <= 0) { # Add this check
    cat("Skipping write for empty table:", paste0(schema_name, ".", table_name), "\n")
    return() # Exit the function if dataframe is empty
  }
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



write_tables_in_list <- function(con, schema_name, list_tables, primary_keys = NULL) {
  for (table_name in list_tables) {
    cat("\n", "---------------------\n", toupper(table_name), "\n", "---------------------\n")
    df <- get(table_name)
    n_rows <- nrow(df) # Get the row count early
    
    # Drop table if it exists from a previous run
    if (table_exists(con, schema_name, table_name)) {
      dbExecute(con, paste0("DROP TABLE IF EXISTS ", schema_name, ".", table_name, " CASCADE"))
      message("Dropping table ", schema_name, ".", table_name)
    } # Note: No "else" needed here, we always try to write if n_rows > 0
    
    # --- MODIFICATION START ---
    # Only attempt to write, verify, and add PK if the dataframe is NOT empty
    if (n_rows > 0) {
      message("Adding new table ", schema_name, ".", table_name) # Message moved inside check
      write_table(df, con, schema_name, table_name) # Will proceed only if n > 0 anyway because of internal check
      verify_table(con, schema_name, table_name) # Now safe to verify
      if (!is.null(primary_keys)) {
        create_pk(con, schema_name, table_name, primary_keys) # Now safe to add PK
      }
    } else {
      # Optional: Add a message here if you want confirmation,
      # but write_table already prints "Skipping write..."
      message("Skipping verify/PK steps for empty table: ", paste0(schema_name, ".", table_name))
    }
    # --- MODIFICATION END ---
    
  }
}

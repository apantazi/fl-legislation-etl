#################################
#                               #
# BENCHMARK_ETL.R               #
#                               #
#################################
# Benchmarking script that runs each ETL stage and logs execution time and memory usage
# This script overrides readline() to run non-interactively
#
# Run from RStudio with: source("scripts/benchmark_etl.R")

#################################
# Configuration                 #
#################################

# SET THESE VALUES BEFORE RUNNING:
BENCHMARK_ENV <- "staging"        # "staging" or "production"
BENCHMARK_USE_DOCKER <- "N"       # "Y" or "N"
BENCHMARK_START_YEAR <- 2025      # Start year for parsing
BENCHMARK_END_YEAR <- 2025        # End year for parsing
BENCHMARK_DEMO_SRC <- "CVAP"      # Demo source
BENCHMARK_DEMO_YEAR <- 22         # Demo year
BENCHMARK_PARTY_LOYALTY <- "partisan"  # Party loyalty setting
BENCHMARK_ELEC_SRC <- "Pres20"    # Election source
BENCHMARK_SKIP_DB <- TRUE         # Skip database operations for faster benchmarking

#################################
# Setup                         #
#################################

# Use here package for portable path resolution
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)
setwd(here("scripts"))  # Set working directory to scripts folder

# Install memory profiling package if needed
if (!requireNamespace("pryr", quietly = TRUE)) {
  install.packages("pryr")
}

#################################
# Override readline             #
#################################

# Store original readline
original_readline <- base::readline

# Create a counter to track which prompt we're on
readline_counter <- new.env()
readline_counter$count <- 0

# Override readline to return preset values based on prompt text
readline <- function(prompt = "") {
  readline_counter$count <- readline_counter$count + 1

  # Match prompt patterns and return appropriate values
  if (grepl("environment.*staging.*production", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_ENV, "\n")
    return(BENCHMARK_ENV)
  }
  if (grepl("docker", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_USE_DOCKER, "\n")
    return(BENCHMARK_USE_DOCKER)
  }
  if (grepl("start year", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_START_YEAR, "\n")
    return(as.character(BENCHMARK_START_YEAR))
  }
  if (grepl("end year", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_END_YEAR, "\n")
    return(as.character(BENCHMARK_END_YEAR))
  }
  if (grepl("demographic.*source|demo.*src", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_DEMO_SRC, "\n")
    return(BENCHMARK_DEMO_SRC)
  }
  if (grepl("demographic.*year|demo.*year", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_DEMO_YEAR, "\n")
    return(as.character(BENCHMARK_DEMO_YEAR))
  }
  if (grepl("party.*loyalty", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_PARTY_LOYALTY, "\n")
    return(BENCHMARK_PARTY_LOYALTY)
  }
  if (grepl("election.*source|elec.*src", prompt, ignore.case = TRUE)) {
    cat(prompt, BENCHMARK_ELEC_SRC, "\n")
    return(BENCHMARK_ELEC_SRC)
  }
  if (grepl("password|pwd", prompt, ignore.case = TRUE)) {
    cat(prompt, "[using config]\n")
    return("")
  }

  # Default: return empty string
  cat(prompt, "[default]\n")
  return("")
}

#################################
# Benchmark Infrastructure      #
#################################

benchmark_results <- data.frame(
  stage = character(),
  script = character(),
  time_seconds = numeric(),
  memory_mb_start = numeric(),
  memory_mb_end = numeric(),
  memory_delta_mb = numeric(),
  objects_created = integer(),
  status = character(),
  error_msg = character(),
  stringsAsFactors = FALSE
)

get_memory_mb <- function() {
  gc(verbose = FALSE)
  pryr::mem_used() / 1024 / 1024
}

count_objects <- function() {
  length(ls(envir = .GlobalEnv))
}

benchmark_stage <- function(stage_name, script_path) {
  cat("\n")
  cat(paste(rep("=", 70), collapse = ""), "\n")
  cat("STAGE:", stage_name, "\n")
  cat("Script:", script_path, "\n")
  cat(paste(rep("=", 70), collapse = ""), "\n")

  if (!file.exists(script_path)) {
    cat("Script not found - SKIPPED\n")
    return(data.frame(
      stage = stage_name, script = script_path,
      time_seconds = NA, memory_mb_start = NA, memory_mb_end = NA,
      memory_delta_mb = NA, objects_created = NA,
      status = "SKIPPED", error_msg = "File not found",
      stringsAsFactors = FALSE
    ))
  }

  gc(verbose = FALSE)
  mem_start <- get_memory_mb()
  obj_start <- count_objects()
  start_time <- Sys.time()

  result <- tryCatch({
    source(script_path, local = FALSE, echo = FALSE)
    list(status = "SUCCESS", error = "")
  }, error = function(e) {
    list(status = "ERROR", error = conditionMessage(e))
  }, warning = function(w) {
    # Continue on warnings
    list(status = "WARNING", error = conditionMessage(w))
  })

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  mem_end <- get_memory_mb()
  obj_end <- count_objects()

  cat("\n--- RESULTS ---\n")
  cat(sprintf("Time: %.2f seconds (%.1f min)\n", elapsed, elapsed/60))
  cat(sprintf("Memory: %.1f MB -> %.1f MB (delta: %+.1f MB)\n",
              mem_start, mem_end, mem_end - mem_start))
  cat(sprintf("Objects: %d -> %d (new: %d)\n", obj_start, obj_end, obj_end - obj_start))
  cat(sprintf("Status: %s\n", result$status))
  if (result$error != "") cat(sprintf("Message: %s\n", result$error))

  return(data.frame(
    stage = stage_name, script = script_path,
    time_seconds = elapsed,
    memory_mb_start = mem_start, memory_mb_end = mem_end,
    memory_delta_mb = mem_end - mem_start,
    objects_created = obj_end - obj_start,
    status = result$status, error_msg = result$error,
    stringsAsFactors = FALSE
  ))
}

#################################
# Load Libraries                #
#################################

cat("\n")
cat(paste(rep("#", 70), collapse = ""), "\n")
cat("#  ETL PIPELINE BENCHMARK                                            #\n")
cat(sprintf("#  Environment: %-10s  Years: %d-%d                          #\n",
            BENCHMARK_ENV, BENCHMARK_START_YEAR, BENCHMARK_END_YEAR))
cat(sprintf("#  Skip DB: %-5s                                                 #\n", BENCHMARK_SKIP_DB))
cat(paste(rep("#", 70), collapse = ""), "\n")

cat("\nLoading libraries...\n")
lib_start <- Sys.time()

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
  library(DBI)
  library(RPostgres)
  library(progress)
  library(dplyr)
  library(pryr)
})

# Optional libraries
tryCatch(library(legiscanrr), error = function(e) cat("Note: legiscanrr not available\n"))
tryCatch(library(googlesheets4), error = function(e) cat("Note: googlesheets4 not available\n"))
tryCatch(library(future.apply), error = function(e) cat("Note: future.apply not available\n"))

lib_time <- as.numeric(difftime(Sys.time(), lib_start, units = "secs"))
cat(sprintf("Libraries loaded in %.1f seconds\n", lib_time))

#################################
# Pre-set Environment Variables #
#################################

# These are normally set by functions_database.R via readline
setting_env <- BENCHMARK_ENV
use_docker <- BENCHMARK_USE_DOCKER

if (BENCHMARK_ENV == "staging") {
  db_name <- "fl_leg_staging"
  db_port <- 5433
} else {
  db_name <- "fl_leg_votes"
  db_port <- 5432
}

# Pre-set parse settings (normally set by 02a_raw_parse_legiscan.R)
setting_parse_start_year <- BENCHMARK_START_YEAR
setting_parse_end_year <- BENCHMARK_END_YEAR

# Pre-set app settings (normally set by 04a_app_settings.R)
setting_demo_src <- BENCHMARK_DEMO_SRC
setting_demo_year <- BENCHMARK_DEMO_YEAR
setting_party_loyalty <- BENCHMARK_PARTY_LOYALTY
setting_elec_src <- BENCHMARK_ELEC_SRC

# Get config for database password
config <- config::get()
password_db <- config::get("postgres_pwd")

#################################
# Define Database Functions     #
#################################

# Simplified database functions (from functions_database.R)
attempt_connection <- function() {
  if (BENCHMARK_SKIP_DB) {
    message("Database connection skipped (BENCHMARK_SKIP_DB=TRUE)")
    return(NULL)
  }
  pw <- password_db
  tryCatch(
    dbConnect(RPostgres::Postgres(), dbname = db_name, host = "localhost",
              port = as.integer(db_port), user = "postgres", password = pw),
    error = function(e) { message("DB connection failed: ", e$message); NULL }
  )
}

write_table <- function(df, con, schema_name, table_name, chunk_size = 1000) {
  if (is.null(con) || BENCHMARK_SKIP_DB) {
    cat("Skipping DB write:", paste0(schema_name, ".", table_name), "\n")
    return()
  }
  n <- nrow(df)
  if (n <= 0) return()

  pb <- progress::progress_bar$new(
    format = paste0("  writing ", schema_name, ".", table_name, " [:bar] :percent"),
    total = n, clear = FALSE, width = 80
  )
  pb$tick(0)
  for (i in seq(1, n, by = chunk_size)) {
    end <- min(i + chunk_size - 1, n)
    dbWriteTable(con, SQL(paste0(schema_name, ".", table_name)),
                 as.data.frame(df[i:end, ]), row.names = FALSE, append = TRUE)
    pb$tick(end - i + 1)
  }
}

table_exists <- function(con, schema_name, table_name) {
  if (is.null(con)) return(FALSE)
  query <- sprintf("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = '%s' AND table_name = '%s')",
                   schema_name, table_name)
  dbGetQuery(con, query)$exists[1]
}

verify_table <- function(con, schema_name, table_name) {
  if (is.null(con)) return()
  n <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM %s.%s", schema_name, table_name))$n
  cat(n, "records in", paste0(schema_name, ".", table_name), "\n")
}

create_pk <- function(con, schema_name, table_name, primary_keys) {
  if (is.null(con)) return()
  pk_columns <- primary_keys[[table_name]]
  if (!is.null(pk_columns)) {
    dbExecute(con, sprintf("ALTER TABLE %s.%s ADD PRIMARY KEY (%s);",
                           schema_name, table_name, paste(pk_columns, collapse = ", ")))
  }
}

write_tables_in_list <- function(con, schema_name, list_tables, primary_keys = NULL) {
  for (table_name in list_tables) {
    cat("\n---", toupper(table_name), "---\n")
    if (!exists(table_name)) { cat("Object not found\n"); next }
    df <- get(table_name)
    if (BENCHMARK_SKIP_DB) { cat("Skipping DB (benchmark mode)\n"); next }
    if (!is.null(con) && table_exists(con, schema_name, table_name)) {
      dbExecute(con, paste0("DROP TABLE IF EXISTS ", schema_name, ".", table_name, " CASCADE"))
    }
    if (nrow(df) > 0) {
      write_table(df, con, schema_name, table_name)
      verify_table(con, schema_name, table_name)
      if (!is.null(primary_keys)) create_pk(con, schema_name, table_name, primary_keys)
    }
  }
}

#################################
# RUN BENCHMARKS                #
#################################

benchmark_total_start <- Sys.time()

# Stage 2a: Parse LegiScan JSON
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("02a_raw_parse_legiscan", "02a_raw_parse_legiscan.R"))

# Stage 2b: Read CSVs
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("02b_raw_read_csvs", "02b_raw_read_csvs.R"))

# Stage 2z: Raw Load (will be skipped if BENCHMARK_SKIP_DB=TRUE)
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("02z_raw_load", "02z_raw_load.R"))

# Stage 3a: Process
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("03a_process", "03a_process.R"))

# Stage 3z: Process Load
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("03z_process_load", "03z_process_load.R"))

# Stage 4a: App Settings
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("04a_app_settings", "04a_app_settings.R"))

# Stage 4b: App Prep
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("04b_app_prep", "04b_app_prep.R"))

# Stage 4c: App Bill Lookup (may not exist)
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("04c_app_bill_lookup", "04c_app_bill_lookup.R"))

# Stage 4z: App Load
benchmark_results <- rbind(benchmark_results,
                           benchmark_stage("04z_app_load", "04z_app_load.R"))

benchmark_total_end <- Sys.time()
total_time <- as.numeric(difftime(benchmark_total_end, benchmark_total_start, units = "secs"))

#################################
# RESULTS REPORT                #
#################################

cat("\n\n")
cat(paste(rep("#", 70), collapse = ""), "\n")
cat("#  BENCHMARK RESULTS                                                 #\n")
cat(paste(rep("#", 70), collapse = ""), "\n")

# Filter successful stages
successful <- benchmark_results[benchmark_results$status == "SUCCESS", ]

if (nrow(successful) > 0) {
  # Sort by time
  successful <- successful[order(-successful$time_seconds), ]

  cat("\n=== ALL STAGES BY EXECUTION TIME ===\n\n")
  cat(sprintf("%-25s %10s %12s %10s\n", "Stage", "Time(sec)", "Memory(MB)", "Status"))
  cat(paste(rep("-", 60), collapse = ""), "\n")

  for (i in 1:nrow(benchmark_results)) {
    r <- benchmark_results[i, ]
    time_str <- if(is.na(r$time_seconds)) "N/A" else sprintf("%.2f", r$time_seconds)
    mem_str <- if(is.na(r$memory_delta_mb)) "N/A" else sprintf("%+.1f", r$memory_delta_mb)
    cat(sprintf("%-25s %10s %12s %10s\n", r$stage, time_str, mem_str, r$status))
  }

  cat("\n")
  cat(paste(rep("*", 60), collapse = ""), "\n")
  cat("*                    TOP 3 SLOWEST STAGES                    *\n")
  cat(paste(rep("*", 60), collapse = ""), "\n")

  top3 <- head(successful, 3)
  for (i in 1:nrow(top3)) {
    r <- top3[i, ]
    cat(sprintf("\n  #%d: %s\n", i, r$stage))
    cat(sprintf("      Time: %.2f seconds (%.1f minutes)\n", r$time_seconds, r$time_seconds/60))
    cat(sprintf("      Memory change: %+.1f MB\n", r$memory_delta_mb))
    cat(sprintf("      Script: %s\n", r$script))
  }

  # Memory analysis
  mem_sorted <- successful[order(-successful$memory_delta_mb), ]
  cat("\n=== TOP 3 MEMORY CONSUMERS ===\n")
  for (i in 1:min(3, nrow(mem_sorted))) {
    r <- mem_sorted[i, ]
    cat(sprintf("  #%d: %-25s %+.1f MB\n", i, r$stage, r$memory_delta_mb))
  }
}

# Errors summary
errors <- benchmark_results[benchmark_results$status == "ERROR", ]
if (nrow(errors) > 0) {
  cat("\n=== ERRORS ===\n")
  for (i in 1:nrow(errors)) {
    cat(sprintf("  %s: %s\n", errors$stage[i], errors$error_msg[i]))
  }
}

cat("\n=== TOTAL TIME ===\n")
cat(sprintf("Total benchmark time: %.2f seconds (%.1f minutes)\n", total_time, total_time/60))

# Save results
log_file <- "../qa/benchmark_results.log"
dir.create(dirname(log_file), showWarnings = FALSE, recursive = TRUE)
sink(log_file)
cat("ETL Pipeline Benchmark Results\n")
cat("==============================\n")
cat("Date:", as.character(Sys.time()), "\n")
cat("Environment:", BENCHMARK_ENV, "\n")
cat("Years:", BENCHMARK_START_YEAR, "-", BENCHMARK_END_YEAR, "\n")
cat("Skip DB:", BENCHMARK_SKIP_DB, "\n\n")
cat("Results:\n")
print(benchmark_results[, c("stage", "time_seconds", "memory_delta_mb", "status")])
cat("\n\nTop 3 Slowest:\n")
if(nrow(successful) > 0) print(head(successful[, c("stage", "time_seconds", "memory_delta_mb")], 3))
sink()

cat("\nResults saved to:", normalizePath(log_file, mustWork = FALSE), "\n")

# Restore original readline
readline <- original_readline

# Return results
benchmark_results

#################################
#                               #
# BENCHMARK_STANDALONE.R        #
#                               #
#################################
# Self-contained benchmark that extracts key functions from ETL scripts
# and runs them without RStudio dependencies
#
# Run with: Rscript benchmark_standalone.R

#################################
# Configuration                 #
#################################
BENCHMARK_START_YEAR <- 2025
BENCHMARK_END_YEAR <- 2025

# Use here package for portable path resolution
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)
setwd(here("scripts"))  # Set working directory to scripts folder

#################################
# Load Libraries                #
#################################
cat("\n========================================\n")
cat("ETL PIPELINE BENCHMARK\n")
cat("Years:", BENCHMARK_START_YEAR, "-", BENCHMARK_END_YEAR, "\n")
cat("========================================\n\n")

cat("Loading libraries...\n")
lib_start <- Sys.time()

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
  library(progress)
  library(dplyr)
  library(data.table)
})

# Install pryr for memory measurement
if (!requireNamespace("pryr", quietly = TRUE)) install.packages("pryr", repos = "https://cloud.r-project.org")
library(pryr)

lib_time <- as.numeric(difftime(Sys.time(), lib_start, units = "secs"))
cat(sprintf("Libraries loaded in %.1f seconds\n\n", lib_time))

#################################
# Benchmark Infrastructure      #
#################################
results <- list()

benchmark_fn <- function(name, expr) {
  cat(sprintf("\n--- %s ---\n", name))
  gc(verbose = FALSE)
  mem_before <- pryr::mem_used() / 1024 / 1024

  start <- Sys.time()
  result <- tryCatch(
    {
      eval(expr)
      list(status = "SUCCESS", error = "")
    },
    error = function(e) {
      list(status = "ERROR", error = conditionMessage(e))
    }
  )
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  gc(verbose = FALSE)
  mem_after <- pryr::mem_used() / 1024 / 1024

  cat(sprintf(
    "  Time: %.2f sec | Memory: %+.1f MB | Status: %s\n",
    elapsed, mem_after - mem_before, result$status
  ))
  if (result$error != "") cat(sprintf("  Error: %s\n", result$error))

  results[[name]] <<- list(
    time = elapsed,
    mem_delta = mem_after - mem_before,
    status = result$status,
    error = result$error
  )
  return(elapsed)
}

#################################
# STAGE 1: Parse LegiScan JSON  #
#################################
cat("\n========================================")
cat("\n STAGE 1: PARSE LEGISCAN JSON")
cat("\n========================================\n")

# Set parse years
setting_parse_start_year <- BENCHMARK_START_YEAR
setting_parse_end_year <- BENCHMARK_END_YEAR
parse_years <- as.character(setting_parse_start_year:setting_parse_end_year)
parse_pattern <- paste0("/(", paste(parse_years, collapse = "|"), ")")

# Get file paths
base_dir <- here("data-raw", "legiscan", "fl")
all_json_paths <- list.files(path = base_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE)
filtered_json_paths <- grep(parse_pattern, all_json_paths, value = TRUE)
text_paths_bills <- filtered_json_paths[grepl("/bill/", filtered_json_paths, ignore.case = TRUE)]
text_paths_legislators <- filtered_json_paths[grepl("/people/", filtered_json_paths, ignore.case = TRUE)]
text_paths_votes <- filtered_json_paths[grepl("/vote/", filtered_json_paths, ignore.case = TRUE)]

cat(sprintf(
  "Found %d bill JSONs, %d people JSONs, %d vote JSONs\n",
  length(text_paths_bills), length(text_paths_legislators), length(text_paths_votes)
))

# Define parsing functions (from 02a_raw_parse_legiscan.R)
extract_bill <- function(input_bill_path, pb) {
  pb$tick()
  bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
  bill <- bill_data$bill
  safe_get <- function(x, default = NA) ifelse(is.null(x), default, x)
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_bill_path, regexpr(session_regex, input_bill_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)

  list(meta = list(
    number = safe_get(bill$bill_number),
    bill_id = safe_get(bill$bill_id),
    session_id = safe_get(bill$session_id),
    session = session_info,
    session_name = safe_get(bill$session$session_name),
    url = safe_get(bill$url),
    state_link = safe_get(bill$state_link),
    title = safe_get(bill$title),
    type = safe_get(bill$type),
    description = safe_get(bill$description),
    status = safe_get(bill$status),
    status_date = safe_get(bill$status_date)
  ))
}

parse_bills <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing bills [:bar] :percent eta: :eta",
    total = length(bill_json_paths), clear = FALSE, width = 60
  )
  pb$tick(0)
  output_list <- lapply(bill_json_paths, extract_bill, pb)
  meta_list <- lapply(output_list, `[[`, "meta")
  tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE))
}

extract_people <- function(input_people_json_path, pb) {
  pb$tick()
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_people_json_path, regexpr(session_regex, input_people_json_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)
  people_data <- jsonlite::fromJSON(input_people_json_path)
  people <- people_data[["person"]]
  people$session <- session_info
  return(people)
}

parse_legislator_sessions <- function(people_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing legislators [:bar] :percent eta: :eta",
    total = length(people_json_paths), clear = FALSE, width = 60
  )
  pb$tick(0)
  output_list <- lapply(people_json_paths, extract_people, pb)
  tibble::as_tibble(data.table::rbindlist(output_list, fill = TRUE))
}

extract_votes <- function(votes, roll_call_id, session_info, pb) {
  if (is.null(votes)) {
    return(NULL)
  }
  do.call(rbind, lapply(votes, function(vote) {
    vote_df <- as.data.frame(vote, stringsAsFactors = FALSE)
    vote_df$roll_call_id <- roll_call_id
    vote_df$session <- session_info
    return(vote_df)
  }))
}

extract_roll_call <- function(input_vote_path, pb) {
  pb$tick()
  session_regex <- "(\\d{4}-\\d{4}_[^/]+)"
  matches <- regmatches(input_vote_path, regexpr(session_regex, input_vote_path))
  session_info <- ifelse(length(matches) > 0, matches, NA_character_)
  roll_call_data <- jsonlite::fromJSON(input_vote_path, simplifyVector = FALSE)
  roll_call <- roll_call_data$roll_call
  safe_get <- function(x, default = NA) ifelse(is.null(x), default, x)

  roll_call_meta_df <- list(
    roll_call_id = safe_get(roll_call$roll_call_id),
    bill_id = safe_get(roll_call$bill_id),
    session = session_info,
    date = safe_get(roll_call$date),
    desc = safe_get(roll_call$desc),
    yea = safe_get(roll_call$yea),
    nay = safe_get(roll_call$nay),
    nv = safe_get(roll_call$nv),
    absent = safe_get(roll_call$absent),
    total = safe_get(roll_call$total),
    passed = safe_get(roll_call$passed),
    chamber = safe_get(roll_call$chamber),
    chamber_id = safe_get(roll_call$chamber_id)
  )
  votes_df <- extract_votes(roll_call$votes, roll_call$roll_call_id, session_info, pb)
  list(meta = roll_call_meta_df, votes = votes_df)
}

parse_roll_calls <- function(vote_json_paths) {
  pb <- progress::progress_bar$new(
    format = "  parsing votes [:bar] :percent eta: :eta",
    total = length(vote_json_paths), clear = FALSE, width = 60
  )
  pb$tick(0)
  output_list <- lapply(vote_json_paths, extract_roll_call, pb)
  meta_list <- lapply(output_list, `[[`, "meta")
  votes_list <- lapply(output_list, `[[`, "votes")
  list(
    meta = tibble::as_tibble(data.table::rbindlist(meta_list, fill = TRUE)),
    votes = tibble::as_tibble(data.table::rbindlist(votes_list, fill = TRUE))
  )
}

# Run parsing benchmarks
benchmark_fn("parse_bills", quote({
  t_bills <- parse_bills(text_paths_bills) %>%
    mutate(
      session_year = as.numeric(str_extract(session_name, "\\d{4}")),
      two_year_period = case_when(
        session_year < 2011 ~ "2010 or earlier",
        session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep = "-"),
        TRUE ~ paste(session_year, session_year + 1, sep = "-")
      )
    )
}))
cat(sprintf("  Created t_bills with %d rows\n", nrow(t_bills)))

benchmark_fn("parse_legislator_sessions", quote({
  t_legislator_sessions <- parse_legislator_sessions(text_paths_legislators)
}))
cat(sprintf("  Created t_legislator_sessions with %d rows\n", nrow(t_legislator_sessions)))

benchmark_fn("parse_roll_calls", quote({
  temp_roll_calls_parsed <- parse_roll_calls(text_paths_votes)
  t_roll_calls <- temp_roll_calls_parsed$meta
  t_legislator_votes <- temp_roll_calls_parsed$votes
}))
cat(sprintf(
  "  Created t_roll_calls with %d rows, t_legislator_votes with %d rows\n",
  nrow(t_roll_calls), nrow(t_legislator_votes)
))

#################################
# STAGE 2: READ CSV FILES       #
#################################
cat("\n========================================")
cat("\n STAGE 2: READ CSV FILES")
cat("\n========================================\n")

benchmark_fn("read_daves_districts", quote({
  t_daves_districts_house <- read_csv(here("data-raw", "daves-redistricting-app", "FL2022_House_new2.csv"), show_col_types = FALSE)
  t_daves_districts_senate <- read_csv(here("data-raw", "daves-redistricting-app", "FL2022_Senate_new2.csv"), show_col_types = FALSE)
}))
cat(sprintf("  House: %d rows, Senate: %d rows\n", nrow(t_daves_districts_house), nrow(t_daves_districts_senate)))

benchmark_fn("read_user_data", quote({
  user_bill_categories <- tryCatch(
    read_csv(here("data-raw", "user-data", "user_bill_categories.csv"), show_col_types = FALSE),
    error = function(e) data.frame()
  )
  user_legislator_events <- tryCatch(
    read_csv(here("data-raw", "user-data", "user_legislator_events.csv"), show_col_types = FALSE),
    error = function(e) data.frame()
  )
  t_legislator_ids <- tryCatch(
    read_csv(here("data-raw", "user-data", "t_legislator_ids.csv"), show_col_types = FALSE),
    error = function(e) data.frame()
  )
}))

#################################
# STAGE 3: PROCESS DATA         #
#################################
cat("\n========================================")
cat("\n STAGE 3: PROCESS DATA")
cat("\n========================================\n")

benchmark_fn("process_bills_sessions", quote({
  p_bills <- t_bills %>%
    rename(bill_desc = description, bill_number = number, bill_title = title, bill_url = url)

  p_sessions <- p_bills %>%
    select(session_id, session_name, session, two_year_period) %>%
    distinct() %>%
    mutate(
      session_year = as.numeric(str_extract(session_name, "\\d{4}")),
      session_biennium = paste(
        if_else(session_year %% 2 == 0, session_year - 1, session_year),
        if_else(session_year %% 2 == 0, session_year, session_year + 1),
        sep = "-"
      )
    )
}))

benchmark_fn("process_roll_calls", quote({
  p_roll_calls <- t_roll_calls %>%
    left_join(p_bills %>% select(bill_id, bill_title, bill_number, session_year, bill_url), by = "bill_id") %>%
    rename(roll_call_date = date, roll_call_desc = desc, roll_call_chamber = chamber, n_total = total) %>%
    mutate(
      pct_of_total = yea / n_total,
      n_present = yea + nay,
      pct_of_present = yea / n_present,
      final_vote = ifelse(grepl("third", roll_call_desc, ignore.case = TRUE), "Y", "N")
    ) %>%
    select(-chamber_id)
}))
cat(sprintf("  Created p_roll_calls with %d rows\n", nrow(p_roll_calls)))

benchmark_fn("process_legislators", quote({
  hist_leg_sessions <- t_legislator_sessions %>%
    filter(party == "D" | party == "R") %>%
    rename(legislator_name = name) %>%
    mutate(
      ballotpedia = paste0("http://ballotpedia.org/", ballotpedia),
      district_number = as.integer(str_extract(district, "\\d+")),
      chamber = case_when(role == "Sen" ~ "Senate", role == "Rep" ~ "House", TRUE ~ role)
    )

  # Handle terminations if user data exists
  if (exists("user_legislator_events") && nrow(user_legislator_events) > 0) {
    calc_leg_terminated <- user_legislator_events %>%
      filter(event == "terminated") %>%
      left_join(hist_leg_sessions, by = c("chamber", "district_number", "last_name")) %>%
      mutate(termination_date = date, temp_name = last_name) %>%
      select(people_id, termination_date, temp_name) %>%
      group_by(people_id) %>%
      summarize(termination_date = max(termination_date, na.rm = TRUE), temp_name = first(temp_name)) %>%
      ungroup()
  } else {
    calc_leg_terminated <- data.frame(people_id = integer(), termination_date = as.Date(character()), temp_name = character())
  }

  p_legislators <- hist_leg_sessions %>%
    left_join(p_sessions %>% select(session, session_id), by = "session") %>%
    arrange(people_id, desc(session_id)) %>%
    group_by(people_id) %>%
    slice(1) %>%
    ungroup() %>%
    left_join(calc_leg_terminated, by = "people_id")
}))
cat(sprintf("  Created p_legislators with %d rows\n", nrow(p_legislators)))

benchmark_fn("process_legislator_votes", quote({
  p_legislator_votes <- t_legislator_votes %>%
    inner_join(hist_leg_sessions %>% select(people_id, session, party, legislator_name), by = c("people_id", "session")) %>%
    inner_join(p_roll_calls, by = c("roll_call_id", "session")) %>%
    inner_join(p_legislators %>% select(people_id, termination_date), by = "people_id")
}))
cat(sprintf("  Created p_legislator_votes with %d rows\n", nrow(p_legislator_votes)))

#################################
# STAGE 4: PARTISANSHIP ANALYSIS#
#################################
cat("\n========================================")
cat("\n STAGE 4: PARTISANSHIP ANALYSIS")
cat("\n========================================\n")

benchmark_fn("calc_roll_call_partisanship", quote({
  calc_rc01_by_party <- p_legislator_votes %>%
    group_by(party, roll_call_id, vote_text) %>%
    summarize(n = n(), .groups = "drop") %>%
    pivot_wider(values_from = n, names_from = vote_text, values_fill = 0) %>%
    mutate(
      n_total = rowSums(across(any_of(c("Yea", "Nay", "NV", "Absent"))), na.rm = TRUE),
      n_present = rowSums(across(any_of(c("Yea", "Nay"))), na.rm = TRUE),
      Yea = if ("Yea" %in% names(.)) Yea else 0
    ) %>%
    mutate(party_pct_of_present = Yea / n_present) %>%
    select(party, roll_call_id, party_pct_of_present, n_present)

  calc_rc02_partisan_pivot <- calc_rc01_by_party %>%
    pivot_wider(names_from = party, values_from = party_pct_of_present, values_fill = NA, id_cols = c(roll_call_id)) %>%
    mutate(
      dem_majority = case_when(D > 0.5 ~ "Y", D < 0.5 ~ "N", D == 0.5 ~ "Equal", TRUE ~ NA_character_),
      gop_majority = case_when(R > 0.5 ~ "Y", R < 0.5 ~ "N", R == 0.5 ~ "Equal", TRUE ~ NA_character_)
    )
}))
cat(sprintf("  Calculated partisanship for %d roll calls\n", nrow(calc_rc02_partisan_pivot)))

benchmark_fn("calc_legislator_partisanship", quote({
  calc_votes01 <- p_legislator_votes %>%
    left_join(calc_rc02_partisan_pivot, by = "roll_call_id") %>%
    filter(!is.na(D) & !is.na(R))

  calc_votes02 <- calc_votes01 %>%
    mutate(
      vote_with_dem_majority = ifelse((dem_majority == "Y" & vote_text == "Yea") | dem_majority == "N" & vote_text == "Nay", 1, 0),
      vote_with_gop_majority = ifelse((gop_majority == "Y" & vote_text == "Yea") | gop_majority == "N" & vote_text == "Nay", 1, 0),
      vote_against_both = ifelse(
        (dem_majority == "Y" & gop_majority == "Y" & vote_text == "Nay") |
          (dem_majority == "N" & gop_majority == "N" & vote_text == "Yea"), 1, 0
      ),
      voted_at_all = (vote_with_dem_majority + vote_with_gop_majority + vote_against_both) >= 1,
      vote_cross_party = ifelse(
        (party == "D" & vote_text == "Yea" & dem_majority == "N" & gop_majority == "Y") |
          (party == "D" & vote_text == "Nay" & dem_majority == "Y" & gop_majority == "N") |
          (party == "R" & vote_text == "Yea" & gop_majority == "N" & dem_majority == "Y") |
          (party == "R" & vote_text == "Nay" & gop_majority == "Y" & dem_majority == "N"), 1, 0
      ),
      vote_party_line = ifelse(
        (vote_with_dem_majority == 1 & party == "D") | (vote_with_gop_majority == 1 & party == "R"), 1, 0
      )
    )

  calc_votes03 <- calc_votes02 %>%
    mutate(
      partisan_vote_type = case_when(
        vote_against_both == 1 ~ "Against Both Parties",
        vote_cross_party == 1 ~ "Cross Party",
        party == "D" & vote_with_dem_majority == 1 & vote_with_gop_majority == 0 ~ "Party Line Partisan",
        party == "R" & vote_with_dem_majority == 0 & vote_with_gop_majority == 1 ~ "Party Line Partisan",
        vote_party_line == 1 ~ "Party Line Bipartisan",
        vote_text == "NV" ~ "Absent/NV",
        vote_text == "Absent" ~ "Absent/NV",
        TRUE ~ "Other"
      )
    )
}))
cat(sprintf("  Calculated partisanship for %d legislator votes\n", nrow(calc_votes03)))

#################################
# RESULTS SUMMARY               #
#################################
cat("\n\n")
cat("########################################\n")
cat("#        BENCHMARK RESULTS             #\n")
cat("########################################\n\n")

# Convert results to dataframe
results_df <- do.call(rbind, lapply(names(results), function(name) {
  r <- results[[name]]
  data.frame(
    function_name = name,
    time_seconds = r$time,
    memory_delta_mb = r$mem_delta,
    status = r$status,
    stringsAsFactors = FALSE
  )
}))

# Sort by time
results_df <- results_df[order(-results_df$time_seconds), ]

cat("=== ALL FUNCTIONS BY EXECUTION TIME ===\n\n")
cat(sprintf("%-30s %12s %12s %10s\n", "Function", "Time(sec)", "Memory(MB)", "Status"))
cat(paste(rep("-", 70), collapse = ""), "\n")
for (i in 1:nrow(results_df)) {
  r <- results_df[i, ]
  cat(sprintf("%-30s %12.2f %12.1f %10s\n", r$function_name, r$time_seconds, r$memory_delta_mb, r$status))
}

cat("\n")
cat("************************************************\n")
cat("*         TOP 3 SLOWEST FUNCTIONS              *\n")
cat("************************************************\n")

successful <- results_df[results_df$status == "SUCCESS", ]
top3 <- head(successful, 3)

for (i in 1:nrow(top3)) {
  r <- top3[i, ]
  cat(sprintf("\n  #%d: %s\n", i, r$function_name))
  cat(sprintf("      Time: %.2f seconds (%.1f minutes)\n", r$time_seconds, r$time_seconds / 60))
  cat(sprintf("      Memory delta: %+.1f MB\n", r$memory_delta_mb))
}

cat("\n=== TOP 3 MEMORY CONSUMERS ===\n")
mem_sorted <- successful[order(-successful$memory_delta_mb), ]
for (i in 1:min(3, nrow(mem_sorted))) {
  r <- mem_sorted[i, ]
  cat(sprintf("  #%d: %-30s %+.1f MB\n", i, r$function_name, r$memory_delta_mb))
}

total_time <- sum(results_df$time_seconds, na.rm = TRUE)
cat(sprintf("\n=== TOTAL BENCHMARK TIME: %.2f seconds (%.1f minutes) ===\n", total_time, total_time / 60))

# Save results
write.csv(results_df, here("qa", "benchmark_results.csv"), row.names = FALSE)
cat("\nResults saved to: qa/benchmark_results.csv\n")

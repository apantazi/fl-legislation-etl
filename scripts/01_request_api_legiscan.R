# REQUEST-API-LEGISCAN.R
# This module requests any Florida datasets accessible from LegiScan via API that haven't already been retrieved

library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")

ask_download <- function() {
  response <- tolower(readline(prompt = "Do you want to download new datasets? (Y/N): "))
  while (!(response %in% c("y", "n"))) {
    response <- tolower(readline(prompt = "Invalid input. Please enter Y or N: "))
  }
  return(response == "y")
}

# Extract the API key
config <- config::get()
LEGISCAN_API_KEY <- config::get("api_key_legiscan")
Sys.setenv(LEGISCAN_API_KEY = LEGISCAN_API_KEY)
if (is.null(LEGISCAN_API_KEY) || LEGISCAN_API_KEY == "") {
  stop("API key is missing. Please ensure it is set in your configuration.")
}

#set working directory to the location of current script, in case this is run independently
if (interactive()) {
  script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
} else {
  script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
}
setwd(script_dir)

if (basename(getwd()) == "scripts") {
  project_root <- normalizePath(file.path(getwd(), ".."))
} else {
  project_root <- getwd()
}

dir_path <- file.path(project_root, "data-raw")


# Check if the directory exists
if (!dir.exists(dir_path)) {
  # If it doesn't exist, create the directory
  dir.create(dir_path, recursive = TRUE)
}

# File to store the list of existing datasets
existing_datasets_file <- file.path(dir_path, "existing_datasets.rds")


if (file.exists(existing_datasets_file)) {
  tryCatch({
    existing_datasets <- readRDS(existing_datasets_file)
  }, error = function(e) {
    warning("Error reading existing datasets file. Proceeding with an empty list.")
    existing_datasets <- data.frame(dataset_hash = character())
  })
} else {
  existing_datasets <- data.frame(dataset_hash = character())
}

#get list of datasets
list_datasets_fl <- legiscanrr::get_dataset_list("fl") 

new_hashes <- sapply(list_datasets_fl, function(x) x$dataset_hash)
if (is.list(existing_datasets)) {
  # Assuming each element of the list has a 'dataset_hash' field
  existing_datasets <- data.frame(dataset_hash = sapply(existing_datasets, function(x) x$dataset_hash))
}
if (nrow(existing_datasets) > 0) {
  existing_hashes <- existing_datasets$dataset_hash
} else {
  existing_hashes <- character(0)  # Create an empty character vector
}

datasets_to_download <- list_datasets_fl[!new_hashes %in% existing_hashes]

if (length(datasets_to_download) > 0) {
  cat("Found", length(datasets_to_download), "new or updated datasets.\n")
  if (ask_download()) {
    cat("Downloading new datasets...\n")
    purrr::walk(datasets_to_download, get_dataset, save_to_dir = "../data-raw/legiscan")
    cat("Downloaded", length(datasets_to_download), "new or updated datasets.\n")
    saveRDS(object = list_datasets_fl, existing_datasets_file)
    cat("Updated existing datasets list.\n")
  } else {
    cat("Skipping download of new datasets.\n")
  }
} else {
  cat("No new or updated datasets found.\n")
}

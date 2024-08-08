# REQUEST-API-LEGISCAN.R
# This module requests any Florida datasets accessible from LegiScan via API that haven't already been retrieved

library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")

# Extract the API key
config <- config::get()
LEGISCAN_API_KEY <- config::get("api_key_legiscan")
Sys.setenv(LEGISCAN_API_KEY = LEGISCAN_API_KEY)

#set working directory to the location of current script, in case this is run independently
script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_dir)

# Define the data directory path
dir_path <- normalizePath(file.path(getwd(), "../data-raw"), winslash = "/")

# Check if the directory exists
if (!dir.exists(dir_path)) {
  # If it doesn't exist, create the directory
  dir.create(dir_path, recursive = TRUE)
}

# File to store the list of existing datasets
existing_datasets_file <- file.path(dir_path, "existing_datasets.rds")

if (file.exists(existing_datasets_file)) {
  existing_datasets <- readRDS(existing_datasets_file)
} else {
  existing_datasets <- data.frame(dataset_hash = character())
}

#get list of datasets
list_datasets_fl <- legiscanrr::get_dataset_list("fl") 

new_hashes <- sapply(list_datasets_fl, function(x) x$dataset_hash)
existing_hashes <- sapply(existing_datasets, function(x) x$dataset_hash)

datasets_to_download <- list_datasets_fl[!new_hashes %in% existing_hashes]

if (length(datasets_to_download) > 0) {
  # Download new datasets
  purrr::walk(datasets_to_download, get_dataset, save_to_dir = "../data-raw/legiscan")
  
  cat("Downloaded", length(datasets_to_download), "new or updated datasets.\n")
} else {
  cat("No new or updated datasets found.\n")
}

# Update the existing datasets file
saveRDS(object = list_datasets_fl, existing_datasets_file)
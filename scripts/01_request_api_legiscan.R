# REQUEST-API-LEGISCAN.R
#
# 6/11/24
# This module requests *all* Florida datasets from LegiScan via API
# I last ran this on 6/17/24
#note that list_datesets_fl appears to be a single record, but in fact is a nested list
# ...and purrr:walk retrieves data going back to 2010 (first, regular, organization)

library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")

#requires user to enter their api key
legiscan_api_key(set_new=TRUE)

# Define the data directory path
dir_path <- "../data-raw/"

# Check if the directory exists
if (!dir.exists(dir_path)) {
  # If it doesn't exist, create the directory
  dir.create(dir_path, recursive = TRUE)
}

# File to store the list of existing datasets
existing_datasets_file <- "../data-raw/existing_datasets.rds"

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
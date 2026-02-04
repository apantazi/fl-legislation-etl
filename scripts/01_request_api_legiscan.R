# 01_REQUEST_API_LEGISCAN.R
# This module requests any florida datasets accessible from LegiScan via API that haven't already been retrieved

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

dir_path <- here("data-raw")


# Check if the directory exists
if (!dir.exists(dir_path)) {
  # If it doesn't exist, create the directory
  dir.create(dir_path, recursive = TRUE)
}

# File to store the list of existing datasets
existing_datasets_file <- file.path(dir_path, "existing_datasets.rds")


if (file.exists(existing_datasets_file)) {
  tryCatch(
    {
      existing_datasets <- readRDS(existing_datasets_file)
    },
    error = function(e) {
      warning("Error reading existing datasets file. Proceeding with an empty list.")
      existing_datasets <- data.frame(dataset_hash = character())
    }
  )
} else {
  existing_datasets <- data.frame(dataset_hash = character())
}

# get list of datasets
list_datasets_fl <- legiscanrr::get_dataset_list("fl")

# Extract new hashes from LegiScan list of lists
new_hashes <- sapply(list_datasets_fl, function(x) x$dataset_hash)

# Make sure existing_datasets is a data.frame with $dataset_hash as a character vector
if (file.exists(existing_datasets_file)) {
  tryCatch(
    {
      existing_datasets <- readRDS(existing_datasets_file)
      if (is.list(existing_datasets) && !is.data.frame(existing_datasets)) {
        # Handle legacy list-of-lists format
        existing_hashes <- sapply(existing_datasets, function(x) x$dataset_hash)
        existing_datasets <- data.frame(dataset_hash = as.character(existing_hashes), stringsAsFactors = FALSE)
      }
    },
    error = function(e) {
      warning("Error reading existing datasets file. Proceeding with an empty list.")
      existing_datasets <- data.frame(dataset_hash = character())
    }
  )
} else {
  existing_datasets <- data.frame(dataset_hash = character())
}

existing_hashes <- as.character(existing_datasets$dataset_hash)

# Identify which datasets are new (hash not in existing)
to_download_idx <- which(!new_hashes %in% existing_hashes)
datasets_to_download <- list_datasets_fl[to_download_idx]

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

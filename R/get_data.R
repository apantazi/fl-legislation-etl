#' Get Legislation Data from LegiScan API
#'
#' Requests datasets for a specific state from the LegiScan API.
#'
#' @param state Two-letter state abbreviation (e.g., "FL").
#' @param api_key LegiScan API key. Defaults to `Sys.getenv("LEGISCAN_API_KEY")`.
#' @param output_dir Directory to save the raw JSON datasets. Defaults to "data-raw/legiscan".
#' @param use_cache Logical. If TRUE, compares against existing datasets and only downloads new ones.
#' @import here
#' @import legiscanrr
#' @importFrom purrr walk
#' @importFrom config get
#' @export
get_legislation_data <- function(state = "fl", 
                                 api_key = Sys.getenv("LEGISCAN_API_KEY"), 
                                 output_dir = "data-raw/legiscan",
                                 use_cache = TRUE) {
  
  # Ensure API key is set
  if (is.null(api_key) || api_key == "") {
    # Try config if available
    if (requireNamespace("config", quietly = TRUE)) {
      try({
        api_key <- config::get("api_key_legiscan")
      }, silent = TRUE)
    }
  }
  
  if (is.null(api_key) || api_key == "") {
    stop("API key is missing. Please provide it as an argument or set 'LEGISCAN_API_KEY' environment variable.")
  }
  
  # Set env var for legiscanrr if needed (some functions might rely on it)
  Sys.setenv(LEGISCAN_API_KEY = api_key)
  
  # Ensure output directory exists
  state_dir <- file.path(output_dir, toupper(state))
  if (!dir.exists(state_dir)) {
    dir.create(state_dir, recursive = TRUE)
    message(paste("Created directory:", state_dir))
  }
  
  # Path for tracking existing datasets
  # Note directly using the state_dir to store the index might be cleaner than parent dir
  existing_datasets_file <- file.path(state_dir, "existing_datasets.rds")
  
  existing_datasets <- data.frame(dataset_hash = character())
  
  if (use_cache && file.exists(existing_datasets_file)) {
    tryCatch({
      existing_datasets <- readRDS(existing_datasets_file)
      # Legacy support: if it was a list of lists, convert to df
      if (is.list(existing_datasets) && !is.data.frame(existing_datasets)) {
        existing_hashes <- sapply(existing_datasets, function(x) x$dataset_hash)
        existing_datasets <- data.frame(dataset_hash = as.character(existing_hashes), stringsAsFactors = FALSE)
      }
    }, error = function(e) {
      warning("Error reading existing datasets cache. Proceeding with empty cache.")
    })
  }
  
  message(paste("Fetching dataset list for state:", state))
  list_datasets <- legiscanrr::get_dataset_list(state)
  
  if (length(list_datasets) == 0) {
    warning("No datasets found (check API key or state code).")
    return(NULL)
  }
  
  # Extract new hashes
  new_hashes <- sapply(list_datasets, function(x) x$dataset_hash)
  existing_hashes <- as.character(existing_datasets$dataset_hash)
  
  # Identify new
  to_download_idx <- which(!new_hashes %in% existing_hashes)
  datasets_to_download <- list_datasets[to_download_idx]
  
  if (length(datasets_to_download) > 0) {
    message(paste("Found", length(datasets_to_download), "new or updated datasets."))
    
    # In package mode, we usually don't want interactive prompts unless explicitly asked.
    # We will assume if the user called this function, they want the data.
    # Future improvement: add 'interactive' arg.
    
    message("Downloading new datasets...")
    # helper for save_to_dir to avoid full path issues if legiscanrr constructs it
    # legiscanrr::get_dataset usually takes save_to_dir and creates {state} subdir?
    # Checking docs/usage: script used `save_to_dir = "../data-raw/legiscan"` and it ended up in FL/
    # So we pass the parent of state_dir.
    
    purrr::walk(datasets_to_download, legiscanrr::get_dataset, save_to_dir = output_dir)
    
    message(paste("Downloaded", length(datasets_to_download), "datasets."))
    
    # Update cache
    # We save the full list as the new state
    saveRDS(object = list_datasets, existing_datasets_file)
    message("Updated existing datasets cache.")
    
  } else {
    message("No new or updated datasets found.")
  }
  
  return(invisible(list_datasets))
}

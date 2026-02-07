# New ETL Pipeline Entry Point
# Usage: Run this script to execute the ETL process using the refactored package.

# Load the package (assumes you are in the project root)
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
devtools::load_all(".")

# Settings
STATE <- "FL"
API_KEY <- Sys.getenv("LEGISCAN_API_KEY") # Ensure this is set
DATA_DIR_RAW <- "data-raw/legiscan"

# 1. Get Data
# set use_cache=TRUE to avoid re-downloading existing files
message("Step 1: Requesting Data...")
# Note: This requires API key. If not set, it will error nicely.
tryCatch({
  get_legislation_data(state = STATE, output_dir = DATA_DIR_RAW, use_cache = TRUE)
}, error = function(e) {
  warning("Skipping download (API key missing or network issue): ", e$message)
})

# 2. Parse Data
message("Step 2: Parsing Data...")
# Points to data-raw/legiscan/FL
state_data_dir <- file.path(DATA_DIR_RAW, STATE)

# Parse all available years (or specify start_year/end_year)
parsed_data <- parse_legiscan_json(data_dir = state_data_dir)

if (length(parsed_data) == 0 || nrow(parsed_data$bills) == 0) {
  stop("No parsed data found. Check data directory.")
}

message(paste("Parsed", nrow(parsed_data$bills), "bills."))

# 3. Process Data
message("Step 3: Processing Data...")
# Optional: Load external inputs if available
# legislator_events <- read.csv("...")
# district_demographics <- parse_daves_demographics(...) 

processed_data <- process_legislation_data(parsed_data)

message("Processing Complete.")
str(processed_data, max.level = 1)

# 4. Save to Database (Optional - Logic to be refactored)
# write_to_postgres(processed_data)

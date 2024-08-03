# INSTALL-PACKAGES.R
# 6/11/24
# only need to run this once for initial R setup on my local computer
# may need to recreate as a requirements file once pushing this database onto Azure

# Function to check if packages are installed and install them if not
install_if_needed <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages)) install.packages(new_packages)
}

# List of CRAN packages to install
cran_packages <- c(
  "tidyverse",
  "tidytext",
  "pscl",
  "wnominate",
  "oc",
  "jsonlite",
  "SnowballC",
  "future.apply",
  "RPostgres",
  "progress",
  "dplyr",
  "lubridate",
  "conflicted"
)

# Install CRAN packages if needed
install_if_needed(cran_packages)

# Install legiscanrr, which needs devtools
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
if (!requireNamespace("legiscanrr", quietly = TRUE)) devtools::install_github("fanghuiz/legiscanrr")

# Install dwnominate, which needs remotes
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("basicspace", quietly = TRUE)) {
  install.packages("https://cran.r-project.org/src/contrib/Archive/basicspace/basicspace_0.24.tar.gz", repos = NULL, type = "source")
}
if (!requireNamespace("dwnominate", quietly = TRUE)) remotes::install_github('wmay/dwnominate')

# Set conflicts preference to prioritize all dplyr functions
conflicted::conflict_prefer_all("dplyr", quiet=TRUE)

# to install an individual package:
# install.packages("dplyr")

#packages for scraping IDs of Florida reps
# install.packages("rvest")
# install.packages("httr")

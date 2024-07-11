#################################
#                               #  
# ETL_MAIN.R                    #
#                               #
#################################
# JUNE and JULY 2024
# This script transforms data that's already been requested or downloaded from LegiScan
# and stored in the folder fl-regular-json (eventually will be in Postgres db)
# remove comment on source("01_request_api_legiscan.R") below to renew API requests, but be wary of API limits

#################################
#                               #  
# load libraries & functions    #
#                               #
#################################
# these libraries need to be installed prior to loading (see install-packages.R)

library(tidyr) #for replace_na function used maybe once in 03_transform 
library(tidyverse)  # A collection of R packages for data science
library(tidytext)   # Text mining using tidy data principles
library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")
library(pscl)       # Political Science Computational Laboratory package for analyzing roll call data and IRT models
library(wnominate)  # W-NOMINATE package for scaling roll call data and estimating ideal points
library(oc)         # Optimal Classification package for scaling roll call data
library(dwnominate) # Dynamic Weighted NOMINATE for analyzing changes in voting patterns over time / remotes::install_github('wmay/dwnominate')
library(jsonlite)   # Tools for parsing, generating, and manipulating JSON data
library(SnowballC)  # Snowball stemmers for text preprocessing and stemming in natural language processing
library(future.apply)

#additional libraries for database interaction
library(DBI)
library(RPostgres)
library(progress) # to show progress bar during database write operations
library(dplyr) # allows excluding specific columns by name from sql commands (e.g. to debug heatmap_data)

library(googlesheets4) # for reading a publicly shared Google sheet

#set working directory to the location of current script
setwd(script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path))

source("functions_database.R") # functions to write to Postgres database
#source("01_request_api_legiscan.R") #request LegiScan data from API 

#ETL for raw layer
source("02a_parse_legiscan.R")
source("02b_read_csvs.R")
source("02z_load_raw.R")

#ETL for processed layer
source("03_transform.R")
source("03y_qa_checks.R")
source("03z_load_processed.R")

#ETL for app layer
source("04_prep_app.R") # merge, prep, analyze data
source("04z_load_app.R") # export dataframes to Postgres

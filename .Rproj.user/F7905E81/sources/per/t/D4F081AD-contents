# ETL.R
# 6/11/24
# This script transforms data that's already been requested or downloaded from LegiScan
# and stored in the folder fl-regular-json (eventually will be in Postgres db) 
# I modularized this based on Andrew Pantazi's code
# See pull-in-process-all-legiscan.R at https://github.com/apantazi/legislator_dashboard for the original script

#################################
#                               #  
# debugging notes 6/12/24       #
#                               #
#################################
#02_parse-legiscan.R
# hack to ensure two-year session (e.g. 2023-2024, vs. 2023-2023). not sure why i had to do this
# bill_vote_all$session <- bill_vote_all$session_string

#################################
#                               #  
# load libraries & functions    #
#                               #
#################################
# these libraries need to be installed prior to loading (see install-packages.R)

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

#set working directory to the location of current script
setwd(script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path))

source("functions_database.R") # functions to write to Postgres database
# 6/12/24 RR using only bulk downloaded data for now
#source("01_request_api_legiscan.R") #request LegiScan data from API 
source("02_parse_legiscan.R") # parse from json files
source("03_load_views.R") # save parsed data to database
source("04_transform.R") # merge, prep, analyze data
source("05_load_app_layer.R") # export dataframes to Postgres

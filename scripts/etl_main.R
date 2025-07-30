#################################
#                               #  
# ETL_MAIN.R                    #
#                               #
#################################
# This script transforms data that's already been requested or downloaded from LegiScan

#################################
#                               #  
# starting up the database(s)   #
#                               #
#################################
# These scripts write data to either the staging or production database in Postgres.
# Prior to running these scripts, make sure you've started up the staging and production databases
# and selected the appropriate source in the command line.
# For detailed steps, see the PROCEDURES document
# https://docs.google.com/document/d/1MyGv2wjyfbNeb2WDrN0YXwZ2sJWINx0Oii3WKnUMDkA/edit#bookmark=id.5j94239a3ie

#################################
#                               #  
# load libraries & functions    #
#                               #
#################################
#set working directory to the location of current script
if (!requireNamespace("rstudioapi", quietly = TRUE)) {
  install.packages("rstudioapi")
}
script_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(script_dir)
source("00_install_packages.R") #only install packages not already installed 

library(tidyverse)  # A collection of R packages for data science
library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")
library(jsonlite)   # Tools for parsing, generating, and manipulating JSON data
library(future.apply)
#additional libraries for database interaction
library(DBI)
library(RPostgres)
library(progress) # to show progress bar during database write operations
library(dplyr) # allows excluding specific columns by name from sql commands (e.g. to debug heatmap_data)
library(googlesheets4) # for reading a publicly shared Google sheet

source("functions_database.R") # functions to write to Postgres database
source("01_request_api_legiscan.R") #request LegiScan data from API 

#ETL for raw layer
source("02a_raw_parse_legiscan.R")
source("02b_raw_read_csvs.R")
source("02z_raw_load.R")

#ETL for processed layer
source("03a_process.R")
source("03z_process_load.R")

#ETL for app layer
source("04a_app_settings.R") # integrate app settings into creating base query layer
source("04b_app_prep.R") # merge, prep, analyze data
source("04c_app_bill_lookup.R") # build bill lookup dataset

# check data quality and write to log file
qa_log <- "../qa/qa_checks.log"
fileConn <- file(qa_log, "w")
close(fileConn)
sink(qa_log, split = TRUE)
source("qa_checks.R")
sink()

source("04z_app_load.R") # export dataframes, including QA data frames, to Postgres

# LOAD_USER_ENTERED.R
# 7/5/24 RR
# this script uploads user-entered data, such as bill categorization and info on contested primary races
# Consider updating this to load user-entered tables from Google Sheets

########################################
#                                      #  
# 1) read user-entered                 #
#                                      #
########################################
# should update this to connect directly to Google Drive
user_incumbents_challenged <- read.csv("../data-raw/user-entry/user_incumbents_challenged.csv")
user_bill_categories <- read.csv("../data-raw/user-entry/user_bill_categories.csv")



########################################
#                                      #  
# 1) read downloaded csvs              #
#                                      #
########################################
t_districts_house <- read.csv("../data-raw/daves/t_districts_house.csv")
t_districts_senate <- read.csv("../data-raw/daves/t_districts_senate.csv")

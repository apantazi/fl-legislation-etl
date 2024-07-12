# READ_CSVS.R
# 7/6/24 RR
# this script retrieves user-entered data and reads downloaded csvs

########################################
#                                      #  
# 1) read Google Sheets user-entered   #
#                                      #
########################################
gs4_deauth() # de-authorize to connect to publicly shared sheets

user_incumbents_challenged <- read_sheet("https://docs.google.com/spreadsheets/d/1woSZBU5bOfTGFKtuaYg2xT8jCo314RVlSpMrSARWl1c/edit?usp=drive_link")
user_bill_categories <- read_sheet("https://docs.google.com/spreadsheets/d/1ivNJS9F6TyBjTr_D3OmUKxN0YCEM9ugLbJRteID6Q24/edit?usp=drive_link")

#back-up connection method in case I need it
#user_incumbents_challenged <- read.csv("../data-raw/user-entry/user_incumbents_challenged.csv")
#user_bill_categories <- read.csv("../data-raw/user-entry/user_bill_categories.csv")



########################################
#                                      #  
# 2) read downloaded csvs              #
#                                      #
########################################

t_daves_districts_house <- read.csv("../data-raw/daves/t_daves_districts_house.csv")
t_daves_districts_senate <- read.csv("../data-raw/daves/t_daves_districts_senate.csv")

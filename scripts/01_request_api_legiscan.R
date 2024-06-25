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

#get list of datasets
list_datasets_fl <- legiscanrr::get_dataset_list("fl") 

## download every session, ??but warning about API limits. #### 
# put all datasets in data-raw
purrr::walk(list_datasets_fl, get_dataset, save_to_dir = "../data-raw/legiscan") 

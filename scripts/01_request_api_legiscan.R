# REQUEST-API-LEGISCAN.R
#
# 6/11/24
# This module would request *all* Florida datasets from LegiScan via API
# It hasn't been run yet. For now we're piloting with 2023-2024 data only.

library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")

#requires user to enter their api key
legiscan_api_key(set_new=TRUE)

#get list of datasets
list_datasets_fl <- legiscanrr::get_dataset_list("fl") 

## download every session, ??but warning about API limits. #### 
# put all datasets in data-raw
purrr::walk(dataset, get_dataset, save_to_dir = "data-raw/legiscan") 

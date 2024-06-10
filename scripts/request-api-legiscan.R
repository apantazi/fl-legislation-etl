library(legiscanrr) # Interface with the LegiScan API for accessing legislative data / devtools::install_github("fanghuiz/legiscanrr")

#requires user to enter their api key
legiscan_api_key(set_new=TRUE)

# RR commenting this out for now, don't want to retrieve data here for performance and concern over API limits
## download every session, ??but warning about API limits. #### 
# dataset <- legiscanrr::get_dataset_list("fl") #get all datasets
# purrr::walk(dataset, get_dataset, save_to_dir = "data_json") #get all datasets and put it in subdir of 'data_json'
# text_paths <- find_json_path(base_dir = "data_json/fl/..", file_type = "vote")
# text_paths_bills <- find_json_path(base_dir = "data_json/fl/..", file_type = "bill")
# text_paths_leg <- find_json_path(base_dir = "data_json/FL/..",file_type = "people")
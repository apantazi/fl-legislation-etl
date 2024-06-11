# libraries & options ####
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

options(scipen = 999) # Set options to display numeric values in precise format

legiscan_api_key(set_new=TRUE)
#next you'll need to put in the api key
# custom functions ####
parse_people_session <- function (people_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing people [:bar] :percent in :elapsed.", 
                                   total = length(people_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  
  extract_people_meta <- function(input_people_json_path) {
    pb$tick()
    # Define a regex to match the session pattern in the file path
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    # Extract session from the file path using the defined regex
    matches <- regmatches(input_people_json_path, regexpr(session_regex, input_people_json_path))
    session_info <- ifelse(length(matches) > 0, matches, NA)
    
    input_people_json <- jsonlite::fromJSON(input_people_json_path)
    people_meta <- input_people_json[["person"]]
    # Append session info as a new column
    people_meta$session <- session_info
    people_meta
  }
  
  output_list <- lapply(people_json_paths, extract_people_meta)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
} #Extracts session information and people metadata from given JSON file paths. It adds session details to each person's metadata.
parse_person_vote_session <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing person-vote [:bar] :percent in :elapsed.", 
                                   total = length(vote_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  extract_vote <- function(input_vote_json_path) {
    pb$tick()
    # Extract session from the file path
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
    input_vote <- jsonlite::fromJSON(input_vote_json_path)
    input_vote <- input_vote[["roll_call"]]
    person_vote <- input_vote[["votes"]]
    person_vote$roll_call_id <- input_vote[["roll_call_id"]]
    # Append session info as a new column
    person_vote$session <- session_info
    person_vote
  }
  output_list <- lapply(vote_json_paths, extract_vote)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
} #Extracts vote information and session details from given JSON file paths. It includes session information for each vote record.
parse_rollcall_vote_session <- function (vote_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing roll call [:bar] :percent in :elapsed.", 
                                   total = length(vote_json_paths), clear = FALSE, width = 60)
  pb$tick(0)
  extract_rollcall <- function(input_vote_json_path) {
    pb$tick()
    # Extract session
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_info <- regmatches(input_vote_json_path, regexpr(session_regex, input_vote_json_path))
    input_vote <- jsonlite::fromJSON(input_vote_json_path)
    input_vote <- input_vote[["roll_call"]]
    vote_info <- purrr::keep(input_vote, names(input_vote) %in% c("roll_call_id", "bill_id", "date", 
                                                                  "desc", "yea", "nay", "nv", "absent", "total", "passed", 
                                                                  "chamber", "chamber_id"))
    # Append session info
    vote_info$session <- session_info
    vote_info
  }
  output_list <- lapply(vote_json_paths, extract_rollcall)
  output_df <- data.table::rbindlist(output_list, fill = TRUE)
  output_df <- tibble::as_tibble(data.table::setDF(output_df))
  output_df
} #Extracts roll call information and session details from given JSON file paths, including session info for each roll call.
parse_bill_session <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing bills [:bar] :percent in :elapsed.",
                                   total = length(bill_json_paths), clear = FALSE, width = 60)
  
  extract_bill_meta <- function(input_bill_path) {
    pb$tick()
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_matches <- regexpr(session_regex, input_bill_path)
    session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
    
    bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
    bill <- bill_data$bill
    
    # Handling missing fields with NA
    number <- ifelse(is.null(bill$bill_number), NA, bill$bill_number)
    bill_id <- ifelse(is.null(bill$bill_id), NA, bill$bill_id)
    session_id <- ifelse(is.null(bill$session_id), NA, bill$session_id)
    session_name <- ifelse(is.null(bill$session$session_name), NA, bill$session$session_name)
    url <- ifelse(is.null(bill$url), NA, bill$url)
    title <- ifelse(is.null(bill$title), NA, bill$title)
    description <- ifelse(is.null(bill$description), NA, bill$description)
    status <- ifelse(is.null(bill$status), NA, bill$status)
    status_date <- ifelse(is.null(bill$status_date), NA, bill$status_date)
    
    progress_list <- lapply(bill$progress, function(x) c(x$date, x$event))
    history_list <- lapply(bill$history, function(x) c(x$date, x$action, x$chamber, x$importance))
    sponsors_list <- lapply(bill$sponsors, function(x) c(x$people_id, x$party, x$role, x$name, x$sponsor_order, x$sponsor_type_id))
    sasts_list <- lapply(bill$sasts, function(x) c(x$type, x$sast_bill_number, x$sast_bill_id))
    texts_list <- lapply(bill$texts, function(x) c(x$date, x$type, x$type_id, x$mime, x$mime_id, x$url, x$state_link, x$text_size))
    
    df <- data.frame(
      number = number,
      bill_id = bill_id,
      session_id = session_id,
      session_string = session_string,
      session_name = session_name,
      url = url,
      title = title,
      description = description,
      status = status,
      status_date = status_date,
      progress = I(list(progress_list)),
      history = I(list(history_list)),
      sponsors = I(list(sponsors_list)),
      sasts = I(list(sasts_list)),
      texts = I(list(texts_list)),
      stringsAsFactors = FALSE
    )
    
    return(df)
  }
  
  output_list <- lapply(bill_json_paths, extract_bill_meta)
  output_df <- do.call(rbind, output_list)
  
  return(output_df)
} #Extracts bill metadata including session information, progress, history, sponsors, and other related attributes from given JSON file paths.
parse_bill_combined <- function(bill_json_paths) {
  pb <- progress::progress_bar$new(format = "  parsing bills [:bar] :percent in :elapsed.", 
                                   total = length(bill_json_paths), clear = FALSE, width = 60)
  
  extract_combined_meta <- function(input_bill_path) {
    pb$tick()
    session_regex <- "(\\d{4}-\\d{4}_[^/]+_Session)"
    session_matches <- regexpr(session_regex, input_bill_path)
    session_string <- ifelse(session_matches != -1, regmatches(input_bill_path, session_matches), NA)
    
    if(file.exists(input_bill_path)) {
      bill_data <- jsonlite::fromJSON(input_bill_path, simplifyVector = FALSE)
    } else {
      warning(paste("File not found:", input_bill_path))
      return(NULL)
    }
    
    bill <- bill_data$bill
    session_name <- bill$session$session_name %||% NA
    
    # Simplify and compile desired attributes into vectors or lists
    sponsors_list <- lapply(bill$sponsors %||% list(), function(x) c(x$people_id, x$party, x$role, x$name, x$sponsor_order, x$sponsor_type_id))
    progress_list <- lapply(bill$progress %||% list(), function(x) c(x$date, x$event))
    
    # Construct the data frame
    df <- data.frame(
      bill_id = bill$bill_id,
      change_hash = bill$change_hash,
      url = bill$url,
      state_link = bill$state_link,
      status = bill$status,
      status_date = bill$status_date,
      state = bill$state,
      state_id = bill$state_id,
      bill_number = bill$bill_number,
      bill_type = bill$bill_type,
      bill_type_id = bill$bill_type_id,
      body = bill$body,
      body_id = bill$body_id,
      current_body = bill$current_body,
      current_body_id = bill$current_body_id,
      title = bill$title,
      description = bill$description,
      pending_committee_id = bill$pending_committee_id,
      session_name = session_name,
      session_string = session_string,
      sponsors = I(sponsors_list),
      progress = I(progress_list),
      stringsAsFactors = FALSE
    )
    
    return(df)
  }
  
  output_list <- lapply(bill_json_paths, extract_combined_meta)
  output_df <- do.call(rbind, output_list)
  
  return(output_df)
} #A combined approach to parsing bill metadata, including sponsors and progress, from given JSON file paths. This function compiles data into simplified vectors or lists.
parse_bill_jsons <- function(json_paths){
  parse_single_json  <- function(json_path) {
    bill_data <- fromJSON(json_path, simplifyVector = FALSE)
    bill <- bill_data$bill
    
    # Extract flat information directly into a data frame
    bill_info_df <- tibble(
      number = bill$bill_number,
      title = bill$title,
      type = bill$bill_type,
      bill_id = bill$bill_id,
      description = bill$description,
      session_id = bill$session$session_id,
      session_name = bill$session$session_name,
      year = bill$session$year_end
      # Add more fields as needed
    )
    
    # Extract sponsors (assuming sponsors are a list of lists)
    sponsors <- bind_rows(lapply(bill$sponsors, as_tibble), .id = bill$sponsor_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    amendments <- bind_rows(lapply(bill$amendments, as_tibble), .id = bill$amendment_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    referrals <- bind_rows(lapply(bill$referrals, as_tibble), .id = bill$committee_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    history <- bind_rows(lapply(bill$history, as_tibble)) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    votes <- bind_rows(lapply(bill$votes, as_tibble), .id = bill$roll_call_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    supplements <- bind_rows(lapply(bill$supplements, as_tibble), .id = bill$supplement_id) %>%
      mutate(bill_id = bill$bill_id) %>%
      select(bill_id, everything())
    
    # Compile into a single list for this example
    list(bill_info_df = bill_info_df,
         sponsors = sponsors, 
         amendments = amendments,
         supplements=supplements,
         votes=votes,
         history=history,
         referrals=referrals)
  }
  pb <- progress::progress_bar$new(
    format = "  Parsing bills [:bar] :percent in :elapsed",
    total = length(json_paths),
    width = 60
  )
  parsed_results <- lapply(json_paths, function(path) {
    pb$tick()
    parse_single_json(path)
  })
  
  combined_results <- list(
    bill_info_df = bind_rows(lapply(parsed_results, `[[`, "bill_info_df")),
    sponsors = bind_rows(lapply(parsed_results, `[[`, "sponsors")),
    amendments = bind_rows(lapply(parsed_results, `[[`, "amendments")),
    supplements = bind_rows(lapply(parsed_results, `[[`, "supplements")),
    votes = bind_rows(lapply(parsed_results, `[[`, "votes")),
    history = bind_rows(lapply(parsed_results, `[[`, "history")),
    referrals = bind_rows(lapply(parsed_results, `[[`, "referrals"))
  )
  
  return(combined_results)
} #Parses multiple JSON paths for bill data, extracting detailed bill information, sponsors, amendments, referrals, history, votes, and supplements. It combines results into a single list.

##every session option, but warning about API limits. #### 
dataset <- legiscanrr::get_dataset_list("fl") #get all datasets
purrr::walk(dataset, get_dataset, save_to_dir = "data_json") #get all datasets and put it in subdir of 'data_json'
text_paths <- find_json_path(base_dir = "data_json/fl/..", file_type = "vote")
text_paths_bills <- find_json_path(base_dir = "data_json/fl/..", file_type = "bill")
text_paths_leg <- find_json_path(base_dir = "data_json/FL/..",file_type = "people")
legislators <- parse_people_session(text_paths_leg) #we use session so we don't have the wrong roles
bills_all_sponsor <- parse_bill_sponsor(text_paths_bills)
primary_sponsors <- bills_all_sponsor %>% filter(sponsor_type_id == 1 & committee_sponsor == 0)
bills_all <- parse_bill_session(text_paths_bills) %>%
  mutate(
    session_year = as.numeric(str_extract(session_name, "\\d{4}")), # Extract year
    two_year_period = case_when(
      session_year < 2011 ~ "2010 or earlier",
      session_year %% 2 == 0 ~ paste(session_year - 1, session_year, sep="-"),
      TRUE ~ paste(session_year, session_year + 1, sep="-")
    )
  )
bill_detailed <- parse_bill_jsons(text_paths_bills)

# make big dfs ####
votes_all <- left_join(bill_detailed$votes,bill_detailed$bill_info_df) %>% mutate(pct = yea/total)

bill_vote_all <- inner_join(bills_all,votes_all,by=c("bill_id","number","title","session_id","session_name"
),suffix=c("","_vote")) %>% mutate(total_vote = (yea+nay),true_pct = yea/total_vote) %>% arrange(true_pct) #bill_id is unique and not duplicated across sessions

primary_sponsors_votes <- primary_sponsors %>% left_join(votes_all,by="bill_id") %>% mutate(total_vote = (yea+nay),true_pct = yea/total_vote) %>% arrange(true_pct)

bill_vote_all$session <- paste0(bill_vote_all$session_year,"-",gsub(" ","_", bill_vote_all$session_name))

leg_votes_with2 <- parse_person_vote_session(text_paths) %>% 
  mutate(roll_call_id = as.character(roll_call_id)) %>%  # Convert roll_call_id to character
  inner_join(legislators,by=c("people_id","session")) %>%
  inner_join(bill_vote_all %>% mutate(roll_call_id = as.character(roll_call_id)), by = c("roll_call_id", "session"))

## analysis & prep ####

analyse_bill <- leg_votes_with2 %>% group_by(party,roll_call_id,title,vote_text,number) %>% summarize(n=n()) %>% arrange(desc(n)) %>% pivot_wider(values_from = n,names_from = vote_text,values_fill = 0) %>% mutate(total=sum(Yea,NV,Absent,Nay,na.rm = TRUE),total2=sum(Yea,Nay)) %>% filter(total>0 & total2 >0) %>% mutate(y_pct = Yea/total,n_pct=Nay/total,nv_pct=NV/total, absent_pct=Absent/total,NV_A=(NV+Absent)/total,y_pct2 = Yea/(Yea+Nay),n_pct2 = Nay/(Yea+Nay),margin=y_pct2-n_pct2)

partisanbillvotes <- analyse_bill %>%   select(party,roll_call_id,title,y_pct2,number) %>% 
  pivot_wider(names_from = party,values_from=y_pct2,values_fill = NA,id_cols = c(roll_call_id,title,number)) %>% 
  mutate(`D-R`=D-R)
partisanbillvotes$Partisan[partisanbillvotes$`D-R`<0] <- "Somewhat GOP"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`< -.25] <- "GOP"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`< - .75] <- "Very GOP"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`==0] <- "Split"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`> 0] <- "Somewhat DEM"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`> .25] <- "DEM"
partisanbillvotes$Partisan[partisanbillvotes$`D-R`> .75] <- "Very DEM"
partisanbillvotes$Partisan[is.na(partisanbillvotes$`D-R`)] <- "Unclear"
partisanbillvotes$GOP[partisanbillvotes$R > .5] <- "GOP Support"
partisanbillvotes$GOP[partisanbillvotes$R > .75] <- "GOP Moderately Support"
partisanbillvotes$GOP[partisanbillvotes$R > .9] <- "GOP Very Strongly Support"
partisanbillvotes$GOP[partisanbillvotes$R == 1] <- "GOP Unanimously Support"
partisanbillvotes$GOP[partisanbillvotes$R == .5] <- "GOP Split"
partisanbillvotes$GOP[partisanbillvotes$R < .5] <- "GOP Oppose"
partisanbillvotes$GOP[partisanbillvotes$R < .25] <- "GOP Moderately Oppose"
partisanbillvotes$GOP[partisanbillvotes$R < .1] <- "GOP Very Strongly Oppose"
partisanbillvotes$GOP[partisanbillvotes$R == 0] <- "GOP Unanimously Oppose"
partisanbillvotes$DEM[partisanbillvotes$D > .5] <- "DEM Support"
partisanbillvotes$DEM[partisanbillvotes$D > .75] <- "DEM Strongly Support"
partisanbillvotes$DEM[partisanbillvotes$D > .9] <- "DEM Very Strongly Support"
partisanbillvotes$DEM[partisanbillvotes$D == 1] <- "DEM Unanimously Support"
partisanbillvotes$DEM[partisanbillvotes$D == .5] <- "DEM Split"
partisanbillvotes$DEM[partisanbillvotes$D < .5] <- "DEM Oppose"
partisanbillvotes$DEM[partisanbillvotes$D < .25] <- "DEM Moderately Oppose"
partisanbillvotes$DEM[partisanbillvotes$D < .1] <- "DEM Very Strongly Oppose"
partisanbillvotes$DEM[partisanbillvotes$D == 0] <- "DEM Unanimously Oppose"
partisanbillvotes$DEM[is.na(partisanbillvotes$D)] <- "DEM No Votes"

leg_votes_with2 <- leg_votes_with2 %>% filter(!is.na(date)&total>0)
leg_votes_with2 <- left_join(leg_votes_with2,partisanbillvotes) %>% filter(!is.na(D)&!is.na(R)&!is.na(`D-R`))
leg_votes_with2 <- leg_votes_with2 %>% arrange(desc(abs(`D-R`)))

leg_votes_with2$dem_majority[leg_votes_with2$D > 0.5] <- "Y"
leg_votes_with2$dem_majority[leg_votes_with2$D < 0.5] <- "N"
leg_votes_with2$dem_majority[leg_votes_with2$D == 0.5] <- "Equal"
leg_votes_with2$gop_majority[leg_votes_with2$R > 0.5] <- "Y"
leg_votes_with2$gop_majority[leg_votes_with2$R < 0.5] <- "N"
leg_votes_with2$gop_majority[leg_votes_with2$R == 0.5] <- "Equal"

#to later create a priority bill filter
leg_votes_with2$priority_bills <- "N"
leg_votes_with2$priority_bills[abs(leg_votes_with2$`D-R`)>.85] <- "Y"

leg_votes_with2 <- leg_votes_with2 %>%
  mutate(vote_with_dem_majority = ifelse(dem_majority == "Y" & vote_text=="Yea", 1, 0),
         vote_with_gop_majority = ifelse(gop_majority == "Y" & vote_text=="Yea", 1, 0),
         vote_with_neither = ifelse((dem_majority == "Y" & gop_majority == "Y" & vote_text=="Nay") |
                                      (dem_majority=="N" & gop_majority == "N" & vote_text=="Yea"),1,0),
         vote_with_dem_majority = ifelse((dem_majority == "Y" & vote_text == "Yea")|dem_majority=="N" & vote_text=="Nay", 1, 0),
         vote_with_gop_majority = ifelse((gop_majority == "Y" & vote_text == "Yea")|gop_majority=="N" & vote_text=="Nay", 1, 0),
         vote_with_neither = ifelse(
           (dem_majority == "Y" & gop_majority == "Y" & vote_text == "Nay") | (dem_majority == "N" & gop_majority == "N" & vote_text == "Yea"), 1, 0),
         voted_at_all = vote_with_dem_majority+vote_with_gop_majority+vote_with_neither,
         maverick_votes=ifelse((party=="D" & vote_text=="Yea" & dem_majority=="N" & gop_majority=="Y") |
                                 (party=="D" & vote_text=="Nay" & dem_majority=="Y" & gop_majority=="N") |
                                 (party=="R" & vote_text=="Yea" & gop_majority=="N" & dem_majority=="Y") |
                                 (party=="R" & vote_text=="Nay" & gop_majority=="Y" & dem_majority=="N"),1,0 ))


# Summarize the data to get the count of votes with majority for each legislator
legislator_majority_votes <- leg_votes_with2 %>%
  group_by(party,role,session_id) %>%
  summarize(votes_with_dem_majority = sum(vote_with_dem_majority, na.rm = TRUE),
            votes_with_gop_majority = sum(vote_with_gop_majority, na.rm = TRUE),
            independent_votes = sum(vote_with_neither,na.rm=TRUE),
            total_votes = n(),
            .groups = 'drop') %>% 
  mutate(d_pct = votes_with_dem_majority/total_votes,
         r_pct=votes_with_gop_majority/total_votes,
         margin=d_pct-r_pct,
         ind_pct=independent_votes/total_votes)

leg_votes_with2$bill_alignment[leg_votes_with2$D == 0.5 | leg_votes_with2$R == 0.5] <- "at least one party even"
leg_votes_with2$bill_alignment[leg_votes_with2$D > 0.5 & leg_votes_with2$R < 0.5] <- "DEM"
leg_votes_with2$bill_alignment[leg_votes_with2$D < 0.5 & leg_votes_with2$R > 0.5] <- "GOP"
leg_votes_with2$bill_alignment[leg_votes_with2$D < 0.5 & leg_votes_with2$R < 0.5] <- "Both"
leg_votes_with2$bill_alignment[leg_votes_with2$D > 0.5 & leg_votes_with2$R > 0.5] <- "Both"

party_majority_votes <- leg_votes_with2 %>% filter(party!=""& !is.na(party)) %>% 
  group_by(roll_call_id, party) %>%
  summarize(majority_vote = if_else(sum(vote_text == "Yea") > sum(vote_text == "Nay"), "Yea", "Nay"), .groups = 'drop') %>% 
  pivot_wider(names_from = party,values_from = majority_vote,id_cols = roll_call_id,values_fill = "NA",names_prefix = "vote_")

heatmap_data <- leg_votes_with2 %>%
  left_join(party_majority_votes, by = c("roll_call_id")) %>%
  filter(!is.na(party)&party!="" & !grepl("2010",session_name,ignore.case=TRUE)& !is.na(session_name)) %>% 
  filter(vote_text=="Yea"|vote_text=="Nay") %>% 
  mutate(diff_party_vote_d = if_else(vote_text != vote_D, 1, 0),diff_party_vote_r = if_else(vote_text != vote_R, 1, 0),
         diff_both_parties = if_else(diff_party_vote_d == 1 & diff_party_vote_r == 1,1,0),
         diff_d_not_r=if_else(diff_party_vote_d==1 & diff_party_vote_r==0,1,0),
         diff_r_not_d=if_else(diff_party_vote_d==0&diff_party_vote_r==1,1,0),
         partisan_metric = ifelse(party=="R",diff_r_not_d,ifelse(party=="D",diff_d_not_r,NA)),
         pct_format = scales::percent(pct)) %>% arrange(desc(partisan_metric)) %>% distinct()

heatmap_data$roll_call_id = with(heatmap_data, reorder(roll_call_id, partisan_metric, sum))
heatmap_data$name = with(heatmap_data, reorder(name, partisan_metric, sum))

legislator_metric <- heatmap_data %>% group_by(name) %>% filter(date >= as.Date("11/10/2012")) %>% summarize(partisan_metric=mean(partisan_metric)) %>% arrange(partisan_metric,name) #create the sort based on partisan metric


### create the text to be displayed in the javascript interactive when hovering over votes ####
createHoverText <- function(numbers, descriptions, urls, pcts, vote_texts,descs,title,date, names, width = 100) {
  # Wrap the description text at the specified width
  wrapped_descriptions <- sapply(descriptions, function(desc) paste(strwrap(desc, width = width), collapse = "<br>"))
  
  # Combine the elements into a single string
  paste(
    names, " voted ", vote_texts, " on ", descs, " for bill ",numbers," - ",title," on ",date,"<br>",
    "Description: ", wrapped_descriptions, "<br>",
    "URL: ", urls, "<br>",
    pcts, " voted for this bill",
    sep = ""
  )
}

heatmap_data$hover_text <- mapply(
  createHoverText,
  numbers = heatmap_data$number,
  descs = heatmap_data$desc,
  title=heatmap_data$title,date=heatmap_data$date,
  descriptions = heatmap_data$description,
  urls = heatmap_data$url,
  pcts = heatmap_data$pct_format,
  vote_texts = heatmap_data$vote_text,
  names = heatmap_data$name,
  SIMPLIFY = FALSE  # Keep it as a list
)
heatmap_data$hover_text <- sapply(heatmap_data$hover_text, paste, collapse = " ")  # Collapse the list into a single string

heatmap_data$partisan_metric2 <- ifelse(heatmap_data$vote_with_neither == 1, 1,
                                        ifelse(heatmap_data$maverick_votes == 1, 2, 0))

heatmap_data$partisan_metric3 <- factor(heatmap_data$partisan_metric2,
                                        levels = c(0, 1, 2),
                                        labels = c("With Party", "Independent Vote", "Maverick Vote"))
d_partisan_votes <- heatmap_data %>% filter(party=="D") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric2)) %>% filter(max>=1)
r_partisan_votes <- heatmap_data %>% filter(party=="R") %>% group_by(roll_call_id) %>% summarize(max=max(partisan_metric2)) %>% filter(max>=1)

d_votes <- heatmap_data %>% filter(party=="D") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(d_partisan_votes$roll_call_id))

r_votes <- heatmap_data %>% filter(party=="R") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1) %>% filter(as.character(roll_call_id) %in% as.character(r_partisan_votes$roll_call_id))

priority_votes <- heatmap_data %>% filter(priority_bills=="Y") %>% group_by(roll_call_id,vote_text) %>% summarize(n=n()) %>%  pivot_wider(names_from=vote_text,values_from=n,values_fill = 0) %>% mutate(y_pct = Yea/(Yea+Nay),n_pct = Nay/(Nay+Yea)) %>% filter(y_pct != 0 & y_pct != 1)

roll_call_to_number <- heatmap_data %>%
  select(roll_call_id, year=session_year,number) %>%
  distinct() %>%
  arrange(desc(year),number,roll_call_id)

roll_call_to_number$number_year <- paste(roll_call_to_number$number,"-",roll_call_to_number$year)

heatmap_data$roll_call_id <- factor(heatmap_data$roll_call_id, levels = roll_call_to_number$roll_call_id)
heatmap_data$name <- factor(heatmap_data$name, levels = legislator_metric$name)

y_labels <- setNames(roll_call_to_number$number_year, roll_call_to_number$roll_call_id)

heatmap_data$final <- "N"
heatmap_data$final[grepl("third",heatmap_data$desc,ignore.case=TRUE)] <- "Y"

heatmap_data$ballotpedia2 <- paste0("http://ballotpedia.org/",heatmap_data$ballotpedia)
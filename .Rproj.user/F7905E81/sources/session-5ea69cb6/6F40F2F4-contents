########################################
#                                      #  
# 2) merge tables and add calculations #
#                                      #
########################################
votes_all <- left_join(bill_detailed$votes,bill_detailed$bill_info_df) %>% mutate(pct = yea/total)

bill_vote_all <- inner_join(bills_all,votes_all,by=c("bill_id","number","title","session_id","session_name"
),suffix=c("","_vote")) %>% mutate(total_vote = (yea+nay),true_pct = yea/total_vote) %>% arrange(true_pct) #bill_id is unique and not duplicated across sessions

#warning re: many-to-many relationship, set `relationship = "many-to-many"` to silence this warning
primary_sponsors_votes <- primary_sponsors %>% left_join(votes_all,by="bill_id") %>% mutate(total_vote = (yea+nay),true_pct = yea/total_vote) %>% arrange(true_pct)

#new column $session combines name and year. this happens after constructing primary_sponsor_votes, so that field is not in the latter frame
#### RR from original code, this may not have worked as intended, b/c session names were duplicating the year e.g. 2023-2023_Regular_Session
# which made joins fail
# bill_vote_all$session <- paste0(bill_vote_all$session_year,"-",gsub(" ","_", bill_vote_all$session_name))
bill_vote_all$session <- bill_vote_all$session_string

#convert roll call id to character (not sure why)
votes_by_legislator <- votes_by_legislator %>% mutate(roll_call_id = as.character(roll_call_id))
bill_vote_all <- bill_vote_all %>% mutate(roll_call_id = as.character(roll_call_id))

#broke this 3-way join into 2, to help with debugging
temp_join_votes_legislators <- votes_by_legislator %>%
  inner_join(legislators, by = c("people_id", "session"))
leg_votes_with2 <- temp_join_votes_legislators %>%
  inner_join(bill_vote_all, by = c("roll_call_id", "session"))

################################
#                              #  
# 3) analyze and prep data     #
#                              #
################################

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
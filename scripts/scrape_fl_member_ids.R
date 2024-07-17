# 7/17/24
# quick (15 minute) attempt to scrape member IDs of Florida legislators from https://www.myfloridahouse.gov/Sections/Representatives/representatives.aspx
# so we can embed profile pictures
# status- did not yet get this to work, may try within my scraping comfort zone (Python)

library(rvest)
library(httr)

url <- 'https://www.myfloridahouse.gov/Sections/Representatives/representatives.aspx'
webpage <- read_html(url)

# Extracting the names
names <- webpage %>%
  html_nodes('.repName a') %>%
  html_text(trim = TRUE)

# Extract URLs to get the Member IDs
urls <- webpage %>%
  html_nodes('.repName a') %>%
  html_attr('href')

# Extract Member IDs from the URLs
member_ids <- urls %>%
  sapply(function(x) {
    member_id <- str_extract(x, "MemberId=\\d+")
    str_replace(member_id, "MemberId=", "")
  })

# Extract District Numbers
districts <- webpage %>%
  html_nodes('.district') %>%
  html_text(trim = TRUE)

# Create a data frame
data <- data.frame(
  Chamber = "House",
  District = districts,
  MemberID = member_ids,
  Name = names,
  stringsAsFactors = FALSE
)
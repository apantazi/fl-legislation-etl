#04d_nominate_scoring.R
# Add a chamber_name column for readability
rollcall_chamber_summary <- qry_leg_votes %>%
  filter(
    vote_text %in% c("Yea", "Nay"),
    !is.na(partisan_vote_type),
    !is.na(roll_call_id),
    !is.na(roll_call_chamber)
  ) %>%
  mutate(
    chamber = case_when(
      roll_call_chamber == "H" ~ "House",
      roll_call_chamber == "S" ~ "Senate",
      TRUE ~ roll_call_chamber  # fallback, just in case
    )
  ) %>%
  group_by(chamber,party) %>%
  summarise(
    n_votes = n(),
    party_line = mean(partisan_vote_type == "Party Line Partisan", na.rm=TRUE),
    bipartisan = mean(partisan_vote_type == "Party Line Bipartisan", na.rm=TRUE),
    cross_party = mean(partisan_vote_type == "Cross Party", na.rm=TRUE),
    against_both = mean(partisan_vote_type == "Against Both Parties", na.rm=TRUE),
    mean_party_loyalty = mean(party_loyalty_weight, na.rm=TRUE),
    mean_party_independence = mean(vote_against_both, na.rm=TRUE)
  ) %>%
  arrange(desc(n_votes))

print(rollcall_chamber_summary)

library(tidyverse)
library(pscl)
library(wnominate)

# Function to build vote matrix for a chamber
build_vote_matrix <- function(qry_leg_votes, chamber_code = "H") {
  votes <- qry_leg_votes %>%
    filter(
      roll_call_chamber == chamber_code,
      vote_text %in% c("Yea", "Nay")
    ) %>%
    mutate(
      vote_code = case_when(
        vote_text == "Yea" ~ 1L,
        vote_text == "Nay" ~ 6L,
        TRUE ~ 9L
      )
    ) %>%
    select(legislator_name, roll_call_id, vote_code) %>%
    pivot_wider(names_from = roll_call_id, values_from = vote_code)
  
  leg_names <- votes$legislator_name
  votes <- votes %>% select(-legislator_name)
  votes_mat <- as.matrix(votes)
  rownames(votes_mat) <- leg_names
  votes_mat[is.na(votes_mat)] <- 9 # treat NA as missing
  return(list(mat = votes_mat, names = leg_names))
}

# Get party lookup for polarity setting
get_party_lookup <- function(qry_leg_votes, chamber_code) {
  qry_leg_votes %>%
    filter(roll_call_chamber == chamber_code) %>%
    select(legislator_name, party) %>%
    distinct()
}

# House
house_vote <- build_vote_matrix(qry_leg_votes, "H")
house_party_lookup <- get_party_lookup(qry_leg_votes, "H")
# pick one R, one D as polarity
pol_house <- c(
  qry_legislators_incumbent %>% filter(party == "R" & chamber == "House") %>% arrange(desc(leg_party_loyalty),leg_party_independence) %>% slice(1) %>% pull(legislator_name),
  qry_legislators_incumbent %>% filter(party == "D"& chamber == "House") %>% arrange(desc(leg_party_loyalty),leg_party_independence) %>% slice(1) %>% pull(legislator_name)
)
pol_indices_house <- match(pol_house, house_vote$names)


house_rc <- rollcall(
  house_vote$mat, yea = 1, nay = 6, missing = 9,notInLegis = 99,
  legis.names = house_vote$names, legis.data = house_party_lookup
)

house_wnom <- wnominate(house_rc, polarity = pol_indices_house)
house_scores <- house_wnom$legislators %>%
  mutate(legislator_name = rownames(house_wnom$legislators), chamber = "House")

# Senate
senate_vote <- build_vote_matrix(qry_leg_votes, "S")
senate_party_lookup <- get_party_lookup(qry_leg_votes, "S")
pol_senate <- c(
  qry_legislators_incumbent %>% filter(party == "R" & chamber == "Senate") %>% arrange(desc(leg_party_loyalty),leg_party_independence) %>% slice(1) %>% pull(legislator_name),
  qry_legislators_incumbent %>% filter(party == "D" & chamber == "Senate") %>% arrange(desc(leg_party_loyalty),leg_party_independence) %>%  slice(1) %>% pull(legislator_name)
)

pol_indices_senate <- match(pol_senate, senate_vote$names)
senate_party_lookup_fixed <- senate_party_lookup %>%
  filter(legislator_name %in% senate_vote$names) %>%
  arrange(factor(legislator_name, levels = senate_vote$names))

# Now, check if this is the right length:
stopifnot(length(senate_vote$names) == nrow(senate_party_lookup_fixed))

senate_rc <- rollcall(
  senate_vote$mat, yea = 1, nay = 6, missing = 9,notInLegis = 99,
  legis.names = senate_vote$names, legis.data = senate_party_lookup_fixed
)
senate_wnom <- wnominate(senate_rc, polarity = pol_indices_senate)
senate_scores <- senate_wnom$legislators %>%
  mutate(legislator_name = rownames(senate_wnom$legislators), chamber = "Senate")
library(ggplot2)
library(dplyr)

# Combine House and Senate scores
all_scores <- bind_rows(
  house_scores %>% select(legislator_name, chamber, party, coord1D),
  senate_scores %>% select(legislator_name, chamber, party, coord1D)
)

# Plot
ggplot(all_scores, aes(x = reorder(legislator_name, coord1D), y = coord1D, color = party)) +
  geom_point(size = 3) +
  facet_wrap(~chamber, scales = "free_x") +
  coord_flip() +
  labs(
    title = "Legislator Ideological Scores (W-NOMINATE 1D)",
    x = "Legislator",
    y = "DW-NOMINATE Score (Dimension 1)"
  ) +
  theme_minimal() +
  theme(
    axis.text.y = element_text(size = 6),
    legend.position = "top"
  )

all_scores_2d <- bind_rows(
  house_scores %>% select(legislator_name, chamber, party, coord1D, coord2D),
  senate_scores %>% select(legislator_name, chamber, party, coord1D, coord2D)
)

ggplot(all_scores_2d, aes(x = coord1D, y = coord2D, color = party, shape = chamber)) +
  geom_point(size = 3) +
  geom_text(aes(label = legislator_name), size = 2, hjust = 0, vjust = 0, check_overlap = TRUE) +
  facet_wrap(~chamber) +
  labs(
    title = "W-NOMINATE: Legislative Coalitions in 2D",
    x = "Dimension 1 (Liberal-Conservative)",
    y = "Dimension 2 (Secondary Split)"
  ) +
  theme_minimal()

p_legislator_votes_min <- p_legislator_votes
p_legislator_votes_min <- p_legislator_votes_min[, !names(p_legislator_votes_min) %in% c("bill_desc")]
write.csv (p_legislator_votes_min, "data-app/p_legislator_votes_min.csv")
write.csv (p_legislator_votes, "data-app/p_legislator_votes.csv")

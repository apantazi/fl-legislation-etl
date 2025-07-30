# 03b_caucus_clustering.R
#################################
# Assign legislators to caucus-style clusters based on roll call votes.
# This script relies on processed tables created in 03a_process.R.
# It creates `p_legislator_clusters` and appends cluster ids to `p_legislators`.
#################################

library(tidyverse)
library(cluster)

# Helper to convert vote text to numeric
vote_numeric <- p_legislator_votes %>%
  mutate(vote_val = case_when(
    vote_text == "Yea" ~ 1,
    vote_text == "Nay" ~ -1,
    TRUE ~ NA_real_
  )) %>%
  select(people_id, roll_call_id, vote_val)

vote_numeric <- vote_numeric %>%
  left_join(select(p_legislators, people_id, chamber), by = "people_id") %>%
  filter(!is.na(chamber))

# Function: Optimal K via Elbow and Silhouette, then Cluster and Impute
cluster_chamber_optimal <- function(votes_df, kmax = 12, participation_cut = 0.1) {
  vote_wide <- votes_df %>%
    pivot_wider(names_from = roll_call_id, values_from = vote_val)
  n_votes <- ncol(vote_wide) - 2 # minus people_id and chamber
  vote_wide <- vote_wide %>%
    mutate(n_cast = rowSums(!is.na(select(., -people_id, -chamber))),
           vote_share = n_cast / n_votes)
  vote_wide_filt <- vote_wide %>% filter(vote_share >= participation_cut)
  if (nrow(vote_wide_filt) == 0) return(tibble(people_id = integer(), caucus_cluster = integer(), chamber = unique(votes_df$chamber)))
  
  leg_ids <- vote_wide_filt$people_id
  vote_mat <- vote_wide_filt %>% select(-people_id, -chamber, -n_cast, -vote_share) %>% as.matrix()
  vote_fill <- vote_mat
  vote_fill[is.na(vote_fill)] <- 0
  
  # --- Elbow and Silhouette Plots ---
  wss <- numeric()
  sil_width <- numeric()
  # Silhouette only valid for k >= 2
  k_range <- 2:kmax
  for (k in k_range) {
    set.seed(123)
    km <- kmeans(vote_fill, centers = k, nstart = 10)
    wss[k] <- km$tot.withinss
    sil <- silhouette(km$cluster, dist(vote_fill))
    sil_width[k] <- mean(sil[, 3])
  }
  # Plot Elbow
  plot(k_range, wss[k_range], type = "b", xlab = "k", ylab = "Within-cluster sum of squares", main = paste("Elbow Plot:", unique(votes_df$chamber)))
  # Plot Silhouette
  plot(k_range, sil_width[k_range], type = "b", xlab = "k", ylab = "Average silhouette width", main = paste("Silhouette:", unique(votes_df$chamber)))
  
  # Pick optimal k (highest average silhouette width)
  best_k <- which.max(sil_width)
  cat("For chamber", unique(votes_df$chamber), "optimal k =", best_k, "based on silhouette\n")
  
  # Cluster with best k
  set.seed(123)
  clusters_prev <- NULL
  vote_fill2 <- vote_mat
  vote_fill2[is.na(vote_fill2)] <- 0
  for (i in 1:10) {
    stopifnot(all(is.finite(vote_fill2)))
    km <- kmeans(vote_fill2, centers = best_k, nstart = 10)
    clusters <- km$cluster
    if (!is.null(clusters_prev) && all(clusters == clusters_prev)) break
    clusters_prev <- clusters
    # Impute missing votes in each cluster using cluster means
    for (cl in unique(clusters)) {
      idx <- which(clusters == cl)
      cl_means <- colMeans(vote_mat[idx, , drop = FALSE], na.rm = TRUE)
      miss <- which(is.na(vote_mat[idx, , drop = FALSE]), arr.ind = TRUE)
      if (nrow(miss) > 0) {
        for (j in seq_len(nrow(miss))) {
          row <- idx[miss[j, "row"]]
          col <- miss[j, "col"]
          val <- cl_means[col]
          if (is.nan(val) || is.na(val) || is.infinite(val)) val <- 0
          vote_fill2[row, col] <- val
        }
      }
    }
    vote_fill2[is.na(vote_fill2) | is.nan(vote_fill2) | is.infinite(vote_fill2)] <- 0
  }
  tibble(people_id = leg_ids, caucus_cluster = clusters, chamber = unique(votes_df$chamber))
}

# Run by chamber, visualize and cluster
chamber_list <- unique(vote_numeric$chamber)
cluster_dfs <- lapply(chamber_list, function(ch) {
  cluster_chamber_optimal(vote_numeric %>% filter(chamber == ch))
})

p_legislator_clusters <- bind_rows(cluster_dfs)

# Merge with p_legislators
p_legislators <- p_legislators %>%
  left_join(select(p_legislator_clusters, people_id, caucus_cluster), by = "people_id")

# --- At this point, you can visualize as described earlier ---

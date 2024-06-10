install.packages(c(
  "tidyverse",
  "tidytext",
  "pscl",
  "wnominate",
  "oc",
  "jsonlite",
  "SnowballC",
  "future.apply"
))
# Install legiscanrr, which needs devtools
if (!requireNamespace("devtools", quietly = TRUE)) install.packages("devtools")
devtools::install_github("fanghuiz/legiscanrr")

# Install dwnominate, which needs remotes
#basicspace is a dependency for dwnominate, but it's no longer in CRAN. found an archived version
if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
install.packages("https://cran.r-project.org/src/contrib/Archive/basicspace/basicspace_0.24.tar.gz", repos = NULL, type = "source")
remotes::install_github('wmay/dwnominate')

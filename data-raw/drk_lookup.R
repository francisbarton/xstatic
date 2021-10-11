# geo lookups to help get area codes
drkane_url <- "https://github.com/drkane/geo-lookups/raw/master/lsoa_la.csv"

drk_lookup <- readr::read_csv(drkane_url)
drk_lookup <- janitor::clean_names(drk_lookup)

# use_data(drk_lookup, internal = TRUE, overwrite = TRUE)

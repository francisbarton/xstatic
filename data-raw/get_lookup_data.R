## code to prepare dataset goes here

## old, original code - replaced by simpler function below
# get_lookup <- function(url = "", data_dir = "data_raw", overwrite = FALSE, chatty = TRUE, ...) {
#
#   # geo lookups to help get area codes
#   drkane_url <- "https://github.com/drkane/geo-lookups/raw/master/lsoa_la.csv"
#
#   # currently it's only ever going to be "" as there's no route to pass it anything else
#   # so this is all overkill but am leaving it as it is for now
#
#   url <- drkane_url
#   if (chatty) {
#     ui_info(paste("Using DR Kane's lookup from GitHub", url))
#   }
#
#   if (basename(url) == "") {
#     destfile = "lookup_download.csv"
#   }
#   else {
#     destfile <- basename(url)
#   }
#
#   if (!dir.exists(here::here(data_dir))) {
#     dir.create(here::here(data_dir))
#     if (chatty) {
#       ui_info(paste("Creating new directory", data_dir))
#     }
#   }
#
#   dl_file <- here::here(data_dir, destfile)
#
#   # check to see if the file already exists
#   if (!file.exists(dl_file) || overwrite) {
#     utils::download.file(url, dl_file, quiet = TRUE, ...)
#   }
#   else {
#     ui_info(
#       paste(
#         "File",
#         dl_file,
#         "already existed, so that was used instead of re-downloading. Pass `overwrite = TRUE` to overwrite the existing file with a fresh download.")
#     )
#   }
#
#   if (str_detect(dl_file, "csv$")) {
#     out <- readr::read_csv(dl_file) %>%
#       janitor::clean_names()
#   }
#   else if (str_detect(dl_file, "json$")) {
#     out <- fromJSON(dl_file) %>%
#       janitor::clean_names()
#   }
#   else {
#     ui_stop(
#       "Downloaded lookup file seems to be neither a CSV nor a JSON file.")
#   }
#   return(out)
# }


get_lookup <- function(overwrite = FALSE, chatty = TRUE) {

    # geo lookups to help get area codes
    drkane_url <- "https://github.com/drkane/geo-lookups/raw/master/lsoa_la.csv"

    if (chatty) {
      ui_info(paste("Using DR Kane's lookup from GitHub", drkane_url))
    }

    destfile <- basename(drkane_url)

    # check to see if the file already exists
    if (!file.exists(destfile) || overwrite) {
      utils::download.file(drkane_url, destfile, quiet = TRUE)
    }
    else {
      ui_info(
        paste(
          "File",
          destfile,
          "already existed, so that was used instead of re-downloading. Pass `overwrite = TRUE` to overwrite the existing file with a fresh download.")
      )
    }

  readr::read_csv(destfile) %>%
    janitor::clean_names()
}

lookup <- get_lookup()

use_data(lookup, overwrite = TRUE)

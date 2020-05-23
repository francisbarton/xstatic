library(assertthat)
library(dplyr)
library(here)
library(janitor)
library(readr)
library(stringr)
library(usethis)

# make this function "chatty" as well!?!

get_lookup <- function(url = "", data_dir = "data", overwrite = FALSE, chatty = TRUE, ...) {

  # geo lookups to help get area codes
  drkane_url <- "https://github.com/drkane/geo-lookups/raw/master/lsoa_la.csv"

  if(url == "") {
    url <- drkane_url
    if(chatty) {
      usethis::ui_info(paste("No lookup URL provided. Using DR Kane's lookup from GitHub", url))
    }
  } else {
    if(chatty) {
      usethis::ui_info(paste("Using provided URL", url, "as lookup source"))
    }
  }

  if(basename(url) == "") {
    destfile = "lookup_download.csv"
  }
  else {
    destfile <- basename(url)
  }

  if(!dir.exists(here::here(data_dir))) {
    dir.create(here::here(data_dir))
    if(chatty) {
      usethis::ui_info(paste("Creating new directory", data_dir))
    }
  }

  dl_file <- here::here(data_dir, destfile)

  # check to see if the file already exists
  if(!file.exists(dl_file) || overwrite) {
    utils::download.file(url, dl_file, quiet = TRUE, ...)
  }
  else {
    usethis::ui_info(
      paste(
        "File",
        dl_file,
        "already existed, so that was used instead of re-downloading. Pass `overwrite = TRUE` to overwrite the existing file with a fresh download.")
      )
  }

  if(str_detect(dl_file, "csv$")) {
    out <- readr::read_csv(dl_file) %>%
      janitor::clean_names()
  }
  else if(str_detect(dl_file, "json$")) {
    out <- jsonlite::fromJSON(dl_file)
  }
  else {
    usethis::ui_stop(
      "Downloaded lookup file is neither a CSV nor a JSON file.")
  }
  return(out)
}


geo_levels <- tibble(
  aliases = c(
    "country",
    "region",
    "upper",
    "local|lad",
    "middle|msoa",
    "lower|lsoa"),
  returns = c(
    "ctry",
    "rgn",
    "utla",
    "lad20",
    "msoa11",
    "lsoa11"),
  geo_level = c(7:2)
)

process_aliases <- function(input) {

  process_string <- function(string, x, y) {
    string <- tolower(string)
    if(str_detect(string, x)) {
      string <- y
    }
    else { string <- "" }
    return(string)
  }

    map2_chr(.x = geo_levels$aliases, .y = geo_levels$returns, ~ process_string(string = input, x = .x, y = .y)) %>%
    str_c(collapse = "")
}

extract_area_codes <- function(df, filter_level, filter_name, return_level, use_aliases, chatty = TRUE) {

  if(use_aliases) {
    return_level <- paste0(process_aliases(return_level), "cd")
  }
  assert_that(is.string(return_level))

  if(filter_level == "") {
    area_codes <- df %>%
      pull(return_level) %>%
      unique
    if(chatty) {
      usethis::ui_info("Extracting area codes from lookup table.")
      usethis::ui_info("No filter by location.")
      usethis::ui_info(paste("Extracting codes at", return_level, "level"))
    }
  } else {

    assert_that(is.string(filter_level))
    assert_that(is.character(filter_name))

    if(use_aliases) {
      filter_level <- paste0(process_aliases(filter_level), "nm")
    }


    if(chatty) {
      usethis::ui_info("Extracting area codes from lookup table.")
      usethis::ui_info(paste("Filtering lookup at level", filter_level))
      usethis::ui_info(paste("Selecting only data within", filter_name))
      usethis::ui_info(paste("Extracting codes at", return_level, "level"))
    }

    # turn string into a symbol so it can be used below as a col name
    filter_level <- dplyr::ensym(filter_level)

    area_codes <- df %>%
      dplyr::filter(str_detect( {{filter_level}}, filter_name )) %>%
      pull(return_level) %>%
      unique
  }

  if(chatty) {
    usethis::ui_info(paste("Returning", length(area_codes), "area codes"))
    usethis::ui_info(paste("Sample codes:", str_c(head(area_codes, 3), sep = ",")))
  }

  return(area_codes)
}


obtain_codes <- function(
  filter_level, filter_name, return_level, use_alias = TRUE, lookup = "", chatty = TRUE, ...) {

  if(lookup == "") {
    lookup <- get_lookup(chatty = chatty, ...)
  }
  assert_that(is.data.frame(lookup))
  codes <- lookup %>% extract_area_codes(., filter_level, filter_name, return_level, use_aliases = use_alias, chatty = chatty)
}


# in case of long lists of areas, split -----------------------------------


# First of all we need to create a list of lists of area codes, with
# each sub-list being no bigger than 1000 items.

# If the list of areas codes is shorter than 1000 the procedure below should
# not do any harm, it will produce something like the original list

# We need to split the list into chunks and then map our lookup across the list
# of chunks, otherwise it's too big a query for the API

# the code here kind of says
#
# "how many 1000s are in your list? round that up.
# now make a list of each number from 1 to that number -
# each number will be treated as a *factor* -
# but with each one repeated 1000 times -
# then truncate that list to the length of the list you started with."



# split_factors <- rep(1:ceiling(length(area_codes)/1000), each = 1000) %>% head(length(area_codes))
# areas_split_list <- area_codes %>% split(., split_factors)

# as a function

make_batched_list <- function(x, batch_size = 1000) {

  if(is.list(x)) {
    x <- unlist(x)
  }
  assert_that(is.vector(x))

  rep(1:ceiling(length(x)/batch_size), each = batch_size) %>%
    head(length(x)) %>%
    split(x, .)
}

process_aliases <- function(x) {

  out <- dplyr::tibble(
    alias = c(
      "country",
      "region",
      "upper",
      "local|lad",
      "middle|msoa",
      "lower|lsoa"),
    geo_code = c(
      "ctry",
      "rgn",
      "utla",
      "lad20",
      "msoa11",
      "lsoa11"),
    geo_level = c(7:2)
  ) %>%
    dplyr::filter(stringr::str_detect(tolower(x), alias))

  if (!nrow(out) == 1) {
    usethis::ui_info("No alias found, returning input only. Please pass a geo_code as a separate argument, as an integer between 1 and 7 (7 = country, 1 = OA).")
    x
  } else {
    out %>%
      dplyr::select(!alias) %>%
      unlist() %>%
      unname()
  }
}

extract_area_codes <- function(lookup, filter_level, filter_area, return_level, chatty = TRUE) {

  return_level <- paste0(process_aliases(return_level)[1], "cd")

  if (is.null(filter_level)) {
    area_codes <- lookup %>%
      dplyr::pull(return_level)
    if (chatty) {
      usethis::ui_info("Extracting area codes from lookup table.")
      usethis::ui_info("No filter by location.")
      usethis::ui_info(paste("Extracting codes at", return_level, "level"))
    }
  } else {
    filter_level <- paste0(process_aliases(filter_level)[1], "nm")

    if (chatty) {
      usethis::ui_info("Extracting area codes from lookup table.")
      usethis::ui_info(paste("Filtering lookup at level", filter_level))
      usethis::ui_info(paste("Selecting only data within", filter_area))
      usethis::ui_info(paste("Extracting codes at", return_level, "level"))
    }

    # turn string into a symbol so it can be used below as a col name
    filter_level <- rlang::ensym(filter_level)

    area_codes <- lookup %>%
      dplyr::filter(dplyr::across(filter_level, ~ stringr::str_detect(., filter_area))) %>%
      dplyr::pull(return_level) %>%
      unique()
  }

  if (chatty) {
    usethis::ui_info(paste("Returning", length(area_codes), "area codes"))
    usethis::ui_info(paste("Sample codes:", stringr::str_c(head(area_codes, 3), sep = ",")))
  }

  # return
  area_codes
}

get_area_codes <- function(area_code_lookup = NULL, ...) {

  if (is.null(area_code_lookup)) area_code_lookup <- drk_lookup

  # fallback as internal sysdta seems not to be loading in properly
  if (is.null(area_code_lookup)) {
    area_code_lookup <- readr::read_csv("https://github.com/drkane/geo-lookups/raw/master/lsoa_la.csv") %>%
      janitor::clean_names()
  }

  area_code_lookup %>%
    extract_area_codes(...)
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

  if (is.list(x)) {
    x <- unlist(x)
  }
  assertthat::assert_that(is.vector(x))

  rep(1:ceiling(length(x)/batch_size), each = batch_size) %>%
    head(length(x)) %>%
    split(x, .)
}

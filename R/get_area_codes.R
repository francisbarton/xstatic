# source(here("data-raw/get_lookup_data.R"))

geo_levels <- dplyr::tibble(
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

  input <- tolower(input)
  out_code <- geo_levels %>%
    filter(stringr::str_detect(input, aliases)) %>%
    pull(returns)

  if (length(out_code) == 0) {
    input
  } else {
    out_code
  }
}

extract_area_codes <- function(df, filter_level, filter_area, return_level, chatty = TRUE) {

    return_level <- paste0(process_aliases(return_level), "cd")

  if (filter_level == "") {
    area_codes <- df %>%
      pull(return_level) %>%
      unique()
    if (chatty) {
      ui_info("Extracting area codes from lookup table.")
      ui_info("No filter by location.")
      ui_info(paste("Extracting codes at", return_level, "level"))
    }
  } else {

      filter_level <- paste0(process_aliases(filter_level), "nm")

    if (chatty) {
      ui_info("Extracting area codes from lookup table.")
      ui_info(paste("Filtering lookup at level", filter_level))
      ui_info(paste("Selecting only data within", filter_area))
      ui_info(paste("Extracting codes at", return_level, "level"))
    }

    # turn string into a symbol so it can be used below as a col name
    filter_level <- ensym(filter_level)

    area_codes <- df %>%
      filter(str_detect({{filter_level}}, filter_area )) %>%
      pull(return_level) %>%
      unique()
  }

  if (chatty) {
    ui_info(paste("Returning", length(area_codes), "area codes"))
    ui_info(paste("Sample codes:", str_c(head(area_codes, 3), sep = ",")))
  }

  return(area_codes)
}

get_area_codes <- function(
  filter_level, filter_area, return_level, area_code_lookup = NULL, chatty = TRUE, ...) {

  if (is.null(area_code_lookup)) area_code_lookup <- lookup

  assert_that(is.data.frame(area_code_lookup))
  codes <- area_code_lookup %>% extract_area_codes(., filter_level, filter_area, return_level, chatty = chatty)
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
  assert_that(is.vector(x))

  rep(1:ceiling(length(x)/batch_size), each = batch_size) %>%
    head(length(x)) %>%
    split(x, .)
}

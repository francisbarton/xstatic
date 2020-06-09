#' statx_slurp
#' @name statx_slurp
#' @import httr
#' @importFrom assertthat assert_that
#' @importFrom dplyr bind_cols bind_rows ensym filter mutate mutate_at pull select slice tibble
#' @importFrom dwpstat dwp_schema
#' @importFrom here here
#' @importFrom janitor clean_names
#' @importFrom jsonlite fromJSON
#' @importFrom purrr map map_chr map2_chr map_dfc pluck reduce
#' @importFrom readr read_csv
#' @importFrom rlang .data :=
#' @importFrom snakecase to_snake_case
#' @importFrom stringr str_c str_detect str_glue str_replace str_subset
#' @importFrom usethis ui_info ui_stop
#' @importFrom utils head tail
#'
#' @param areas_list provide a list of area codes for the query
#' @param dataset_name name of the dataset on Stat-Xplore (partial/regex works)
#' @param location_level return data within an area at this level
#' @param filter_location return data within this area. defaults to ".*"
#' @param data_level return data at this level
#' @param area_code_lookup use this source to lookup area codes at data_level within filter_location
#' @param use_alias TRUE by default. Set to FALSE to turn off aliases for location_level and data_level
#' @param batch_size If data for more than 1000 area codes are requested then they will be batched into queries of this size. Default is 1000.
#' @param chatty TRUE by default. Provides verbose commentary on the query process.
#' @param ... space to pass parameters to the helper function get_dwp_codes, mainly to do with the number of recent periods (months or quarters) to retrieve data for: provide `periods_tail = n`; see also `periods_head`; you can also tweak the query away from the default of Census geographies to Westminster constituencies, for example, where available, by providing a different value for `geo_type`; you can also change the subset of data from the default by providing a value for `ds`.
#'
#' @return Data frame
#' @export
#'
#' @examples
#' \donttest{
#' statx_slurp(
#' areas_list = "",
#' dataset_name = "^Carers",
#' location_level = "lad",
#' filter_location = "City of London",
#' data_level = "msoa",
#' periods_tail = 2,
#' batch_size = 1000,
#' use_alias = TRUE,
#' chatty = TRUE)
#' }

utils::globalVariables(c("."))

statx_slurp <- function(areas_list = "", dataset_name, location_level = "", filter_location = ".*", data_level, area_code_lookup = "", use_alias = TRUE, batch_size = 1000, chatty = TRUE, ...) {

  # source(here("R/slurp_helpers.R"))

  if(areas_list == "") {
    if(chatty) {
      ui_info("No list of area codes provided. Using a lookup instead.")
    }
    # source(here("R/obtain_codes.R"))

    # make sure we've got a vector of area codes to work with -----------------
    area_codes <- obtain_codes(location_level, filter_location, data_level, lookup = area_code_lookup, use_alias = use_alias, chatty = chatty)
    areas_list <- make_batched_list(area_codes, batch_size = batch_size)

    # not sure I am doing this right
    assert_that(is.list(areas_list))
    assert_that(length(areas_list) > 0)

    if(chatty) {
      ui_info(paste(length(area_codes), "area codes retrieved and batched into a list of", length(areas_list), "batches, of max batch size", batch_size))
    }
  }


  # get build codes/ids etc
  # source(here("R/get_dwp_codes.R"))

  data_level <- process_aliases(data_level)
  geo_level <- geo_levels %>%
    filter(returns == data_level) %>%
    pull(geo_level)

  build_list <- get_dwp_codes(dataset_name, geo_level = geo_level, chatty = chatty, ...)

  assert_that(is.list(build_list))
  assert_that(length(build_list) == 6)

  dates <- str_replace(build_list[["periods"]], "(.*:)([:digit:]*$)", "\\2")

  # create geo_codes_list
  geo_codes_list <- areas_list %>%
    map( ~ list(
      convert_geo_ids(build_list[["geo_level_id"]], .),
      build_list[["periods"]])
      )


  # map along each chunk of geo_codes_list to create a query for each chunk

  # shamelessly borrowing this
  # source(here("R/evanodell_sx_get_data_util.R"))

  data_out_list <- geo_codes_list %>%
    map( ~ build_query(
      build_list = build_list,
      geo_codes_chunk = .) %>%
    sx_get_data_util(table_endpoint, .) %>%
    pull_sx_data(., dates = dates))


  data_out <- reduce(data_out_list, bind_rows)
  assert_that(nrow(data_out) == length(dates) * length(area_codes))
  ui_info(paste(nrow(data_out), "rows of data at", data_level, "level retrieved."))

  # ui_info(paste("Data level:", data_level))
  data_level_code <- paste0(data_level, "cd")
  data_level_name <- paste0(data_level, "nm")
  tidy_ben_name <- snakecase::to_snake_case(dataset_name)
  # ui_info(paste("Data level code:", data_level_code))
  # ui_info(paste("Data level name:", data_level_name))

  tibble(data_date = rep(dates, each = length(area_codes))) %>%
    bind_cols(data_out) %>%
    select({{data_level_code}} := uris,
           {{data_level_name}} := labels,
           data_date,
           {{tidy_ben_name}} := values)

}

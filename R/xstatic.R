#' xstatic
#'
#' @name xstatic
#'
#' @param ben name of a benefit dataset on Stat-Xplore (partial/regex works)
#' @param area_codes (optional) provide your own vector (list) of area codes for the query (don't use built-in lookup)
#' @param filter_level return data within an area at this level
#' @param filter_area return data within this area. defaults to ".*" (all)
#' @param return_level return data at this level
#' @param area_code_lookup use this source to lookup area codes at return_level within filter_area
#' @param geo_level If for some reason you need to pass a return_level that is different from the standard options, you will also need to pass a geo_level - an integer between 1 and 7, where 1 means "OA" and 7 refers to "country"
#' @param chatty TRUE by default. Provides verbose commentary on the query process.
#' @param ... space to pass parameters to the helper function get_dwp_codes, mainly to do with the number of recent periods (months or quarters) to retrieve data for: provide `periods_tail = n` (uses 1 - just return most recent period - by default); see also `periods_head`; you can also tweak the query away from the default of Census geographies to Westminster constituencies, for example, where available, by providing a different value for `geo_type`; you can also change the subset of data from the default by providing a different value for `ds`.
#'
#' @return A data frame
#' @export
#'
#' @examples
#' xstatic(
#' ben = "^Carers",
#' filter_level = "lad", # case-insensitive
#' filter_area = "City of London", # case sensitive
#' return_level = "MsOa", # case-insensitive
#' periods_tail = 2, # starting with most recent available month/quarter
#' periods_head = 1, # returns penultimate data period only (ie first 1 of 2)
#' chatty = FALSE)

xstatic <- function(ben, area_codes = NULL, filter_level = NULL, filter_area = ".*", return_level, area_code_lookup = NULL, geo_level = NULL, chatty = TRUE, ...) {

  if (is.null(area_codes)) {
    if (chatty) {
      usethis::ui_info("No list of area codes provided. Using a lookup instead.")
    }

    area_code_lookup <- drk_lookup

    area_codes <- get_area_codes(area_code_lookup, filter_level, filter_area, return_level, chatty)
  }

  areas_list <- make_batched_list(area_codes, batch_size = 1000)

  if (chatty) {
    usethis::ui_info(paste(length(area_codes), "area codes retrieved and batched into a list of", length(areas_list), "batches"))
  }


  data_level <- process_aliases(return_level)[1]
  geo_level <- geo_level %||% as.numeric(process_aliases(return_level)[2])

  build_list <- get_dwp_codes(ben, geo_level, chatty, ...)

  assertthat::assert_that(is.list(build_list))
  assertthat::assert_that(length(build_list) == 6)

  # a simple list of the dates of the periods requested
  dates <- stringr::str_replace(build_list[["periods"]], "(.*:)([:digit:]+$)", "\\2") %>%
    as.integer()

  # create geo_codes_list
  geo_codes_list <- areas_list %>%
    purrr::map( ~ list(
      convert_geo_ids(build_list[["geo_level_id"]], .),
      build_list[["periods"]])
      )


  # map along each chunk of geo_codes_list to create a JSON query for each chunk
  # then send each query to SX using dwp_get_data_util
  # shamelessly borrowing this function:
  # source(here("R/dwp_get_data_util.R"))

  data_out_list <- geo_codes_list %>%
    purrr::map( ~ build_query(
      build_list = build_list,
      geo_codes_chunk = .) %>%
    dwp_get_data_util() %>%
    pull_sx_data(., dates = dates))

  # condense the list of data results into a single data frame
  data_out <- purrr::reduce(data_out_list, dplyr::bind_rows)

  # if all has gone well it should be this long:
  assertthat::assert_that(nrow(data_out) == length(dates) * length(area_codes))
  if (chatty) {
    usethis::ui_info(paste(nrow(data_out), "rows of data at", data_level, "level retrieved."))
  }


  # ui_info(paste("Data level:", data_level))

  # prepare area level codes and benefit name to be column names
  data_level_code <- paste0(data_level, "cd")
  data_level_name <- paste0(data_level, "nm")
  tidy_ben_name <- snakecase::to_snake_case(ben)
  # ui_info(paste("Data level code:", data_level_code))
  # ui_info(paste("Data level name:", data_level_name))

  # build final tibble as the result to return.
  # Feels pretty risky due to use of bind_cols (as opposed to something like left_join);
  # it ought to match up ok but it's vulnerable to glitches. Needs testing.
  dplyr::tibble(data_date = rep(dates, each = length(area_codes))) %>%
    dplyr::bind_cols(data_out) %>%
    dplyr::select({{data_level_code}} := uris,
           {{data_level_name}} := labels,
           data_date,
           {{tidy_ben_name}} := values)
}

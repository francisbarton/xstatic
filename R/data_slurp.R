
# libraries ---------------------------------------------------------------

library(assertthat)
library(dplyr)
library(here)
library(purrr)
library(stringr)


data_slurp <- function(areas_list = "", dataset_name, location_level = "", filter_location = ".*", data_level, area_code_lookup = "", use_alias = TRUE, batch_size = 1000, chatty = TRUE, ...) {

  if(chatty) {
    library(usethis)
  }

  if(areas_list == "") {
    if(chatty) {
      usethis::ui_info("No list of area codes provided. Using a lookup instead.")
    }
    source(here("R/obtain_codes.R"))

    # make sure we've got a vector of area codes to work with -----------------
    area_codes <- obtain_codes(location_level, filter_location, data_level, lookup = area_code_lookup, use_alias = use_alias, chatty = chatty)
    areas_list <- make_batched_list(area_codes, batch_size = batch_size)

    # not sure I am doing this right
    assert_that(is.list(areas_list))
    assert_that(length(areas_list) > 0)

    if(chatty) {
      usethis::ui_info(paste(length(area_codes), "area codes retrieved and batched into a list of", length(areas_list), "batches, of max batch size", batch_size))
    }
  }



  # get build codes/ids etc
  source(here("R/get_dwp_codes.R"))

  data_level <- process_aliases(data_level)
  geo_level <- geo_levels %>%
    filter(returns == data_level) %>%
    pull(geo_level)

  build_list <- get_dwp_codes(dataset_name, geo_level = geo_level, ...)

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
  source(here("R/evanodell_sx_get_data_util.R"))

  data_out_list <- geo_codes_list %>%
    map( ~ build_query(
      build_list = build_list,
      geo_codes_chunk = .) %>%
    sx_get_data_util(table_endpoint, .) %>%
    pull_sx_data(.))


  data_out <- reduce(data_out_list, bind_rows)
  assert_that(nrow(data_out) == length(dates) * length(area_codes))
  usethis::ui_info(paste(nrow(data_out), "rows of data at", data_level, "level retrieved."))

  # usethis::ui_info(paste("Data level:", data_level))
  data_level_code <- paste0(data_level, "cd")
  data_level_name <- paste0(data_level, "nm")
  tidy_ben_name <- snakecase::to_snake_case(dataset_name)
  # usethis::ui_info(paste("Data level code:", data_level_code))
  # usethis::ui_info(paste("Data level name:", data_level_name))

  tibble(data_date = rep(dates, each = length(area_codes))) %>%
    bind_cols(data_out) %>%
    select({{data_level_code}} := uris,
           {{data_level_name}} := labels,
           data_date,
           {{tidy_ben_name}} := values)

}



## build the query `build_json_query()`
## it's notoriously hard to generate valid JSON by hand
## so here I have split up the function into smaller functions
## (or rather, I made the big function by adding together the smaller ones)
## for the sake of easier debugging

build_recodes <- function(id_list, chunk, total = "false") {

  # sub-function
  recode_paste <- function(x, y, ...) {
    str_c(
      str_c("\"", x, "\" : {"),
      str_c("\"map\" : [ ",
            str_c(y, collapse = ","),
            " ],"),
      str_c("\"total\" : ", ...),
      "}")
  }

  # sub-function
  create_recodes <- function(field_id, area_id, ...) {
    str_c("[ \"", area_id, "\" ]") %>%
      recode_paste(x = field_id, y = ., ...) %>%
      str_c(collapse = "", sep = ",")
  }


  # main function
  map2_chr(id_list, chunk,
           ~ create_recodes(field_id = .x, area_id = .y, total = total)) %>%
    str_c(collapse = ",") %>%
    str_c("\"recodes\" : {", ., "}")
}

build_dimensions <- function(x) {
  str_c("[ \"", x, "\" ]") %>%
    str_c(., collapse = ",") %>%
    str_c("\"dimensions\" : [", ., "]")
}


build_query <- function(build_list, geo_codes_chunk) {

  # make all the parts (helper functions below, outside this function)

  query_db <- str_c(
    "\"database\" : \"", build_list[["db_id"]], "\""
  )
  query_ms <- str_c(
    "\"measures\" : [ \"", build_list[["count_id"]], "\" ]"
  )

  id_list <- list(
    build_list[["geo_field_id"]],
    build_list[["period_id"]]
  )

  recodes_section <- build_recodes(id_list = id_list, chunk = geo_codes_chunk)

  query_dimensions <- build_dimensions(id_list)



  # actually combine everything into a JSON query
  str_c(
    query_db,
    query_ms,
    recodes_section,
    query_dimensions,
    sep = ",") %>%
    str_c(
      "{", ., "}"
    )
}

# this is a post-production function to create a geocode for the query
# from each area code and `build_list[["geo_level_id"]]`
convert_geo_ids <- function(id, x) {
  id %>%
    str_replace("valueset", "value") %>%
    paste0(., ":", x)
}


# extract and tidy the data from the API return
pull_sx_data <- function(df) {
  df %>%
    pluck("fields", "items", 1) %>%
    select(-1) %>%
    mutate_at("uris", ~ str_replace(., "(.*:)([:alnum:]*$)", "\\2") %>% unlist()) %>%
    mutate_at("labels", ~ unlist(.)) %>%
    map_dfc( ~ rep(., times = length(dates))) %>%
    bind_cols(values = c(pluck(df, "cubes", 1, "values")))
}

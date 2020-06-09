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
pull_sx_data <- function(df, dates) {
  df %>%
    pluck("fields", "items", 1) %>%
    select(-1) %>%
    mutate_at("uris", ~ str_replace(., "(.*:)([:alnum:]*$)", "\\2") %>% unlist()) %>%
    mutate_at("labels", ~ unlist(.)) %>%
    map_dfc( ~ rep(., times = length(dates))) %>%
    bind_cols(values = c(pluck(df, "cubes", 1, "values")))
}

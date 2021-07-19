## build the query `build_json_query()`
## it's notoriously hard to generate valid JSON by hand
## so here I have split up the function into smaller functions
## (or rather, I made the big function by adding together the smaller ones)
## for the sake of easier debugging

# `total` means whether to ask the API for a total figure for each query
# I don't need this and I suggest users keep this as "false"
# (NB this needs to be the string "false" or "true" not logical FALSE or TRUE)
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


  # main part of build_recodes
  # take a list of codes and a chunk of area codes and map along them with `create_recodes`
  map2_chr(id_list, chunk,
           ~ create_recodes(field_id = .x, area_id = .y, total = total)) %>%
    str_c(collapse = ",") %>%
    str_c("\"recodes\" : {", ., "}")
}

# build another part of the JSON query
build_dimensions <- function(x) {
  str_c("[ \"", x, "\" ]") %>%
    str_c(., collapse = ",") %>%
    str_c("\"dimensions\" : [", ., "]")
}

# this is where it all gets brought together

build_query <- function(build_list, geo_codes_chunk) {

  # `build_list` is what is returned by `get_dwp_codes`

  # make all the parts (helper functions below, outside this function)

  query_db <- str_c(
    "\"database\" : \"", build_list[["db_id"]], "\""
  )
  query_ms <- str_c(
    "\"measures\" : [ \"", build_list[["count_id"]], "\" ]"
  )

  id_list <- list(
    build_list[["geo_area_type"]],
    build_list[["measure_id"]]
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


# extract and tidy the data from each SX API return
# dates is a list of all the data point dates returned (just the most recent 1 by default)
pull_sx_data <- function(lst, dates) {
  lst %>%
    pluck("fields", "items", 1) %>%
    select(-1) %>%
    # extract area codes
    mutate(across(uris, ~ str_replace(., "(.*:)([:alnum:]+$)", "\\2"))) %>%
    # area names
    mutate(across(c(uris, labels), ~ unlist(.))) %>%
    # repeat as many times as needed (repeat each area for each item of dates)
    # shouldn't this be map_dfr? - need to investigate what happens
    map_dfc( ~ rep(., times = length(dates))) %>%
    bind_cols(values = c(pluck(lst, "cubes", 1, "values")))
}

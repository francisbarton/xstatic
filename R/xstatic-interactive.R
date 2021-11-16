#' Xplore the Stat-Xplore API interactively
#'
#' @export
xstatic_interactive <- function() {

  sx_pull_id <- function(slice, ...) {
    dwpstat::dwp_schema(...) %>%
      dplyr::slice(slice) %>%
      dplyr::pull(id)
  }
  sx_pull_col <- function(col, ...) {
    dwpstat::dwp_schema(...) %>%
      dplyr::pull(col)
  }

  sx_get_periods <- function(id, type = "VALUESET", tail = 1, head = NULL) {

    # if periods_head not specified, or larger than tail, then set it to same as
    # periods_tail so it has no effect
    if (is.null(head) || head > tail) head <- tail

    dwpstat::dwp_schema(id) %>%
      dplyr::filter(type == type) %>%
      dplyr::slice_tail(n = 1) %>% # in case there's >1 VALUESET option
      dplyr::pull("id") %>%
      sx_pull_col(col = "id", .) %>%
      tail(tail) %>%
      head(head)
  }


  usethis::ui_info("Welcome to xstatic interactive. Please wait. Getting schema...")
  schema <- dwpstat::dwp_schema()


  bens_list <- schema %>%
    dplyr::pull(label)


  ben <- readline("Name of benefit to retrieve\n(partial match/regex is OK)\nor enter 1 for a list of all available benefits: ")
  assertthat::is.string(ben)
  assertthat::assert_that(nchar(ben) < 50)


  if (ben == "1") {
    usethis::ui_line(bens_list)

    ben <- readline("Name of benefit to retrieve\n(partial match/regex is OK)\nor enter 1 for a list of all available benefits: ")
    assertthat::is.string(ben)
    assertthat::assert_that(nchar(ben) < 50)
  }


  ben <- stringr::str_subset(bens_list, ben)

  while (!length(ben == 1)) {
    usethis::ui_oops("That didn't match a benefit name precisely enough. Please try again or press Esc or Ctrl|Cmd+C to exit.")

    if (usethis::ui_yeah("Show list of available benefits? ", n_no = 1)) {
      usethis::ui_line(bens_list)
    }

    ben <- readline("Name of benefit to retrieve\n(partial match/regex is OK)\nor enter 1 for a list of all available benefits: ")
    assertthat::is.string(ben)
    assertthat::assert_that(nchar(ben) < 50)

    ben <- stringr::str_subset(bens_list, ben)
  }

  usethis::ui_done(paste0("*** Dataset: ", ben))

  # get folder id code
  folder <- schema %>%
    dplyr::filter(label == ben)
  usethis::ui_done(paste0("[Folder id: ", folder$id, "]"))


  count_options <- dwpstat::dwp_schema(folder$id)
  usethis::ui_info(paste0("All count options:\n\t", stringr::str_c(paste0(seq(length(count_options$label)), ": ", count_options$label), collapse = "\n\t")))

  ds <- readline("Enter a number to choose a count: ")
  ds <- as.integer(ds)
  assertthat::is.count(ds)
  assertthat::assert_that(ds %in% seq(nrow(count_options)))

  usethis::ui_info(paste0("Choosing option ", ds, ", ", count_options$label[ds]))

  count_id <- count_options$id[ds]
  usethis::ui_done(paste0("[Count id: ", count_id, "]"))


  count_measures <- dwpstat::dwp_schema(count_id)

  # what numbers are going to be retrieved
  usethis::ui_info("What numbers are going to be retrieved: ")
  count2_id <- count_measures %>%
    dplyr::filter(type == "COUNT") %>%
    dplyr::pull(id)
  usethis::ui_info(paste0("[Specific count id: ", count2_id, "]"))



  # print out options
  measure_options <- count_measures %>%
    dplyr::filter(type == "FIELD")

  usethis::ui_info(paste0("Available measures:\n\t", stringr::str_c(paste0(seq(length(measure_options$label)), ": ", measure_options$label), collapse = "\n\t")))

  measure <- readline("Please choose a measure: ")
  measure <- as.integer(measure)
  assertthat::is.number(measure)
  assertthat::assert_that(measure %in% seq(nrow(measure_options)))

  measure_id <- measure_options$id[measure]
  usethis::ui_done(paste0("[Measure id: ", measure_id, "]"))

  while (usethis::ui_nope("Happy to proceed? ", n_no = 1, shuffle = FALSE)) {
    measure <- readline("Please choose a measure: ")
    measure <- as.integer(measure)
    assertthat::is.count(measure)
    assertthat::assert_that(measure %in% seq(nrow(measure_options)))

    measure_id <- measure_options$id[measure]
    usethis::ui_done(paste0("[Measure id: ", measure_id, "]"))
  }

  periods_tail <- readline("Go back how many months/quarters (as applicable)? ")

  periods_tail <- as.integer(periods_tail)
  assertthat::is.count(periods_tail)

  if (periods_tail > 1) {
    periods_head <- readline(stringr::str_glue("All {periods_tail} months/quarters [Enter], or just oldest _n_ months/quarters [enter number]?: "))

    if (periods_head == "") periods_head <- periods_tail
    periods_head <- as.integer(periods_head)
    assertthat::is.count(periods_head)
  } else {
    periods_head <- periods_tail
  }

  periods <- sx_get_periods(measure_id, tail = periods_tail, head = periods_head)
  if (length(periods) > 1) {
    usethis::ui_done(paste("First period code:", head(periods, 1)))
  }
  usethis::ui_done(paste("Latest period code:", tail(periods, 1)))




  usethis::ui_info("Printing out geo type options...")

  geo_type_options <- count_measures %>%
    dplyr::filter(type == "GROUP")

  usethis::ui_info(paste0("Available measures:\n\t", stringr::str_c(paste0(seq(length(geo_type_options$label)), ": ", geo_type_options$label), collapse = "\n\t")))

  geo_type_index <- readline("Please choose a geography measure type: ")
  geo_type_index <- as.integer(geo_type_index)
  assertthat::is.count(geo_type_index)
  assertthat::assert_that(geo_type_index %in% seq(nrow(geo_type_options)))

  geo_type_id <- geo_type_options$id[geo_type_index]
  usethis::ui_info(paste0("[Geography type id: ", geo_type_id, "]"))

  while (usethis::ui_nope("Proceed? ", n_no = 1, shuffle = FALSE)) {
    geo_type_index <- readline("Please choose a geography measure type: ")
    geo_type_index <- as.integer(geo_type_index)
    assertthat::is.count(geo_type_index)
    assertthat::assert_that(geo_type_index %in% seq(nrow(geo_type_options)))

    geo_type_id <- geo_type_options$id[geo_type_index]
    usethis::ui_info(paste0("[Geography type id: ", geo_type_id, "]"))
  }



  geo_level_options <- dwpstat::dwp_schema(geo_type_id)

  usethis::ui_info(paste0("Available measures:\n\t", stringr::str_c(paste0(seq(length(geo_level_options$label)), ": ", geo_level_options$label), collapse = "\n\t")))

  geo_level_index <- readline("Please choose a geography dataset: ")
  geo_level_index <- as.integer(geo_level_index)
  assertthat::is.count(geo_level_index)
  assertthat::assert_that(geo_level_index %in% seq(nrow(geo_level_options)))

  geo_level_id <- geo_level_options$id[geo_level_index]

  usethis::ui_done(paste0("[Geography level id: ", geo_level_id, "]"))




  geo_area_options <- dwpstat::dwp_schema(geo_level_id)

  usethis::ui_info(paste0("Available measures:\n\t", stringr::str_c(paste0(seq(length(geo_area_options$label)), ": ", geo_area_options$label), collapse = "\n\t")))

  geo_area_index <- readline("Please choose a geography area type: ")
  geo_area_index <- as.integer(geo_area_index)
  assertthat::is.count(geo_area_index)
  assertthat::assert_that(geo_area_index %in% seq(nrow(geo_area_options)))

  geo_area_id <- geo_area_options$id[geo_area_index]

  usethis::ui_done(paste0("[Geography area id: ", geo_area_id, "]"))


}

get_dwp_codes <- function(
  ben,
  geo_level = NULL,
  chatty = TRUE,
  periods_tail = 1,
  periods_head = NULL,
  ds = NULL,
  measure = NULL,
  geo_dataset_id = NULL,
  geo_type = NULL) {

  # store a list of all datasets available from the StatX API
  bens_list <- dwpstat::dwp_schema() %>%
    dplyr::pull(label)

  # try to match ben to a full dataset name
  ben <- stringr::str_subset(bens_list, ben)

  assertthat::assert_that(length(ben) == 1 && is.character(ben), msg = "A single dataset name was not matched.")

  if (chatty) {
    usethis::ui_info(paste0("Dataset is: ", ben))
  }

  # get folder id code
  folder <- dwpstat::dwp_schema() %>%
    dplyr::filter(label == ben) %>%
    dplyr::pull(id)

  # I could combine these info reports into fewer blocks, but when kept separate
  # they can help with debugging - help you to work out where a process fails
  if (chatty) {
    usethis::ui_info(paste0("Folder name is: ", folder))
  }

  # just a bit of fun that feeds into a chatty info line below
  default <- "default "
  if (!is.null(ds)) { default <- "" }

  # exception hacks
  # add more to these lists as we discover them
  universal_type <- c("Universal Credit")
  disability_type <- c("Personal Independence Payment")
  housing_type <- c("Housing Benefit")
  pension_type <- c("Pension Credit",
                    "Employment and Support Allowance",
                    "Carers Allowance",
                    "Disability Living Allowance")


  if (is.null(ds)) {
    if (ben %in% universal_type) {
      ds <- 2
      geo_dataset_id <- 5
      measure <- 4
    } else if (ben %in% disability_type) {
      ds <- 3
    } else {
      ds <- 1
    }
  }

  if (is.null(measure)) {
    if (ben %in% universal_type) {
      measure <- 2
    } else if (ben %in% housing_type) {
      measure <- 4
    } else {
      measure <- 3
    }
  }

  if (is.null(geo_dataset_id)) {
    if (ben %in% housing_type) {
      geo_dataset_id <- 6
    } else {
      geo_dataset_id <- 4
    }
  }

  if (is.null(geo_type)) {
    geo_type <- 1
  }

  # this should usually be provided by xstatic.R but here is a fallback
  # (2 = LSOA level)
  if (is.null(geo_level)) {
    geo_level <- 2
  }


  # get chatty - show other options as well as the default
  if (chatty) {
    db_options <- sx_pull_col("label", folder)
    usethis::ui_info(paste0("All options:\n\t", stringr::str_c(paste0(1:length(db_options), ": ", db_options), collapse = "\n\t")))
    usethis::ui_info(paste0("Choosing ", default, "option (ds parameter): ", ds))
    usethis::ui_info(paste0("Data subset name is: ", db_options[ds]))
  }

  db_id <- sx_pull_id(ds, folder)
  # report the options that are being used - for reference
  if (chatty) {
    usethis::ui_info(paste0("Data subset id is: ", db_id))
    usethis::ui_info(paste0("Available measures:\n\t", stringr::str_c(sx_pull_col("label", db_id), collapse = "\n\t")))
  }

  # what numbers are going to be retrieved
  count_id <- dwpstat::dwp_schema(db_id) %>%
    dplyr::filter(type == "COUNT") %>%
    dplyr::pull(id)
  if (chatty) {
    usethis::ui_info(paste("Count id is:", count_id))
  }

  # specific measure
  measure_id <- sx_pull_id(measure, db_id)
  if (chatty) {
    usethis::ui_info(paste("Measure id is:", measure_id))
  }
  periods <- sx_get_periods(measure_id, tail = periods_tail, head = periods_head)
  if (chatty) {
    usethis::ui_info(paste("Latest period code:", tail(periods, 1)))
  }

  # geography info: check these look right for your query
  geo_dataset <- sx_pull_id(geo_dataset_id, db_id)
  if (chatty) {
    usethis::ui_info(paste("Geography area type is:", geo_dataset))
  }

  geo_area_type <- sx_pull_id(geo_type, geo_dataset)
  if (chatty) {
    usethis::ui_info(paste("Geography field id is:", geo_area_type))
  }

  geo_level_id <- sx_pull_id(geo_level, geo_area_type)
  if (chatty) {
    usethis::ui_info(paste("Geography level id is:", geo_level_id))
  }

  # return list of codes (used as `build_list` for construction of JSON API query)
  list(db_id = db_id, count_id = count_id, measure_id = measure_id, periods = periods, geo_area_type = geo_area_type, geo_level_id = geo_level_id)

}


# helper functions used in the above --------------------------------------

# these are all effectively wrappers around Evan Odell's `dwp_schema`
# I have tried to make these as efficient as I can and remove duplication

# sx_pull_id and sx_pull_col are little manoeuvres for digging down through the schema;
# they are used within the other functions (they do not return useful info per se)

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
  # periods_tail so it has no effect (keeps all periods specified by p._tail)
  if (is.null(head) || head > tail) { head <- tail }

  dwpstat::dwp_schema(id) %>%
    dplyr::filter(type == type) %>%
    dplyr::pull(id) %>%
    sx_pull_col(col = "id") %>%
    tail(tail) %>%
    head(head)
}

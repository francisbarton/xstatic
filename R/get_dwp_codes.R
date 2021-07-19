get_dwp_codes <- function(
  ben,
  ds = NULL,
  period = 2,
  periods_tail = 1,
  periods_head = NULL,
  geo_dataset_id = 4,
  geo_type = 1,
  geo_level = 2,
  chatty = TRUE) {

  # store a list of all datasets available from the StatX API
  bens_list <- dwpstat::dwp_schema() %>%
    pull(label)

  # try to match ben to a full dataset name
  ben <- stringr::str_subset(bens_list, ben)

  assert_that(length(ben) == 1 && is.character(ben), msg = "A single dataset name was not matched.")

  if (chatty) {
    ui_info(paste0("Dataset is: ", ben))
  }

  # get folder id code
  folder <- dwpstat::dwp_schema() %>%
    filter(label == ben) %>%
    pull(id)

  # I could combine these info reports into fewer blocks, but when kept separate
  # they can help with debugging - help you to work out where a process fails
  if (chatty) {
    ui_info(paste0("Folder name is: ", folder))
  }

  # just a bit of fun that feeds into a chatty info line below
  default <- "default "
  if (!is.null(ds)) { default <- "" }

  # exception hacks
  # add more to these lists as we discover them
  universal_type <- c("Universal Credit")
  housing_type <- c("Housing Benefit")
  pension_type <- c("Pension Credit",
                    "Employment and Support Allowance",
                    "Carers Allowance",
                    "Disability Living Allowance")
  disability_type <- c("Personal Independence Payment")


  if (is.null(ds) && ben %in% c(universal_type, disability_type)) {
    ds <- 3
  }
  else if (is.null(ds)) {
    ds <- 1
  }

  # Households on UC as opposed to "people on"
  if (ds == 2 && ben %in% universal_type) {
    period <- 3
  }

  if (ben %in% housing_type) {
    period <- 4
    geo_dataset_id <- 6
  }

  if (ben %in% pension_type) {
    period <- 3
  }

  if (ben %in% pension_type && ds == 3) {
    period <- 2
    geo_type <- 3
  }

  if (ben %in% disability_type) {
    period <- 3
    geo_dataset_id <- 4
    geo_type <- 1
  }




  # get chatty - show other options as well as the default
  if (chatty) {
    db_options <- sx_pull_col("label", folder)
    ui_info(paste0("All options:\n\t", str_c(paste0(1:length(db_options), ": ", db_options), collapse = "\n\t")))
    ui_info(paste0("Choosing ", default, "option (ds parameter): ", ds))
    ui_info(paste0("Data subset name is: ", db_options[ds]))
  }

  db_id <- sx_pull_id(ds, folder)
  # report the options that are being used - for reference
  if (chatty) {
    ui_info(paste0("Data subset id is: ", db_id))
    ui_info(paste0("Available measures:\n\t", str_c(sx_pull_col("label", db_id), collapse = "\n\t")))
  }

  # what numbers are going to be retrieved
  count_id <- dwpstat::dwp_schema(db_id) %>%
    filter(type == "COUNT") %>%
    pull(id)
  if (chatty) {
    ui_info(paste("Count id is:", count_id))
  }

  # period info: month or quarter and how many
  period_id <- sx_pull_id(period, db_id)
  if (chatty) {
    ui_info(paste("Period id is:", period_id))
  }
  periods <- sx_get_periods(period_id, tail = periods_tail, head = periods_head)
  if (chatty) {
    ui_info(paste("Latest period code:", tail(periods, 1)))
  }

  # geography info: check these look right for your query
  geo_dataset <- sx_pull_id(geo_dataset_id, db_id)
  if (chatty) {
    ui_info(paste("Geography area type is:", geo_dataset))
  }

  geo_area_type <- sx_pull_id(geo_type, geo_dataset)
  if (chatty) {
    ui_info(paste("Geography field id is:", geo_area_type))
  }

  geo_level_id <- sx_pull_id(geo_level, geo_area_type)

  if (chatty) {
    ui_info(paste("Geography level id is:", geo_level_id))
  }

  if (chatty) {
  # clear these out of env as no longer needed
  rm(ben, db_options, folder, geo_area_type,
     universal_type, housing_type, pension_type)
  }

  # return list of codes (used as `build_list` for construction of JSON API query)
  list(db_id = db_id, count_id = count_id, period_id = period_id, periods = periods, geo_dataset = geo_dataset, geo_level_id = geo_level_id)

}


# helper functions used in the above --------------------------------------

# these are all effectively wrappers around Evan Odell's `dwp_schema`
# I have tried to make these as efficient as I can and remove duplication

# sx_pull_id and sx_pull_col are little manoeuvres for digging down through the schema;
# they are used within the other functions (they do not return useful info per se)

sx_pull_id <- function(slice, ...) {
  dwpstat::dwp_schema(...) %>%
    slice(slice) %>%
    pull(id)
}
sx_pull_col <- function(col, ...) {
  dwpstat::dwp_schema(...) %>%
    pull(col)
}

sx_get_periods <- function(id, type = "VALUESET", ms = 1, tail = 1, head = NULL) {

  # if periods_head not specified, or larger than tail, then set it to same as
  # periods_tail so it has no effect
  if (is.null(head) | head > tail) { head <- tail }

  dwpstat::dwp_schema(id) %>%
    filter(type == type) %>%
    pull(id) %>%
    sx_pull_col(col = "id") %>%
    tail(tail) %>%
    head(head)
}

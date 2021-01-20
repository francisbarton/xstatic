get_dwp_codes <- function(
  ben = "",
  ds = "",
  period = 2,
  periods_tail = 1,
  periods_head = "",
  geo_type = 4,
  geo_field = 1,
  geo_level = 3,
  chatty = TRUE) {

  # store a list of all datasets available from the StatX API
  bens_list <- dwpstat::dwp_schema() %>%
    pull(label)

  # try to match ben to a full dataset name

  if (stringr::str_detect(ben, "^([:alpha:]|[:blank:])+$")) {
    ben <- stringr::str_to_title(ben)
  }
  ben <- stringr::str_subset(bens_list, ben)

  assert_that(length(ben) == 1 & is.character(ben), msg = "A single dataset name was not matched.")

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
  if (!ds == "") { default <- "" }

  # exception hacks
  # add more to these lists as we discover them
  universal_type <- c("Universal Credit")
  housing_type <- c("Housing Benefit")
  pension_type <- c("Pension Credit",
                    "Employment and Support Allowance",
                    "Carers Allowance",
                    "Disability Living Allowance")
  disability_type <- c("Personal Independence Payment")

  if (ds == "" && ben %in% c(universal_type, disability_type)) {
    ds <- 3
  }
  else if (ds == "") {
    ds <- 1
  }

  # Households on UC as opposed to "people on"
  if (ds == 2 && ben %in% universal_type) {
    period <- 3
    # geo_type <- 4
  }

  if (ben %in% housing_type) {
    period <- 4
    geo_type <- 6
  }

  if (ben %in% pension_type) {
    period <- 3
    # geo_type <- 4
  }

  if (ben %in% pension_type && ds == 3) {
    period <- 2
    geo_type <- 3
  }

  if (ben %in% disability_type) {
    period <- 4
    geo_type <- 5
  }




  # get chatty - show other options as well as the default
  if (chatty) {
    db_options <- sx_pull_col("label", folder)
    ui_info(paste0("Choosing ", default, "option: ds=", ds))
    ui_info(paste0("All options:\n\t", str_c(paste0(1:length(db_options), ": ", db_options), collapse = "\n\t")))
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
  geo_type_id <- sx_pull_id(geo_type, db_id)
  if (chatty) {
    ui_info(paste("Geography type id is:", geo_type_id))
  }
  geo_field_id <- sx_pull_id(geo_field, geo_type_id)
  if (chatty) {
    ui_info(paste("Geography field id is:", geo_field_id))
  }

  geo_level_id <- sx_pull_id(geo_level, geo_field_id)

  if (chatty) {
    ui_info(paste("Geography level id is:", geo_level_id))

    geo_level_label <- dwpstat::dwp_schema(geo_field_id) %>%
      slice(geo_level) %>%
      pull(label)
    ui_info(paste("Geography level is:", geo_level_label))
  }

  if (chatty) {
  # clear these out of env as no longer needed
  rm(ben, db_options, folder, geo_type_id, geo_level_label,
     universal_type, housing_type, pension_type)
  }

  # return list of codes (used as `build_list` for construction of JSON API query)
  list(db_id = db_id, count_id = count_id, period_id = period_id, periods = periods, geo_field_id = geo_field_id, geo_level_id = geo_level_id)

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

sx_get_periods <- function(id, type = "VALUESET", ms = 1, tail = 1, head = "") {

  # if periods_head not specified then set it to same as periods_tail
  # so it has no effect
  if (head == "") { head <- tail }

  dwpstat::dwp_schema(id) %>%
    filter(type == type) %>%
    pull(id) %>%
    sx_pull_col(col = "id") %>%
    tail(tail) %>%
    head(head)
}


# adapted from dwpstat package by Evan Odell

dwp_get_data_util <- function(query) {

  table_endpoint <- "https://stat-xplore.dwp.gov.uk/webapi/rest/v1/table"

  api_get <- httr::POST(
    url = table_endpoint,
    body = query,
    config = httr::add_headers(APIKey = getOption("DWP.API.key")),
    encode = "json"
  )

  if (httr::http_error(api_get)) {
    stop(
      paste0(
        "Stat-Xplore API request failed with status ",
        httr::status_code(api_get),
        if (httr::status_code(api_get) == 422) {
          ". Please check your parameters."
        } else if (httr::status_code(api_get) == 403) {
          ". Please check your API key."
        }
      ),
      call. = FALSE
    )
  }

  httr::content(api_get, as = "text") %>%
    jsonlite::fromJSON(flatten = TRUE)
}


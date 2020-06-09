
# from dwpstat package by Evan Odell

# library(httr)
# library(jsonlite)

table_endpoint <- "https://stat-xplore.dwp.gov.uk/webapi/rest/v1/table"

sx_get_data_util <- function(query, body_query) {
  api_get <- httr::POST(
    url = query,
    body = body_query,
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

  fromJSON(httr::content(api_get, as = "text"), flatten = TRUE)
}


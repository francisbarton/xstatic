# from olihawkins/statxplorer

# library(httr)
# library(jsonlite)
# library(statxplorer)
# library(stringr)

request_table <- function(query) {

  # Get api key from cache
  api_key <- get_api_key()

  # Set headers
  headers <- httr::add_headers(
    "APIKey" = api_key,
    "Content-Type" = "application/json")

  # POST and return
  tryCatch({
    response <- httr::POST(
      URL_TABLE,
      headers,
      body = query,
      encode = "form",
      timeout = 60)},
    error = function(c) {
      stop("Could not connect to Stat-Xplore: the server may be down")
    })

  # Extract the text
  response_text <- httr::content(response, as = "text", encoding = "utf-8")

  # If the server returned an error raise it with the response text
  if (response$status_code != 200) {
    stop(str_glue(
      "The server responded with the error message: {response_text}"))
  }

  # Process the JSON, and return
  fromJSON(response_text, simplifyVector = FALSE)
}

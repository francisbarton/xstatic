# libraries ---------------------------------------------------------------

# example

library(here)

source(here("R/data_slurp.R"))

something <- data_slurp(

  # don't provide own list of area codes -> use built-in lookup (this is the default)
  areas_list = "",

   # should find "Carers Allowance" (regexp is fine)
  dataset_name = "^Carers",

  # "filter at level:" - `upper` works as an alias for to `utlacd`
  location_level = "upper",

  # "filter by name (optional) - if not provided then should return all at `location_level`
  filter_location = "^Gloucestershire",

  # "return data at level:" - `msoa` works as an alias for `msoa11cd`
  data_level = "msoa",

  # not used directly by `data_slurp`;
  # it's passed via `...` to a sub-function.
  # Return this many of the most recent issues of the data.
  # Defaults to 1 if not provided (ie just returns most recent data
  # (whether monthly or quarterly))
  periods_tail = 2,

  # if more than 1000 areas are requested then they will be batched
  # into queries of `batch_size`. Default is 1000.
  batch_size = 1000,

  # currently TRUE by default but you have the option to disable it
  # if for some reason the feature is stopping your query from working
  use_alias = TRUE,

  # currently TRUE by default for testing purposes.
  # Best to turn it off if embedding in another script or automated report
  # Maybe I should use something like `is_interactive()` instead.
  # Will probably switch the default to FALSE at some point.
  chatty = TRUE
)

glimpse(something)

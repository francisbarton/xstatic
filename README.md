
# xstatic

<!-- badges: start -->
<!-- badges: end -->

The goal of `xstatic` is to make the user happy.

The [Stat-Xplore](https://stat-xplore.dwp.gov.uk/) interface rarely makes people happy.
But things are going to change around here.

## Summary

I wanted to build a script that would enable me to easily retrieve benefit claims data at various geographic levels across England (and possibly Wales, Scotland and Northern Ireland also), without having to go the Stat-Xplore website and download a csv or a JSON query.

I'm usually only interested in getting data for certain benefits at geographic areas eg Census areas, not by Job Centre, and not using multiple filters or wafers or whatever.

So this gives me the ability to do that, within its limitations.

Tips of the my proverbial hat to
[Evan Odell](https://github.com/dr-uk/dwpstat),
[Oli Hawkins](https://github.com/olihawkins/statxplorer) and
[David Millson](https://github.com/davidmillson/stat-xplore-R)
for their prior work on this issue.
There may be others with similar work I haven't found yet.

This package relies at its core on Evan's `dwp_schema` and `sx_get_data_util` functions, and in many senses should be thought of as a wrapper for his work with additional bells and whistles.

The package also contains an optional usage of one of DR Kane's [Great Britain geographic lookup tables](https://github.com/drkane/geo-lookups/) - very useful to have all that in one file!
But you can in theory feed your own alternative lookup to the script, either as a URL that sends a CSV or JSON return or as a local file (actually I still need to check that those bits work ok).

Earlier attempts at this were used as part of digital inclusion projects working for my employer [Citizens Online](https://www.citizensonline.org.uk).

I'm not sure how useful it is to anyone else but as always it has been a good learning experience and adventure in using `R` to do this kind of thing.

## Installation

When I have made this into a valid package, this should work:

``` r
remotes::install_github("francisbarton/xstatic")

```

## Limitations

There are many.

Please let me know ideas for things I have missed,
things I could have done more efficiently, or
things you would like to see.

The script involves building a JSON query programatically which is super-fragile, it seems, and probably doomed to failure.

Please give it a try but be gentle, it is a fragile beast.
Let me know what breaks.

Pull requests are welcomed and of course it's all MIT-licensed open code so fork away.

* Currently the script is set up to get totals for a variety of geographic areas.
Not to get data segmented by age, gender, claimant status etc, because that is beyond what I need currently.
And it was complicated enough.
* There's a load of hacks in there to accommodate places where the schema uses different table structures for different benefits
* I was too lazy to include Travel to Work zones as an area filter in my area codes script but I don't think Stat-Xplore provides data at those levels anyway?

## Example

Just one example here so far.
This gets Carers Allowance cases by MSOA level in the county (upper tier local authority) of Gloucestershire.

``` r
# when valid package
# library(xstatic)

# for now:
library(here)

source(here("R/data_slurp.R"))

# here goes
something <- data_slurp(
  
  # don't provide own list of area codes -> use built-in lookup (this is the default)
  areas_list = "", 
  
   # should find "Carers Allowance" (regexp is fine)
  dataset_name = "^Carers",
  
  # "filter at level:" - `upper` works as an alias for to `utlacd`
  location_level = "upper", 
  
  # "filter by name (optional) - if not provided then should return all at `location_level` 
  filter_location = "Gloucestershire", 
  
  # "return data at level:" - `msoa` works as an alias for `msoa11cd`
  data_level = "msoa",
  
  # not used directly by `data_slurp`;
  # it's passed via `...` to a sub-function.
  # Return this many of the most recent issues of the data.
  # Defaults to 1 if not provided (ie just returns most recent data
  # (whether monthly or quarterly))
  # you can combine this with `periods_head` as well if you should need to
  # for example get just the data from the third-latest issue
  # but not the last two (yes I do this sometimes)
  periods_tail = 2,
  
  # if more than 1000 areas are requested then they will be batched
  # into queries of `batch_size` so as not to overwhelm the API.
  # Default is 1000
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

```

## Future plans

* write up documentation for functions
* include `testthat` and more `assertthat` lines in the code. Still learning.
* increase coverage of the exception hacks in `get_dwp_codes.R`
* make it into a proper package


### List of area aliases

From `obtain_codes.R`.

Using any of the aliases in the first list below will be translated to the return string from the second list.
This works for `location_level` and `data_level` in the `data_slurp` script.

Purely added in for informality/user-friendliness.

*NB this is really designed to work with DR Kane's lookup table or anything else that uses the same codes as variable names/colnames. If you're using a different lookup table these may well break.*

```{r}
geo_levels <- tibble(
  aliases = c(
    "country",
    "region",
    "upper",
    "local|lad",
    "middle|msoa",
    "lower|lsoa"),
  returns = c(
    "ctry",
    "rgn",
    "utla",
    "lad20",
    "msoa11",
    "lsoa11"),
  geo_level = c(7:2)
)

if(use_aliases) {
    return_level <- paste0(process_aliases(return_level), "cd")
  }
  
if(use_aliases) {
    filter_level <- paste0(process_aliases(filter_level), "nm")
  }
  
```

### Contact me

You can email francis.barton@citizensonline.org.uk or ping me on twitter @ludictech

Please [use](https://trinkerrstuff.wordpress.com/2013/08/31/github-package-ideas-i-stole/) issues on this repo to make suggestions or report problems or bugs.

### Licence

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](http://badges.mit-license.org)
In the UK we spell it (the noun) 'licence' but anyway this has an MIT *License*.
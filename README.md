
# xstatic

<!-- badges: start -->
[![Travis build status](https://travis-ci.org/francisbarton/xstatic.svg?branch=master)](https://travis-ci.org/francisbarton/xstatic)
<!-- badges: end -->

The goal of `xstatic` is to make the user happy.

The [Stat-Xplore](https://stat-xplore.dwp.gov.uk/) interface rarely makes people happy.
But things are going to change around here.

## Summary

I wanted to build a script that would enable me to easily retrieve benefit claims data at various geographic levels across England (and possibly Wales, Scotland and Northern Ireland also), without having to go the Stat-Xplore website and download a csv or a JSON query.

And to allow easy updating, including programmatically or automatically, from within R.

I'm usually only interested in getting data for certain benefits at geographic areas eg Census areas, not by Job Centre, and not using multiple filters or wafers or whatever.

So this gives me the ability to do that, within its limitations.

Tips of my proverbial hat to

* [Evan Odell](https://github.com/dr-uk/dwpstat),
* [Oli Hawkins](https://github.com/olihawkins/statxplorer) and
* [David Millson](https://github.com/davidmillson/stat-xplore-R)

for their prior work on this issue.
There may be others with similar work I'm not yet aware of.

This package relies at its core on Evan's `dwp_schema` and `sx_get_data_util` functions, and in a sense should be thought of as a wrapper for his work with additional bells and whistles.

The package also provides, and by default uses, one of DR Kane's [Great Britain geographic lookup tables](https://github.com/drkane/geo-lookups/) - very useful to have all that in one file!
The data included in that file is sourced from the [ONS Geoportal](http://geoportal.statistics.gov.uk/) and contains public sector information licensed under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

You can instead feed your own alternative lookup file to the script, either as a URL that sends a CSV or JSON return or as a local file.

Earlier attempts at this were built and used as part of digital inclusion projects working for my employer [Citizens Online](https://www.citizensonline.org.uk).

I'm not sure how useful it is to anyone else but as always it has been a good learning experience and adventure in using `R` to do this kind of thing.

## Installation

This should work:

``` r
remotes::install_github("francisbarton/xstatic")

```

## Limitations

There are many!

Please let me know ideas for things I have missed,
things I could have done more efficiently, or
things you would like to see.

The whole thing is built around `tidyverse` functions and things like `jsonlite::fromJSON` and `janitor::clean_names`.
I suppose ideally I should have built it more around base functions, but I like the tidyverse approach,
so that's what you get.
If I'm honest I live in the tidyverse and I don't really know how to make things work in base R any more.

The script involves building a JSON query programatically, which is a super-fragile process.

Please give it a try but be gentle, it is a delicate beast.
Let me know what breaks.

Pull requests are welcomed and of course it's all MIT-licensed open code so fork away.

* Currently the script is set up to get totals for a variety of geographic areas.
Not to get data segmented by age, gender, claimant status etc, because that is beyond what I need currently.
And it was already complicated enough...
* There's a load of hacks in there to accommodate places where the schema uses different table structures for different benefits (see "exception hacks" in `get_dwp_codes.R`)
* I was too lazy to include Travel to Work zones as an area filter in my area codes script but I don't think Stat-Xplore provides data at those levels anyway?

## Example

Just one example here so far.
This gets Universal Credit claims by LSOA level in the county (an upper tier local authority) of Herefordshire,
for the last two reporting periods (`periods_tail = 2`).

The example in the manual (`?xstatic`) is a much smaller one.

``` r
library(xstatic)

something <- xstatic_slurp(
  
  # should find "Universal Credit" (R-style regexes are accepted)
  # will throw an error if there's more than one match - should be fixable
  # by providing a more specific string (chatty mode will show you the options)
  # What you pass here will be used as the column name for your data output (but it still has to match!)
  dataset_name = "^Universal",

  # provide own list of area codes or leave as empty string to use the built-in lookup table
  # (this is the default)
  areas_list = "", 
  
  # "filter at level:" - `upper` works as an alias for to `utlacd`
  filter_level = "upper", 
  
  # "filter by name (optional) - if not provided then should return all (neutralises filter_level) 
  # in theory you can pass a string of piped strings (as OR booleans) to this
  # like "Devon|Cornwall" - this seems to work.
  # Obviously if you do this, both have to be the same type of area.
  # Take care with multiple matches eg "Brent" will match both "Brent" and "Brentwood",
  # (use "Brent$" instead), "Gloucestershire" will match "South Gloucestershire" etc
  filter_area = "Herefordshire",
  
  # "return data at level:" - `LSOA` works as an alias for `lsoa11cd`
  return_level = "LSOA",
  
  # not used directly by `xstatic_slurp`;
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
  use_aliases = TRUE,
  
  # currently TRUE by default for testing purposes.
  # Best to turn it off if embedding in another script or automated report
  # Maybe I should use something like `is_interactive()` instead.
  # Will probably switch the default to FALSE at some point.
  chatty = TRUE
)

glimpse::glimpse(something)

```

## Future plans

* [x] write up documentation for core function
* [x] make it into a valid R package
* [ ] write up documentation for other functions
* [ ] include `testthat` and more `assertthat` lines in the code. Still learning about these
* [ ] increase coverage of the exception hacks in `get_dwp_codes.R`


### List of area aliases

From `get_area_codes.R`.

Using any of the aliases in the first list below will be translated to the return string from the second list.
Matching is not case-sensitive.
Purely added in for informality/user-friendliness.

This works for `filter_level` and `return_level` in the `xstatic_slurp` script.

*NB this is designed to work with DR Kane's lookup table or anything else that uses the same area codes as variable names/colnames. If you're supplying a different lookup table these may well break.* You can turn this aliasing behaviour off by passing `use_aliases = FALSE`.

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

## Code of Conduct

Please note that the xstatic project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

### Contact me

You can email francis.barton@citizensonline.org.uk or ping me on twitter [@ludictech](https://twitter.com/ludictech)

Please [use](https://trinkerrstuff.wordpress.com/2013/08/31/github-package-ideas-i-stole/) issues on this repo to make suggestions or report problems or bugs.

### Licence

[![License](http://img.shields.io/:license-mit-blue.svg?style=flat-square)](http://badges.mit-license.org)

In the UK we spell it (the noun) 'licence', but anyway, this has an MIT *License*.

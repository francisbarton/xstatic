# xstatic 0.4.2

* Not sure what happened to 0.4.1
* Rejigged `get_dwp_codes` quite a bit. Some queries weren't working. Still needs better documentation.


# xstatic 0.4.0

* Tidies up the chatty bits of get_dwp_codes
* Restores the original name of the dwp_get_data_util function in dwp_get_data_util.R
* Adds more comments to code
* Fixes error in data-raw/get_lookup_data.R
* Adds extra hack to `get_dwp_codes.R` to cover change of ds:
  ```r
    if (ben %in% pension_type && ds == 3) {
    period = 2
    geo_type = 3
  }
  ```
  fixes issue #1 (!)

# xstatic 0.3.0

* changes the name of the primary function from `statx_slurp` to `xstatic_slurp`!
* (and changes the name of the relevant file)
* makes significant changes to the parameter names of the main function:
  * `location_level` becomes `filter_level`
  * `filter_location` becomes `filter_area`
  * `data_level` becomes `return_level`
  * `use_alias` becomes `use_aliases`
  * and other standardisations between parameter names in the primary function and auxiliary functions
* makes changes to the examples in the man page and in the README
* adds additional explanation and makes corrections in README.md

# xstatic 0.2.0

* many, many, many exhausting battles with the R package checks and documentation procedures
* SO MANY mysterious and nonsensical error messages that contradict what's right in front of your eyes
* ended up adding 'packagename::' to the beginning of most of my functions to get rid of warnings about packages not being found or properly available. I don't understand!
* fixed the above by doing lots of @importFrom statements instead
* but hopefully I have made this at last into a valid package... it's been a battle.
* added Travis CI integration as per http://r-pkgs.had.co.nz/check.html#travis
* added Code of Conduct statement
* I learned that you don't need to `source` other R scripts in a package, just put them in the `R` folder and R will source them all automatically. `source` commands tend to cause devtools::check() to fail.

# xstatic 0.1.0

* initial commit that works but maybe needs extending and maybe refactoring
* wrote up README.md with acknowledgements and a commented example

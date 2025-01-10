*! version 0.2.9


/***
Title
====== 

__label_acs_pums__ {hline 2} Label ACS microdata in memory.


Description
-----------

__label_acs_pums__ labels 
[American Community Survey public use microdata](https://www.census.gov/programs-surveys/acs/microdata.html)
in memory using information retrieved from the ACS PUMS data dictionaries.

Only 2013 and later ACS microdata are supported.

By default, the data dictionaries and intermediate labeling .do files are 
cached. Specify __use_cache__ to use the cached files rather than re-downloading
and re-generating them.

Variable and value labels generated by __label_acs_pums__ are not a substitute 
for the ACS microdata data dictionary. Labels may be truncated and some 
important information may be missing.


Syntax
------ 

__label_acs_pums__, {opt year(integer)} [_options_]


{synoptset 16}{...}
{synopthdr:options}
{synoptline}
  {synopt:{opt year(integer)}}Year of dataset in memory; 2013 or later.{p_end}
  {synopt:{opt sample(integer)}}Sample of dataset in memory; 1 for the 1-year sample (the default) or 5 for the 5-year sample.{p_end}
  {synopt:{opt use_cache}}Use data from the cache if it exists. An internet connection is required when __use_cache__ is not specified or cached data does not exist.{p_end}
{synoptline}

    
Website
-------

[centeronbudget.github.io/cbpp-stata-utils](https://centeronbudget.github.io/cbpp-stata-utils/)

***/


* capture program drop label_acs_pums

program define label_acs_pums

  syntax , year(integer) [sample(integer 1) use_cache]
  
  
  **# Checks ------------------------------------------------------------------
  
  if `year' < 2013 {
    display as error "{bf:year()} must be 2013 or later"
    exit 198
  }
  if !inlist(`sample', 1, 5) {
    display as error "{bf:sample()} must be 1 or 5"
    exit 198
  }
  if `year' == 2020 & `sample' == 1 {
    display as error "Standard 2020 1-year ACS microdata were not released"
    exit
  }
  
  
  **# Set up ------------------------------------------------------------------
  
  * Cache directory
  _cbppstatautils_cache  
  local cache_dir = "`s(cache_dir)'"
  
  * File names
  local data_dict "acs_pums_dict_`year'_`sample'yr.txt"
  local lbl_do "lbl_acs_pums_`year'_`sample'yr.do"
  
  * Need to download data dictionary?
  capture confirm file "`cache_dir'/`data_dict'"
  local download_dict = (_rc != 0) | ("`use_cache'" == "")
  
  * Need to create label .do file?
  capture confirm file "`cache_dir'/`lbl_do'"
  local create_do = (_rc != 0) | ("`use_cache'" == "")
  
  
  **# Download data dictionary from Census Bureau FTP -------------------------
  
  if `download_dict' {
    
    if `sample' == 1 {
      local yr = substr("`year'", 3, 4)
      local dict_url_file =   ///
        cond(`year' > 2016, "PUMS_Data_Dictionary_`year'", "PUMSDataDict`yr'")
    }
    if `sample' == 5 {
      local start_year = `year' - 4
      local dict_url_file "PUMS_Data_Dictionary_`start_year'-`year'"
    }

    quietly copy "https://www2.census.gov/programs-surveys/acs/tech_docs/pums/data_dict/`dict_url_file'.txt"  ///
      "`cache_dir'/`data_dict'", replace
  }

  
  **# Create label .do file ---------------------------------------------------
  
  if `create_do' {
    
    preserve

    quietly {
      
      infix str500 input 1-500  using "`cache_dir'/`data_dict'", clear
      
      generate str500 output = "", before(input)
      replace input = strtrim(stritrim(input))
      
      split input, generate(value) parse(".") // Split by value definition
      split input, generate(token) // Split by word
      
      
      **## Variable names -----------------------------------------------------

      * Detect variable name rows
      * After 2017, data type was added to the variable name line of the 
      * data dictionary text file
      local varname_row_wordcount = cond(`year' < 2017, 2, 3)   
      local varname_row_token = cond(`year' < 2017, "token3", "token4")
      generate is_varname =   ///
        input[_n-1] == ""  &  ///    
        wordcount(input) == `varname_row_wordcount' & ///
        `varname_row_token' == "",  ///
        after(input)
      generate varname = lower(token1) if is_varname, after(is_varname)

      
      **## Variable labels ----------------------------------------------------
      
      generate var_lbl = input[_n+1] if is_varname, after(varname)  
      replace output =  ///
        "capture label variable " + varname + " " + `"""' + var_lbl + `"""' ///
        if is_varname & var_lbl != ""
        
      
      **## Value labels -------------------------------------------------------
      
      replace varname = varname[_n-1] if varname == ""  // Fill down 
      generate is_value_lbl = regexm(token2, "^\."), before(value1)
      generate label =  ///
        substr(input, strpos(input, "." ) + 1, .)   ///
        if is_value_lbl, after(is_value_lbl)
      replace output =  ///
        "capture label define " + varname + "_lbl " + value1 + " " +  ///
        `"""' + label + `"""' + ", add" ///
        if is_value_lbl & !strmatch(input, "*..*") & !regexm(value1, "^b")
      egen var_has_value_lbls = max(regexm(output, "label define")), by(varname)         
      replace output =  ///
        "capture label values " + varname + " " + varname + "_lbl"  ///
        if var_has_value_lbls & is_varname[_n+1]    
      
      
      **## Variable notes -----------------------------------------------------
      
      generate is_note = ustrregexm(token1, "Note:", 1)
      replace is_note =   ///
        is_note[_n-1] if !is_note & varname == varname[_n-1] & input != ""
      replace is_note = 0 if missing(is_note)
      generate note_clean = ustrregexrf(input, "note: ", "", 1) if is_note
      replace output = "capture note " + varname + ": " + note_clean if is_note

      
      **## Cleanup ------------------------------------------------------------
      
      keep if output != "" | is_varname 
      duplicates drop if output != ""
      keep output is_varname varname
      
      * Add white space (while preserving order within a variable's lines)
      expand 2 if is_varname, generate(new_obs)
      replace output = "" if new_obs
      sort varname, stable
      
      * Add header
      insobs 3, before(1)
      replace output = "* Generated $S_DATE'" in 1
      keep output
      compress
      
    }
    
    quietly outfile using "`cache_dir'/`lbl_do'", noquote replace
    
    restore
  }
  
  
  **# Run label .do file ------------------------------------------------------
  
  quietly do "`cache_dir'/`lbl_do'"
  display as result "Data labeled with dictionary for `year' `sample'-year sample."
  
end



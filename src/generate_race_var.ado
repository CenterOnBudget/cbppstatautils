
/***
Title
====== 

__generate_race_var__ {hline 2} Generate categorical race-ethnicity variable for CPS or ACS microdata.


Description
-----------

__generate_race_var__ generates a categorial variable for race-ethnicity. It can be used with CPS or ACS microdata. Users may specify the desired number of levels: 2, 4, 5-7 for CPS and 2, 4, 5-8 for ACS.


Syntax
------ 

__generate_race_var__ _{help newvar}_, __categories(_integer_)__ __dataset(_string_)__ [_options_]


{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
	{synopt:{opt cat:egories(integer)}}number of values for the categorical variable to be generated.{p_end}
	{synopt:{opt data:set(string)}}CPS or ACS (case insensitive).{p_end}
	
{syntab:Optional}
    {synopt:{opt nolab:el}}{it:newvar} will not be labelled.{p_end}
    {synopt:{opt replace}}{it:newvar} will be replaced if it exists.{p_end}


Category Definitions / Labels
-----------------------------

{p2colset 4 22 22 2}
{p2col:{bf}categories({it:2}){sf}}1 	White Non-Hisp.
								  2 	Not White Non-Hisp.{p_end}

{p2col:{bf}categories({it:4}){sf}}1 	White Non-Hisp.		
								  2 	Black Non-Hisp.
								  3 	Hispanic (of any race)
								  4 	Another Race or Mult. Races Non-Hisp.{p_end}

{p2col:{bf}categories({it:5}){sf}}1 	White Non-Hisp.		
								  2 	Black Non-Hisp.
								  3 	Hispanic (of any race)
								  4		Asian Non-Hisp.
								  5 	Another Race or Mult. Races Non-Hisp.{p_end}

{p2col:{bf}categories({it:6}){sf}}1 	White Non-Hisp.		
								  2 	Black Non-Hisp.
								  3 	Hispanic (of any race)
								  4		Asian Non-Hisp.
								  5 	AIAN Non-Hisp.
								  6 	Another Race or Mult. Races Non-Hisp.{p_end}

{p2col:{bf}categories({it:7}){sf}}1 	White Non-Hisp.		
								  2 	Black Non-Hisp.
								  3 	Hispanic (of any race)
								  4		Asian Non-Hisp.
								  5 	AIAN Non-Hisp.
								  6 	NHOPI Non-Hisp.
								  7 	 __ACS:__ Another Race or Mult. Races Non-Hisp 
								  7		 __CPS:__ Mult. Races Non-Hisp.{p_end}

{p2col:{bf}categories({it:8}){sf}}1 	White Non-Hisp.{p_end}
{p2col:{it:ACS only}}2 	Black Non-Hisp.
								  3 	Hispanic (of any race)
								  4		Asian Non-Hisp.
								  5 	AIAN Non-Hisp.
								  6 	NHOPI Non-Hisp.
								  7 	Some Other Race Non-Hisp 
								  8		Mutliple Races{p_end}
{p2colreset}{...}
	
Example(s)
----------

   Generate a 5-category race-ethnicity variable named "race_5" for ACS microdata.
        {bf:. generate_race_var race_5, categories(5) dataset(acs)}

    Generate an unlabeled 2-category (person of color/white non-Hispanic) race-ethnicity variable for CPS microdata.
        {bf:. generate_race_var person_of_color, categories(2) dataset(cps) nolabel}

		
Website
-------

[github.com/CenterOnBudget/cbppstatautils](https://github.com/CenterOnBudget/cbppstatautils)


- - -

This help file was dynamically produced by 
[MarkDoc Literate Programming package](http://www.haghish.com/markdoc/) 
***/

* capture program drop generate_race_var

program generate_race_var

	syntax name(name = new_varname), CATegories(integer) DATAset(string) [NOLABel replace]
	
	* checks ------------------------------------------------------------------
	
	// check that new_varname does not already exist if no replace
	if "`replace'" == "" {
		capture confirm variable `new_varname' 
		if _rc == 0 {
			display as error "`new_varname' already defined. Choose another name or use 'replace' option." 
			exit
		}
	}
	
	// check that categories is correctly specified
	if !inlist(`categories', 2, 4, 5, 6, 7, 8) {
		display as error "categories(`categories') invalid. Must be one of 2, 4, 5, 6, 7, or 8."
		exit
	}
	
	if `categories' == 8 & "`dataset'" == "cps" {
		display as result "categories(`categories') A maximum of 7 categories are available when using the CPS. Using 7 categories."
	}
	
	// check that dataset is correctly specified
	local dataset = lower("`dataset'")
	if !(inlist("`dataset'", "acs", "cps")){
		display as error "dataset(`dataset') invalid. Must be acs or cps."
		exit
	}
	
	// check that needed variable exist
	local needed_vars = cond("`dataset'" == "acs", "rac1p hisp", "prdtrace pehspnon")
	foreach var in `needed_vars' {
		capture confirm variable `var'
		if _rc != 0 {
			display as error "Variable `var' needed but not found."
			exit
		}
	}
	
	// (optionally) drop new_varname if it already exists
	if "`replace'" != "" {
		capture drop `new_varname'
	}
	
	* acs ------------------------------------------------------------------

	quietly {
		if "`dataset'" == "acs" {
			generate `new_varname' = 1 if rac1p == 1
			if `categories' == 2 {
				replace `new_varname' = 2 if rac1p != 1 | hisp != 1
			}
			if `categories' >= 4 {
				replace `new_varname' = 2 if rac1p == 2
				replace `new_varname' = 4 if !inlist(rac1p, 1, 2)
			}
			if `categories' >= 5 {
				replace `new_varname' = . if `new_varname' == 4
				replace `new_varname' = 4 if rac1p == 6 
				replace `new_varname' = 5 if !inlist(rac1p, 1, 2, 6)
			}
			if `categories' >= 6 {
				replace `new_varname' = . if `new_varname' == 5
				replace `new_varname' = 5 if inrange(rac1p, 3, 5) 
				replace `new_varname' = 6 if !inrange(rac1p, 1, 6) 
			}
			if `categories' >= 7 {
				replace `new_varname' = . if `new_varname' == 6
				replace `new_varname' = 6 if rac1p == 7
				replace `new_varname' = 7 if !inrange(rac1p, 1, 7)
			}
			
			if `categories' == 8 {
				replace `new_varname' = . if `new_varname' == 7
				replace `new_varname' = (rac1p - 1) if inlist(rac1p, 8, 9)
			}
			if `categories' > 2 {
				replace `new_varname' = 3 if hisp != 1
			}
		}
	}
	
	* cps ------------------------------------------------------------------

	quietly {
		if "`dataset'" == "cps" {
			generate `new_varname' = 1 if prdtrace == 1
			if `categories' == 2 {
				replace `new_varname' == 2 if prdtrace != 1 | pehspnon == 1
			}
			if `categories' >= 4 {
				replace `new_varname' = 2 if prdtrace == 2
				replace `new_varname' = 4 if !inlist(prdtrace, 1, 2)
			}
			if `categories' >= 5 {
				replace `new_varname' = . if `new_varname' == 4
				replace `new_varname' = 4 if prdtrace == 4
				replace `new_varname' = 5 if !inlist(prdtrace, 1, 2, 4)
			}
			if `categories' >= 6 {
				replace `new_varname' = . if `new_varname' == 5
				replace `new_varname' = 5 if prdtrace == 3
				replace `new_varname' = 6 if !inrange(prdtrace, 1, 5)
			}
			if `categories' >= 7 {
				replace `new_varname' = . if `new_varname' == 6
				replace `new_varname' = 6 if prdtrace == 5
				replace `new_varname' = 7 if !inrange(prdtrace, 1, 5)
			}
			if `categories' > 2 {
				replace `new_varname' = 3 if pehspnon == 1
			}
		}
	}
	
	* create label ------------------------------------------------------------
	
	if "`nolabel'" == "" {
	
		capture label drop `new_varname'_lbl
		
		label define `new_varname'_lbl 	1 "White Non-Hisp."
		
		if `categories' == 2 {
			label define `new_varname'_lbl 2 "Not White Non-Hisp.", add
		}
		if `categories' >= 4 {
			label define `new_varname'_lbl 2 "Black Non-Hisp.", add
		}
		if `categories' >= 5 {
			label define `new_varname'_lbl 4 "Asian Non-Hisp.", add
		}
		if `categories' >= 6 {
			label define `new_varname'_lbl 5 "AIAN Non-Hisp.", add
		}
		if `categories' >= 7 {
			label define `new_varname'_lbl 6 "NHOPI Non-Hisp.", add
		}
		if `categories' == 8 & "`dataset'" == "acs" {
			label define `new_varname'_lbl 7 "Some Other Race Non-Hisp.", add
			label define `new_varname'_lbl 8 "Multiple Races Non-Hisp.", add
		}
		if inrange(`categories', 2, 7) {
			local acs_lbl_mod = cond("`dataset'" == "acs", "Another Race or ", "")
			label define `new_varname'_lbl `categories' "`acs_lbl_mod'Mult. Races Non-Hisp.", add
		}
		if `categories' > 2 {
			label define  `new_varname'_lbl 3 "Hispanic (of any race)", add
		}
		
		label values `new_varname' `new_varname'_lbl
	}
	
end

set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
1. quarterly_doses_by_manu.dta created in: make_quarterly_doses_by_manu.do
*/

capture log close
log using "$output\IHME\make_quarterly_vaccine_coverage_pfizer_v_other", text replace

////////////////////////////////////////////////////////////////////////////////
//////////////// aggregate total doses to Pfizer vs all others /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_doses_by_manu", clear 
drop if inlist(country, "China", "Macao")

keep country yyyy_qq year quarter total_doses *_total_doses
order country yyyy_qq year quarter total_doses pfizer_biontech_total_doses

egen other = rowtotal(astrazeneca_total_doses moderna_total_doses johnson_johnson_total_doses novavax_total_doses sputnik_v_total_doses coronavac_total_doses sinopharm_total_doses cansinobio_total_doses covaxin_total_doses other_total_doses)
ren pfizer_biontech_total_doses pfizer
keep country yyyy_qq year quarter total_doses pfizer other 
assert abs((pfizer + other) - total_doses)<.1  

////////////////////////////////////////////////////////////////////////////////
//////// create cumulative doses as the running sum of quarterly doses /////////
////////////////////////////////////////////////////////////////////////////////

sort country year quarter 

foreach var in total_doses pfizer other {
	by country : gen cum_`var' = sum(`var')
}

// make sure there are no missing values in the dataset 

des, varlist 
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	capture count if `var'==.
	if _rc==0 {
		assert r(N)==0
	}
	else if _rc>0 {
		count if `var'==""
		assert r(N)==0
	}
}
		
compress	
save "$output\IHME\quarterly_vaccine_coverage_pfizer_v_other", replace

log close 

exit 

// end

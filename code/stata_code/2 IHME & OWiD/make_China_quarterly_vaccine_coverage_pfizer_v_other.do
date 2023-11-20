set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
1. vax_Hong_Kong_China_Macoa.dta created in: make_China_dosage_adjustment_factor.do
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
3. quarterly_doses_by_manu.dta created in: make_quarterly_doses_by_manu.do
4. China_dosage_adjustment_factor_v2.dta created in: make_China_dosage_adjustment_factor.do
*/

capture log close
log using "$output\IHME\make_China_quarterly_vaccine_coverage_pfizer_v_other", text replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////////// compute population weights ////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\vax_Hong_Kong_China_Macoa", clear
drop if country=="China"
sort country year quarter
isid country year quarter

merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3
drop _m
compress

sort year quarter country 
by year quarter: egen all_pop=total(tot_pop)
gen wt = tot_pop/all_pop 

keep country year quarter yyyy_qq tot_pop wt
compress 
save "$output\IHME\Hong_Kong_China_Macoa_pop_wts", replace

////////////////////////////////////////////////////////////////////////////////
//////////////// aggregate total doses to Pfizer vs all others /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_doses_by_manu", clear 
keep if inlist(country, "Hong Kong","Macao")

keep country yyyy_qq year quarter total_doses *_total_doses
order country yyyy_qq year quarter total_doses pfizer_biontech_total_doses

egen other = rowtotal(astrazeneca_total_doses moderna_total_doses johnson_johnson_total_doses novavax_total_doses sputnik_v_total_doses coronavac_total_doses sinopharm_total_doses cansinobio_total_doses covaxin_total_doses other_total_doses)
ren pfizer_biontech_total_doses pfizer
keep country yyyy_qq year quarter total_doses pfizer other 
assert abs((pfizer + other) - total_doses)<.1 

////////////////////////////////////////////////////////////////////////////////
//// compute population-wtd average of per capita Hong Kong and Macao doses ////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter using "$output\IHME\Hong_Kong_China_Macoa_pop_wts"
drop if year==2022 & quarter>2
drop if year==2020 & quarter<4
assert _m==3
drop _m 
sort country year quarter 

// compute the per capital doses 

foreach var in total_doses pfizer other {
	replace `var' = `var'/tot_pop
}

// map on the adjustment factor

merge m:1 year quarter using "$output\IHME\China_dosage_adjustment_factor_v2"
drop if year==2020 & quarter<4
assert _m ==3 
drop _m
compress

sort year quarter country

// compute the weighted sum of doses 

foreach var in total_doses pfizer other {
	replace `var' = `var'*wt
}

collapse (sum) total_doses pfizer other , by(yyyy_qq year quarter adj_factor_v2)

foreach var in total_doses pfizer other {
	replace `var' = `var'*adj_factor_v2
}

gen country="China" 
order country 

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
save "$output\IHME\China_quarterly_vaccine_coverage_pfizer_v_other_v2", replace

log close 

exit

// end
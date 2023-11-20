set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
gdp_usd_ihme.xlsx
vax_coverage_by_manu_unique_countries_w_pop_gt_1M.dta created in: make_quarterly_doses_by_manu.do
*/

capture log close
log using "$output\ECONOMIC DATA\make_quarterly_gdp_usd", text replace

////////////////////////////////////////////////////////////////////////////////
/////// get quarterly GDP denominated in real LCUs used to contruct gdp gaps ///
////////////////////////////////////////////////////////////////////////////////

import excel using "$output\KNEE\gdp_usd_ihme.xlsx", ///
clear first case(lower) 
keep country date gdp_projected_usd

gen year = substr(date,1,4), before(date)
gen quarter = substr(date,-1,1), before(date)
gen qtr = substr(date,-2,2), before(date)
gen yyyy_qq = year + "_" + qtr
drop qtr date
destring year, replace 
destring quarter, replace
drop if year==2019
order country year quarter yyyy_qq
sort  country year quarter

drop if inlist(yyyy_qq,"2022_Q3","2022_Q4")

compress

qui tab country 
di "There are `r(r)' countries"

isid country yyyy_qq

// keep the IHME relevant countries

merge m:1 country using "$output\IHME\vax_coverage_by_manu_unique_countries_w_pop_gt_1M"

tab country if _m==2
assert inlist(country, "Cuba","North Korea","Palestine","Syria","Venezuela") if _m==2 

keep if _m==3 
drop _m 

qui tab country 
di "There are `r(r)' countries"

sort country yyyy_qq
isid country yyyy_qq
ren gdp_projected_usd gdp_usd_projected
compress 

save "$output\ECONOMIC DATA\quarterly_gdp_usd", replace 

log close
exit 

// end
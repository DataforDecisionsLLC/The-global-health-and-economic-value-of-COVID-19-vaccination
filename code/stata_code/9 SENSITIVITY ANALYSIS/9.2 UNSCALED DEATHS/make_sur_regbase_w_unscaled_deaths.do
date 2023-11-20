set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
quarterly_unscaled_deaths.dta created in: make_quarterly_unscaled_deaths.do 
quarterly_unscaled_deaths_China.dta created in: make_quarterly_unscaled_deaths_China.do 
national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
outputs:
sur_regbase_w_unscaled_deaths.dta 
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_sur_regbase_w_unscaled_deaths", text replace

use "$output\IHME\quarterly_unscaled_deaths", clear
drop if inlist(country, "Macao","China")
append using "$output\IHME\quarterly_unscaled_deaths_China"
sort country year quarter 
compress 

merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3 
drop _m 

assert tot_pop<. & tot_pop>1000000

foreach var in daily_deaths  {
	replace `var'=`var'/tot_pop
}

foreach var in daily_deaths  {
	sum `var', d
}

drop tot_pop 

sort country year quarter 

ren daily_deaths daily_deaths_unscaled
drop if year>2021 

merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf"
drop if _m==1 
assert year<2020 if _m==2 
assert daily_deaths==. if year<2020
drop _m 

qui tab country 
di "There are `r(r)' countries"

compress 
save "$root\REGRESSION RESULTS\SUR\sur_regbase_w_unscaled_deaths", replace

log close 

exit 

// end


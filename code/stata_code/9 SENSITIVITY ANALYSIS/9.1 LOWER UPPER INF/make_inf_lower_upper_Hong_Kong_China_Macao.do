set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
Historical-and-Projected-Covid-19-data.dta created in: make_historical_data_countries_w_pop_gt_1M.do
outputs:
infections_Hong_Kong_China_Macoa.dta
*/

capture log close
log using "$output\IHME\make_inf_lower_upper_Hong_Kong_China_Macao", text replace

////////////////////////////////////////////////////////////////////////////////
////////// get the Hong Kong and Macao infections, deaths and vax data /////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
drop version_name
isid country date

replace country = "Hong Kong" if country=="Hong Kong Special Administrative Region of China"
replace country = "Macao" if country=="Macao Special Administrative Region of China"
keep if inlist(country, "Hong Kong","Macao","China")
tab country 
assert r(r)==3
sort date country

keep country date inf_cuml_mean inf_cuml_lower inf_cuml_upper inf_mean inf_lower inf_upper

// drop records after Q2 of 2022 

gen year=year(date)
gen quarter=quarter(date)
drop if year==2023
drop if year==2022 & quarter>2 

sort date 
assert date==mdy(2,4,2020) if _n==1
assert date==mdy(6,30,2022) if _n==_N

compress
save "$output\IHME\infections_Hong_Kong_China_Macoa", replace

log close

exit 

// end
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
quarterly_gdp_usd.dta created in: make_quarterly_gdp_usd.do
annual_gdp_regbase.dta created in: make_annual_gdp_regbase.do
*/

capture log close
log using "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\annual_gdp_regs_overall", text replace

use "$output\ECONOMIC DATA\quarterly_gdp_usd", clear 
keep if year == 2020 & quarter == 4
keep country gdp_usd_projected
replace gdp_usd_projected = gdp_usd_projected*4
ren gdp_usd_projected gdp_usd_projected_2020

merge 1:1 country using "$output\IHME\annual_gdp_regbase"
assert _m!=2 

keep if _m==3 
drop _m 
sort country year quarter 

assert yyyy_qq == "2021_Q4"

reg d_gap g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4, robust

predict yhat_1, xb

foreach brand in pfizer other {
	replace cum_uptake_`brand'=0
}

predict yhat_2, xb

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2

gen vax_actual  = (yhat_1 + g2020)*gdp_usd_projected
gen novax_actual = (yhat_2 + g2020)*gdp_usd_projected
gen gdp_gain=vax_actual-novax_actual 

gen pand_gdp_2021 = gdp_gap*gdp_usd_projected

gen pand_gdp_2020 = g2020*gdp_usd_projected_2020

keep country gdp_usd_projected gdp_usd_projected_2020 gdp1 gdp2 gdpdiff0 pand_gdp_2021 pand_gdp_2020 gdp_gain vax_actual novax_actual 

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\overall_annual_gdp", replace

log close 

exit 

// end
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
sur_regbase_infections_lower_gdp_annual.dta 
sur_regbase_infections_upper_gdp_annual.dta
outputs:
lower_gdp_annual_overall.dta 
lower_gdp_annual_pfz.dta 
upper_gdp_annual_overall.dta 
upper_gdp_annual_pfz.dta 
*/

// lower overall

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_lower_gdp_annual", clear
assert yyyy_qq == "2021_Q4"

reg gdp_gap g2020 cum_uptake_other cum_uptake_pfizer cum_inf_lower

predict yhat_1, xb

foreach brand in pfizer other {
	replace cum_uptake_`brand'=0
}

predict yhat_2, xb

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2

keep country gdp_usd_projected gdp1 gdp2 gdpdiff0 

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_annual_overall", replace

// lower pfizer

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_lower_gdp_annual", clear
assert yyyy_qq == "2021_Q4"

reg gdp_gap g2020 cum_uptake_other cum_uptake_pfizer cum_inf_lower

predict yhat_1, xb

foreach brand in pfizer {
	replace cum_uptake_`brand'=0
}

predict yhat_2, xb

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2

keep country gdp_usd_projected gdp1 gdp2 gdpdiff0 

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_annual_pfz", replace

// upper overall

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_upper_gdp_annual", clear
assert yyyy_qq == "2021_Q4"

reg gdp_gap g2020 cum_uptake_other cum_uptake_pfizer cum_inf_upper

predict yhat_1, xb

foreach brand in pfizer other {
	replace cum_uptake_`brand'=0
}

predict yhat_2, xb

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2

keep country gdp_usd_projected gdp1 gdp2 gdpdiff0 

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\upper_gdp_annual_overall", replace

// upper pfizer

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_upper_gdp_annual", clear
assert yyyy_qq == "2021_Q4"

reg gdp_gap g2020 cum_uptake_other cum_uptake_pfizer cum_inf_upper

predict yhat_1, xb

foreach brand in pfizer {
	replace cum_uptake_`brand'=0
}

predict yhat_2, xb

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2

keep country gdp_usd_projected gdp1 gdp2 gdpdiff0 

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\upper_gdp_annual_pfz", replace

exit 

// end


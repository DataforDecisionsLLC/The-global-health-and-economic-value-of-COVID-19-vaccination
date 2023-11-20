set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
quarterly_regbase_infections_lower_upper.dta created in: make_quarterly_regbase_infections_lower_upper.do
annual_gdp_regbase.dta created in: make_annual_gdp_regbase.do
sur_regbase_infections_lower_gdp_annual.dta 
sur_regbase_infections_upper_gdp_annual.dta 
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_sur_regbase_infections_lower_upper_gdp_annual", text replace

////////////////////////////////////////////////////////////////////////////////
////////////////// get the pre-vax OSI for the no-vax scenario /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase_infections_lower_upper", clear
keep country year quarter yyyy_qq inf_mean inf_lower inf_upper tot_pop

foreach var in mean lower upper {
	replace inf_`var' = inf_`var'*tot_pop
}

sort country year quarter 

foreach var in mean lower upper {
	by  country: gen cum_inf_`var' = sum(inf_`var')
}

foreach var in mean lower upper {
	replace cum_inf_`var' = cum_inf_`var'/tot_pop
}

keep if yyyy_qq == "2020_Q4"

keep country cum_inf_mean cum_inf_lower cum_inf_upper
isid country

merge 1:1 country using  "$output\IHME\annual_gdp_regbase"
assert _m!=2 
keep if _m==3 
drop _m 
sort country 

assert cum_inf_mean==cn2020Q4

drop cn2020Q4

assert _N==66

save "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_annual", replace

use "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_annual", clear 
drop cum_inf_mean cum_inf_upper cum_uptake

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_lower_gdp_annual", replace

use "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_annual", clear 
drop cum_inf_mean cum_inf_lower cum_uptake

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_upper_gdp_annual", replace


log close 

exit 

// end

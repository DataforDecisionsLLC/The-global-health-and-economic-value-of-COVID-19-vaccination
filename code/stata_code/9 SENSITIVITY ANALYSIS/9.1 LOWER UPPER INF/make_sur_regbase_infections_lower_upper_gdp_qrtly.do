set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
quarterly_gdp_regbase.dta created in: make_quarterly_gdp_usd.do
quarterly_regbase_infections_lower_upper.dta created in: make_quarterly_regbase_infections_lower_upper.do
outputs:
sur_regbase_infections_lower_gdp_qrtly.dta 
sur_regbase_infections_upper_gdp_qrtly.dta 
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_sur_regbase_infections_lower_upper_gdp_qrtly", text replace

////////////////////////////////////////////////////////////////////////////////
////////////////// get the pre-vax OSI for the no-vax scenario /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\quarterly_gdp_regbase", clear
drop inf_mean cum_inf_mean L1_inf_mean L1_cum_inf_mean L2_inf_mean L2_cum_inf_mean

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_regbase_infections_lower_upper", ///
keepusing(country yyyy_qq year quarter inf_mean inf_lower inf_upper)

keep if _m==3 
drop _m 
qui tab country 
di "There are `r(r)' countries"
count if year>=2020 
assert `r(N)' == 408
order country time yyyy_qq daily_deaths gdp_gap inf_* 

////////////////////////////////////////////////////////////////////////////////
///////// create the cumualative per capita infections variables ///////////////
////////////////////////////////////////////////////////////////////////////////

foreach var in mean lower upper {
	gen nat_immun_`var' = inf_`var'*tot_pop
}

sort country year quarter 

foreach var in mean lower upper {
	by  country: gen cum_inf_`var' = sum(nat_immun_`var')
	replace cum_inf_`var' = cum_inf_`var'/tot_pop
	drop nat_immun_`var'
}

codebook mean_index uptake_pfizer uptake_other cum_uptake_pfizer cum_uptake_other 
codebook cum_inf_mean cum_inf_lower cum_inf_upper

foreach var in mean_index uptake_pfizer uptake_other cum_uptake_pfizer cum_uptake_other cum_inf_mean cum_inf_lower cum_inf_upper {
	assert `var'<.
}

codebook gdp_gap daily_deaths inf_mean if year>=2020

foreach var in gdp_gap daily_deaths inf_mean  {
	assert `var'<. if year>=2020
}

////////////////////////////////////////////////////////////////////////////////
///////////////////////// create the lagged variables //////////////////////////
////////////////////////////////////////////////////////////////////////////////

sort country year quarter

foreach var in inf_mean inf_lower inf_upper cum_inf_mean cum_inf_lower cum_inf_upper {
	by country: gen L1_`var' = `var'[_n-1]
}

foreach var in inf_mean inf_lower inf_upper cum_inf_mean cum_inf_lower cum_inf_upper {
	by country: gen L2_`var' = `var'[_n-2]
}

foreach var in mean lower upper {
	replace L1_inf_`var'=0 if L1_inf_`var'==. 
	replace L2_cum_inf_`var'=0 if L2_cum_inf_`var'==. 
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper  {
	assert `var'<. if year>=2020
}

foreach var in L1_inf_mean L2_cum_inf_mean L1_inf_lower L2_cum_inf_lower L1_inf_upper L2_cum_inf_upper {
	assert `var'<. if !inlist(yyyy_qq,"2018_Q4","2019_Q1")
}

order country time yyyy_qq gdp_gap daily_deaths inf_mean uptake* cum_* L1_* L2_* 

qui tab country 
di "There are `r(r)' countries"

save "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_qrtly", replace

use "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_qrtly", clear 
drop cum_inf_upper L1_inf_upper L1_cum_inf_upper L2_inf_upper L2_cum_inf_upper inf_upper ///
cum_inf_mean L1_inf_mean L1_cum_inf_mean L2_inf_mean L2_cum_inf_mean inf_mean

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_lower_gdp_qrtly", replace

use "$root\REGRESSION RESULTS\SUR\sur_regbase_infections_lower_upper_gdp_qrtly", clear 
drop cum_inf_lower L1_inf_lower L1_cum_inf_lower L2_inf_lower L2_cum_inf_lower inf_lower ///
cum_inf_mean L1_inf_mean L1_cum_inf_mean L2_inf_mean L2_cum_inf_mean inf_mean

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_upper_gdp_qrtly", replace

log close 

exit 

// end

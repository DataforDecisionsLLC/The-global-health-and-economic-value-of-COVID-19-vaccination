set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
S_inf.dta created in: make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do 
country_group_lookup_deaths_inf.dta created in: make_country_time_lookups_deaths_inf.do 
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_infections_betas_sims1000", text replace

////////////////////////////////////////////////////////////////////////////////
////////////// get the betas from the infection regression /////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\S_inf", clear

xpose, clear
forvalues s=1/1000 {
	assert v`s'[1]==`s'
}

drop in 1
assert _N==159
gen var=_n, before(v1)

tostring var, replace

replace var = "L1_uptake_pfizer" if var=="1"
replace var = "L2_cum_uptake_pfizer" if var=="2"
replace var = "L1_uptake_other" if var=="3"
replace var = "L2_cum_uptake_other" if var=="4"
replace var = "L1_inf_mean" if var=="5"
replace var = "L2_cum_inf_mean" if var=="6"
replace var = "L1_mean_index" if var=="7"

replace var = "time_07" if var=="8"
replace var = "time_08" if var=="9"
replace var = "time_09" if var=="10"
replace var = "time_10" if var=="11"
replace var = "time_11" if var=="12"
replace var = "time_12" if var=="13"
replace var = "time_13" if var=="14"
replace var = "Constant" if var=="159"

forvalues v = 15/158 {
	replace var = "country" + "_" + "`=`v'-13'" if var=="`v'"
}

forvalues s=1/1000 {
	ren v`s' beta_`s'
}

ren var variable

compress 
save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_results_sims1000", replace

use  "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_results_sims1000", clear
merge 1:1 variable using "$root\REGRESSION RESULTS\SUR\country_group_lookup_deaths_inf"
assert variable == "country_1" if _m==2 
drop if _m==2
assert _m ==3 if regexm(variable,"^country") 
list _m variable if _m==1, sep(0)

drop _m 
compress 
order country

save  "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_betas_sims1000", replace

log close 

exit 

// end


set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
country_group_lookup_deaths_inf.dta created in: make_country_time_lookups_deaths_inf.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_infections_betas_deaths_inf", text replace

////////////////////////////////////////////////////////////////////////////////
////////////// get the betas from the infection regression /////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
replace L1_mean_index=L1_mean_index/100

reg inf_mean ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_145

matrix b = get(_b)

clear 
svmat b
gen reg="inf"
order reg
reshape long b, i(reg) j(var)
drop reg
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

ren var variable
ren b beta
compress 
gen rownum = _n
order rownum
sort rownum

save "$root\REGRESSION RESULTS\SUR\infections_results_deaths_inf", replace

use  "$root\REGRESSION RESULTS\SUR\infections_results_deaths_inf", clear
merge 1:1 variable using "$root\REGRESSION RESULTS\SUR\country_group_lookup_deaths_inf"
assert variable == "country_1" if _m==2 
drop if _m==2
assert _m ==3 if regexm(variable,"^country") 
sort rownum
list _m variable if _m==1, sep(0)

drop _m 
compress 
order country
save  "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_betas_deaths_inf", replace

log close 

exit 

// end

set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
X_vax_lower.dta created in: make_X_vax_lower_upper.do
X_vax_upper.dta created in: make_X_vax_lower_upper.do
tot_pop_deaths_inf.dta created in: make_X_vax_deaths_inf.do
country_betas_deaths_inf.dta created in: make_beta_&_X_vax_deaths_inf.do 
infections_betas_deaths_inf.dta created in: make_infections_betas_deaths_inf.do 
outputs:
sim_0_beta_&_X_vax_lower.dta
sim_0_beta_&_X_vax_upper.dta
*/

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// combine betas & Xs /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop getx
program getx
version 18.0
set type double
set more off 
args inf

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\X_vax_`inf'", clear
drop if variable == "tot_pop"
drop if regexm(variable,"^country_")
replace variable = "L1_inf_mean" if variable== "L1_inf_`inf'" 
replace variable = "L2_cum_inf_mean" if variable == "L2_cum_inf_`inf'" 

append using "$root\REGRESSION RESULTS\SUR\tot_pop_deaths_inf"
append using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\country_betas_deaths_inf"

merge m:1 variable using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_betas_deaths_inf"
drop if regexm(variable,"^country_")
assert _m!=2
drop country country_group 
assert inlist(variable,"time_06", "tot_pop","country") if _m==1

keep variable time x_* country_* beta
// time=6 is the omitted time dummy
assert beta<. if !inlist(variable,"time_06", "tot_pop","country") 

sort time variable
order variable time beta
sort time variable

gen beta_constant=., before(x_1)
replace beta_constant=beta if variable=="Constant"
assert variable[1]=="Constant"
replace beta_constant = beta_constant[_n-1] if beta_constant==. & _n>1
drop if variable=="Constant"

forvalues c = 1/145 {
	gen cty_`c' = ., before(x_`c')
}

forvalues c = 2/145 {
	replace cty_`c' = country_`c' if variable=="country"
	drop country_`c'
}

sort cty_2
assert variable=="country" if _n==1 

forvalues c = 2/145 {
	replace cty_`c' = cty_`c'[_n-1] if _n>1
}

forvalues c = 1/145 {
	ren cty_`c' beta_`c'
}

drop if variable =="country"

gen sortme=.
replace sortme=1 if variable=="L1_uptake_pfizer"
replace sortme=2 if variable=="L2_cum_uptake_pfizer"
replace sortme=3 if variable=="L1_uptake_other"
replace sortme=4 if variable=="L2_cum_uptake_other"
replace sortme=5 if variable=="L1_inf_mean"
replace sortme=6 if variable=="L2_cum_inf_mean"
replace sortme=7 if variable=="L1_mean_index"
replace sortme=8 if variable=="time_06"
replace sortme=9 if variable=="time_07"
replace sortme=10 if variable=="time_08"
replace sortme=11 if variable=="time_09"
replace sortme=12 if variable=="time_10"
replace sortme=13 if variable=="time_11"
replace sortme=14 if variable=="time_12"
replace sortme=15 if variable=="time_13"
replace sortme=16 if variable=="time_13"
replace sortme=17 if variable=="tot_pop" & time==2020
replace sortme=18 if variable=="tot_pop" & time==2021

assert sortme<.

sort time sortme
order variable time sortme

compress
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_vax_`inf'", replace

end

getx lower 
getx upper

exit 

// end
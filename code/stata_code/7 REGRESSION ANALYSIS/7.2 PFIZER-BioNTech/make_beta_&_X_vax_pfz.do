set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
X_vax_pfz.dta created in: make_X_vax_pfz.do 
tot_pop_deaths_inf.dta created in: make_X_vax_deaths_inf.do
country_betas_sims1000.dta created in: make_beta_&_X_vax_sims1000.do 
infections_betas_sims1000.dta created in: make_infections_betas_sims1000.do 
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_beta_&_X_vax_pfz", text replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// combine betas & Xs /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop getxb
program getxb 
version 18.0
set type double 
set more off 
args sim 

di "***************************************************************************"
di "************************** SIMULATIONS `sim' ******************************"
di "***************************************************************************"

use "$root\REGRESSION RESULTS\SUR\X_vax_pfz", clear
drop if variable == "tot_pop"
drop if regexm(variable,"^country_")

append using "$root\REGRESSION RESULTS\SUR\tot_pop_deaths_inf"
append using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\country_betas_sims1000"
order sim

merge m:1 variable using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\infections_betas_sims1000"
drop if regexm(variable,"^country_")
assert _m!=2
drop country country_group 
assert inlist(variable,"time_06", "tot_pop","country") if _m==1

keep sim variable time x_* country_* beta_`sim'
// time=6 is the omitted time dummy
ren beta_`sim' beta
assert beta<. if !inlist(variable,"time_06", "tot_pop","country") 

drop if variable=="country" & sim!=`sim'

sort time sim variable
order sim variable time beta
sort time sim variable

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

sort sim
assert variable=="country" if _n==1 

forvalues c = 2/145 {
	replace cty_`c' = cty_`c'[_n-1] if _n>1
}

forvalues c = 1/145 {
	ren cty_`c' beta_`c'
}

replace sim = sim[_n-1] if _n>1
assert sim==`sim' 
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
order sim variable time sortme

compress
save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_beta_&_X_vax_pfz", replace

end 

forvalues s = 1/1000 {
	getxb `s'
}

log close 

exit 

// end
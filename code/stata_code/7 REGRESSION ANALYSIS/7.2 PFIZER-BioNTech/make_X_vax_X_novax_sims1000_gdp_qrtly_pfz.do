set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
quarterly_gdp_regbase.dta created in: make_quarterly_gdp_regbase.do
sim_`sim'_novax_inf_pfz.dta created in: make_novax_infections_pfz.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_X_vax_X_novax_sims1000_gdp_qrtly_pfz", text replace

////////////////////////////////////////////////////////////////////////////////
////// get the simulation-specific design matrices under novax /////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop getX
program getX
version 18.0 
set more off 
set type double 
args sim

use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_pfz==1

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\quarterly_gdp_regbase"
drop if _m==1
drop _m 

drop if year<2020
egen check=rownonmiss(daily_deaths inf_mean gdp_gap)
assert check==3
drop check
qui tab country 
assert `r(r)'==52
assert _N==408

gen constant=1, before(prevax_osi)

replace L1_mean_index=L1_mean_index/100
replace prevax_osi_pfz=prevax_osi_pfz/100

// map on the novax infections under novax for all vax

merge 1:1 country_group time using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_novax_inf_pfz"

list country_group time novax_L1_inf_mean novax_L2_cum_inf_mean if _m==2, sep(0)

drop if _m==2 

sort country year quarter

foreach brand in pfizer {
	replace     L1_uptake_`brand'=0
	replace L2_cum_uptake_`brand'=0
}

replace L1_mean_index=prevax_osi_pfz if time==launch_time & prevax_osi_pfz<.
replace L1_mean_index=prevax_osi_pfz if time>=launch_time & prevax_osi_pfz<.

replace L1_inf_mean = novax_L1_inf_mean if novax_L1_inf_mean<. & _m==3
replace L2_cum_inf_mean = novax_L2_cum_inf_mean if novax_L2_cum_inf_mean<. &_m==3

drop _m

mkmat ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_52 ///
constant , matrix(X)

clear
svmat X

compress
count
assert `r(N)'==408

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_X_novax_gdp_qrtly_pfz", replace

end

forvalues s = 1/1000 {
	getX `s' 	
}

log close 

exit 

// end
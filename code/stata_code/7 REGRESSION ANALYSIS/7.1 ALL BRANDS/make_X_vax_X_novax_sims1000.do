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
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
sim_`sim'_novax_inf_all_vax.dta created in: make_novax_infections_sims1000.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_X_vax_X_novax_sims1000", text replace

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
keep if launch_all==1

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf"
assert _m==3
drop _m 

drop if year<2020
egen check=rownonmiss(daily_deaths inf_mean)
assert check==2
drop check
qui tab country 
di "There are `r(r)' countries in the sur model"
assert _N==1160

gen constant=1, before(prevax_osi)

replace L1_mean_index=L1_mean_index/100
replace prevax_osi=prevax_osi/100

// map on the novax infections under novax for all vax

merge 1:1 country_group time using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_novax_inf_all_vax"

list country_group time novax_L1_inf_mean novax_L2_cum_inf_mean if _m==2, sep(0)

drop if _m==2 

sort country year quarter

foreach brand in pfizer other {
	replace     L1_uptake_`brand'=0
	replace L2_cum_uptake_`brand'=0
}

replace L1_mean_index=prevax_osi if time==launch_time
replace L1_mean_index=prevax_osi if time>=launch_time

replace L1_inf_mean = novax_L1_inf_mean if novax_L1_inf_mean<. & _m==3
replace L2_cum_inf_mean = novax_L2_cum_inf_mean if novax_L2_cum_inf_mean<. &_m==3

drop _m

mkmat ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_145 ///
constant , matrix(X)

clear
svmat X

compress
count

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_X_novax_sureg", replace

end

forvalues s = 1/1000 {
	getX `s' 	
}

////////////////////////////////////////////////////////////////////////////////
//////// get the similation-constant design matrices under vax /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
drop if year<2020
egen check=rownonmiss(daily_deaths inf_mean)
assert check==2 
drop check
qui tab country 
di "There are `r(r)' countries in the sur model"

gen constant=1, before(prevax_osi)

replace L1_mean_index=L1_mean_index/100
replace prevax_osi=prevax_osi/100

sort country year quarter

mkmat ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_145 ///
constant, matrix(X)

clear
svmat X

compress
count

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_sureg", replace

log close 

exit 

// end

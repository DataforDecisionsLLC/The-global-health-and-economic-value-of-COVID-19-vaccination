set more off
clear all
set type double
set matsize 5000
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
sims_quarterly_gdp.dta created in: make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do
X_vax_gdp_qrtly.dta created in: make_X_vax_X_novax_sims1000_gdp_qrtly.do 
sim_`sim'_X_novax_gdp_qrtly_pfz.dta created in: make_X_vax_X_novax_sims1000_gdp_qrtly_pfz.do
vov_vars_gdp_qrtly.dta created in: sims1000_gdp_qrtly.do 
*/

////////////////////////////////////////////////////////////////////////////////
////////// 1. make the matrix that stacks the coefficient estimates ////////////
/// estimates from the quarterly gdp regression for each of the 1000 draws /////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sims_quarterly_gdp", clear 

qui des ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_52 constant, varlist

local ind = r(varlist) 
di "The independent variables are `ind'"

mkmat `ind', matrix(S_gdp_qrtly)

////////////////////////////////////////////////////////////////////////////////
/////////// 2. make the matrix where each row is an observation in the /////////
// regression and each column is an independent variable where the vax dosage //
////////////////// variables retain the values under vax ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_gdp_qrtly", clear

mkmat X1-X66, matrix(X_vax_gdp_qrtly)

********************************************************************************
********************************************************************************
********************** simulation specific program *****************************
********************************************************************************
********************************************************************************

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_gdp_qrtly", clear
keep X1
assert _N==408
gen rownum=_n 
drop X1
save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_pfz.dta", replace

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_1000_gdp_qrtly_pfz", text replace

capture program drop getvov 
program getvov 
version 18.0 
set type double 
set more off 
args sim

di "***************************************************************************"
di "*********************** RUNNING SIMULATION `sim' *************************"
di "***************************************************************************"

////////////////////////////////////////////////////////////////////////////////
//// 3. compute the predicted values under vax for each of the 1000 vectors ////
////////////// of coefficient estimates from the regression ////////////////////
////////////////////////////////////////////////////////////////////////////////

matrix F_vax_gdp_qrtly = S_gdp_qrtly*X_vax_gdp_qrtly'

clear 
svmat F_vax_gdp_qrtly

keep in `sim'

tempfile yhat_1_gdp_qrtly
save `yhat_1_gdp_qrtly'

////////////////////////////////////////////////////////////////////////////////
/////////// 4. make the matrix where each row is an observation in the /////////
// regression and each column is an independent variable where all vax dosage //
///// variables are equal to zero (novax), the osi variable is prevax, and /////
/////////////// the infections variables are at the novax levels ///////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_X_novax_gdp_qrtly_pfz", clear

mkmat X1-X66, matrix(X_novax_gdp_qrtly)

////////////////////////////////////////////////////////////////////////////////
//////////////////// compute the predicted values under novax //////////////////
////////// for each of the 1000 vectors of coefficient estimates ///////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////// 8c. quarterly gdp regression ////////////////////////

matrix F_novax_gdp_qrtly = S_gdp_qrtly*X_novax_gdp_qrtly'

clear 
svmat F_novax_gdp_qrtly

keep in `sim'

tempfile yhat_2_gdp_qrtly
save `yhat_2_gdp_qrtly'

////////////////////////////////////////////////////////////////////////////////
/////// 5. compute the difference in predicted outcomes under vax v novax ////// 
////////////////////////////////////////////////////////////////////////////////

use `yhat_1_gdp_qrtly', clear 

mkmat F_vax_gdp_qrtly1-F_vax_gdp_qrtly408, matrix(Y_1_gdp_qrtly)
 
use `yhat_2_gdp_qrtly', clear 

mkmat F_novax_gdp_qrtly1-F_novax_gdp_qrtly408, matrix(Y_2_gdp_qrtly)

matrix D_gdp_qrtly=Y_1_gdp_qrtly-Y_2_gdp_qrtly

matrix G_gdp_qrtly = D_gdp_qrtly'

clear 
svmat G_gdp_qrtly

gen rownum = _n
order rownum 

tempfile gains_sureg
save `gains_sureg'

////////////////////////////////////////////////////////////////////////////////
/// 6. compute averted non-fatal infections for each of the 1000 simulations ///
////////////////////////////////////////////////////////////////////////////////

ren G_gdp_qrtly1 G_gdp_qrtly`sim' 

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_pfz.dta"
assert _m==3 
drop _m 
sort rownum

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_pfz.dta", replace

end 

forvalues s=1/1000 {
	getvov `s'
}

log close

////////////////////////////////////////////////////////////////////////////////
///////////////////// 7. map on the 2019 per capita gdp ////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_pfz", clear 

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\vov_vars_gdp_qrtly"
assert _m==3 
drop _m 
sort rownum
order rownum gdp_usd_projected

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_w_vov_vars_pfz", replace

////////////////////////////////////////////////////////////////////////////////
///// 8. compute total averted gdp loss for each of the 1000 simulations ///////
////////////////////////////////////////////////////////////////////////////////

use   "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_w_vov_vars_pfz", clear

forvalues s = 1/1000 {
	gen gain_gdp`s' = gdp_usd_projected*G_gdp_qrtly`s'
	drop G_gdp_qrtly`s'
}

reshape long gain_gdp, i(rownum gdp_usd_projected) j(sim) 
order sim
isid rownum sim 
sort sim rownum 

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_qrtly_long_pfz", replace

drop gdp_usd_projected

ren gain_gdp gain_gdp_

reshape wide gain_gdp_, i(sim) j(rownum)

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gdp_qrtly_vov_pfz", replace

egen VoV_gdp_qrtly=rowtotal(gain_gdp_1 - gain_gdp_408)
drop gain_gdp_*

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_gdp_qrtly_pfz", replace

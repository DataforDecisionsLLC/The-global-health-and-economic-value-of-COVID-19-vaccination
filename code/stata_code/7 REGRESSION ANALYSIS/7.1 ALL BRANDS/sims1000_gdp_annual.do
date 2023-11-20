set more off
clear all
set type double
set matsize 5000
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
sims_annual_gdp.dta created in: make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do
X_vax_gdp_annual.dta created in: make_X_vax_X_novax_sims1000_gdp_annual.do 
X_novax_gdp_annual.dta creaated in: make_X_vax_X_novax_sims1000_gdp_annual.do 
annual_gdp_regbase.dta created in: make_annual_gdp_regbase.do
*/

////////////////////////////////////////////////////////////////////////////////
///////// 1. make the matrix that stacks the coefficient estimates /////////////
////// estimates from the annual gdp regression for each of the 1000 draws /////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sims_annual_gdp", clear 

qui des g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4 constant, varlist

local ind = r(varlist) 
di "The independent variables are `ind'"

mkmat g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4 constant, matrix(S_gdp_annual)

////////////////////////////////////////////////////////////////////////////////
/// 2. make the matrix where each row is an observation in the /////////////////
// regression and each column is an independent variable where the vax dosage //
////////////////// variables retain the values under vax ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_gdp_annual", clear

mkmat X1-X5, matrix(X_vax_gdp_annual)

********************************************************************************
********************************************************************************
********************** simulation specific program *****************************
********************************************************************************
********************************************************************************

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_gdp_annual", clear
keep X1
assert _N==66
gen rownum=_n 
drop X1
save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual.dta", replace

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_1000_gdp_annual", text replace

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

matrix F_vax_gdp_annual = S_gdp_annual*X_vax_gdp_annual'

clear 
svmat F_vax_gdp_annual

keep in `sim'

tempfile yhat_1_gdp_annual
save `yhat_1_gdp_annual'

////////////////////////////////////////////////////////////////////////////////
/////// 4. make the matrix where each row is an observation in the /////////////
// regression and each column is an independent variable where all vax dosage //
///// variables are equal to zero (novax), the osi variable is prevax, and /////
/////////////// the infections variables are at the novax levels ///////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_novax_gdp_annual", clear

mkmat X1-X5, matrix(X_novax_gdp_annual)

////////////////////////////////////////////////////////////////////////////////
//////////////////// compute the predicted values under novax //////////////////
////////// for each of the 1000 vectors of coefficient estimates ///////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////// 8d. annual gdp regression ///////////////////////////

matrix F_novax_gdp_annual = S_gdp_annual*X_novax_gdp_annual'

clear 
svmat F_novax_gdp_annual

keep in `sim'

tempfile yhat_2_gdp_annual
save `yhat_2_gdp_annual'

////////////////////////////////////////////////////////////////////////////////
/////// 5. compute the difference in predicted outcomes under vax v novax ////// 
////////////////////////////////////////////////////////////////////////////////

use `yhat_1_gdp_annual', clear 

mkmat F_vax_gdp_annual1-F_vax_gdp_annual66, matrix(Y_1_gdp_annual)
 
use `yhat_2_gdp_annual', clear 

mkmat F_novax_gdp_annual1-F_novax_gdp_annual66, matrix(Y_2_gdp_annual)

matrix D_gdp_annual=Y_1_gdp_annual-Y_2_gdp_annual

matrix G_gdp_annual = D_gdp_annual'

clear 
svmat G_gdp_annual

gen rownum = _n
order rownum 

tempfile gains_sureg
save `gains_sureg'

////////////////////////////////////////////////////////////////////////////////
/// 6. compute averted non-fatal infections for each of the 1000 simulations ///
////////////////////////////////////////////////////////////////////////////////

ren G_gdp_annual1 G_gdp_annual`sim' 

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual.dta"
assert _m==3 
drop _m 
sort rownum

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual.dta", replace

end 

forvalues s=1/1000 {
	getvov `s'
}

log close

////////////////////////////////////////////////////////////////////////////////
////////////////////// 7. map on 2019 per capita gdp ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\annual_gdp_regbase", clear 
sort country  year  quarter
keep gdp_usd_projected
gen rownum=_n
order rownum
assert _N==66

save "$root\REGRESSION RESULTS\SUR\vov_vars_gdp_annual", replace

//////////////////////////////// all brands ////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual", clear 

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\vov_vars_gdp_annual"
assert _m==3 
drop _m 
sort rownum
order rownum gdp_usd_projected

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual_w_vov_vars", replace

////////////////////////////////////////////////////////////////////////////////
///// 8. compute total averted gdp loss for each of the 1000 simulations ///////
////////////////////////////////////////////////////////////////////////////////

use   "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual_w_vov_vars", clear

forvalues s = 1/1000 {
	gen gain_gdp`s' = gdp_usd_projected*G_gdp_annual`s'
	drop G_gdp_annual`s'
}

reshape long gain_gdp, i(rownum gdp_usd_projected) j(sim) 
order sim
isid rownum sim 
sort sim rownum 

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_gdp_annual_long", replace

drop gdp_usd_projected

ren gain_gdp gain_gdp_

reshape wide gain_gdp_, i(sim) j(rownum)

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gdp_annual_vov_sureg", replace

egen VoV_gdp_annual=rowtotal(gain_gdp_1 - gain_gdp_66)
drop gain_gdp_*

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_gdp_annual", replace

exit 
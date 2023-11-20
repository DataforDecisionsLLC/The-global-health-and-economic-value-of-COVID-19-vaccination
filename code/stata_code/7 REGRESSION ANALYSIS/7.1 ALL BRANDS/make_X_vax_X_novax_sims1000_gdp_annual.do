set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
annual_gdp_regbase.dta created in: make_annual_gdp_regbase.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\make_X_vax_X_novax_sims1000_gdp_annual", text replace

////////////////////////////////////////////////////////////////////////////////
////////////get the similation-constant design matrices under novax ////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\annual_gdp_regbase", clear
assert gdp_gap<.

qui tab country 
assert `r(r)'==66
assert _N==66

gen constant=1

foreach brand in pfizer other {
	replace cum_uptake_`brand'=0
}

mkmat g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4 constant , matrix(X)

clear
svmat X

compress
count
assert `r(N)'==66

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_novax_gdp_annual", replace

////////////////////////////////////////////////////////////////////////////////
/////// get the similation-constant design matrices under no pfizer ////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\annual_gdp_regbase", clear
assert gdp_gap<.

qui tab country 
assert `r(r)'==66
assert _N==66

gen constant=1

foreach brand in pfizer {
	replace cum_uptake_`brand'=0
}

mkmat g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4 constant , matrix(X)

clear
svmat X

compress
count
assert `r(N)'==66

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_novax_gdp_annual_pfz", replace

////////////////////////////////////////////////////////////////////////////////
//////// get the similation-constant design matrices under vax /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\annual_gdp_regbase", clear
assert gdp_gap<.

qui tab country 
assert `r(r)'==66
assert _N==66

gen constant=1

mkmat g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4 constant , matrix(X)

clear
svmat X

compress
count
assert `r(N)'==66

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_gdp_annual", replace

log close 

exit 

// end

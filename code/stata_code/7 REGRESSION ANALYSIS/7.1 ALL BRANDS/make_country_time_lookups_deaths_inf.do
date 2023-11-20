
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
input: 
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
*/

////////////////////////////////////////////////////////////////////////////////
///////////////////////// make country group lookup ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
keep country country_group
duplicates drop 
sort country 
gen variable="", before(country)
replace variable = "country" + "_" + strofreal(country_group)
drop if country_group==.
compress 
save  "$root\REGRESSION RESULTS\SUR\country_group_lookup_deaths_inf", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////// make time period lookup /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
drop if year<2020
keep yyyy_qq time
duplicates drop 
sort time 
gen variable="", before(time)
tostring time, replace 
replace time = "0" + time if inlist(time,"1","2","3","4","5","6","7","8","9")
replace variable = "time" + "_" + time
drop time
ren yyyy_qq lookup
compress 
save  "$root\REGRESSION RESULTS\SUR\time_period_lookup_deaths_inf", replace
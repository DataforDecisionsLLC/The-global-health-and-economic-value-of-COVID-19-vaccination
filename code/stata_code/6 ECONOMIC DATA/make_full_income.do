set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
gl knee   ".......\JK Work\"
cd        "$root"

/*
inputs:
1. time_use_processed.xlsx created by JK
2. hrly_wage_2019USD_final.dta created in: make_hrly_wage_2019USD.do
3. final_pcgni_current_2019USD.dta created in: pc_income_current_2019USD.do 
*/

capture log close
log using "$output\ECONOMIC DATA\FULL INCOME\make_full_income", text replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// Combine files ////////////////////////////////// 
////////////////////////////////////////////////////////////////////////////////

import excel using "$knee\Time Use\time_use_processed_ihme.xlsx", clear first case(lower) 
keep country nonmarkettime
gen nmtime_hrs_per_day=nonmarkettime/60
sum nmtime_hrs_per_day
gen nmtime_hrs_per_year = nmtime_hrs_per_day*365
sum nmtime_hrs_per_year 

merge 1:1 country using "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD_final"
assert _m!=2
keep if _m==3 
drop _m 
merge 1:1 country WHO_region WB_income_group_1 using "$output\ECONOMIC DATA\GNI\final_pcgni_current_2019USD"
assert _m==3
drop _m 

sort country 
order country who_income WHO_region WB_income_group_1 hrly_wage_2019USD pcgni_current_2019USD nonmarkettime*
compress 
isid country
count 

merge 1:1 country using "$output\IHME\projections_unique_countries", keepusing(country)
assert _m!=2
assert country=="Djibouti" if _m==1 
drop _m 
sort country

codebook 

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// Compute full income ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

gen yf = pcgni_current_2019USD + nmtime_hrs_per_year*hrly_wage_2019USD
sum yf, d

compress
save "$output\ECONOMIC DATA\FULL INCOME\full_income", replace 

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// summary stats ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\FULL INCOME\full_income", clear

levelsof WB_income_group_1, local(group) 
foreach x of local group {
	di "******************************"
	di "The income group is `x'"
	di "******************************"	
	sum yf if WB_income_group_1=="`x'"
}

levelsof WHO_region, local(group) 
foreach x of local group {
	di "******************************"
	di "The WHO region is `x'"
	di "******************************"	
	sum yf if WHO_region=="`x'" 
}

levelsof who_income, local(group) 
foreach x of local group {
	di "******************************"
	di "The region-income group is `x'"
	di "******************************"	
	sum yf if who_income=="`x'" 
}

log close 

exit

// end
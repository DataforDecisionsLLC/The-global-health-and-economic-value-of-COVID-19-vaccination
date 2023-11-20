set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
sur_regbase_deaths_inf.dta
country_group_lookup_deaths_inf.dta
*/

////////////////////////////////////////////////////////////////////////////////
///////////////////////// make country group lookup ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
drop if year<2020
drop if year==2022 

drop if inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan")
drop country_* country_group time_* 

egen check=rownonmiss(inf_mean daily_deaths)
tab check, m
assert check==2 if year>=2020

drop check

keep country year quarter yyyy_qq time uptake uptake_pfizer uptake_other
assert abs(uptake - (uptake_pfizer + uptake_other ))<.000000001

// identify the launch of the primary series for all vaccines
sort country time 
by country: gen run_all = sum(uptake)
gen launch_all = . 
by country: replace launch_all=1 if run_all[_n-1]==0 & run_all>0 

// identify the launch of the primary series for the pfizer vaccines
by country: gen run_pfz = sum(uptake_pfizer)
gen launch_pfz = . 
by country: replace launch_pfz=1 if run_pfz[_n-1]==0 & run_pfz>0 

gen keepme=0 
replace keepme=1 if launch_all == 1
replace keepme=1 if launch_pfz == 1
keep if keepme==1 
drop keepme run* uptake*

sort country time
assert time<13 if launch_all ==1 
keep country time yyyy_qq launch_all launch_pfz

// map on the country_group

merge m:1 country using "$root\REGRESSION RESULTS\SUR\country_group_lookup_deaths_inf"
assert _m==3 
drop _m 

qui tab country 
di "There are `r(r)' countries in the sur model"
sort country time

compress
save  "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", replace

exit 

// end
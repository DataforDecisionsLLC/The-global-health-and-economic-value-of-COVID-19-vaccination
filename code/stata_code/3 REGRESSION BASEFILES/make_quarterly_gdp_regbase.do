set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"

/*
inputs: 
gdp_gap_ihme.xlsx
quarterly_regbase.dta created in: make_quarterly_regbase.do
gri_quarterly_avg_ihme_countries.dta created in: make_gri.do
prevax_osi.dta created in: make_sur_regbase_deaths_inf.do
*/

capture log close
log using "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\make_quarterly_gdp_regbase", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////// get the quarterly countries //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$output\KNEE\gdp_gap_ihme.xlsx", ///
clear first case(lower) 

keep if type == "quarterly" 
keep country 
duplicates drop 

////////////////////////////////////////////////////////////////////////////////
///////////////////// map to the regression basefile ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:m country using  "$output\IHME\quarterly_regbase"
drop if year==2022
assert _m!=1
keep if _m ==3 
drop _m

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// map on the gri /////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country yyyy_qq using "$output\OXFORD\gri_quarterly_avg_ihme_countries"
assert _m!=1 if year>=2020
drop if _m==2 
drop _m
replace gri=0 if year<2020
ren gri mean_index

qui tab country 
assert `r(r)'==52

////////////////////////////////////////////////////////////////////////////////
//////////////// map on the pre-vax OSI for the no-vax scenario ////////////////
////////////////////////////////////////////////////////////////////////////////

merge m:1 country using "$root\REGRESSION RESULTS\SUR\prevax_osi"
assert _m!=1
keep if _m==3
drop _m 

qui tab country 
assert `r(r)'==52

////////////////////////////////////////////////////////////////////////////////
//////////////// drop observations with missing gdp ratio or osi ///////////////
////////////////////////////////////////////////////////////////////////////////

drop if gdp_gap==. & year>=2020 

foreach var in gdp_gap mean_index  {
	assert `var'<. if year>=2020
}

assert !inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan")

////////////////////////////////////////////////////////////////////////////////
//////////////// drop Moldova since it only has one observation ////////////////
////////////////////////////////////////////////////////////////////////////////

drop if country=="Moldova"

////////////////////////////////////////////////////////////////////////////////
//////////////////// create the cumualative infections variables ///////////////
////////////////////////////////////////////////////////////////////////////////

gen nat_immun = inf_mean*tot_pop
sort country year quarter 
by  country: gen cum_inf_mean = sum(nat_immun)
replace cum_inf_mean = cum_inf_mean/tot_pop
drop nat_immun

foreach var in mean_index uptake_pfizer uptake_other cum_uptake_pfizer cum_uptake_other cum_inf_mean {
	assert `var'<.
}

foreach var in gdp_gap  {
	assert `var'<. if year>=2020
}

////////////////////////////////////////////////////////////////////////////////
///////////////////////// create the lagged variables //////////////////////////
////////////////////////////////////////////////////////////////////////////////

sort country year quarter

foreach var in uptake_pfizer uptake_other cum_uptake_pfizer cum_uptake_other inf_mean cum_inf_mean mean_index {
	by country: gen L1_`var' = `var'[_n-1]
}

foreach var in uptake_pfizer uptake_other cum_uptake_pfizer cum_uptake_other inf_mean cum_inf_mean mean_index {
	by country: gen L2_`var' = `var'[_n-2]
}

replace L1_inf_mean=0 if L1_inf_mean==. 
replace L2_cum_inf_mean=0 if L2_cum_inf_mean==. 

foreach var in gdp_gap  {
	assert `var'<. if year>=2020
}

foreach var in L1_uptake_pfizer L2_cum_uptake_pfizer L1_uptake_other L2_cum_uptake_other L1_inf_mean L2_cum_inf_mean L1_mean_index {
	assert `var'<. if !inlist(yyyy_qq,"2018_Q4","2019_Q1")
}

order country time yyyy_qq gdp_gap uptake* cum_* L1_* L2_* 

////////////////////////////////////////////////////////////////////////////////
///////////////// create the country and quarter dummies ///////////////////////
////////////////////////////////////////////////////////////////////////////////

drop time time_* country_group country_*

egen country_group=group(country)
egen time=group(yyyy_qq)

sum country_group
di "There are `r(max)' countries"

sum time
di "There are `r(max)' time periods"

qui tab country_group, gen(country_)
qui tab time, gen(time_)

gen rownum=_n
order rownum country time yyyy_qq gdp_gap

count if year>=2020

compress

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\quarterly_gdp_regbase", replace

log close 

exit 

// end




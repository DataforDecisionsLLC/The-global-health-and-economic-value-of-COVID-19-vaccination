set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
quarterly_regbase.dta created in: make_quarterly_regbase.do
gri_quarterly_avg_ihme_countries.dta created in: make_gri.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_sur_regbase_deaths_inf", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////// map the gri to the quarterly regbase /////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase", clear
drop if country=="Puerto Rico"
drop if year ==2022 
merge 1:1 country yyyy_qq using "$output\OXFORD\gri_quarterly_avg_ihme_countries"
assert _m !=2
tab _m if year>=2020 
tab yyyy_qq if _m==1 
tab country if _m==1 & year>=2020

assert gri ==. if _m==1 & year>=2020
drop if inlist(country,"Armenia","Equatorial Guinea","Guinea-Bissau","North Macedonia","Puerto Rico")
assert _m ==3 if year>=2020
drop _m
ren gri mean_index 
replace mean_index=0 if year<2020
codebook mean_index
assert mean_index<.

egen check = rownonmiss(inf_mean daily_deaths)
assert inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan") if check==0 & year>=2020
drop if inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan")
assert check==2 if year>=2020
drop check 

foreach var in daily_deaths inf_mean mean_index  {
	assert `var'<. if year>=2020
}

save "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// get the pre-vax OSI for the no-vax scenario /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
drop if year<2020
drop if year==2022 

assert !inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan")
drop country_* country_group time_* 

keep country year quarter yyyy_qq mean_index uptake uptake_pfizer uptake_other
assert abs(uptake - (uptake_pfizer + uptake_other ))<.000000001

// identify the launch of the primary series for any vaccine and for Pfizer 

sort country year quarter 
by country: gen run_all=sum(uptake)
by country: gen run_pfz=sum(uptake_pfizer)

gen launch=0
by country: replace launch=1 if run_all>0 & run_all[_n-1] ==0 & _n>1
gen launch_pfz=0
by country: replace launch_pfz=1 if run_pfz>0 & run_pfz[_n-1] ==0 & _n>1

list country yyyy_qq if launch==1 & inlist( yyyy_qq,"2021_Q3","2021_Q4"), sep(0)

sort country year quarter
by country: gen prevax_osi = mean_index[_n-1]
gen keepme=0 
replace keepme=1 if launch==1 
replace keepme=1 if launch_pfz==1 
keep if keepme 
drop keepme 
sort country year quarter 

assert prevax_osi<.

keep country launch launch_pfz prevax_osi

preserve 

keep if launch==1
assert prevax_osi<. 
keep country prevax_osi
save "$root\REGRESSION RESULTS\SUR\prevax_osi", replace

restore 

keep if launch_pfz==1
assert prevax_osi<. 
keep country prevax_osi
ren prevax_osi prevax_osi_pfz
merge 1:1 country using "$root\REGRESSION RESULTS\SUR\prevax_osi"
assert _m!=1
drop _m 
sort country 

save "$root\REGRESSION RESULTS\SUR\prevax_osi", replace

////////////////////////////////////////////////////////////////////////////////
//// drop observations with missing deaths, infections, gdp ratio, or osi //////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear

drop if year==2022 

foreach var in daily_deaths inf_mean mean_index  {
	assert `var'<. if year>=2020
}

assert !inlist(country,"Burundi","Djibouti","Eritrea","Laos","Mauritius","Nicaragua","Tajikistan","Tanzania","Turkmenistan")
drop country_* country_group time_* 

// confirm the panel is balanced 

sort country year quarter 
by   country: assert _N==13

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

foreach var in daily_deaths inf_mean  {
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

foreach var in daily_deaths inf_mean  {
	assert `var'<. if year>=2020
}

foreach var in L1_uptake_pfizer L2_cum_uptake_pfizer L1_uptake_other L2_cum_uptake_other L1_inf_mean L2_cum_inf_mean L1_mean_index {
	assert `var'<. if !inlist(yyyy_qq,"2018_Q4","2019_Q1")
}

order country time yyyy_qq daily_deaths inf_mean uptake* cum_* L1_* L2_* 

////////////////////////////////////////////////////////////////////////////////
///////////////// create the country and quarter dummies ///////////////////////
////////////////////////////////////////////////////////////////////////////////

qui tab country 
di "There are `r(r)' countries"

egen country_group=group(country)
qui tab country_group, gen(country_)
qui tab time, gen(time_)

sum country_group
di "There are `r(max)' countries"

sum time
di "There are `r(max)' time periods"

gen rownum=_n
order rownum country time yyyy_qq daily_deaths inf_mean gdp_gap

count if year>=2020

compress

save "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////// map on the pre-vax osi ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use  "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear 
merge m:1 country using "$root\REGRESSION RESULTS\SUR\prevax_osi"
assert _m==3
drop _m 

compress

save "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", replace

log close 

exit 

// end

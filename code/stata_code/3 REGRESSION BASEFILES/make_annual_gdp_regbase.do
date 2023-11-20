set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
gl knee   ".......\JK Work\"

/*
inputs: 
annual_gdp_regbase.xlsx
gdp_gap_ihme.xlsx
quarterly_regbase.dta created in: make_quarterly_regbase.do
quarterly_gdp_usd.dta created in: make_quarterly_gdp_usd.do
*/

// get JK's annual regression file

import excel using "$knee\annual_gdp_regbase.xlsx", clear first
isid country
drop if country=="Puerto Rico" 
count 
save "$output\KNEE\annual_gdp_regbase", replace

// make the annual gdp file 

import excel using "$output\KNEE\gdp_gap_ihme.xlsx", ///
clear first case(lower) 

keep if type == "annual" 
gen year = substr(date, 1,4)
destring year, replace 
keep country year gdp_gap 
duplicates drop 
drop if year==2022

isid country year 
qui tab country 
di "`r(r)'"

merge 1:m country year gdp_gap using "$output\IHME\quarterly_regbase"
drop if year==2022
drop if year<2020

tab country if _m==1

keep if _m ==3 
drop _m 

qui tab country 
di "`r(r)'"
save "$output\IHME\annual_gdp_regbase", replace

// get the countries that had a 2020 Q4 or 2021 Q1 vax launch 

use "$output\IHME\quarterly_regbase", clear
drop if year<2020
drop if year==2022 

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
keep country time yyyy_qq launch_all launch_pfz

merge 1:m country using "$output\IHME\annual_gdp_regbase" 
keep if _m ==3 
drop _m 

qui tab country 
di "`r(r)'"

save "$output\IHME\annual_gdp_regbase", replace

// filter to JK sample 

use "$output\IHME\annual_gdp_regbase", clear

merge m:1 country using "$output\KNEE\annual_gdp_regbase", keepusing(country)
assert _m!=2 
keep if _m==3 
drop _m 
sort country year quarter 

qui tab country 
di "`r(r)'"

// compute cumulative infections at the end of 2020

gen inf = inf_mean*tot_pop 
sort country year quarter 
by country: gen cum_inf_mean = sum(inf)
replace cum_inf_mean=cum_inf_mean/tot_pop
drop inf

keep country gdp_gap year yyyy_qq quarter cum_uptake cum_uptake_pfizer cum_uptake_other cum_inf_mean

keep if quarter == 4 
sort country year quarter 
by country: gen d_gap = gdp_gap[2] - gdp_gap[1]
by country: gen g2020 = gdp_gap[1]
by country: gen cn2020Q4 = cum_inf_mean[1]
keep if year==2021 & quarter == 4
order country d_gap g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4

save "$output\IHME\annual_gdp_regbase", replace

// map on the projected gdp in 2021 Q4

use "$output\ECONOMIC DATA\quarterly_gdp_usd", clear 
keep if year == 2021 & quarter == 4
keep country gdp_usd_projected
replace gdp_usd_projected = gdp_usd_projected*4

merge 1:1 country using "$output\IHME\annual_gdp_regbase"
assert _m!=2 

keep if _m==3 
drop _m 
sort country year quarter 

save "$output\IHME\annual_gdp_regbase", replace

// map on the projected gdp in 2020 Q4

use "$output\ECONOMIC DATA\quarterly_gdp_usd", clear 
keep if year == 2020 & quarter == 4
keep country gdp_usd_projected
replace gdp_usd_projected = gdp_usd_projected*4
ren gdp_usd_projected gdp_usd_projected_2020

merge 1:1 country using "$output\IHME\annual_gdp_regbase"
assert _m!=2 
keep if _m==3 
drop _m 

assert _N== 66 
sort country year quarter 

save "$output\IHME\annual_gdp_regbase", replace
set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
1. owid-covid-data_9.22.2022.xlsx
2. master_country_list_owid.xlsx
3. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
*/

capture log close
log using "$output\owid_raw_countries_w_pop_gt_1M", text replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////// read in the raw OWID data  /////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\OWID\owid-covid-data_9.22.2022.xlsx", ///
clear sheet("owid-covid-data_9.22.2022") cellrange(C1:BO218245) first case(lower) 

des, full

// drop location aggregates

drop if regexm(location,"income")
drop if inlist(location,"Africa","Asia","Europe","European Union","International","North America","Oceania","South America","World")

ren location country
qui tab country, m 
di "There are `r(r)' locations"

compress
save "$output\owid_raw", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////// merge on UN regional classification ////////////////////
////////////////////////////////////////////////////////////////////////////////

/*
master_country_list_owid.xlsx has mapped the geo classifications and income 
group classifications to the master list of countries.
*/

import excel using "$output\master_country_list_owid.xlsx", ///
clear sheet("master_list") cellrange(A1:M246) first 

keep country UN_region 

drop if mi(country)
drop if mi(UN_region)

compress

merge 1:m country using "$output\owid_raw"

qui tab country if _m==2
di "There are `r(r)' locations not in the regional file"

drop if _m==1
drop _m

qui tab country, m 
di "There are `r(r)' locations"

gen region = UN_region

replace region="Asia" if country=="Japan"
replace region="Asia" if region=="" & inlist(country,"Taiwan", "Palestine", "Hong Kong", "Macao","Timor", "Northern Cyprus" ) 
replace region="Europe" if region=="" & inlist(country,"Faeroe Islands","Isle of Man","Jersey","Kosovo","Vatican", "Guernsey")
replace region="Latin America and the Caribbean" if region=="" & inlist(country,"Bonaire Sint Eustatius and Saba","Curacao","Sint Maarten (Dutch part)")
replace region="Oceania" if region=="" & inlist(country,"Northern Mariana Islands","Pitcairn")
replace region="Africa" if region=="" & country=="Western Sahara"
replace region="Northern America" if region=="" & country=="Saint Pierre and Miquelon"

tab country if mi(region)

compress

save "$output\owid_raw_w_region", replace

////////////////////////////////////////////////////////////////////////////////
//////////////// drop countries with 2020 population <1000000 //////////////////
////////////////////////////////////////////////////////////////////////////////

gen year = 2020 
replace country = "Timor-Leste" if country=="Timor" 
merge m:1 country year using "$output\national_population_2020_2021_2022" 
keep if year==2020
drop year
tab country if _m==1
assert tot_pop<=1000000 if _m==2

keep if _m==3
drop _m

qui tab country 
di "There are `r(r)' countries"

drop if tot_pop <= 1000000
drop if tot_pop==.
drop tot_pop

qui tab country , m 
di "There are `r(r)' locations with more than 1M pop"

sort country date
compress

// create the year and quarter variables

gen year = year(date)
gen quarter=quarter(date)
gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
sort country year quarter date
order country year quarter yyyy_qq date region

compress 
save "$output\owid_raw_countries_w_pop_gt_1M", replace

log close
exit

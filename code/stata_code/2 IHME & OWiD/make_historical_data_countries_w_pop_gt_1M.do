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
1. Historical-and-Projected-Covid-19-data.xlsx
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
*/

capture log close
log using "$output\IHME\make_historical_data_countries_w_pop_gt_1M", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// import the raw IHME datafile /////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\IHME 3\Historical-and-Projected-Covid-19-data.xlsx", ///
clear sheet("Historical-and-Projected-Covid-") first case(lower) 
assert icu_beds_lower==w
drop w 
order location_name date version_name admis_lower admis_mean admis_upper admis_lower_unvax admis_mean_unvax admis_upper_unvax admis_lower_vax admis_mean_vax admis_upper_vax cumulative_all_effectively_vacci cumulative_all_fully_vaccinated cumulative_deaths cumulative_deaths_unscaled daily_deaths daily_deaths_unscaled hospital_beds_mean hospital_beds_upper hospital_beds_lower icu_beds_lower

des, full 
compress
save "$output\IHME\Historical-and-Projected-Covid-19-data", replace

////////////////////////////////////////////////////////////////////////////////
/////////////// drop countries with population <= 1M ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep country 
duplicates drop 
count 

replace country = "Hong Kong" if country=="Hong Kong Special Administrative Region of China"
replace country = "Macao" if country=="Macao Special Administrative Region of China"
replace country = "Taiwan" if country=="Taiwan (Province of China)"
replace country = "Taiwan" if country=="Taiwan (Province of China)"
replace country = "Bolivia" if country=="Bolivia (Plurinational State of)"
replace country = "Cote d'Ivoire" if country=="CÃ´te d'Ivoire"
replace country = "Democratic Republic of Congo" if country=="Democratic Republic of the Congo"
replace country = "Iran" if regexm(country,"Iran")
replace country = "Moldova" if country=="Republic of Moldova"
replace country = "Russia" if country=="Russian Federation"
replace country = "South Korea" if country=="Republic of Korea"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "United States" if country=="United States of America"
replace country = "Venezuela" if country=="Venezuela (Bolivarian Republic of)"
replace country = "Vietnam" if country=="Viet Nam"
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Turkey" if country=="TÃ¼rkiye"

compress

merge 1:m country using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3
drop _m
keep if year==2020

drop if tot_pop<=1000000
drop tot_pop year

keep country
isid country 
count

sort country 
compress 

save "$output\IHME\projections_unique_countries", replace

////////////////////////////////////////////////////////////////////////////////
////////// sum the Hong Kong and Macao infections, deaths and vax data /////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
drop version_name
isid country date

replace country = "Hong Kong" if country=="Hong Kong Special Administrative Region of China"
replace country = "Macao" if country=="Macao Special Administrative Region of China"
keep if inlist(country, "Hong Kong","Macao")
tab country 
assert r(r)==2
sort date country

keep country date inf_cuml_mean inf_mean cumulative_deaths daily_deaths ///
cumulative_all_effectively_vacci cumulative_all_fully_vaccinated 

collapse (sum) cumulative_all_effectively_vacci cumulative_all_fully_vaccinated cumulative_deaths daily_deaths inf_cuml_mean inf_mean, by(date)

gen country="Hong Kong + Macao"
order  country 
isid date

// drop records after Q2 of 2022 

gen year=year(date)
gen quarter=quarter(date)
drop if year==2023
drop if year==2022 & quarter>2 

sort date 
assert date==mdy(2,4,2020) if _n==1
assert date==mdy(6,30,2022) if _n==_N

compress

save "$output\IHME\infections_deaths_vaxs_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
/////////// construct the analytical file with countries with pop>1M ///////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
isid country date

keep country date inf_cuml_mean inf_mean cumulative_deaths daily_deaths ///
cumulative_all_effectively_vacci cumulative_all_fully_vaccinated 

sort country date 

replace country = "Hong Kong" if country=="Hong Kong Special Administrative Region of China"
replace country = "Macao" if country=="Macao Special Administrative Region of China"
replace country = "Taiwan" if country=="Taiwan (Province of China)"
replace country = "Bolivia" if country=="Bolivia (Plurinational State of)"
replace country = "Cote d'Ivoire" if country=="CÃ´te d'Ivoire"
replace country = "Democratic Republic of Congo" if country=="Democratic Republic of the Congo"
replace country = "Iran" if regexm(country,"Iran")
replace country = "Moldova" if country=="Republic of Moldova"
replace country = "Russia" if country=="Russian Federation"
replace country = "South Korea" if country=="Republic of Korea"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "United States" if country=="United States of America"
replace country = "Venezuela" if country=="Venezuela (Bolivarian Republic of)"
replace country = "Vietnam" if country=="Viet Nam"
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Turkey" if country=="TÃ¼rkiye"

compress

merge m:1 country using "$output\IHME\projections_unique_countries"
assert _m!=2 
keep if _m==3 
drop _m 

qui tab country
di "There are `r(r)' unique countries with population > 1M"
sort country date

// drop records after Q2 of 2022 

gen year=year(date)
gen quarter=quarter(date)
drop if year==2023
drop if year==2022 & quarter>2 

sort country date 
by country: assert date==mdy(2,4,2020) if _n==1
by country: assert date==mdy(6,30,2022) if _n==_N

order country date year quarter cumulative_deaths daily_deaths ///
inf_cuml_mean inf_mean cumulative_all_effectively_vacci cumulative_all_fully_vaccinated

compress
save "$output\IHME\projections_countries_w_pop_gt_1M", replace

////////////////////////////////////////////////////////////////////////////////
///// subtract Hong Kong and Macao infections, deaths and vax from China ///////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\infections_deaths_vaxs_Hong_Kong_plus_Macoa" , clear 
append using "$output\IHME\projections_countries_w_pop_gt_1M"
isid country date
keep if inlist(country, "Hong Kong + Macao", "China")

tab country
assert r(r)==2
compress

sort date country
foreach var in ///
cumulative_all_effectively_vacci ///
cumulative_all_fully_vaccinated ///
cumulative_deaths ///
daily_deaths ///
inf_cuml_mean ///
inf_mean {
	by date: replace `var' = `var'-`var'[_n+1] if country=="China" & country[_n+1]=="Hong Kong + Macao"
}

keep if country=="China"

compress 
save "$output\IHME\infections_deaths_vaxs_China_minus_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
/// append the corrected China infections, deaths and vax to the master file ///
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\projections_countries_w_pop_gt_1M", clear
drop if country=="China"
append using "$output\IHME\infections_deaths_vaxs_China_minus_Hong_Kong_plus_Macoa"
sort country date 
isid country date

qui tab country
di "There are `r(r)' countries"
 
compress
save "$output\IHME\projections_countries_w_pop_gt_1M", replace

log close

exit 

// end
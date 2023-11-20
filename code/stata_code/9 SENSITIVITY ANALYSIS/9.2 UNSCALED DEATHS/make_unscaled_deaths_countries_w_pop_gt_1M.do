set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
Historical-and-Projected-Covid-19-data.xlsx
projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
outputs:
unscaled_deaths_countries_w_pop_gt_1M.dta 
unscaled_deaths_Hong_Kong_China_Macoa.dta 
*/

capture log close
log using "$output\IHME\make_unscaled_deaths_countries_w_pop_gt_1M", text replace

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

keep country date cumulative_deaths_unscaled daily_deaths_unscaled

collapse (sum) cumulative_deaths_unscaled daily_deaths_unscaled, by(date)

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

save "$output\IHME\unscaled_deaths_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
/////////// construct the analytical file with countries with pop>1M ///////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
isid country date

keep country date daily_deaths_unscaled cumulative_deaths_unscaled

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

order country date year quarter daily_deaths_unscaled cumulative_deaths_unscaled

compress
save "$output\IHME\unscaled_deaths_countries_w_pop_gt_1M", replace

////////////////////////////////////////////////////////////////////////////////
///// subtract Hong Kong and Macao infections, deaths and vax from China ///////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\unscaled_deaths_Hong_Kong_plus_Macoa", clear 
append using "$output\IHME\unscaled_deaths_countries_w_pop_gt_1M"
isid country date
keep if inlist(country, "Hong Kong + Macao", "China")

tab country
assert r(r)==2
compress

sort date country
foreach var in cumulative_deaths_unscaled daily_deaths_unscaled {
	by date: replace `var' = `var'-`var'[_n+1] if country=="China" & country[_n+1]=="Hong Kong + Macao"
}

keep if country=="China"

compress 
save "$output\IHME\unscaled_deaths_China_minus_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
/// append the corrected China infections, deaths and vax to the master file ///
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\unscaled_deaths_countries_w_pop_gt_1M", clear
drop if country=="China"
append using "$output\IHME\unscaled_deaths_China_minus_Hong_Kong_plus_Macoa"
sort country date 
isid country date

qui tab country
di "There are `r(r)' countries"

compress
save "$output\IHME\unscaled_deaths_countries_w_pop_gt_1M", replace

////////////////////////////////////////////////////////////////////////////////
////////// get the Hong Kong and Macao infections, deaths and vax data /////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
drop version_name
isid country date

replace country = "Hong Kong" if country=="Hong Kong Special Administrative Region of China"
replace country = "Macao" if country=="Macao Special Administrative Region of China"
keep if inlist(country, "Hong Kong","Macao","China")
tab country 
assert r(r)==3
sort date country

keep country date cumulative_deaths_unscaled daily_deaths_unscaled

// drop records after Q2 of 2022 

gen year=year(date)
gen quarter=quarter(date)
drop if year==2023
drop if year==2022 & quarter>2 

sort date 
assert date==mdy(2,4,2020) if _n==1
assert date==mdy(6,30,2022) if _n==_N

compress
save "$output\IHME\unscaled_deaths_Hong_Kong_China_Macoa", replace

log close

exit 

// end
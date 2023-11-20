set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work"
gl raw    ".......\RAW DATA"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
government_response_index_avg.xlsx
quarterly_regbase.dta created in: make_quarterly_regbase.do
*/

import excel using "$raw\GRI\government_response_index_avg.xlsx", ///
clear first sheet("import")
ren country_name country

replace country = "Czechia" if country == "Czech Republic"
replace country = "Kyrgyzstan" if country == "Kyrgyz Republic"
replace country = "Slovakia" if country == "Slovak Republic"

reshape long avg_, i(country) j(yyyy_qq) string
ren avg_ gri

compress
save "$output\OXFORD\gri_quarterly_avg", replace

// keep only the ihme countries 

use "$output\IHME\quarterly_regbase", clear 
drop if country=="Puerto Rico"
keep country 
duplicates drop 
count 

merge 1:m country using "$output\OXFORD\gri_quarterly_avg"
tab country if _m ==1 

keep if _m ==3 
drop _m 
sort country yyyy_qq 

compress
save "$output\OXFORD\gri_quarterly_avg_ihme_countries", replace


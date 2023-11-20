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
1. WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xls
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
3. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do 
*/

capture log close
log using "$output\LIFE TABLES\make_life_tables_2019", text replace

////////////////////////////////////////////////////////////////////////////////
/////////////// read in UN single-age life tables 2015-2021 estimates //////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\LIFE TABLES\WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx", ///
clear sheet("import") cellrange(C3:W166855)  first case(lower)

drop notes location_code iso3_code iso2_code sdmx_code geo_type parent_code

ren location country
ren l L

keep if year==2019
tab year, m 

assert country!=""
qui tab country
di "There are `r(r)' unique countries"

replace country = "Bolivia" if regexm(country,"Bolivia")
replace country = "Bonaire Sint Eustatius and Saba" if regexm(country,"Bonaire")
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Hong Kong" if country=="China, Hong Kong SAR"
replace country = "Macao" if country=="China, Macao SAR"
replace country = "Taiwan" if country=="China, Taiwan Province of China"
replace country = "Cote d'Ivoire" if country=="Côte d'Ivoire"
replace country = "Curacao" if country=="Curaçao"
replace country = "North Korea" if country=="Dem. People's Republic of Korea"
replace country = "Democratic Republic of Congo" if country=="Democratic Republic of the Congo"
replace country = "Falkland Islands" if country=="Falkland Islands (Malvinas)"
replace country = "Faeroe Islands" if country=="Faroe Islands"
replace country = "Iran" if country=="Iran (Islamic Republic of)"
replace country = "Kosovo" if country=="Kosovo (under UNSC res. 1244)"
replace country = "Laos" if country=="Lao People's Democratic Republic"
replace country = "Micronesia (country)" if country=="Micronesia (Fed. States of)"
replace country = "South Korea" if country=="Republic of Korea"
replace country = "Moldova" if country=="Republic of Moldova"
replace country = "Russia" if country=="Russian Federation"
replace country = "Palestine" if country=="State of Palestine"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "Turkey" if country=="Türkiye"
replace country = "United States" if country=="United States of America"
replace country = "Venezuela" if country=="Venezuela (Bolivarian Republic of)"
replace country = "Vietnam" if country=="Viet Nam"
replace country = "Wallis and Futuna" if country=="Wallis and Futuna Islands"
replace country = "Tanzania" if country=="United Republic of Tanzania"
replace country = "Saint Martin" if country=="Saint Martin (French part)"

compress
save "$output\LIFE TABLES\raw_life_tables_2019", replace 

// drop countries with population <= 1M

use "$output\national_population_2020_2021_2022" , clear
keep if year==2020 
drop year 

drop if tot_pop<=1000000
drop tot_pop

merge 1:m country using "$output\LIFE TABLES\raw_life_tables_2019"
keep if _m==3
drop _m

qui tab country
di "There are `r(r)' unique countries with population > 1M"

// keep the IHME relevant countries

merge m:1 country using "$output\IHME\projections_unique_countries", keepusing(country)
assert _m!=2
drop if _m==1 
assert _m==3 
drop _m 

qui tab country
di "There are `r(r)' unique IHME countries"

sort country year age
compress 

save "$output\LIFE TABLES\life_tables_2019", replace 

log close 

exit 

// end
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
data_download_file_reference_2020.xlsx
data_download_file_reference_2021.xlsx
data_download_file_reference_2022.xlsx
national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
regions.dta created in: make_regions.do
*/ 

capture log close
log using "$output\make_IHME_unique_countries", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// 2020 IHME data ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\IHME\data_download_file_reference_2020.xlsx", ///
clear sheet("data_download_file_reference_20") first case(lower) 

compress 
tab location_id if location_name =="Georgia",m 
drop if location_id ==533 & location_name =="Georgia"
tab location_id if location_name =="Georgia",m 

save "$output\ihme_2020_raw", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// 2021 IHME data //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\IHME\data_download_file_reference_2021.xlsx", ///
clear sheet("data_download_file_reference_20") first case(lower) 

compress 
tab location_id if location_name =="Georgia",m 
drop if location_id ==533 & location_name =="Georgia"
tab location_id if location_name =="Georgia",m 

save "$output\ihme_2021_raw", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// 2022 IHME data ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\IHME\data_download_file_reference_2022.xlsx", ///
clear sheet("data_download_file_reference_20") first case(lower) 

compress 
tab location_id if location_name =="Georgia",m 
drop if location_id ==533 & location_name =="Georgia"
tab location_id if location_name =="Georgia",m 

save "$output\ihme_2022_raw", replace

////////////////////////////////////////////////////////////////////////////////
/////////////// Stack the raw 2020, 2021, and 2022 IHME datafiles //////////////
////////////////////////////////////////////////////////////////////////////////

use location_name using "$output\ihme_2020_raw", clear
append using "$output\ihme_2021_raw", keep(location_name)
append using "$output\ihme_2022_raw", keep(location_name)
ren location_name country 
duplicates drop

// use China (without Hong Kong and Macao) for China

drop if country=="China"
tab country if regexm(country, "China"),m

replace country = "China" if country=="China (without Hong Kong and Macao)"
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

compress

////////////////////////////////////////////////////////////////////////////////
////////////////////// drop countries with <= 1M population ////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:m country using "$output\national_population_2020_2021_2022" 

preserve 

drop if _m==3
gen keepme=0
replace keepme=1 if _m==1
replace keepme=1 if _m==2 & year==2020 
keep if keepme==1
drop keepme 
isid country 
order country tot_pop
sort country
isid country 
compress
save "$output\ihme_location_name_exclusions" , replace

restore

keep if _m==3
drop _m

qui tab country 
di "There are `r(r)' countries"

drop if tot_pop<=1000000

drop year tot_pop
duplicates drop

count 

////////////////////////////////////////////////////////////////////////////////
///////////////////////// map on the region-income group ///////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country using "$output\regions.dta", keepusing(country WHO_region WB_income_group_1)

drop if _m==2 

replace WHO_region = "WPRO" if inlist(country,"Hong Kong","Taiwan") & _m== 1
replace WHO_region = "EMRO" if country=="Palestine" & _m== 1
replace WHO_region = "AMRO" if country == "Puerto Rico" & WHO_region == "Not Classified"

replace WB_income_group_1 = "High Income" if inlist(country,"Hong Kong","Taiwan") & _m== 1
replace WB_income_group_1 = "Middle Income" if country == "Palestine" & _m== 1 
replace WB_income_group_1 = "High Income" if country == "Puerto Rico" & WB_income_group_1 == "Not Classified"

assert WHO_region!="" 
assert WB_income_group_1!=""

assert WHO_region!="Not Classified" 
assert WB_income_group_1!="Not Classified"

drop _m 

split WB_income_group_1, parse("") gen(income_)

gen income=""
replace income="LIC" if income_1=="Low"
replace income="MIC" if income_1=="Middle"
replace income="HIC" if income_1=="High"
tab income income_1, m 

drop income_1 income_2 WB_income_group_1

gen who_income=WHO_region + "_" + income
ren income WB_income_group_1

tab who_income, m 
di "There are `r(r)' region-income groups"

compress 

save "$output\IHME_unique_countries", replace

log close 

exit 

// end
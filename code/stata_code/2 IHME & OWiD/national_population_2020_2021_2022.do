
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
1. WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
2. WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-median_variant.xlsx
*/

capture log close
log using "$output\national_population_2020_2021_2022", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// 2020 and 2021 POPULATION DATA ////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\POPULATION\WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx", ///
clear sheet("import") cellrange(C2:DH474)  first case(lower)

keep if inlist(year, 2020, 2021)
drop notes location_code iso3_code iso2_code sdmx_code type parent_code

reshape long age_, i(country year) j(age)
ren age_ pop
sort country year age
collapse (sum) tot_pop=pop, by(country year)

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

save "$output\national_population_2020_2021_2022", replace 

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// 2022 POPULATION DATA /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\POPULATION\WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-median_variant.xlsx", ///
clear sheet("import") cellrange(C2:DH474)  first case(lower)

keep if inlist(year, 2022)
drop notes location_code iso3_code iso2_code sdmx_code type parent_code

reshape long age_, i(country year) j(age)
ren age_ pop
sort country year age
collapse (sum) tot_pop=pop, by(country year)
isid country

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

append using "$output\national_population_2020_2021_2022"

// confirm that there are 3 years of data for each country
sort country year
by country: assert _N==3

// the population unit in the raw data is 1,000
replace tot_pop=tot_pop*1000

qui tab country, m 
di "There are `r(r)'"

compress
save "$output\national_population_2020_2021_2022", replace 

log close

exit

// end

set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$output\wdi_ihme_country_match", text replace

/*
inputs:
1. P_Data_Extract_From_World_Development_Indicators.xlsx
2. P_Data_Extract_From_World_Development_Indicators_per_capita_GDP.xlsx
3. WEOOct2019all_import.xlsx
4. national_population_2020_2021_2022.dta created in national_population_2020_2021_2022.do
5. IHME_unique_countries.dta created in: make_IHME_unique_countries.do
*/

////////////////////////////////////////////////////////////////////////////////
/// get final consumption and GNI per capita in 2019 USD from WDI from WDI /////
////////////////////////////////////////////////////////////////////////////////

import excel using ///
"$raw\WDI\P_Data_Extract_From_World_Development_Indicators.xlsx", ///
clear sheet("Data") cellrange(A1:E2777) first case(lower)

compress
drop if yr2019==".."
destring yr2019, replace

drop seriescode countrycode
ren countryname country

qui tab country, m 
di "There are `r(r)' countries"

replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "Faeroe Islands" if country=="Faroe Islands"
replace country = "Congo" if country=="Congo, Rep."
replace country = "Bahamas" if regexm(country,"Bahamas")
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Democratic Republic of Congo" if country=="Congo, Dem. Rep."
replace country = "Egypt" if regexm(country,"Egypt")
replace country = "Gambia" if regexm(country,"Gambia")
replace country = "Hong Kong" if regexm(country,"Hong Kong")
replace country = "Iran" if regexm(country,"Iran, Islamic Rep.")
replace country = "South Korea" if country=="Korea, Rep."
replace country = "North Korea" if country=="Korea, Dem. People's Rep."
replace country = "Kyrgyzstan" if country=="Kyrgyz Republic"
replace country = "Laos" if country=="Lao PDR"
replace country = "Macao" if regexm(country,"Macao")
replace country = "Micronesia (country)" if regexm(country,"Micronesia")
replace country = "Russia" if country=="Russian Federation"
replace country = "Slovakia" if country=="Slovak Republic"
replace country = "Saint Kitts and Nevis" if country=="St. Kitts and Nevis"
replace country = "Saint Lucia" if country=="St. Lucia"
replace country = "Saint Vincent and the Grenadines" if country=="St. Vincent and the Grenadines"
replace country = "Saint Martin" if country=="St. Martin (French part)"
replace country = "Turkey" if country=="Turkiye"
replace country = "Yemen" if country=="Yemen, Rep."
replace country = "Palestine" if country=="West Bank and Gaza"
replace country = "Venezuela" if country=="Venezuela, RB"

save "$output\wdi_data_all_countries", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// get gdp per capita in 2019 USD from WDI /////////////////////
//////////////////////////////////////////////////////////////////////////////// 

import excel using ///
"$raw\WDI\P_Data_Extract_From_World_Development_Indicators_per_capita_GDP.xlsx", ///
clear sheet("Data") cellrange(A1:E869) first case(lower)

compress
drop if yr2019==".."
destring yr2019, replace

drop seriescode countrycode
ren countryname country

qui tab country, m 
di "There are `r(r)' countries"

keep if seriesname =="GDP per capita (current US$)"

replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "Faeroe Islands" if country=="Faroe Islands"
replace country = "Congo" if country=="Congo, Rep."
replace country = "Bahamas" if regexm(country,"Bahamas")
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Democratic Republic of Congo" if country=="Congo, Dem. Rep."
replace country = "Egypt" if regexm(country,"Egypt")
replace country = "Gambia" if regexm(country,"Gambia")
replace country = "Hong Kong" if regexm(country,"Hong Kong")
replace country = "Iran" if regexm(country,"Iran, Islamic Rep.")
replace country = "South Korea" if country=="Korea, Rep."
replace country = "North Korea" if country=="Korea, Dem. People's Rep."
replace country = "Kyrgyzstan" if country=="Kyrgyz Republic"
replace country = "Laos" if country=="Lao PDR"
replace country = "Macao" if regexm(country,"Macao")
replace country = "Micronesia (country)" if regexm(country,"Micronesia")
replace country = "Russia" if country=="Russian Federation"
replace country = "Slovakia" if country=="Slovak Republic"
replace country = "Saint Kitts and Nevis" if country=="St. Kitts and Nevis"
replace country = "Saint Lucia" if country=="St. Lucia"
replace country = "Saint Vincent and the Grenadines" if country=="St. Vincent and the Grenadines"
replace country = "Saint Martin" if country=="St. Martin (French part)"
replace country = "Turkey" if country=="Turkiye"
replace country = "Yemen" if country=="Yemen, Rep."
replace country = "Palestine" if country=="West Bank and Gaza"
replace country = "Venezuela" if country=="Venezuela, RB"

append using "$output\wdi_data_all_countries"
sort country seriesname

save "$output\wdi_data_all_countries", replace

////////////////////////////////////////////////////////////////////////////////
/// get gdp per capita for South Sudan, Taiwan, and Venezuela from IMF data ////
////////////////////////////////////////////////////////////////////////////////

import excel using ///
"$raw\IMF\WEOOct2019all_import.xlsx", ///
clear sheet("import") cellrange(A1:P8731) first case(lower)
keep if inlist(country,"South Sudan","Taiwan Province of China","Venezuela")
keep if subjectdescriptor=="Gross domestic product per capita, current prices"
keep if units=="U.S. dollars"
assert scale=="Units"
keep country year_2019
ren  year_2019  yr2019
gen seriesname = "GDP per capita (current US$)"
order country seriesname yr2019
destring yr2019, replace

replace country = "Taiwan" if country=="Taiwan Province of China"

sort country 
compress
list 

append using "$output\wdi_data_all_countries"
save "$output\wdi_data_all_countries", replace

// drop countries with population <= 1M

use "$output\national_population_2020_2021_2022" , clear
keep if year==2020
ren tot_pop tot_pop_2020
drop year
merge 1:m country using "$output\wdi_data_all_countries"
list country if _m==2

keep if _m==3
drop _m 

qui tab country 
di "There are `r(r)' countries"

drop if tot_pop_2020<=1000000

qui tab country 
di "There are `r(r)' countries"

compress 
save "$output\wdi_data_countries_w_pop_gt_1M", replace

// match to the ihme countries with population >1M

use  "$output\wdi_data_countries_w_pop_gt_1M", clear 

drop if seriesname=="GDP (current US$)"
drop if seriesname=="GDP (current LCU)"
drop if seriesname=="GDP (constant 2015 US$)"
drop if seriesname=="GDP (constant LCU)"

drop if regexm(series,"constant")
drop if regexm(series,"LCU")
drop if seriesname=="Final consumption expenditure (% of GDP)"
drop if seriesname=="Final consumption expenditure (current LCU)"

gen series="", before(seriesname)
replace series="cons_current_USD"      if seriesname=="Final consumption expenditure (current US$)"
replace series="pcgni_current_USD"     if seriesname=="GNI per capita, Atlas method (current US$)"
replace series="pcgdp_current_2019USD" if seriesname=="GDP per capita (current US$)"

assert series!=""
tab series, m 
assert `r(r)' ==3 

drop seriesname
sort country series
ren yr2019 yr2019_
reshape wide yr2019_, i(country tot_pop_2020) j(series) string

sort country 
isid country
compress

// keep the IHME relevant countries

merge 1:1 country using "$output\ECONOMIC DATA\IHME_unique_countries"
assert _m!=2
drop if _m==1 
drop _m

sort country
isid country
order country tot_pop_2020 who_income WHO_region WB_income_group_1

tab who_income, m 
di "There are `r(r)' region-income groups"

compress

save "$output\wdi_ihme_country_match", replace

log close 

exit

// end
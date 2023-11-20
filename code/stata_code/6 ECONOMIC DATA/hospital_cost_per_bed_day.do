set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl knee   ".......\JK Work"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$output\ECONOMIC DATA\DIRECT COSTS\hospital_cost_per_bed_day", text replace

/*
inputs:
1. forex_2010_to_2019_jk.xlsx created by JK
2. who_choice_2010.xlsx
3. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
4. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
5. regions.dta created in: make_regions.do 
6. P_Data_Extract_From_World_Development_Indicators-GDP deflators.xlsx
7. WEOOct2019all_import.xls
8. wdi_ihme_country_match.dta created in: wdi_ihme_country_match.do
*/

////////////////////////////////////////////////////////////////////////////////
///////////////////////// get 2010 and 2019 forex //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$knee\pfizer_covid\output\forex_2010_to_2019_jk.xlsx", clear first
keep country forex_2010 forex_2019
compress 
save "$output\KNEE\forex_2010_&_2019_jk", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// WHO CHOICE outpatient cost data in 2010 nominal USD /////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\WHO CHOICE\who_choice_2010.xlsx", ///
clear sheet("outpatient_USD") cellrange(A4:B198) first case(lower)

ren healthcentrenobeds cost_per_day_mild
ren regioncountry country

compress
save "$output\ECONOMIC DATA\DIRECT COSTS\outpatient_cost_per_day", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// WHO CHOICE hospital cost data in 2010 nominal USD ///////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\WHO CHOICE\who_choice_2010.xlsx", ///
clear sheet("bed_day_USD") cellrange(A4:D198) first case(lower)

drop secondaryhospital
ren primaryhospital cost_per_day_severe
ren tertiaryhospital cost_per_day_critical
ren regioncountry country

merge 1:1 country using "$output\ECONOMIC DATA\DIRECT COSTS\outpatient_cost_per_day"
assert _m==3 
drop _m 

sort country 
order country cost_per_day_mild cost_per_day_severe cost_per_day_critical

foreach var in cost_per_day_mild cost_per_day_severe cost_per_day_critical {
	replace `var'="" if `var'=="NA"
}

foreach var in cost_per_day_mild cost_per_day_severe cost_per_day_critical {
	destring `var', replace
}

isid country
count

// drop countries with population <=1M

replace country = "Tanzania" if country=="United Republic of Tanzania"
replace country = "Eswatini" if country=="Swaziland"
replace country = "Micronesia (country)" if country=="Micronesia (Federated States of)"
replace country = "Laos" if country=="Lao People's Democratic Republic"
replace country = "Bolivia" if country=="Bolivia Plurinational States of"
replace country = "Cape Verde" if country=="Cabo Verde Republic of"
replace country = "Czechia" if country=="Czech Republic"
replace country = "Cote d'Ivoire" if country=="Côte d'Ivoire"
replace country = "Curacao" if country=="Curaçao"
replace country = "Macao" if country=="Macau, China"
replace country = "Moldova" if country=="Moldova, Republic of"
replace country = "Palestine" if country=="Occupied Palestinian Territory"
replace country = "Russia" if country=="Russian Federation"
replace country = "South Korea" if country=="Korea, Republic of"
replace country = "North Korea" if country=="Democratic People's Republic of Korea"
replace country = "Turkey" if country=="Türkiye"
replace country = "Vietnam" if country=="Viet Nam"
replace country = "Hong Kong" if country=="Hong Kong, China"
replace country = "Taiwan" if country=="Taiwan, China"
replace country = "Iran" if country=="Iran, Islamic Republic of"
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Democratic Republic of Congo" if country=="Democratic Republic of the Congo"
replace country = "South Korea" if country=="Republic of Korea"
replace country = "Iran" if country=="Iran (Islamic Republic of)"
replace country = "Moldova" if country=="Republic of Moldova"
replace country = "Russia" if country=="Russian Federation"
replace country = "North Macedonia" if country=="The former Yugoslav Republic of Macedonia"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "United States" if country=="United States of America"
replace country = "Venezuela" if country=="Venezuela (Bolivarian Republic of)"
replace country = "Vietnam" if country=="Viet Nam"

compress

gen year=2020

merge 1:m country year using "$output\national_population_2020_2021_2022" 
assert _m!=1

keep if _m==3
drop _m

drop if tot_pop<=1000000
drop tot_pop year
duplicates drop 

isid country
count

// keep the IHME relevant countries

merge 1:1 country using "$output\IHME\projections_unique_countries"

drop if _m==1 
sort country 
list country if _m==2, sep(0)

drop _m 

egen num_miss=rowmiss(cost_per_day_mild cost_per_day_severe cost_per_day_critical)
count if num_miss==3

///////////////////////// map on the region-income group ///////////////////////

merge 1:1 country using "$output\regions.dta", keepusing(country WHO_region WB_income_group_1)
drop if _m==2
tab country if _m==1

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
save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs", replace

////////////////////////////////////////////////////////////////////////////////
////////////// convert 2010 nominal USDs to 2010 nominal LCUs //////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs", clear
merge 1:1 country using "$output\KNEE\forex_2010_&_2019_jk"
keep if _m==3
drop _m 

egen numrecs = rownonmiss(forex_2010 forex_2019) 
tab numrecs, m
list country forex* if numrecs<2

foreach s in mild severe critical {
	gen `s'_2010LCU = cost_per_day_`s'*forex_2010
}

drop cost_per_day_* 

save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs", replace

////////////////////////////////////////////////////////////////////////////////
////////// convert 2010 LCUs to 2019 LCUs using GDP deflator in LCUs  //////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw/WDI/P_Data_Extract_From_World_Development_Indicators-GDP deflators.xlsx", ///
clear first sheet("Data") case(lower) cellrange(A1:O218)

ren countryname country
assert seriesname=="GDP deflator (base year varies by country)"

keep country yr2010 yr2018 yr2019

foreach y in 2010 2018 2019 {
	replace yr`y'="" if yr`y'==".."
}

foreach y in 2010 2018 2019 {
	destring yr`y', replace
}

foreach y in 2010 2018 2019 {
	ren yr`y' gdp_deflator_`y'
}

drop if inlist(country,"Bahamas, The", "Channel Islands","Virgin Islands (U.S.)")
replace country = "Cape Verde" if country=="Cabo Verde"
replace country = "Congo" if country=="Congo, Rep."
replace country = "Democratic Republic of Congo" if country=="Congo, Dem. Rep."
replace country = "Faeroe Islands" if country=="Faroe Islands"
replace country = "Gambia" if country=="Gambia, The"
replace country = "Hong Kong" if country=="Hong Kong SAR, China"
replace country = "North Korea" if country=="Korea, Dem. People's Rep."
replace country = "South Korea" if country=="Korea, Rep."
replace country = "Kyrgyzstan" if country=="Kyrgyz Republic"
replace country = "Laos" if country=="Lao PDR"
replace country = "Macao" if country=="Macao SAR, China"
replace country = "Micronesia (country)" if country=="Micronesia, Fed. Sts."
replace country = "Slovakia" if country=="Slovak Republic"
replace country = "Saint Kitts and Nevis" if country=="St. Kitts and Nevis"
replace country = "Saint Lucia" if country=="St. Lucia"
replace country = "Saint Martin (French part)" if country=="St. Martin (French part)"
replace country = "Saint Vincent and the Grenadines" if country=="St. Vincent and the Grenadines"
replace country = "Turkey" if country=="Turkiye"
replace country = "Venezuela" if country=="Venezuela, RB"
replace country = "Yemen" if country=="Yemen, Rep."
replace country = "Egypt" if country=="Egypt, Arab Rep."
replace country = "Palestine" if country=="West Bank and Gaza"
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Russia" if country=="Russian Federation"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "Iran" if regexm(country,"Iran")

compress
count 

gen year = 2020
isid country

merge 1:m country year using "$output\national_population_2020_2021_2022" 
assert _m!=1

keep if _m==3
drop _m

drop if tot_pop<=1000000
drop tot_pop year

qui tab country 
di "There are `r(r)' countries"

// keep the IHME relevant countries

merge 1:1 country using "$output\IHME\projections_unique_countries", keepusing(country)
drop if country=="Djibouti"
drop if _m==1 

// use the 2018 deflator for the 2019 deflator in Syria

replace gdp_deflator_2019 = gdp_deflator_2018 if gdp_deflator_2019==. & gdp_deflator_2018<. & country=="Syria"
drop gdp_deflator_2018

gen has_deflator=1
replace has_deflator=0 if _m==2
drop _m 

merge 1:1 country using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs"
assert _m==3 
drop _m 

compress 
save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs", replace

// get the data for Taiwan (2010, 2019), Djibouti (2010), Somalia (2011), South Sudan (2019), and Venezuela (2018) from IMF

import excel using "$raw/IMF/WEOOct2019all_import.xlsx", clear first sheet("import") case(lower) cellrange(A1:P8692)

keep if subjectdescriptor=="Gross domestic product, deflator"
assert units == "Index"
assert scale==""

replace country = "Taiwan" if country =="Taiwan Province of China" 
keep if inlist(country, "Taiwan", "Djibouti", "Somalia", "South Sudan", "Venezuela")

keep country year_2010 year_2011 year_2018 year_2019

compress 

foreach y in 2010 2011 2018 2019 {
	replace year_`y'="" if year_`y'=="n/a"
}

foreach y in 2010 2011 2018 2019 {
	destring year_`y', replace
}

replace year_2010=year_2011 if year_2010==. & year_2011<.
replace year_2019=year_2018 if year_2019==. & year_2018<.

assert year_2010<.
assert year_2019<.

keep country year_2010 year_2019

foreach y in 2010 2019 {
	ren year_`y' imf_gdp_deflator_`y'
}

isid country 
count 

merge 1:m country using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs"
drop if country=="Djibouti"
assert _m!=1 

foreach y in 2010 2019 {
	replace gdp_deflator_`y' = imf_gdp_deflator_`y' if gdp_deflator_`y' ==. &  _m==3
}

foreach y in 2010 2019 {
	drop imf_gdp_deflator_`y'
}

foreach y in 2010 2019 {
	assert gdp_deflator_`y'<. if _m==3
}

drop _m 

sort country 

assert gdp_deflator_2010<. 
assert gdp_deflator_2019<. 

sort country 
isid country 
compress
count 

save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs", replace

// calculate current 2019 LCUs by adjusting for local inflation

use "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2010LCUs", clear 

gen conversion_factor = gdp_deflator_2019/gdp_deflator_2010

foreach s in mild severe critical {
	gen `s'_current_2019LCU = `s'_2010LCU*conversion_factor
}

////////////////////////////////////////////////////////////////////////////////
//////////////// convert current 2019 LCUs to current 2019 USDs ////////////////
////////////////////////////////////////////////////////////////////////////////

foreach s in mild severe critical {
	gen cost_per_day_`s' = `s'_current_2019LCU/forex_2019 
}

/*
num_miss = 3: missing cost data
numrecs: the number of years of forex data
*/

foreach s in mild severe critical {
	assert  cost_per_day_`s' ==. if num_miss == 3
}

gen has_data=1

foreach s in mild severe critical {
	replace has_data=0 if cost_per_day_`s' ==.
}

foreach s in mild severe critical {
	assert cost_per_day_`s' <. if has_data==1
}

foreach s in mild severe critical {
	assert cost_per_day_`s' ==. if has_data==0
}

keep has_data country WHO_region WB_income_group_1 who_income cost_per_day_*
order has_data country WHO_region WB_income_group_1 who_income cost_per_day_mild cost_per_day_severe cost_per_day_critical

compress 

save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2019USDs", replace

// map the per capita gdp for the imputations

use "$output\wdi_ihme_country_match", clear
keep country WHO_region WB_income_group_1 yr2019_pcgdp_current_2019USD

merge 1:1 country WHO_region WB_income_group_1 using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_2019USDs"
drop if country=="Djibouti"
assert _m==3 
drop _m 

tab has_data, m 

egen group = group(WHO_region WB_income_group_1)
sum group

order has_data group
sort group has_data country 

by group: egen numdonors=total(has_data)
tab country group if numdonors==0
assert numdonors>0

order has_data group
sort country
compress

save "$output\ECONOMIC DATA\DIRECT COSTS\wdi_direct_costs_country_match", replace

// make files for the imputations

use  "$output\ECONOMIC DATA\DIRECT COSTS\wdi_direct_costs_country_match", clear 
drop cost_per_day_severe cost_per_day_critical
save "$output\ECONOMIC DATA\DIRECT COSTS\MILD\cost_per_day_mild", replace

use  "$output\ECONOMIC DATA\DIRECT COSTS\wdi_direct_costs_country_match", clear 
drop cost_per_day_mild cost_per_day_critical
save "$output\ECONOMIC DATA\DIRECT COSTS\SEVERE\cost_per_day_severe", replace

use  "$output\ECONOMIC DATA\DIRECT COSTS\wdi_direct_costs_country_match", clear 
drop cost_per_day_mild cost_per_day_severe
save "$output\ECONOMIC DATA\DIRECT COSTS\CRITICAL\cost_per_day_critical", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// IMPUTATIONS ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

///////////// make the files of region-income group donor pools ////////////////

capture program drop matchpools
program matchpools 
version 18.0
set more off
set type double
args pool matchvar folder

use if group==`pool' using "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\`matchvar'", clear
drop WHO_region WB_income_group_1 
sort has_data country
gen needmatch=""
replace needmatch=country if has_data==0
egen index=group(needmatch)
gen keepme=0
replace keepme=1 if has_data==1 
save "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\matchpool_`pool'" , replace 

end

forvalues p = 1/14 {
	matchpools `p' cost_per_day_mild MILD
}

forvalues p = 1/14 {
	matchpools `p' cost_per_day_severe SEVERE
}

forvalues p = 1/14 {
	matchpools `p' cost_per_day_critical CRITICAL
}

clear
capture erase "$output\ECONOMIC DATA\DIRECT COSTS\MILD\cost_per_day_mild_matches.dta"
save          "$output\ECONOMIC DATA\DIRECT COSTS\MILD\cost_per_day_mild_matches.dta", replace emptyok

clear
capture erase "$output\ECONOMIC DATA\DIRECT COSTS\SEVERE\cost_per_day_severe_matches.dta"
save          "$output\ECONOMIC DATA\DIRECT COSTS\SEVERE\cost_per_day_severe_matches.dta", replace emptyok

clear
capture erase "$output\ECONOMIC DATA\DIRECT COSTS\CRITICAL\cost_per_day_critical_matches.dta"
save          "$output\ECONOMIC DATA\DIRECT COSTS\CRITICAL\cost_per_day_critical_matches.dta", replace emptyok

////////////////////////////////////////////////////////////////////////////////
///// nn matching by yr2019_pcgdp_current_2019USD in region-income pools ///////
////////////////////////////////////////////////////////////////////////////////

capture program drop matchme
program matchme 
version 18.0
set more off
set type double 
args pool matchvar folder

use "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\matchpool_`pool'" , clear
drop if yr2019_pcgdp_current_2019USD==.

levelsof index, local(enn) 
foreach n of local enn {
	use "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\matchpool_`pool'" , clear
	if numdonors>0 {
		replace keepme=1 if index==`n'	
		keep if keepme==1
		drop keepme index

		sort has_data
		assert has_data==0 if _n==1 
		assert has_data==1 if _n>1
		gen index=_n
		replace index=index-1
		order index

		levelsof index, local(cty)
		foreach c of local cty {
			gen gdp_`c' = .
			replace gdp_`c' = yr2019_pcgdp_current_2019USD if index==`c' & has_data==1
		}

		replace gdp_0 = yr2019_pcgdp_current_2019USD[1]
		assert  gdp_0 == yr2019_pcgdp_current_2019USD if has_data==0

		levelsof index, local(cty)
		foreach c of local cty {
			gen diff_`c' = .
			replace diff_`c' = abs(gdp_0 - gdp_`c') if index==`c' & has_data==1
		}

		gen distance=.
		levelsof index, local(cty)
		foreach c of local cty {
			replace distance = diff_`c' if index==`c' & has_data==1
		}

		egen match = min(distance)
		gen keepme=0
		replace keepme=1 if has_data==0 | match == distance
		keep if keepme==1
		drop gdp_* diff_* index distance match keepme needmatch

		sort has_data
		gen ratio=yr2019_pcgdp_current_2019USD[1]/yr2019_pcgdp_current_2019USD[2]
		replace `matchvar' = `matchvar'[_n+1] if has_data==0
		gen match=country[_n+1] if has_data==0
		keep if has_data==0	
		append using "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\`matchvar'_matches"
		sort group country 
		compress 
		save         "$output\ECONOMIC DATA\DIRECT COSTS\\`folder'\\`matchvar'_matches", replace
	}	
}

end 

forvalues p = 1/14 {
	matchme `p' cost_per_day_mild MILD
}

forvalues p = 1/14 {
	matchme `p' cost_per_day_severe SEVERE
}

forvalues p = 1/14 {
	matchme `p' cost_per_day_critical CRITICAL
}

////////////////////////////////////////////////////////////////////////////////
////// adjust imputed variable by the ratio of own to donor pcgdp_current //////
////////////////////////////////////////////////////////////////////////////////

use  "$output\ECONOMIC DATA\DIRECT COSTS\SEVERE\cost_per_day_severe_matches", clear
merge 1:1 has_data group country yr2019_pcgdp_current_2019USD yr2019_pcgdp_current_2019USD numdonors ratio match ///
using "$output\ECONOMIC DATA\DIRECT COSTS\CRITICAL\cost_per_day_critical_matches"
assert _m==3 
drop _m 
merge 1:1 has_data group country yr2019_pcgdp_current_2019USD yr2019_pcgdp_current_2019USD numdonors ratio match ///
using "$output\ECONOMIC DATA\DIRECT COSTS\MILD\cost_per_day_mild_matches"
assert _m==3 
drop _m 

sort country 
order has_data group country yr2019_pcgdp_current_2019USD numdonors match ratio cost_per_day_severe cost_per_day_mild cost_per_day_severe cost_per_day_critical

assert cost_per_day_mild<.
assert cost_per_day_severe<.
assert cost_per_day_critical<. 
assert ratio<.
sum ratio, d

replace cost_per_day_mild = cost_per_day_mild*ratio
replace cost_per_day_severe = cost_per_day_severe*ratio
replace cost_per_day_critical = cost_per_day_critical*ratio
drop ratio match

merge 1:1 has_data group country yr2019_pcgdp_current_2019USD yr2019_pcgdp_current_2019USD numdonors using ///
"$output\ECONOMIC DATA\DIRECT COSTS\wdi_direct_costs_country_match"
assert _m!=1 
assert has_data==0 if _m==3
drop _m numdonors has_data group yr2019_pcgdp_current_2019USD

assert cost_per_day_mild<.
assert cost_per_day_severe<.
assert cost_per_day_critical<.

ren cost_per_day_mild     cost_per_bed_day_mild
ren cost_per_day_severe   cost_per_bed_day_severe
ren cost_per_day_critical cost_per_bed_day_critical

sort country 
isid country
count 

compress

save "$output\ECONOMIC DATA\DIRECT COSTS\hospital_cost_per_bed_day_2019USD", replace

log close 

exit 

// end
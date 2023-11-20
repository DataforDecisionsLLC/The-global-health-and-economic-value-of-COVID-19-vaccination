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
1. Szende et al.-2014-EQ-5D Index Population Norms-import.xlsx
2. WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx
3. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
4. IHME_unique_countries.dta created in: make_IHME_unique_countries.do
*/

capture log close
log using "$output\QALY\make_baseline_health_utility", text replace

////////////////////////////////////////////////////////////////////////////////
///////////// get the Szende et al. 2014 baseline health utilities /////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\HEALTH UTILITIES\Szende et al.-2014-EQ-5D Index Population Norms-import.xlsx", ///
clear sheet("Table 3.5. import") cellrange(B3:I31) first case(lower) allstring

drop if inlist(country,"Regional","Spain-Canary Islands","Spain – Catalunya","Sweden – Stockholm county","UK-England")
replace country="United States" if country=="US" 
replace country="United Kingdom" if country=="UK" 
replace country="South Korea" if country=="Korea" 

isid country 
reshape long age_, i(country) j(age_group) string
ren age_ util_ 
replace util_ = "" if util_=="N/A"
destring util_, replace
list if util_==., sep(0)

sort country age_group 
by country: assert age_group=="75_100" if _n==_N
by country: replace util_ = util_[_n-1] if util_==. & age_group=="75_100" & age_group[_n-1]=="65_74"
by country: assert age_group=="18_24" if _n==1
by country: replace util_ = util_[_n+1] if util_==. & age_group=="18_24" & age_group[_n+1]=="25_34"

assert util_<.

reshape wide util_, i(country) j(age_group) string

compress 
save "$output\QALY\szende_raw", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////// get life expectancy at birth ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\LIFE TABLES\WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx", ///
clear sheet("import") cellrange(C3:W166855)  first case(lower)

ren location country
keep country year age e 

keep if year==2019
keep if age==0
ren e le_birth_2019
isid country 
drop year age

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

// drop countries with population <= 1M

merge 1:m country using "$output\national_population_2020_2021_2022" 
assert _m==3
drop _m
keep if year==2020

drop if tot_pop<=1000000
drop tot_pop year

qui tab country
di "There are `r(r)' unique countries with population > 1M"

// keep the IHME relevant countries

merge m:1 country using "$output\ECONOMIC DATA\IHME_unique_countries", keepusing(country)
assert _m!=2
drop if _m==1 
assert _m==3 
drop _m 

qui tab country
di "There are `r(r)' unique IHME countries"

sort country 
compress 

save "$output\LIFE TABLES\life_expectancy_birth_2019", replace

////////////////////////////////////////////////////////////////////////////////
///////// identify ihme countries that are missing health utilities ////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\QALY\szende_raw", clear
merge 1:1 country using "$output\LIFE TABLES\life_expectancy_birth_2019"
assert _m!=1 
gen has_data=0 
replace has_data=1 if _m==3 
tab _m has_data, m 
drop _m 

sort has_data country
gen needmatch=""
replace needmatch=country if has_data==0
egen index=group(needmatch)
gen keepme=0
replace keepme=1 if has_data==1 
save "$output\QALY\le_birth_matchpool", replace 

////////////////////////////////////////////////////////////////////////////////
// map each country that is missing health utilility to the nearest country ////
///////////////// with respect to life excpectancy at birth ////////////////////
////////////////////////////////////////////////////////////////////////////////

clear
capture erase "$output\QALY\le_birth_matches.dta"
save          "$output\QALY\le_birth_matches", replace emptyok

use "$output\QALY\le_birth_matchpool", clear

levelsof index, local(enn) 
foreach n of local enn {
	use "$output\QALY\le_birth_matchpool" , clear
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
		gen le_`c' = .
		replace le_`c' = le_birth_2019 if index==`c' & has_data==1
	}

	replace le_0 = le_birth_2019[1]
	assert  le_0 == le_birth_2019 if has_data==0

	levelsof index, local(cty)
	foreach c of local cty {
		gen diff_`c' = .
		replace diff_`c' = abs(le_0 - le_`c') if index==`c' & has_data==1
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
	ren le_birth_2019 matchvar
	drop le_* diff_* index distance match keepme needmatch
	ren matchvar le_birth_2019
	
	sort has_data
	foreach matchvar in util_18_24 util_25_34 util_35_44 util_45_54 util_55_64 util_65_74 util_75_100 {
		replace `matchvar' = `matchvar'[_n+1] if has_data==0
	}
	
	gen match=country[_n+1] if has_data==0
	keep if has_data==0	
	
	append using "$output\QALY\le_birth_matches.dta"
	sort country 
	compress 
	save         "$output\QALY\le_birth_matches.dta", replace
}	

use "$output\QALY\le_birth_matches.dta", clear

sort country 
foreach matchvar in util_18_24 util_25_34 util_35_44 util_45_54 util_55_64 util_65_74 util_75_100 {
	assert `matchvar' <.
}

merge 1:1 has_data country le_birth_2019 using "$output\QALY\le_birth_matchpool"
assert _m!=1 
assert has_data==0 if _m==3

drop _m match keepme index needmatch has_data le_birth_2019

foreach matchvar in util_18_24 util_25_34 util_35_44 util_45_54 util_55_64 util_65_74 util_75_100 {
	assert `matchvar' <.
}

sort country 
isid country
count 

compress

save "$output\QALY\baseline_health_utility", replace

log close 

exit 

// end

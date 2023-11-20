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
1. WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
3. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
4. 2019_qaly_adj_le.dta created in: make_2019_qaly_adjusted_discounted_le.do
5. age_buckets_qaly_losses.xlsx created by JK
6. COVerAGE_quarterly_death_age_structures.dta created in: COVerAGE_quarterly_death_age_structures.do
*/

capture log close
log using "$output\QALY\make_qaly_losses_per_fatal_case", text replace

////////////////////////////////////////////////////////////////////////////////
//// create population weights using the number of survivors in life tables ////
///////////////// based on the Szende et al. 2014 age groups ///////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\LIFE TABLES\WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx", ///
clear sheet("import") cellrange(C3:W166855)  first case(lower)

keep location year age survivors_l

ren location country

keep if year==2019
tab year, m 
drop year

ren survivors_l survivors_

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

sort country age 
reshape wide survivors_, i(country) j(age) 
compress 

// drop countries with population <= 1M

merge 1:m country using "$output\national_population_2020_2021_2022" 
assert _m==3
drop _m
keep if year==2020

drop if tot_pop<=1000000
drop tot_pop

qui tab country
di "There are `r(r)' unique countries with population > 1M"

// keep the IHME relevant countries

merge m:1 country using "$output\IHME\projections_unique_countries", keepusing(country)
assert _m!=2
drop if _m==1 
assert _m==3 
drop _m year

qui tab country
di "There are `r(r)' unique IHME countries"

reshape long survivors_, i(country) j(age) 

ren survivors_ survivors_2019

sort country age 

gen cuts = irecode(age, 14, 24, 34, 44, 54, 64, 74)

forvalues a = 0/7 {
	di "*****The age cut is `a'*****"
	sum age if cuts==`a'
}

sort country cuts age 
by country cuts: egen total_pop=total(survivors_2019)
by country cuts: egen age_group = min(age)
gen wt = survivors_2019/total_pop

drop cuts survivors_2019 total_pop
sort country age 

compress

qui tab country
di "There are `r(r)' unique IHME countries"

save "$output\QALY\population_weights", replace 

////////////////////////////////////////////////////////////////////////////////
// aggregate the qaly-adjusted discounted life expectancy to the age groups ////
//////////////////// in age groups in Szende et al. 2014 ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\QALY\2019_qaly_adj_le", clear 

gen cuts = irecode(age, 14, 24, 34, 44, 54, 64, 74)

sort country year cuts age 
by country year cuts: egen age_group = min(age)
drop cuts 

merge m:1 country age_group age using "$output\QALY\population_weights"
drop if country=="Djibouti"
assert _m==3 
drop _m 
order country year age_group age 
sort  country year age_group age  
by country year age_group : egen wt_qaly = total(wt*qaly)
by country year age_group : keep if _n==1
assert age == age_group 
drop age qaly wt

qui tab country
di "There are `r(r)' unique IHME countries"

compress

drop year 

save "$output\QALY\wtd_baseline_qaly", replace 

////////////////////////////////////////////////////////////////////////////////
//// compute the portion of deaths in each Szende et al. 2014 age group ////////
////////////////////////////////////////////////////////////////////////////////

use "$output\COVerAGE_quarterly_death_age_structures", clear
gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
order country year quarter yyyy_qq 

// confirm that the proportions sum to one
drop check originally data_source nobs
egen check = rowtotal(prop_0 prop_15 prop_25 prop_35 prop_45 prop_55 prop_65 prop_75)
sum check, d
assert abs(1-check)<.0000001
drop check

reshape long prop_, i(country year quarter yyyy_qq) j(age_group)
sort country year quarter age_group 
ren prop_ prop

merge m:1 country age_group using "$output\QALY\wtd_baseline_qaly"
drop if country=="Djibouti"
assert _m==3 
drop _m 
sort country year quarter age_group 
by country year quarter : egen total_qaly=total(prop*wt_qaly)
by country year quarter : keep if _n==1
drop age_group prop wt_qaly
isid  country year quarter 
sort  country year quarter

ren total_qaly fatal_qaly

save "$output\QALY\qaly_losses_per_fatal_case", replace 

log close 

exit 

// end



set more off
clear all
set type double
version 18.0

/*
inputs:
1. Productivity costs-Di Fusco 2022.xlsx
2. WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
3. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do 
4. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
5. hospital_cost_per_bed_day_2019USD.dta created in: hospital_cost_per_bed_day.do 
6. severity_splits.dta created in: make_severity_splits.do
*/

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD", text replace

////////////////////////////////////////////////////////////////////////////////
///////// get LOS for general ward and ICU from Di Fusco 2021 Table 2 //////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\INDIRECT COSTS\Productivity costs-Di Fusco 2022.xlsx", ///
clear sheet("los") cellrange(A2:I9) first case(lower)

keep age los_ward los_icu
drop if mi(age)
replace age = "0-17" if age=="12-17"
replace age = "75-100" if age=="75+"

compress

save "$output\ECONOMIC DATA\INDIRECT COSTS\los", replace

////////////////////////////////////////////////////////////////////////////////
//// construct population weights for age groups used in Di Fusco 2022 /////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\POPULATION\WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx", ///
clear sheet("import_2") cellrange(C2:DH238)  first case(lower)
assert year==2019
keep country age_*
isid country
compress

reshape long age_, i(country) j(age)
ren age_ pop
sort country age
by country: egen tot_pop=total(pop)

gen cuts = irecode(age,17,29,49,64,74)
tab cuts, m

forvalues c = 0/5 {
	tab cuts if cuts==`c'
	sum age if cuts==`c'
}

order country cuts
collapse (sum) pop, by(country tot_pop cuts)

ren cuts age_group
gen share_=pop/tot_pop
sort country age_group
by country : egen check = total(share_)
sum check, d
drop check pop tot_pop

reshape wide share_, i(country) j(age_group)
isid country

drop if country=="Channel Islands"
drop if regexm(country,"Samoa")
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

isid country

count

// drop countries with population <= 1M

gen year = 2020

merge 1:1 country year using "$output\national_population_2020_2021_2022" 

keep if _m==3
drop _m

drop if tot_pop<=1000000
drop tot_pop year

count

// keep the IHME relevant countries

merge 1:1 country using "$output\IHME\projections_unique_countries"
assert _m!=2 
drop if _m==1 
drop _m 

sort country 
isid country 
count 

reshape long share_, i(country) j(age_group)

gen age="" 
replace age="0-17"  if age_group==0
replace age="18-29"  if age_group==1
replace age="30-49"  if age_group==2
replace age="50-64"  if age_group==3
replace age="65-74"  if age_group==4
replace age="75-100" if age_group==5
assert age!=""
tab age age_group, m 
drop age_group 
ren share_ share

compress 
save "$output\ECONOMIC DATA\DIRECT COSTS\population_weights_Di_Fusco", replace 

////////////////////////////////////////////////////////////////////////////////
//// map population weights to WHO CHOICE hospital cost per bed day data ///////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\DIRECT COSTS\population_weights_Di_Fusco", clear
merge m:1 country using "$output\ECONOMIC DATA\DIRECT COSTS\hospital_cost_per_bed_day_2019USD"
assert _m==3 
drop _m 
sort country age 

////////////////////////////////////////////////////////////////////////////////
/////////// map to LOS and construct population-weighted average LOS ///////////
////////////////////////////////////////////////////////////////////////////////

merge m:1 age using "$output\ECONOMIC DATA\INDIRECT COSTS\los"
assert _m==3 
drop _m 

sort country age 
isid country age

foreach los in los_ward los_icu {
	by country: egen avg_`los' = total(`los'*share)
}

sum avg_los_ward, d 
sum avg_los_icu, d 

drop share age los_ward los_icu 
duplicates drop 

isid country 
order country cost_per_bed_day_mild cost_per_bed_day_severe cost_per_bed_day_critical avg_los_ward avg_los_icu

////////////////////////////////////////////////////////////////////////////////
///// multiply population-weighted average LOS to hospital cost per bed day ////
//////////////////// set outpatient utilization to 1 ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

gen cost_per_day_mild  = cost_per_bed_day_mild
gen cost_per_day_severe   = cost_per_bed_day_severe*avg_los_ward
gen cost_per_day_critical = cost_per_bed_day_critical*avg_los_icu
gen cost_per_day_asymp = 0

keep  country cost_per_day_asymp cost_per_day_mild cost_per_day_severe cost_per_day_critical who_income WHO_region WB_income_group_1
order country cost_per_day_asymp cost_per_day_mild cost_per_day_severe cost_per_day_critical who_income WHO_region WB_income_group_1

compress 
save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD", replace 

////////////////////////////////////////////////////////////////////////////////
//////////////////////// get the severity splits ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\INDIRECT COSTS\severity_splits", clear
keep country year quarter yyyy_qq nf_inf asymp_inf mild severe critical

// Lesotho does not have any severity splits in 2020_Q1; backfill these with 2020_Q2

sort country year quarter 

foreach s in nf_inf asymp_inf mild severe critical {
	by country: replace `s' = `s'[_n+1] if `s'==0 & `s'[_n+1]>0 & country == "Lesotho" & yyyy_qq =="2020_Q1" & yyyy_qq[_n+1] =="2020_Q2"
}

assert (asymp_inf + mild + severe + critical)==nf_inf

foreach s in nf_inf asymp_inf mild severe critical {
	assert `s'>0  & `s'<. 
}

// construct the severity weights 

gen wt_asymp    =  asymp_inf/nf_inf
gen wt_mild     = mild/nf_inf
gen wt_severe = severe/nf_inf
gen wt_critical = critical/nf_inf

// confirm that the proportions of non-fatal symptomatic cases sum to one

egen check = rowtotal(wt_asymp wt_mild wt_severe wt_critical)
sum check, d
assert abs(1-check)<.0000000000001 
drop check nf_inf

////////////////////////////////////////////////////////////////////////////////
//////////////////// map on the direct medical costs and ///////////////////////
// calculate wtd-average direct medical cost across severe and critical cases //
////////////////////////////////////////////////////////////////////////////////

keep country year quarter yyyy_qq wt_asymp wt_mild wt_severe wt_critical 
sort country year quarter
merge m:1 country using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD", ///
keepusing(country cost_per_day_asymp cost_per_day_mild cost_per_day_severe cost_per_day_critical) 
assert _m==3 
drop _m 

foreach s in asymp mild severe critical  {
	replace cost_per_day_`s'= cost_per_day_`s'*wt_`s'
}

drop wt*

egen direct_costs = rowtotal(cost_per_day_asymp cost_per_day_mild cost_per_day_severe cost_per_day_critical)

keep country year quarter yyyy_qq direct_costs
gen currency = "2019USD"

sort country year quarter 
qui tab country
di "There are `r(r)' unique countries"

compress 
save "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD", replace 


log close 

exit

// end
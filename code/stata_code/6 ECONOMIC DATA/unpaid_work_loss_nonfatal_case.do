set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
gl knee   ".......\JK Work\"
cd        "$root"

capture log close
log using "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case", text replace

/*
inputs: 
1. Productivity costs-Di Fusco 2022.xlsx
2. WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
3. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
4. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
5. time_use_processed_ihme.xlsx
6. hrly_wage_2019USD_final.dta created in: make_hrly_wage_2019USD.do 
7. severity_splits.dta created in: make_severity_splits.do
*/

////////////////////////////////////////////////////////////////////////////////
////// Use lost work days from Table S9 and S13 of Di Fusco et al 2022 /////////
///////////// for lost unpaid work days  ///////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\INDIRECT COSTS\Productivity costs-Di Fusco 2022.xlsx", ///
clear sheet("import") cellrange(A2:T9) first case(lower)

keep age dayslostoutpatient dayslostseverecase dayslostcriticalcase
drop if mi(age)

ren dayslostoutpatient mild 
ren dayslostseverecase severe
ren dayslostcriticalcase critical

/*
create the total work days lost for severe and critical pasc, decomposing 
workdays lost into those in the first year and those in the second year 
for severe pasc, the latter of which will be discounted.
*/
gen severe_pasc = 45 + severe
gen critical_pasc_y1 = 365 
gen critical_pasc_y2 = 548 + critical - 365  

replace age = "15-17" if age=="12-17"
replace age = "75-100" if age=="75+"
compress
list, sep(0)

compress
save "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_days_lost", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////// construct population weights that sum to 1 /////////////////
///////// across the age groups above based on Di Fusco et al 2022 /////////////
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
drop if age<15 

by country: egen tot_pop=total(pop)

gen cuts = irecode(age,17, 29,49,64,74)
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
replace age="15-17"  if age_group==0
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
save "$output\ECONOMIC DATA\INDIRECT COSTS\population_weights_di_Fusco_agegroups", replace

////////////////////////////////////////////////////////////////////////////////
///////////////// compute population-weighted sum of days lost for /////////////
////////// mild, severe, severe pasc, critical, and critical pasc cases ////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\INDIRECT COSTS\population_weights_di_Fusco_agegroups", clear
merge m:1 age using "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_days_lost"
assert _m==3 
drop _m 
order country age share mild severe* critical*

sort country age 

foreach s in mild severe severe_pasc critical critical_pasc_y1 critical_pasc_y2 {
	by country: egen avg_`s' = total(share*`s')
}

assert abs(10-avg_mild)<.000000001

drop age share mild severe* critical*
duplicates drop 
isid country 
sort country 

foreach s in mild severe severe_pasc critical  {
	ren avg_`s' avg_work_days_lost_`s'
}

ren avg_critical_pasc_y1 wordays_lost_critical_pasc_y1 
ren avg_critical_pasc_y2 wordays_lost_critical_pasc_y2 

compress
save "$output\ECONOMIC DATA\INDIRECT COSTS\avg_unpaid_work_days_lost_nonfatal_case", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////// compute daily unpaid work hours ////////////////////////// 
////////////////////////////////////////////////////////////////////////////////

import excel using "$knee\Time Use\time_use_processed_ihme.xlsx", clear first case(lower) 
keep country unpaidworktime
compress 
gen daily_unpaid_work_hrs=unpaid/60 
sum daily_unpaid_work_hrs, d 

keep country daily_unpaid_work_hrs

////////////////////////////////////////////////////////////////////////////////
/////////// map to hourly wage and compute daily value of unpaid work //////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country using "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD_final", keepusing(country hrly_wage_2019USD)

assert _m!=2
keep if _m==3 
drop _m 
sort country

gen daily_value_unpaid_work = daily_unpaid_work_hrs*hrly_wage_2019USD
keep country daily_value_unpaid_work

////////////////////////////////////////////////////////////////////////////////
/////////// map to average number of work days lost by severity level //////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country using "$output\ECONOMIC DATA\INDIRECT COSTS\avg_unpaid_work_days_lost_nonfatal_case"
drop if country=="Djibouti"
assert _m==3 
drop _m 
sort country
isid country

////////////////////////////////////////////////////////////////////////////////
///////////////////// map on the severity splits ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:m country using "$output\ECONOMIC DATA\INDIRECT COSTS\severity_splits", ///
keepusing(country year quarter yyyy_qq asymp_inf mild severe critical nf_inf)
assert _m==3 
drop _m 
sort country year quarter 

assert (asymp_inf + mild + severe + critical)==nf_inf

foreach s in nf_inf asymp_inf mild severe critical {
	assert `s'>0  & `s'<. if country != "Lesotho" & yyyy_qq !="2020_Q1"
}
 
gen wt_asymp    =  asymp_inf/nf_inf
gen wt_mild     = mild/nf_inf
gen wt_severe   = severe/nf_inf
gen wt_critical = critical/nf_inf
egen check = rowtotal(wt_asymp wt_mild wt_severe wt_critical)
sum check, d
assert abs(1-check)<.000000001 if nf_inf>0
drop check wt*

////////////////////////////////////////////////////////////////////////////////
// decompose severe and critical into those with and without pasc using 45.7% //
/////////////// from Di Fusco 2022 Table S9 ////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

gen severe_pasc = severe*.457
gen severe_no_pasc = severe*(1-.457)
assert abs((severe_no_pasc + severe_pasc)-severe)<.000000001
drop severe 
ren severe_no_pasc severe

gen critical_pasc = critical*.457
gen critical_no_pasc = critical*(1-.457)
assert abs((critical_no_pasc + critical_pasc)-critical)<.000000001

drop critical
ren critical_no_pasc critical

// construct the severity weights 

gen wt_asymp    =  asymp_inf/nf_inf
gen wt_mild     = mild/nf_inf
gen wt_severe = severe/nf_inf
gen wt_severe_pasc  = severe_pasc/nf_inf
gen wt_critical = critical/nf_inf
gen wt_critical_pasc = critical_pasc/nf_inf

// confirm that the proportions of non-fatal symptomatic cases sum to one

egen check = rowtotal(wt_asymp wt_mild wt_severe wt_severe_pasc wt_critical wt_critical_pasc)
sum check, d
assert abs(1-check)<.000000001 if nf_inf>0
drop check nf_inf

compress 
save "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case", replace

////////////////////////////////////////////////////////////////////////////////
// calculate discounted lost nonmarket productivity for critical pasc in year 2 //
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case", clear 

keep  country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2 
order country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2
sort country year quarter

gen prod_lost_critical_pasc_y2 = wordays_lost_critical_pasc_y2*daily_value_unpaid_work*wt_critical_pasc
gen prod_lost_critical_pasc_y2_disc = prod_lost_critical_pasc_y2/(1.03)
drop prod_lost_critical_pasc_y2

merge 1:1 country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2 ///
using "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case"
assert _m==3 
drop _m 
sort country year quarter

////////////////////////////////////////////////////////////////////////////////
////////// calculate undiscounted lost nonmarket productivity for: /////////////
/// mild, severe, severe_pasc, critical, and the first year of critical pasc ///
////////////////////////////////////////////////////////////////////////////////

foreach s in mild severe severe_pasc critical   {
	gen prod_lost_`s'= avg_work_days_lost_`s'*daily_value_unpaid_work*wt_`s'
}

gen prod_lost_critical_pasc_y1 = wordays_lost_critical_pasc_y1*daily_value_unpaid_work*wt_critical_pasc
gen prod_lost_critical_pasc =  prod_lost_critical_pasc_y1 + prod_lost_critical_pasc_y2_disc
gen prod_lost_asymp=0*wt_asymp

drop prod_lost_critical_pasc_y2_disc prod_lost_critical_pasc_y1

keep  country year quarter yyyy_qq prod_lost_* 
order country year quarter yyyy_qq prod_lost_* 

foreach s in asymp mild severe severe_pasc critical critical_pasc  {
	assert prod_lost_`s'<. if country != "Lesotho" & yyyy_qq !="2020_Q1"
}

////////////////////////////////////////////////////////////////////////////////
// calculate weighted-average lost non-market productivity across severity levels //
////////////////////////////////////////////////////////////////////////////////

egen unpaid_work_loss_nonfatal_case = rowtotal(prod_lost_asymp prod_lost_mild prod_lost_severe prod_lost_severe_pasc prod_lost_critical prod_lost_critical_pasc)

replace unpaid_work_loss_nonfatal_case=. if country == "Lesotho" & yyyy_qq =="2020_Q1"

keep country year quarter yyyy_qq unpaid_work_loss_nonfatal_case
gen currency = "2019USD"
sort country year quarter 
qui tab country
di "There are `r(r)' unique countries"

compress 
save "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case", replace


log close

exit

// end


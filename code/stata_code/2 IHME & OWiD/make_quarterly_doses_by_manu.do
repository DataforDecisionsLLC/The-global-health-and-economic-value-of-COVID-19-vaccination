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
1. Vaccine-coverage-by-manufacturer-quarterly-countries-import.xlsx
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
3. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
4. owid_raw_countries_w_pop_gt_1M.dta created in: owid_raw_countries_w_pop_gt_1M.do
*/

capture log close
log using "$output\IHME\make_quarterly_doses_by_manu", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// import the raw IHME datafile /////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw\IHME 3\Vaccine-coverage-by-manufacturer-quarterly-countries-import.xlsx", ///
clear sheet("import") first case(lower) cellrange(A2:BS1424)

compress
save "$output\IHME\Vaccine-coverage-by-manufacturer-quarterly", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////// drop countries with population <= 1M ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Vaccine-coverage-by-manufacturer-quarterly", clear

ren location_name country
keep country 
duplicates drop

drop if country=="Global"
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
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "North Korea" if country=="Democratic People's Republic of Korea"
replace country = "Laos" if country=="Lao People's Democratic Republic"
replace country = "Micronesia (country)" if country=="Micronesia (Federated States of)"
replace country = "Tanzania" if country=="United Republic of Tanzania"

compress

merge 1:m country using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3
drop _m
keep if year==2020

drop if tot_pop<=1000000
drop tot_pop year

qui tab country
di "There are `r(r)' unique countries with population > 1M"
sort country 
compress
save "$output\IHME\vax_coverage_by_manu_unique_countries_w_pop_gt_1M", replace

////////////////////////////////////////////////////////////////////////////////
/////////// identify countries in dataset 2 not in dataset 1 ///////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\vax_coverage_by_manu_unique_countries_w_pop_gt_1M", clear

// merge to the unique countries in the dataset 1

merge 1:1 country using "$output\IHME\projections_unique_countries"
assert _m!=2 
tab country if _m==1 
keep if _m==1 
drop _m 
compress
save "$output\IHME\countries_w_pop_gt_1M_in_dataset_2_not_in_dataset_1", replace

////////////////////////////////////////////////////////////////////////////////
/////////////// filter the data to countries with pop gt 1M ////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Vaccine-coverage-by-manufacturer-quarterly", clear

ren location_name country

drop if country=="Global"
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
replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "North Korea" if country=="Democratic People's Republic of Korea"
replace country = "Laos" if country=="Lao People's Democratic Republic"
replace country = "Micronesia (country)" if country=="Micronesia (Federated States of)"
replace country = "Tanzania" if country=="United Republic of Tanzania"

compress

merge m:1 country using "$output\IHME\vax_coverage_by_manu_unique_countries_w_pop_gt_1M"
assert _m!=2 
gen keepme=0 
replace keepme=1 if country=="Macao"
replace keepme=1 if _m==3
keep if keepme==1
assert _m==1 if country=="Macao"
drop _m 

sort country quarter

gen yyyy_qq = substr(quarter,1,4) + "_" + substr(quarter,6,2)
tab quarter yyyy_qq, m 
drop quarter location_id 
gen year = substr(yyyy_qq,1,4)
gen quarter = substr(yyyy_qq,7,1)
destring year, replace 
destring quarter, replace
tab yyyy_qq year, m 
tab yyyy_qq quarter, m 
order country yyyy_qq year quarter

qui tab country
di "There are `r(r)' unique countries with population > 1M"

sort country year quarter

keep country yyyy_qq year quarter total_doses *_total_doses
order country yyyy_qq year quarter total_doses pfizer_biontech_total_doses

drop if inlist(country,"Turkmenistan","North Korea")
compress
save "$output\IHME\quarterly_vaccine_coverage_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
////////////// identify countries with missing doses in 2022 ///////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_vaccine_coverage_by_manu", clear 
gen flag=0
replace flag=1 if total_doses==0 & year==2022
order flag
by country: egen look=max(flag==1)
keep if look==1 
tab country yyyy_qq if flag==1 & year==2022
di "There are `r(r)' countries with no vaccination data in 2022"

keep if flag==1 & year==2022
keep flag country yyyy_qq year quarter

qui tab country
di "There are `r(r)' unique countries with issues"

compress
save "$output\IHME\countries_w_missing_2022_vax_coverage_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
//// get IHME cumulative vax for countries with missing 2022 doses by brand ////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\countries_w_missing_2022_vax_coverage_by_manu", clear
by country: gen nobs=_N
keep country nobs 
duplicates drop

merge 1:m country using "$output\IHME\projections_countries_w_pop_gt_1M", ///
keepusing(country date cumulative_all_fully_vaccinated)
assert inlist(country,"Laos","Tajikistan") if _m==1 
keep if _m==3 
drop _m 
sort country date 
gen keepme=0 
replace keepme=1 if date==mdy(9,30,2021)
replace keepme=1 if date==mdy(12,31,2021)
replace keepme=1 if date==mdy(3,31,2022)
replace keepme=1 if date==mdy(6,30,2022)
keep if keepme==1 
drop keepme
by country: assert _N==4

gen year = year(date) 
gen quarter = quarter(date)
order nobs country date year quarter cumulative_all_fully_vaccinated

qui tab country
di "There are `r(r)' unique countries with issues"

compress
save "$output\IHME\cum_vax_countries_w_missing_2022_vax_coverage_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
////// 1. extrapolate missing Q2 2022 doses using cumulative vax growth rate ///
//////// for countries with Q1 2022 and Q2 2022 IHME cumulative vax ////////////
////////////////////////////////////////////////////////////////////////////////

use if nobs==1 using "$output\IHME\cum_vax_countries_w_missing_2022_vax_coverage_by_manu", clear 
drop if inlist(country,"Bosnia and Herzegovina", "Cote d'Ivoire", "Timor-Leste","United Arab Emirates")
ren cumulative_all_fully_vaccinated cv

drop if date==mdy(9,30,2021)

sort country date 

by country: assert date==mdy(12,31,2021) if _n==1
by country: assert date==mdy(3,31,2022)  if _n==2
by country: assert date==mdy(6,30,2022)  if _n==3

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_vaccine_coverage_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q2 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q2=., before(`var'_total_doses)
}

replace tot_dose_2022_Q2 = total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q2 = `var'_total_doses*(1+growth) if yyyy_qq=="2022_Q1"
}

by country: replace total_doses=tot_dose_2022_Q2[_n-1] if total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & tot_dose_2022_Q2[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q2[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & `var'_dose_2022_Q2[_n-1]<.
}

drop *_dose_2022_Q2 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q2"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_vaccine_coverage_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q2" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q2" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m
compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
////// 2. extrapolate missing Q2 2022 doses using cumulative vax growth rate ///
//////////// for countries without Q2 2022 IHME cumulative vax /////////////////
////////////////////////////////////////////////////////////////////////////////

use if nobs==1 & country=="Bosnia and Herzegovina" using ///
"$output\IHME\cum_vax_countries_w_missing_2022_vax_coverage_by_manu", clear 

ren cumulative_all_fully_vaccinated cv

sort country date 
by country: assert date==mdy(9,30,2021)  if _n==1
by country: assert date==mdy(12,31,2021) if _n==2
by country: assert date==mdy(3,31,2022)  if _n==3
by country: assert date==mdy(6,30,2022)  if _n==4

assert cv[4]==cv[3]

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_vaccine_coverage_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q2 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q2 = . , before(`var'_total_doses)
}

replace tot_dose_2022_Q2 = total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q2 = `var'_total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
}

by country: replace total_doses=tot_dose_2022_Q2[_n-1] if total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & tot_dose_2022_Q2[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q2[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & `var'_dose_2022_Q2[_n-1]<.
}

drop *_dose_2022_Q2 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q2"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q2" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q2" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m 
compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
///// 3. extrapolate missing Q1 2022 doses for countries missing Q1 & Q2 2022 //
////////////////////////////////////////////////////////////////////////////////

use if nobs==2 using "$output\IHME\cum_vax_countries_w_missing_2022_vax_coverage_by_manu", clear 
drop if inlist(country,"Bosnia and Herzegovina", "Cote d'Ivoire", "Timor-Leste","United Arab Emirates")
ren cumulative_all_fully_vaccinated cv

sort country date 
by country: assert date==mdy(9,30,2021)  if _n==1
by country: assert date==mdy(12,31,2021) if _n==2
by country: assert date==mdy(3,31,2022)  if _n==3
by country: assert date==mdy(6,30,2022)  if _n==4

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_vaccine_coverage_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q1 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q1 = . , before(`var'_total_doses)
}

replace tot_dose_2022_Q1 = total_doses*(1+growth) if yyyy_qq=="2021_Q4" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q1 = `var'_total_doses*(1+growth) if yyyy_qq=="2021_Q4" 
}

by country: replace total_doses=tot_dose_2022_Q1[_n-1] if total_doses==0 & yyyy_qq=="2022_Q1" & yyyy_qq[_n-1]=="2021_Q4" & tot_dose_2022_Q1[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q1[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q1" & yyyy_qq[_n-1]=="2021_Q4" & `var'_dose_2022_Q1[_n-1]<.
}

drop *_dose_2022_Q1 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q1"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q1" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q1" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m

compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
///// 4. extrapolate missing Q2 2022 doses for countries missing Q1 & Q2 2022 /////
///////////// that show growth in cumulative vax in Q2 2022 ////////////////////
////////////////////////////////////////////////////////////////////////////////

use if nobs==2 using "$output\IHME\cum_vax_countries_w_missing_2022_vax_coverage_by_manu", clear 
drop if inlist(country,"Bosnia and Herzegovina", "Cote d'Ivoire", "Timor-Leste","United Arab Emirates")
drop if inlist(country,"Cambodia", "Kazakhstan")
ren cumulative_all_fully_vaccinated cv

drop if date==mdy(9,30,2021)

sort country date 
by country: assert date==mdy(12,31,2021) if _n==1
by country: assert date==mdy(3,31,2022)  if _n==2
by country: assert date==mdy(6,30,2022)  if _n==3

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q2 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q2 = . , before(`var'_total_doses)
}

replace tot_dose_2022_Q2 = total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q2 = `var'_total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
}

by country: replace total_doses=tot_dose_2022_Q2[_n-1] if total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & tot_dose_2022_Q2[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q2[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & `var'_dose_2022_Q2[_n-1]<.
}

drop *_dose_2022_Q2 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q2"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q2" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q2" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m

compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// get OWID cumulative vax //////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\countries_w_missing_2022_vax_coverage_by_manu", clear
keep country 
duplicates drop 

merge 1:m country using "$output\owid_raw_countries_w_pop_gt_1M", ///
keepusing(country year quarter yyyy_qq date people_vaccinated)

assert _m!=1 
keep if _m==3 
drop _m 

qui tab country
di "There are `r(r)' unique countries with issues"

drop if yyyy_qq == "2022_Q3"
drop if year==2020 & quarter<4
tab yyyy_qq, m 
assert `r(r)'==7

drop if people_vaccinated==.
sort country year quarter date 
by country: assert people_vaccinated>=people_vaccinated[_n-1] if _n>1
by country year quarter: keep if _n==_N 
sort country year quarter 
ren people_vaccinated qtrly_owid_cum_vaxed
compress 
save "$output\owid_qtrly_cum_vaccinated", replace

// filter the OWID file to the countries with missing Q1 and/or Q2 vaccinations in both IHME datasets

use "$output\IHME\countries_w_missing_2022_vax_coverage_by_manu", clear 
gen keepme=0 
replace keepme=1 if inlist(country,"Bosnia and Herzegovina","Cambodia","Cote d'Ivoire","Kazakhstan","Timor-Leste","United Arab Emirates")
replace keepme=1 if inlist(country,"Laos","Tajikistan")
keep if keepme==1
keep country 
duplicates drop 
count 

merge 1:m country using "$output\owid_qtrly_cum_vaccinated"
assert _m!=1 
keep if _m==3 
drop _m 
sort country year quarter
compress 
save "$output\IHME\owid_cum_vax_countries_w_missing_2022_ihme_data", replace

////////////////////////////////////////////////////////////////////////////////
///////// 5. extrapolate missing Q2 2022 doses for the following cases: ////////
// 1. missing Q1 & Q2 2022; IHME derived growth in Q1 2022 but not in Q2 2022 //
// 2. missing Q2 2022; no IHME derived growth in Q2 2022 ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\owid_cum_vax_countries_w_missing_2022_ihme_data", clear 
keep if inlist(country,"Cambodia","Kazakhstan","Timor-Leste","Laos","Tajikistan")
keep if year==2022 | year==2021 & quarter==4

sort country date 
by country: assert year==2021 & quarter==4 if _n==1
by country: assert year==2022 & quarter==1 if _n==2
by country: assert year==2022 & quarter==2 if _n==3

ren qtrly_owid_cum_vaxed cv

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using  "$output\IHME\quarterly_doses_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q2 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q2 = ., before(`var'_total_doses)
}

replace tot_dose_2022_Q2 = total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q2 = `var'_total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
}

by country: replace total_doses=tot_dose_2022_Q2[_n-1] if total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & tot_dose_2022_Q2[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q2[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & `var'_dose_2022_Q2[_n-1]<.
}

drop *_dose_2022_Q2 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q2"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q2" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q2" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m
compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
///// 6. extrapolate missing Q1 2022 doses for countries missing Q1 & Q2 2022 //
//////////////////////// in IHME datasets 1 and 2 //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\owid_cum_vax_countries_w_missing_2022_ihme_data", clear 
keep if inlist(country,"Cote d'Ivoire","United Arab Emirates")
drop if year==2021 & quarter<3

sort country date 
by country: assert year==2021 & quarter==3 if _n==1
by country: assert year==2021 & quarter==4 if _n==2
by country: assert year==2022 & quarter==1 if _n==3
by country: assert year==2022 & quarter==2 if _n==4

ren qtrly_owid_cum_vaxed cv

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_vaccine_coverage_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q1 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q1 = . , before(`var'_total_doses)
}

replace tot_dose_2022_Q1 = total_doses*(1+growth) if yyyy_qq=="2021_Q4" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q1 = `var'_total_doses*(1+growth) if yyyy_qq=="2021_Q4" 
}

by country: replace total_doses=tot_dose_2022_Q1[_n-1] if total_doses==0 & yyyy_qq=="2022_Q1" & yyyy_qq[_n-1]=="2021_Q4" & tot_dose_2022_Q1[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q1[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q1" & yyyy_qq[_n-1]=="2021_Q4" & `var'_dose_2022_Q1[_n-1]<.
}

drop *_dose_2022_Q1 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q1"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1
sort country year quarter

replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q1" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q1" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m

compress 
save "$output\IHME\quarterly_doses_by_manu", replace

////////////////////////////////////////////////////////////////////////////////
///// 7. extrapolate missing Q2 2022 doses for countries missing Q1 & Q2 2022 //
//////////////////////// in IHME datasets 1 and 2 //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\owid_cum_vax_countries_w_missing_2022_ihme_data", clear 
keep if inlist(country,"Cote d'Ivoire","United Arab Emirates")

drop if year==2021 & quarter<4

sort country date 
by country: assert year==2021 & quarter==4 if _n==1
by country: assert year==2022 & quarter==1 if _n==2
by country: assert year==2022 & quarter==2 if _n==3

ren qtrly_owid_cum_vaxed cv

by country: gen a = cv[3]-cv[2]
by country: gen b = cv[2]-cv[1]
gen growth=(a-b)/b

keep country growth
duplicates drop 

merge 1:m country using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1
keep if _m==3 
drop _m 
sort country year quarter

gen tot_dose_2022_Q2 = . , before(total_doses)
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	gen `var'_dose_2022_Q2 = . , before(`var'_total_doses)
}

replace tot_dose_2022_Q2 = total_doses*(1+growth) if yyyy_qq=="2022_Q1" 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_dose_2022_Q2 = `var'_total_doses*(1+growth) if yyyy_qq=="2022_Q1"
}

by country: replace total_doses=tot_dose_2022_Q2[_n-1] if total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & tot_dose_2022_Q2[_n-1]<.
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	by country: replace `var'_total_doses=`var'_dose_2022_Q2[_n-1] if `var'_total_doses==0 & yyyy_qq=="2022_Q2" & yyyy_qq[_n-1]=="2022_Q1" & `var'_dose_2022_Q2[_n-1]<.
}

drop *_dose_2022_Q2 growth
by country: assert _N==7
keep if yyyy_qq=="2022_Q2"

ren total_doses imputed_total_doses
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	ren `var'_total_doses imputed_`var'_doses
}

merge 1:1 country yyyy_qq year quarter using "$output\IHME\quarterly_doses_by_manu"
assert _m!=1

sort country year quarter
replace total_doses = imputed_total_doses if _m==3 & yyyy_qq=="2022_Q2" & total_doses==0 
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	replace `var'_total_doses = imputed_`var'_doses if _m==3 & yyyy_qq=="2022_Q2" & `var'_total_doses==0 
}

assert total_doses>0 if _m==3
foreach var in pfizer_biontech astrazeneca moderna johnson_johnson novavax sputnik_v coronavac sinopharm cansinobio covaxin other {
	assert `var'_total_doses>0 if imputed_`var'_doses>0 & _m==3
}

drop imputed_* _m

compress 
save "$output\IHME\quarterly_doses_by_manu", replace

log close 

exit 

// end

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
1. Historical-and-Projected-Covid-19-data.dta created in: make_historical_data_countries_w_pop_gt_1M.do
2. projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
3. gdp_deaths_infections.dta created in: make_quarterly_regbase.do
*/

////////////////////////////////////////////////////////////////////////////////
//////////////// get the admis_mean and icu_beds_mean veriables ////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\Historical-and-Projected-Covid-19-data", clear
ren location_name country
keep if version_name=="reference"
isid country date

keep country date admis_mean icu_beds_mean 

sort country date 

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
replace country = "Turkey" if country=="TÃ¼rkiye"

compress

merge m:1 country using "$output\IHME\projections_unique_countries"
assert _m!=2 
gen keepme=0 
replace keepme=1 if _m==3 
replace keepme=1 if country=="Macao"
keep if keepme==1 
drop _m 

qui tab country
di "There are `r(r)' unique countries with population > 1M"
sort country date

// drop records after Q2 of 2022 

gen year=year(date)
gen quarter=quarter(date)
drop if year==2023
drop if year==2022 & quarter>2 

sort country date 
by country: assert date==mdy(2,4,2020) if _n==1
by country: assert date==mdy(6,30,2022) if _n==_N

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)

codebook admis_mean icu_beds_mean

des admis_mean icu_beds_mean, varlist
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	count if `var'==.
}

// there are no missing values 

////////////////////////// aggregate to the quarter level //////////////////////

collapse (sum) admis_mean icu_beds_mean, by(country year quarter yyyy_qq)
assert admis_mean <.
assert icu_beds_mean<.

sort country year quarter
by country: assert _N==10 

compress 
save "$output\IHME\quarterly_admins_icu_beds", replace

////////////////////////////////////////////////////////////////////////////////
////////////// sum the Hong Kong and Macao hospital and icu data ///////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_admins_icu_beds", clear
keep if inlist(country,"Hong Kong","Macao")

collapse (sum) admis_mean icu_beds_mean, by(year quarter yyyy_qq)

gen country="Hong Kong + Macao"
order  country 
isid year quarter

save "$output\IHME\quarterly_admins_icu_beds_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
/////// subtract Hong Kong and Macao hospital and icu data from China //////////
////////////////////////////////////////////////////////////////////////////////

use          "$output\IHME\quarterly_admins_icu_beds", clear 
append using "$output\IHME\quarterly_admins_icu_beds_Hong_Kong_plus_Macoa"
isid country year quarter
keep if inlist(country, "Hong Kong + Macao", "China")

tab country
assert r(r)==2
compress

sort year quarter country
foreach var in admis_mean icu_beds_mean {
	by year quarter: replace `var' = `var'-`var'[_n+1] if country=="China" & country[_n+1]=="Hong Kong + Macao"
}

keep if country=="China"

compress 
save "$output\IHME\quarterly_admins_icu_beds_China", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// update the China death and infection data ///////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_admins_icu_beds", clear
drop if inlist(country, "Macao","China")
append using "$output\IHME\quarterly_admins_icu_beds_China"
sort country year quarter 
compress 
save "$output\IHME\quarterly_admins_icu_beds" , replace

///////////////////// append to the infections and deaths //////////////////////

use  "$output\IHME\gdp_deaths_infections", clear 
drop if country=="Djibouti"
drop gdp_gap 
merge 1:1 country year quarter yyyy_qq using "$output\IHME\quarterly_admins_icu_beds"
assert _m==3 
drop _m 
sort country year quarter 
compress 

des inf_mean daily_deaths admis_mean icu_beds_mean, varlist
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	count if `var'==.
}

save "$output\IHME\inf_death_admin_icu_beds", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////// construct non-fatal severity splits //////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////// construct asymtomatic vs symtomatic cases ///////////////////

use "$output\IHME\inf_death_admin_icu_beds", clear 

gen asymp_inf = inf_mean*.192
gen  symp_inf = inf_mean-asymp_inf
assert abs((symp_inf + asymp_inf) - inf_mean)<.000001

///////////////////////////// construct non-fatal cases ////////////////////////

gen nf_inf = asymp_inf - daily_deaths

/////////////////// use hospital admissions for severe cases ///////////////////

ren admis_mean severe

///////////////////////////// construct critical cases /////////////////////////

gen icu_duration = (9.6*16496 + 18.6*21632)/(16496+21632)
gen critical = icu_beds_mean/icu_duration

////////////////////// construct mild cases as the residual ////////////////////

gen mild = inf_mean - (asymp_inf + daily_deaths + severe + critical)

order country year quarter yyyy_qq inf_mean asymp_inf daily_deaths mild severe critical
compress

drop nf_inf 
gen nf_inf = asymp_inf + mild + severe + critical

save "$output\QALY\severity_splits", replace

////////////////////////////////////////////////////////////////////////////////
////////////// compute average qaly loss per non-fatal case ////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\QALY\severity_splits", clear 
drop icu_beds_mean icu_duration inf_mean symp_inf daily_deaths

///// assign non-fatal health states a qaly loss from Robinson et al. 2022 /////

gen qaly_loss_asymp    = 0 
gen qaly_loss_mild     = 0.009151
gen qaly_loss_severe   = 0.018781
gen qaly_loss_critical = 0.231753

//////// compute the weighted average qaly loss over all health states /////////

gen wt_asymp    =  asymp_inf/nf_inf
gen wt_mild     = mild/nf_inf
gen wt_severe   = severe/nf_inf
gen wt_critical = critical/nf_inf
egen check = rowtotal(wt_asymp wt_mild wt_severe wt_critical)
sum check, d
assert abs(1-check)<.000000001 if nf_inf>0
drop check

gen nf_qaly = (qaly_loss_asymp*wt_asymp) + (qaly_loss_mild*wt_mild) + (qaly_loss_severe*wt_severe) + (qaly_loss_critical*wt_critical)

order country year quarter yyyy_qq nf_qaly
compress 

isid country yyyy_qq

save "$output\QALY\qaly_losses_per_nonfatal_case", replace


set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
unpaid_work_loss_nonfatal_case_undiscounted.dta created in: unpaid_work_loss_nonfatal_case_undiscounted.do
no_cont_2_lags_death_pfizer_v_other_overall.dta created in: quarterly_death_pfizer_v_other_overall.do 
no_cont_2_lags_infections_pfizer_v_other_overall.dta created in: quarterly_infections_pfizer_v_other_overall.do
direct_costs_current_2019USD.dta created in: direct_costs_current_2019USD.do
qaly_losses_per_nonfatal_case.dta created in: make_qaly_losses_per_nonfatal_case.do
undiscounted_qaly_losses_per_fatal_case.dta created in: make_undiscounted_qaly_losses_per_fatal_case.do
no_cont_2_lags_death_pfizer_v_other_pfz.dta created in: quarterly_death_pfizer_v_other_pfz.do 
no_cont_2_lags_infections_pfizer_v_other_pfz.dta created in: quarterly_infections_pfizer_v_other_pfz.do
value_of_vax_gdp_qrtly.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
value_of_vax_gdp_annual.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
full_income.dta created in: make_full_income.do
*/

////////////////////////////////////////////////////////////////////////////////
////////// compute country-quarter total direct and indirect costs /////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case_undiscounted", clear
ren unpaid_work_loss_nonfatal_case indirect_costs_nf_case
drop currency 
compress 
save "$output\ECONOMIC DATA\INDIRECT COSTS\indirect_costs_nonfatal_case_undiscounted", replace


////////////////////////////////////////////////////////////////////////////////
//////////// compute overall averted fatal and non-fatal cases /////////////////
////////////////////////////////////////////////////////////////////////////////

use                                          "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_death_pfizer_v_other_overall", clear 
merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_infections_pfizer_v_other_overall"
assert _m==3 
drop _m 

sort country year quarter
gen averted_nf_cases_overall = averted_inf_overall - averted_death_overall

////////////////////////////////////////////////////////////////////////////////
///// map overall averted infections, fatal and non-fatal cases to costs ///////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\INDIRECT COSTS\indirect_costs_nonfatal_case_undiscounted"
drop if year==2022 
keep if  _m==3 
drop _m 

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD"
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

gen nf_indirect_cost_overall = averted_nf_cases_overall*indirect_costs_nf_case
gen direct_cost_averted_overall = averted_inf_overall*direct_costs

gen averted_cost_overall = nf_indirect_cost_overall + direct_cost_averted_overall

drop currency direct_costs indirect_costs_nf_case

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// map on the QALY gains ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter yyyy_qq using "$output\QALY\qaly_losses_per_nonfatal_case", ///
keepusing(country year quarter yyyy_qq nf_qaly)
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

merge 1:1 country year quarter yyyy_qq using "$output\QALY\undiscounted_qaly_losses_per_fatal_case", ///
keepusing(country year quarter yyyy_qq fatal_qaly)
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

gen fatal_qaly_gain = averted_death_overall*fatal_qaly 
gen nf_qaly_gain = averted_nf_cases*nf_qaly
gen qaly_gain_overall = fatal_qaly_gain + nf_qaly_gain

drop nf_qaly fatal_qaly

ren fatal_qaly_gain fatal_qaly_gain_overall
ren nf_qaly_gain nf_qaly_gain_overall 

gen brand = "Overall"
order brand

compress 
save "$root\VALUE OF VAX\value_of_vax_costs_undiscounted", replace

////////////////////////////////////////////////////////////////////////////////
//////////// compute Pfizer's averted fatal and non-fatal cases ////////////////
////////////////////////////////////////////////////////////////////////////////

use                                          "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_death_pfizer_v_other_pfz", clear 
merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_infections_pfizer_v_other_pfz"
assert _m==3 
drop _m 

sort country year quarter
gen averted_nf_cases_pfz = averted_inf_pfz - averted_death_pfz

////////////////////////////////////////////////////////////////////////////////
////// map Pfizer averted infections, fatal and non-fatal cases to costs ///////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\INDIRECT COSTS\indirect_costs_nonfatal_case_undiscounted"
drop if year==2022 
keep if  _m==3 
drop _m 

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD"
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

gen nf_indirect_cost_pfz = averted_nf_cases_pfz*indirect_costs_nf_case
gen direct_cost_averted_pfz = averted_inf_pfz*direct_costs

gen averted_cost_pfz = nf_indirect_cost_pfz + direct_cost_averted_pfz

drop currency direct_costs indirect_costs_nf_case

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// map on the QALY gains ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter yyyy_qq using "$output\QALY\qaly_losses_per_nonfatal_case", ///
keepusing(country year quarter yyyy_qq nf_qaly)
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

merge 1:1 country year quarter yyyy_qq using "$output\QALY\undiscounted_qaly_losses_per_fatal_case", ///
keepusing(country year quarter yyyy_qq fatal_qaly)
drop if year==2022 
keep if  _m==3 
drop _m 

sort country year quarter

gen fatal_qaly_gain = averted_death_pfz*fatal_qaly 
gen nf_qaly_gain = averted_nf_cases*nf_qaly
gen qaly_gain_pfz = fatal_qaly_gain + nf_qaly_gain

ren fatal_qaly_gain fatal_qaly_gain_pfz
ren nf_qaly_gain nf_qaly_gain_pfz 

gen brand = "Pfizer"
order brand

append using  "$root\VALUE OF VAX\value_of_vax_costs_undiscounted"

compress 
save "$root\VALUE OF VAX\value_of_vax_costs_undiscounted", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////// map on the GDP results  ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\value_of_vax_gdp_qrtly", clear

merge 1:1 country yyyy_qq year quarter brand using "$root\VALUE OF VAX\value_of_vax_costs_undiscounted"
assert _m!=1
drop _m 

compress 
sort brand country year quarter 
drop yyyy_qq
collapse (sum) ///
gdp_gain_overall_qrtly gdp_gain_pfz_qrtly ///
averted_death_overall averted_inf_overall averted_nf_cases_overall ///
averted_death_pfz averted_inf_pfz averted_nf_cases_pfz ///
fatal_qaly_gain_overall nf_qaly_gain_overall qaly_gain_overall ///
fatal_qaly_gain_pfz     nf_qaly_gain_pfz     qaly_gain_pfz ///
averted_cost_overall direct_cost_averted_overall nf_indirect_cost_overall  ///
averted_cost_pfz direct_cost_averted_pfz nf_indirect_cost_pfz , by(country brand)

sort brand country 
compress
isid country brand

merge 1:1 country brand using "$root\REGRESSION RESULTS\SUR\value_of_vax_gdp_annual"
tab country brand if _m==2 , m

/*
these countries are not in the infections & deaths regressions b/c they do not
have the gri variable: Armenia, Equatorial Guinea, North Macedonia
*/

drop _m 
sort country brand 
order brand country gdp_gain_overall_qrtly gdp_gain_pfz_qrtly gdp_gain_overall_annual gdp_gain_pfz_annual

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// map on full income ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge m:1 country using "$output\ECONOMIC DATA\FULL INCOME\full_income", keepusing(country yf)
assert _m!=1
keep if _m==3 
drop _m 
sort brand country

gen vov_overall = qaly_gain_overall*yf
gen vov_pfizer  =  qaly_gain_pfz*yf

order  brand country ///
vov_overall gdp_gain_overall_qrtly gdp_gain_overall_annual averted_cost_overall ///
vov_pfizer  gdp_gain_pfz_qrtly     gdp_gain_pfz_annual     averted_cost_pfz

keep  brand country ///
vov_overall averted_cost_overall ///
vov_pfizer  averted_cost_pfz ///
gdp_gain_overall_qrtly gdp_gain_overall_annual ///
gdp_gain_pfz_qrtly     gdp_gain_pfz_annual ///
fatal_qaly_gain_pfz fatal_qaly_gain_overall ///
nf_qaly_gain_pfz nf_qaly_gain_overall ///
nf_indirect_cost_pfz direct_cost_averted_pfz averted_cost_pfz ///
nf_indirect_cost_overall direct_cost_averted_overall averted_cost_overall ///
qaly_gain_overall qaly_gain_pfz ///
averted_death_overall averted_death_pfz ///
averted_inf_overall averted_inf_pfz

collapse (sum)  fatal_qaly_gain_pfz fatal_qaly_gain_overall nf_qaly_gain_pfz nf_qaly_gain_overall vov_overall vov_pfizer nf_indirect_cost_pfz direct_cost_averted_pfz averted_cost_pfz ///
nf_indirect_cost_overall direct_cost_averted_overall averted_cost_overall ///
qaly_gain_overall qaly_gain_pfz ///
averted_death_overall averted_death_pfz ///
averted_inf_overall averted_inf_pfz ///
gdp_gain_overall_qrtly gdp_gain_overall_annual ///
gdp_gain_pfz_qrtly     gdp_gain_pfz_annual  

gen Full_VoV_all    = vov_overall + gdp_gain_overall_qrtly + gdp_gain_overall_annual + averted_cost_overall
gen Full_VoV_Pfizer = vov_pfizer  + gdp_gain_pfz_qrtly     + gdp_gain_pfz_annual     + averted_cost_pfz

foreach var in vov_overall Full_VoV_all Full_VoV_Pfizer {
	format `var' %20.0gc
}

list Full_VoV_all Full_VoV_Pfizer

exit 

// end 
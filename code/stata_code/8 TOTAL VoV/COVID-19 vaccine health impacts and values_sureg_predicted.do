set more off
clear all
set type double
set linesize 225
version 18

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
no_cont_2_lags_death_pfizer_v_other_overall.dta created in: quarterly_death_pfizer_v_other_overall.do 
no_cont_2_lags_infections_pfizer_v_other_overall.dta created in: quarterly_infections_pfizer_v_other_overall.do
indirect_costs_nonfatal_case.dta created in: "COVID-19 vaccine health impacts and values_sureg_means.do"
direct_costs_current_2019USD.dta created in: direct_costs_current_2019USD.do
qaly_losses_per_nonfatal_case.dta created in: make_qaly_losses_per_nonfatal_case.do
qaly_losses_per_fatal_case.dta created in: make_qaly_losses_per_fatal_case.do
no_cont_2_lags_gdp_pfizer_v_other_overall_quarterly_gdp.dta created in: quarterly_regs_overall.do 
overall_annual_gdp.dta created in: annual_gdp_regs_overall.do
full_income.dta created in: make_full_income.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\\COVID-19 vaccine health impacts and values_sureg_predicted", text replace

////////////////////////////////////////////////////////////////////////////////
//////////// compute overall averted fatal and non-fatal cases /////////////////
////////////////////////////////////////////////////////////////////////////////

use                                          "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_death_pfizer_v_other_overall", clear 
drop averted_death_overall yhat_* predicted_novax tot_pop
ren predicted_vax averted_death_overall 

merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\no_cont_2_lags_infections_pfizer_v_other_overall", ///
keepusing(country year quarter yyyy_qq predicted_vax)
assert _m==3 
drop _m 
ren predicted_vax averted_inf_overall

sort country year quarter
gen averted_nf_cases_overall = averted_inf_overall - averted_death_overall

////////////////////////////////////////////////////////////////////////////////
///// map overall averted infections, fatal and non-fatal cases to costs ///////
////////////////////////////////////////////////////////////////////////////////

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\INDIRECT COSTS\indirect_costs_nonfatal_case"
drop if year==2022 
assert _m!=1
keep if _m==3 
drop _m 

merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD"
drop if year==2022 
assert _m!=1
keep if _m==3 
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
assert _m!=1
keep if _m==3 
drop _m 

sort country year quarter

merge 1:1 country year quarter yyyy_qq using "$output\QALY\qaly_losses_per_fatal_case", ///
keepusing(country year quarter yyyy_qq fatal_qaly)
drop if year==2022 
assert _m!=1
keep if _m==3 
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
save "$root\REGRESSION RESULTS\SUR\value_of_vax_costs_predicted", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////// quarterly GDP results  /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\no_cont_2_lags_gdp_pfizer_v_other_overall_quarterly_gdp", clear
keep country yyyy_qq year quarter gdp1 gdp_usd_projected
gen gdp_gain_overall_qrtly = gdp_usd_projected - gdp1 
drop gdp_usd_projected gdp1 
gen brand = "Overall"
order brand

compress 
save "$root\REGRESSION RESULTS\SUR\predicted_gdp_qrtly", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////////// annual GDP results ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\overall_annual_gdp", clear
keep country gdp_usd_projected vax_actual gdp_usd_projected_2020 pand_gdp_2020
gen gdp_gain_overall_annual = (gdp_usd_projected - vax_actual) + (gdp_usd_projected_2020 - pand_gdp_2020)

drop gdp_usd_projected_2020 gdp_usd_projected vax_actual pand_gdp_2020
gen brand = "Overall"
order brand

compress 
save "$root\REGRESSION RESULTS\SUR\predicted_gdp_annual", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////// combine health and GDP results //////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\predicted_gdp_qrtly", clear

merge 1:1 country yyyy_qq year quarter brand using "$root\REGRESSION RESULTS\SUR\value_of_vax_costs_predicted"
assert _m!=1
drop _m 

compress 
sort brand country year quarter 
drop yyyy_qq

collapse (sum) ///
gdp_gain_overall_qrtly ///
averted_death_overall averted_inf_overall averted_nf_cases_overall ///
fatal_qaly_gain_overall nf_qaly_gain_overall qaly_gain_overall ///
averted_cost_overall direct_cost_averted_overall nf_indirect_cost_overall fatal_indirect_cost_overall, by(country brand) 

sort brand country 
compress
isid country brand

merge 1:1 country brand using "$root\REGRESSION RESULTS\SUR\predicted_gdp_annual"
tab country brand if _m==2 , m
drop _m 

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// map on full income ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

merge m:1 country using "$output\ECONOMIC DATA\FULL INCOME\full_income", keepusing(country yf)
assert _m!=1
keep if _m==3 
drop _m 
sort brand country

gen vov_overall = qaly_gain_overall*yf
order  brand country ///
vov_overall gdp_gain_overall_qrtly gdp_gain_overall_annual averted_cost_overall

keep  brand country ///
vov_overall gdp_gain_overall_qrtly gdp_gain_overall_annual averted_cost_overall ///
qaly_gain_overall ///
fatal_qaly_gain_overall ///
nf_qaly_gain_overall ///
nf_indirect_cost_overall direct_cost_averted_overall averted_cost_overall ///
qaly_gain_overall ///
averted_death_overall  ///
averted_inf_overall

collapse (sum) vov_overall  ///
nf_indirect_cost_overall direct_cost_averted_overall averted_cost_overall ///
qaly_gain_overall  ///
averted_death_overall  ///
averted_inf_overall  ///
gdp_gain_overall_qrtly gdp_gain_overall_annual

gen VoV_all_brands = vov_overall + gdp_gain_overall_qrtly + gdp_gain_overall_annual + averted_cost_overall

foreach var in VoV_all_brands vov_overall gdp_gain_overall_qrtly gdp_gain_overall_annual averted_cost_overall {
	format `var' %20.0gc
}

list VoV_all_brands vov_overall gdp_gain_overall_qrtly gdp_gain_overall_annual averted_cost_overall

foreach var in averted_death_overall  averted_inf_overall  {
	format `var' %20.0gc
}

foreach var in gdp_gain_overall_qrtly gdp_gain_overall_annual  {
	format `var' %20.0gc
}

format qaly_gain_overall %20.0gc

format vov_overall %20.0gc

format direct_cost_averted_overall %20.0gc
format nf_indirect_cost_overall %20.0gc
format averted_cost_overall %20.0gc

list gdp_gain_overall_qrtly gdp_gain_overall_annual

list averted_inf_overall
list averted_death_overall

list qaly_gain_overall
list vov_overall

list direct_cost_averted_overall 
list nf_indirect_cost_overal 

order ///
gdp_gain_overall_qrtly gdp_gain_overall_annual ///
averted_inf_overall  ///
averted_death_overall ///
qaly_gain_overall  ///
vov_overall ///
direct_cost_averted_overall nf_indirect_cost_overall averted_cost_overall ///
VoV_all_brands

export excel using "$root\MANUSCRIPT\tables2_and_3_formatted.xlsx", ///
first(var) sheet("DB_predicted") sheetreplace

log close 

exit 

// end 
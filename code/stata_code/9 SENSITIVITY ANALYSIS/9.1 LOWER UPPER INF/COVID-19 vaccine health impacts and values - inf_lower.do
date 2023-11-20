set more off
clear all
set type double
version 18

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
lower_death_pfizer_v_other_overall.dta 
lower_infections_pfizer_v_other_overall.dta 
indirect_costs_nonfatal_case.dta 
direct_costs_current_2019USD.dta 
qaly_losses_per_nonfatal_case.dta 
qaly_losses_per_fatal_case.dta 
lower_death_pfizer_v_other_pfz.dta 
lower_infections_pfizer_v_other_pfz.dta 
lower_gdp_pfizer_v_other_overall.dta 
lower_gdp_pfizer_v_other_pfz.dta 
lower_gdp_annual_overall.dta 
lower_gdp_annual_pfz.dta 
full_income.dta 
*/

////////////////////////////////////////////////////////////////////////////////
//////////// compute overall averted fatal and non-fatal cases /////////////////
////////////////////////////////////////////////////////////////////////////////

use                                          "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_death_pfizer_v_other_overall", clear 
merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_infections_pfizer_v_other_overall"
assert _m==3 
drop _m 

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
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_costs_lower", replace

////////////////////////////////////////////////////////////////////////////////
//////////// compute Pfizer's averted fatal and non-fatal cases ////////////////
////////////////////////////////////////////////////////////////////////////////

use                                          "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_death_pfizer_v_other_pfz", clear 
merge 1:1 country year quarter yyyy_qq using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_infections_pfizer_v_other_pfz"
assert _m==3 
drop _m 

sort country year quarter
gen averted_nf_cases_pfz = averted_inf_pfz - averted_death_pfz

////////////////////////////////////////////////////////////////////////////////
////// map Pfizer averted infections, fatal and non-fatal cases to costs ///////
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

gen fatal_qaly_gain = averted_death_pfz*fatal_qaly 
gen nf_qaly_gain = averted_nf_cases*nf_qaly
gen qaly_gain_pfz = fatal_qaly_gain + nf_qaly_gain

ren fatal_qaly_gain fatal_qaly_gain_pfz
ren nf_qaly_gain nf_qaly_gain_pfz 

gen brand = "Pfizer"
order brand

append using  "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_costs_lower"

compress 
save          "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_costs_lower", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////// map on the quarterly GDP results  //////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_pfizer_v_other_overall", clear
keep country yyyy_qq year quarter gdpdiff0
ren gdpdiff0 gdp_gain_overall_qrtly
gen brand = "Overall"
order brand

append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_pfizer_v_other_pfz", keep(country yyyy_qq year quarter gdpdiff0)
sort country year quarter 
ren gdpdiff0 gdp_gain_pfz_qrtly
replace brand = "Pfizer" if brand==""

compress 
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_gdp_qrtly", replace

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_annual_overall"
keep country gdpdiff0 
gen brand = "Overall"
order brand
ren gdpdiff0 gdp_gain_overall_annual

append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_gdp_annual_pfz", keep(country gdpdiff0)
replace brand = "Pfizer" if brand==""
ren gdpdiff0 gdp_gain_pfz_annual

compress 
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_gdp_annual", replace

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_gdp_qrtly", clear

merge 1:1 country yyyy_qq year quarter brand using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_costs_lower"
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

merge 1:1 country brand using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\value_of_vax_gdp_annual"
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
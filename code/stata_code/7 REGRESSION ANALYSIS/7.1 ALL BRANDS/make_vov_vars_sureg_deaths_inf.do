set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
1. sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
2. qaly_losses_per_nonfatal_case.dta created in: make_qaly_losses_per_nonfatal_case.do
3. qaly_losses_per_fatal_case.dta created in: make_qaly_losses_per_fatal_case.do
4. unpaid_work_loss_nonfatal_case.dta created in: unpaid_work_loss_nonfatal_case.do
5. direct_costs_current_2019USD.dta created in: direct_costs_current_2019USD.do
6. full_income.dta created in: make_full_income.do
7. quarterly_gdp_usd.dta created in: make_quarterly_gdp_usd.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_vov_vars_sureg", text replace

////////////////////////////////////////////////////////////////////////////////
//// get population, QALY gains, direct costs, indirect costs, full income /////
////////////////// and pre-pandemic projected pcpgd variable ///////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear
drop if year<2020
assert year>=2020 & year<=2021
keep country yyyy_qq year quarter tot_pop

sort country year quarter
merge 1:1 country year quarter yyyy_qq using "$output\QALY\qaly_losses_per_nonfatal_case", ///
keepusing(country year quarter yyyy_qq nf_qaly)
drop if year==2022 
keep if _m==3
drop _m 

sort country year quarter
merge 1:1 country year quarter yyyy_qq using "$output\QALY\qaly_losses_per_fatal_case", ///
keepusing(country year quarter yyyy_qq fatal_qaly)
drop if year==2022 
keep if _m==3
drop _m 

sort country year quarter
merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case", ///
keepusing(country year quarter yyyy_qq unpaid_work_loss_nonfatal_case)
drop if year==2022 
keep if _m==3
drop _m 

sort country year quarter
merge 1:1 country year quarter yyyy_qq using "$output\ECONOMIC DATA\DIRECT COSTS\direct_costs_current_2019USD"
drop if year==2022 
keep if _m==3
drop _m 

// 2019 pre-pandemic full income is at the country level

sort country year quarter
merge m:1 country using "$output\ECONOMIC DATA\FULL INCOME\full_income", keepusing(country yf)
keep if _m==3
drop _m 

sort country year quarter
merge 1:1 country yyyy_qq year quarter using "$output\ECONOMIC DATA\quarterly_gdp_usd"
assert year>=2020
drop if year>2021
keep if _m==3
assert _N==1112
drop _m 
compress 

sort country year quarter
gen rownum=_n, before(tot_pop)
drop country year quarter yyyy_qq currency
assert _N==1112
sum rownum 
assert r(max)==1112
compress 

save "$root\REGRESSION RESULTS\SUR\make_vov_vars_sureg_deaths_inf", replace

log close 

exit 

// end

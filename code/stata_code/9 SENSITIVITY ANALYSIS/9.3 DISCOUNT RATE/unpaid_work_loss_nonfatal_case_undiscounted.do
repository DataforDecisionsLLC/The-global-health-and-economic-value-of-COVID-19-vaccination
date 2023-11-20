set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
gl knee   ".......\JK Work\"
cd        "$root"

/*
time_use_processed_ihme.xlsx
hrly_wage_2019USD_final.dta created in: make_hrly_wage_2019USD.do
avg_unpaid_work_days_lost_nonfatal_case.dta created in: unpaid_work_loss_nonfatal_case.do
severity_splits.dta created in: make_severity_splits.do
output:
unpaid_work_loss_nonfatal_case_undiscounted.dta
*/

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
save "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case_undiscounted", replace

////////////////////////////////////////////////////////////////////////////////
// calculate undiscounted lost nonmarket productivity for critical pasc in year 2 //
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case_undiscounted", clear 

keep  country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2 
order country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2
sort country year quarter

gen prod_lost_critical_pasc_y2 = wordays_lost_critical_pasc_y2*daily_value_unpaid_work*wt_critical_pasc
//gen prod_lost_critical_pasc_y2_disc = prod_lost_critical_pasc_y2/(1.06)
drop prod_lost_critical_pasc_y2

merge 1:1 country year quarter daily_value_unpaid_work wt_critical_pasc wordays_lost_critical_pasc_y2 ///
using "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case_undiscounted"
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
save "$output\ECONOMIC DATA\INDIRECT COSTS\unpaid_work_loss_nonfatal_case_undiscounted", replace

exit

// end


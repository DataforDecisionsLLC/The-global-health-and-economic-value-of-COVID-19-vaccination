set more off
clear all
set type double
version 18.0
 
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
2019_qaly_adj_6pct_discounted_le.dta created in: make_2019_qaly_adjusted_6pct_discounted_le.do 
population_weights.dta created in: make_qaly_losses_per_fatal_case.do
COVerAGE_quarterly_death_age_structures.dta created in COVerAGE_quarterly_death_age_structures_5year.do
outputs:
6pct_discounted_qaly_losses_per_fatal_case.dta
*/

capture log close
log using "$output\QALY\make_6pct_discounted_qaly_losses_per_fatal_case", text replace

////////////////////////////////////////////////////////////////////////////////
// aggregate the qaly-adjusted discounted life expectancy to the age groups ////
//////////////////// in age groups in Szende et al. 2014 ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\QALY\2019_qaly_adj_6pct_discounted_le", clear 

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

save "$output\QALY\wtd_baseline_6pct_discounted_qaly", replace 

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

merge m:1 country age_group using "$output\QALY\wtd_baseline_6pct_discounted_qaly"
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

save "$output\QALY\6pct_discounted_qaly_losses_per_fatal_case", replace 

log close 

exit 

// end



set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work"
gl output "$root\DATA"
gl raw    ".......\RAW DATA"
cd        "$root"

/*
inputs:
1. baseline_health_utility.dta created in: make_baseline_health_utility.do
2. life_tables_2019.dta created in: make_life_tables_2019.do
*/

capture log close
log using "$output\QALY\make_2019_qaly_adjusted_discounted_le", text replace

////////////////////////////////////////////////////////////////////////////////
// reshape baseline health utilities to long form and expand to single ages ////
////////////////////////////////////////////////////////////////////////////////

use "$output\QALY\baseline_health_utility", clear
reshape long util_, i(country) j(age) string
// create records for ages 0-17 
gen expand = 0
replace expand=2 if age=="18_24"
expand expand
sort country age
by country: replace age="0_17" if _n==1 & age=="18_24" & expand==2
drop expand

split age, parse("_")
destring age1, replace 
destring age2, replace
gen expand = age2-age1 + 1
expand expand
ren age age_group 
gen age=age1, before(age1)
sort country age1 
by country: replace age=age[_n-1] + 1 if _n>1
by country age1: gen fobs=_n==1
assert age == age1 if fobs==1
by country: assert age==0 if _n==1 
by country: assert age==100 if _n==_N 
by country: assert _N==101

drop expand fobs age_group age1 age2 
ren util_ util 
compress
isid country age

save "$output\QALY\baseline_health_utility_single_ages", replace

////////////////////////////////////////////////////////////////////////////////
//////////////// map baseline health utilities to life tables //////////////////
////////////////////////////////////////////////////////////////////////////////
 
use "$output\QALY\baseline_health_utility_single_ages", clear
merge 1:m country age using "$output\LIFE TABLES\life_tables_2019"
drop if country=="Djibouti"
assert _m==3 
drop _m 
isid country year age 
sort country year age
keep country util age year survivors_l L
compress

save "$output\QALY\baseline_2019_health_utility_w_life_tables", replace

////////////////////////////////////////////////////////////////////////////////
////////// compute discounted qaly-adjusted life expectancy at age x ///////////
////////////////////////////////////////////////////////////////////////////////

clear 
capture erase "$output\QALY\2019_qaly_adj_le" 
save          "$output\QALY\2019_qaly_adj_le", emptyok replace 

capture program drop qaly 
program qaly 
version 18.0
set more off
set type double 
args year

use  "$output\QALY\baseline_2019_health_utility_w_life_tables", clear

keep if year==`year'
sort country year age

forvalues x = 0/100 {
	gen L_`x'=L
}

forvalues x = 0/100 {
	replace L_`x'=. if age<`x'
}

forvalues x = 0/100 {
	gen util_`x'=util
}

forvalues x = 0/100 {
	replace util_`x'=. if age<`x'
}

forvalues x = 0/100 {
	replace L_`x' = L_`x'*util_`x'
}

forvalues x = 0/100 {
	drop util_`x'
}

forvalues x = 0/100 {
	replace L_`x'= L_`x'/(1.03^(age-`x'))
}

forvalues x = 0/100 {
	by country year: egen T_`x' = total(L_`x')
}

forvalues x = 0/100 {
	gen LE_`x' = .
}

forvalues x = 0/100 {
	replace LE_`x' = T_`x'/survivors_l if age==`x'
}

gen LE=., before(survivors_l)

forvalues x = 0/100 {
	replace LE=LE_`x' if age==`x'
}

drop survivors_l L L_* T_* LE_* util
ren LE qaly

compress 

append using "$output\QALY\2019_qaly_adj_le" 
sort country year age 
save "$output\QALY\2019_qaly_adj_le" , replace 

end

qaly 2019 

use "$output\QALY\2019_qaly_adj_le" , clear
egen group=group(country)
sum group 
assert r(max) == 150
save "$output\QALY\2019_qaly_adj_le" , replace 

log close 

exit 

// end



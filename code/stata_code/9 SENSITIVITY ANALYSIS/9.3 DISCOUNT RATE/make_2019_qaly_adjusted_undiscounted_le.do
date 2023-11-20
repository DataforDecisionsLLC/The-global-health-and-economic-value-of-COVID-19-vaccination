set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"
     "$root"

/*
inputs:
baseline_2019_health_utility_w_life_tables.dta created in: make_2019_qaly_adjusted_6pct_discounted_le.do
outputs:
2019_qaly_adj_undiscounted_le.dta
*/

capture log close
log using "$output\QALY\make_2019_qaly_adjusted_undiscounted_le", text replace

////////////////////////////////////////////////////////////////////////////////
////////// compute discounted qaly-adjusted life expectancy at age x ///////////
////////////////////////////////////////////////////////////////////////////////

clear 
capture erase "$output\QALY\2019_qaly_adj_undiscounted_le" 
save          "$output\QALY\2019_qaly_adj_undiscounted_le", emptyok replace 

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

append using "$output\QALY\2019_qaly_adj_undiscounted_le" 
sort country year age 
save "$output\QALY\2019_qaly_adj_undiscounted_le" , replace 

end

qaly 2019 

use "$output\QALY\2019_qaly_adj_undiscounted_le" , clear
egen group=group(country)
sum group 
assert r(max) == 150
save "$output\QALY\2019_qaly_adj_undiscounted_le" , replace 

log close 

exit 

// end



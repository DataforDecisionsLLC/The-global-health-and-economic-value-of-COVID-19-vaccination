set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
prevax_osi.dta created in: make_sur_regbase_deaths_inf.do
*/

capture log close
log using "$root\REGRESSION RESULTS\SUR\make_X_vax_deaths_inf", text replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////// map the empty shell file /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop getshell
program getshell
version 18.0
set type double
set more off 
args country

use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_all==1
keep if country_group==`country'

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf"
keep if _m==3
drop _m 
assert country_group==`country'

// map on the pre-vax osi

merge m:1 country using "$root\REGRESSION RESULTS\SUR\prevax_osi"
keep if _m==3
drop _m 

drop L1_mean_index
replace mean_index=mean_index/100
replace prevax_osi=prevax_osi/100

replace mean_index=prevax_osi if time==launch_time
replace mean_index=prevax_osi if time>=launch_time

sort country year quarter
foreach var in mean_index {
	by country: gen L1_`var' = `var'[_n-1]
}

drop if year<2020
gen Constant=1, before(prevax_osi)

sort country year quarter

keep country_group time ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index Constant tot_pop

order country_group time ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index Constant tot_pop

order country_group time
replace country_group=1 

xpose, clear varname
order _varname
ren _varname variable
compress 

forvalues v = 1/8 {
	ren v`v' x_`=`v'+5'
}

reshape long x_, i(variable) j(time)
drop if time>6 & variable=="Constant"

replace x_=1 if variable=="time"
tostring time, replace
replace time = "0" + time if inlist(time,"1","2","3","4","5","6","7","8","9") & variable=="time"
replace variable = "time" + "_" + time if variable=="time"
destring time, replace

ren x x_`country'

sort variable time 
compress
save "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf.dta",replace

end

getshell 138
use "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf.dta", clear
drop x_138
save "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf.dta", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////// map the Xs for each country /////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop getx
program getx
version 18.0
set type double
set more off 
args country

di "***************************************************************************"
di "///////////////////// country group `country' /////////////////////////////"
di "***************************************************************************"

use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_all==1
keep if country_group==`country'

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf"
keep if _m==3
drop _m 
assert country_group==`country'

// map on the pre-vax osi

merge m:1 country using "$root\REGRESSION RESULTS\SUR\prevax_osi"
keep if _m==3
drop _m 

drop L1_mean_index
replace mean_index=mean_index/100
replace prevax_osi=prevax_osi/100

replace mean_index=prevax_osi if time==launch_time
replace mean_index=prevax_osi if time>=launch_time

sort country year quarter
foreach var in mean_index {
	by country: gen L1_`var' = `var'[_n-1]
}

drop if year<2020
gen Constant=1, before(prevax_osi)

sort country year quarter

keep country_group time ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index Constant tot_pop

order country_group time ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean      L2_cum_inf_mean ///
L1_mean_index Constant tot_pop

order country_group time
replace country_group=1 

xpose, clear varname
order _varname
ren _varname variable
compress 

qui des, varlist
local t=`r(k)'-1
di "the number of time periods is `t'"

forvalues v = 1/`t' {
	ren v`v' x_`=`v'+5'
}

reshape long x_, i(variable) j(time)
drop if time>6 & variable=="Constant"

replace x_=1 if variable=="time"
tostring time, replace
replace time = "0" + time if inlist(time,"1","2","3","4","5","6","7","8","9") & variable=="time"
replace variable = "time" + "_" + time if variable=="time"
destring time, replace

ren x x_`country'

merge 1:1 variable time using "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf.dta"
assert _m!=1
assert time > `t' + 4 if _m==2
drop _m 
sort variable time
order x_`country' , last

compress
save "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf.dta",replace

end


use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_all==1
drop if country_group==.
keep country 
merge 1:m country using "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf"
assert _m!=1
keep if _m==3
drop _m 
qui tab country 
di "There are `r(r)' countries"

forvalues c = 1/`r(r)' {
	getx `c'
}

////////////////////////////////////////////////////////////////////////////////
/////////////////////// get the 2020 and 2021 populations //////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\X_vax_deaths_inf", clear
keep if variable=="tot_pop"
reshape long x_, i(variable time) j(country_group)
sort country_group time 
keep if inlist(time, 6,10)
replace time=2020 if time==6
replace time=2021 if time==10

reshape wide x_, i(variable time) j(country_group)

forvalues c = 1/141 {
		assert x_`c'[1]!=x_`c'[2]
}

compress
save "$root\REGRESSION RESULTS\SUR\tot_pop_deaths_inf", replace

log close 

exit 

// end
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
quarterly_deaths_&_infections_lower_upper.dta created in: make_quarterly_infections_lower_upper.do
quarterly_deaths_&_infections_lower_upper_China.dta
gdp_gap_ihme.xlsx 
quarterly_vaccine_coverage_pfizer_v_other.dta created in: make_quarterly_vaccine_coverage_pfizer_v_other.do
national_population_2020_2021_2022.dta 
China_quarterly_vaccine_coverage_pfizer_v_other_v2.dta created in:  make_China_quarterly_vaccine_coverage_pfizer_v_other.do
outputs:
quarterly_regbase_infections_lower_upper.dta
*/

capture log close
log using "$output\IHME\make_quarterly_regbase_infections_lower_upper", text replace

////////////////////////////////////////////////////////////////////////////////
////////////////// update the China death and infection data ///////////////////
////////////////////////////////////////////////////////////////////////////////

                 
use "$output\IHME\quarterly_deaths_&_infections_lower_upper", clear
drop if inlist(country, "Macao","China")
append using "$output\IHME\quarterly_deaths_&_infections_lower_upper_China"
sort country year quarter 
compress 
save "$output\IHME\gdp_deaths_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
//////// map the quarterly gdp ratio variable to infections and deaths /////////
////////////////////////////////////////////////////////////////////////////////
	
import excel using "$output\KNEE\gdp_gap_ihme.xlsx", ///
clear first case(lower) 

gen year=substr(date,1,4)
gen quarter=substr(date,5,2)
tab date year, m 
tab date quarter, m

drop if year=="2019" 

gen yyyy_qq = year + "_" + quarter
tab date yyyy_qq , m

gen qtr = substr(quarter, 2,2)
destring year, replace 
destring qtr, replace
drop quarter
ren qtr quarter

drop if year==2022 & quarter>2 
drop date

keep  country year quarter yyyy_qq gdp_gap
order country year quarter yyyy_qq gdp_gap

qui tab country 
di "There are `r(r)' countries"

sort country year quarter 
by country: assert _N==10

//drop observed projected type

merge 1:1 country year quarter yyyy_qq using "$output\IHME\gdp_deaths_infections_lower_upper"
tab country if _m==1 

assert inlist(country, "Cuba","Palestine","Syria","Venezuela") if _m==2

drop _m

qui tab country 
di "There are `r(r)' countries"

sort country year quarter 
by country: assert _N==10

order country yyyy_qq year quarter gdp_gap daily_deaths inf_mean inf_lower inf_upper 

compress

save "$output\IHME\gdp_deaths_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// map the vaccination variables ////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_vaccine_coverage_pfizer_v_other", clear
assert !inlist(country, "China", "Macao")

// confirm there are no missing values for doses

des, varlist 
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	capture count if `var'==.
	if _rc==0 {
		assert r(N)==0
	}
	else if _rc>0 {
		count if `var'==""
		assert r(N)==0
	}
}

merge 1:1 country year quarter yyyy_qq using "$output\IHME\gdp_deaths_infections_lower_upper"
drop if inlist(country,"China","Macao","North Korea","Turkmenistan")
assert year==2020 & quarter<4 if _m==2 

// recode doses to zero prior to Q4 2020

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	replace `var' = 0 if `var' == . & _m==2
}

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	assert `var'==0 if year==2020 & quarter<4
}

drop _m 

order country yyyy_qq year quarter gdp_gap daily_deaths inf_mean inf_lower inf_upper

sort country year quarter 
by country: assert _N==10
qui tab country
di "There are `r(r)' unique countries with population > 1M"
compress

save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
/////////////// compute per capita measures of covid variables /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase_infections_lower_upper", clear
merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3 
drop _m 

assert tot_pop<. & tot_pop>1000000

foreach var in daily_deaths inf_mean inf_lower inf_upper total_doses pfizer other cum_total_doses cum_pfizer cum_other {
	replace `var'=`var'/tot_pop
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper total_doses pfizer other cum_total_doses cum_pfizer cum_other {
	sum `var', d
}

sort country year quarter 

qui tab country 
di "There are `r(r)' countries"
compress 

save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////////////// create the China regbase  /////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\China_quarterly_vaccine_coverage_pfizer_v_other_v2", clear

// confirm there are no missing values for doses

des, varlist 
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	capture count if `var'==.
	if _rc==0 {
		assert r(N)==0
	}
	else if _rc>0 {
		count if `var'==""
		assert r(N)==0
	}
}

merge 1:1 country year quarter yyyy_qq using "$output\IHME\gdp_deaths_infections_lower_upper"
keep if country=="China"

assert _m!=1
assert (year==2020 & quarter<4) | year==2022 if _m==2 

// recode doses to zero prior to Q4 2020

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	replace `var' = 0 if `var' == . & _m==2
}

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	assert `var'==0 if year==2020 & quarter<4
}

drop _m adj_factor_v2

order country yyyy_qq year quarter gdp_gap daily_deaths inf_mean inf_lower inf_upper

sort country year quarter 
by country: assert _N==10
compress

////////////////////////////////////////////////////////////////////////////////
/////////// compute per capita measures of deaths and infections ///////////////
////////////////////////////////////////////////////////////////////////////////

merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3 
drop _m 

assert tot_pop<. & tot_pop>1000000

foreach var in daily_deaths inf_mean inf_lower inf_upper {
	replace `var'=`var'/tot_pop
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper total_doses pfizer other cum_total_doses cum_pfizer cum_other {
	sum `var'
}

sort country year quarter 

append using "$output\IHME\quarterly_regbase_infections_lower_upper"

qui tab country 
di "There are `r(r)' countries"

compress 

// confirm there are no missing values for doses

des total_doses pfizer other cum_total_doses cum_pfizer cum_other, varlist 
local myvars = r(varlist)
di "`myvars'"
local numvars: word count `myvars'
tokenize `myvars'
forvalues i = 1/`numvars' {
	local var: word `i' of `myvars'
	di "*********************************************"
	di "*************** `var' ***********************"
	di "*********************************************"
	capture count if `var'==.
	if _rc==0 {
		assert r(N)==0
	}
	else if _rc>0 {
		count if `var'==""
		assert r(N)==0
	}
}

save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// create Q4 2019 ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase_infections_lower_upper", clear

gen expand=0 
replace expand=2 if year==2020 & quarter==4
expand expand

sort country year quarter 
by country year: replace yyyy_qq="2019_Q4" if _n==_N & year==2020 & quarter==4 & expand==2

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	by country year: replace `var'=0 if _n==_N & year==2020 & quarter==4 & expand==2
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper {
	by country year: replace `var'=. if _n==_N & year==2020 & quarter==4 & expand==2
}

by country year: replace year = 2019 if _n==_N & year==2020 & quarter==4 & expand==2

sort country year quarter
by country: assert year==2019 if _n==1
by country: assert quarter==4 if _n==1
by country: assert yyyy_qq=="2019_Q4" if _n==1

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	by country: assert `var'==0 if _n==1
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper {
	by country: assert `var'==. if _n==1
}

by country: assert _N==11
drop expand

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// create Q1-Q3 2019 ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

gen expand=0 
replace expand=4 if year==2019 & quarter==4
expand expand

sort country year quarter 

by country year: replace yyyy_qq ="2019_Q1" if _n==1 & year==2019 & quarter==4 & expand==4
by country year: replace yyyy_qq ="2019_Q2" if _n==2 & year==2019 & quarter==4 & expand==4
by country year: replace yyyy_qq ="2019_Q3" if _n==3 & year==2019 & quarter==4 & expand==4

by country year: replace quarter = 1  if _n==1 & year==2019 & quarter==4 & expand==4
by country year: replace quarter = 2  if _n==2 & year==2019 & quarter==4 & expand==4
by country year: replace quarter = 3  if _n==3 & year==2019 & quarter==4 & expand==4

sort country year quarter 

forvalues x=1/4 {
	by country: assert year==2019 if _n==`x'
}

forvalues x=1/4 {
	by country: assert quarter == `x' if _n==`x'
}

by country: assert yyyy_qq =="2019_Q1" if _n==1 
by country: assert yyyy_qq =="2019_Q2" if _n==2 
by country: assert yyyy_qq =="2019_Q3" if _n==3 
by country: assert yyyy_qq =="2019_Q4" if _n==4 

forvalues x=1/4 {
	foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {	
		by country: assert `var'==0 if _n==`x'
	}
}

forvalues x=1/4 {
	foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper {
		by country: assert `var'==. if _n==`x'
	}
}

drop expand

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// create Q4 2018 ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

gen expand=0 
replace expand=2 if year==2019 & quarter==4
expand expand

sort country year quarter 
by country year: replace yyyy_qq="2018_Q4" if _n==_N & year==2019 & quarter==4 & expand==2

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	by country year: replace `var'=0 if _n==_N & year==2019 & quarter==4 & expand==2
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper {
	by country year: replace `var' = . if _n==_N & year==2019 & quarter==4 & expand==2
}

by country year: replace year = 2018 if _n==_N & year==2019 & quarter==4 & expand==2

sort country year quarter
by country: assert year==2018 if _n==1
by country: assert quarter==4 if _n==1
by country: assert yyyy_qq=="2018_Q4" if _n==1

foreach var in total_doses pfizer other cum_total_doses cum_pfizer cum_other  {
	by country: assert `var'==0 if _n==1
}

foreach var in gdp_gap daily_deaths inf_mean inf_lower inf_upper {
		by country: assert `var' == . if _n==1
}

by country: assert _N==15
drop expand

ren total_doses uptake
ren pfizer uptake_pfizer
ren other uptake_other

ren cum_total_doses cum_uptake
ren cum_pfizer cum_uptake_pfizer
ren cum_other cum_uptake_other

qui tab country 
di "There are `r(r)' countries"

compress 
save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
////////////// drop countries with zero doses for all quarters /////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase_infections_lower_upper", clear
sort country year quarter 
by country: egen numdoses=total(uptake) 
assert country != "Turkmenistan"
assert numdoses>0 & numdoses<.

qui tab country 
di "There are `r(r)' countries"

compress 
save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
///////////////// create country and period dummy variables ////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_regbase_infections_lower_upper", clear

egen country_group=group(country)
egen time=group(yyyy_qq)

sum country_group
di "There are `r(max)' countries"

sum time
di "There are `r(max)' time periods"

qui tab country_group, gen(country_)
qui tab time, gen(time_)

des, f

save "$output\IHME\quarterly_regbase_infections_lower_upper", replace

log close 

exit 

// end
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
infections_countries_w_pop_gt_1M.dta created in: make_inf_lower_upper_countries_w_pop_gt_1M.do
quarterly_deaths_&_infections.dta created in: make_quarterly_deaths_&_infections.do
outputs:
quarterly_deaths_&_infections_lower_upper.dta
*/

capture log close
log using "$output\IHME\make_quarterly_infections_lower_upper", text replace

////////////////////////////////////////////////////////////////////////////////
///// construct dependent variables for the death and infection regressions ////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\infections_countries_w_pop_gt_1M", clear 

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
order country date year quarter yyyy_qq

sort country year quarter date 

////////////////////////////////////////////////////////////////////////////////
//////// confirm there are no missing infections between non-missing values ////
////////////////////////////////////////////////////////////////////////////////

foreach i in lower upper mean {
	assert inf_`i' ==. if inf_cuml_`i'==. 
	assert inf_cuml_`i'==. if inf_`i' == . 
}

gen flag=0
sort country year quarter date 

foreach i in lower upper mean {
	by country: replace flag=1 if _n>1 & _n<_N & inf_cuml_`i'==. & inf_cuml_`i'[_n-1] < . & inf_cuml_`i'[_n+1] <.
}

assert flag==0 
drop flag

/////////////////////////////// infections issue 4 /////////////////////////////

foreach i in lower upper mean {
	replace inf_`i'=0 if inf_`i'==. & country== "Lesotho" & inlist(yyyy_qq, "2020_Q1","2020_Q2")
}


////////////////////////////////////////////////////////////////////////////////
/// examine any remaining missing values for daily deaths & infections /////////
////////////////////////////////////////////////////////////////////////////////

foreach i in lower upper mean {
	assert inf_`i'<. 
}

////////////////////////////////////////////////////////////////////////////////
///////// recode the first non-missing/non-zero daily values of to the /////////
///// corresponding cumulative values in cases where they are not equal ////////
////////////////////////////////////////////////////////////////////////////////

///////////////////////////////// infections ///////////////////////////////////

sort country year quarter date 

foreach i in lower upper mean {

	by country: gen run_infections_`i' = sum(inf_`i')
	gen flag_infections_`i'=0 
	by country: replace flag_infections_`i'=1 if _n>1 & run_infections_`i' > 0 & run_infections_`i'[_n-1]==0 & inf_cuml_`i' > inf_`i'
	by country: replace flag_infections_`i'=1 if _n==1 & run_infections_`i' > 0 & inf_cuml_`i' > inf_`i'
	list country date inf_cuml_`i' inf_`i' if flag_infections_`i'==1, sep(0)

	replace inf_`i' = inf_cuml_`i' if flag_infections_`i'==1
	list country date inf_cuml_`i' inf_`i' if flag_infections_`i'==1, sep(0)
	drop run_infections_`i' flag_infections_`i'
}

////////////////////////////////////////////////////////////////////////////////
////////////////// aggregate infections to the quarter level ///////////////////
////////////////////////////////////////////////////////////////////////////////

drop inf_cuml_lower inf_cuml_mean inf_cuml_upper

codebook inf_mean inf_lower inf_upper
collapse (sum) inf_mean inf_lower inf_upper, by(country year quarter yyyy_qq)

foreach i in lower upper mean {
	assert inf_`i'<.
}

sort country year quarter
by country: assert _N==10 


compress 
save "$output\IHME\quarterly_infections_lower_upper", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// map to the original file /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_deaths_&_infections", clear
merge 1:1 country year quarter yyyy_qq inf_mean using "$output\IHME\quarterly_infections_lower_upper"
assert _m==3 
drop _m 

compress 
save "$output\IHME\quarterly_deaths_&_infections_lower_upper", replace

log close

exit

// end
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
unscaled_deaths_Hong_Kong_China_Macoa.dta created in: make_unscaled_deaths_countries_w_pop_gt_1M.do
outputs:
quarterly_unscaled_deaths_China.dta 
*/

capture log close
log using "$output\IHME\make_quarterly_unscaled_deaths_China", text replace

////////////////////////////////////////////////////////////////////////////////
///// construct dependent variables for the death and infection regressions ////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\unscaled_deaths_Hong_Kong_China_Macoa", clear

ren daily_deaths_unscaled daily_deaths
ren cumulative_deaths_unscaled cumulative_deaths

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
order country date year quarter yyyy_qq

sort country year quarter date 

////////////////////////////////////////////////////////////////////////////////
//////// confirm there are no missing deaths between non-missing values ////////
////////////////////////////////////////////////////////////////////////////////

assert daily_deaths ==. if cumulative_deaths==. 
assert cumulative_deaths==. if daily_deaths == . 

gen flag=0
sort country year quarter date 
by country: replace flag=1 if _n>1 & _n<_N & cumulative_deaths==. & cumulative_deaths[_n-1] < . & cumulative_deaths[_n+1] <.
assert flag==0 
drop flag

////////////////////////////////////////////////////////////////////////////////
/// examine any remaining missing values for daily deaths & infections /////////
////////////////////////////////////////////////////////////////////////////////

sort country year quarter date 
tab yyyy_qq if daily_deaths==.
assert inlist(yyyy_qq,"2020_Q1","2020_Q2") if daily_deaths==.

gen flag=0 
by country: replace flag=1 if _n>1 & _n<_N & daily_deaths>=0 & daily_deaths<. & daily_deaths[_n-1] ==. & yyyy_qq==yyyy_qq[_n-1]
by country: replace flag=1 if _n>1 & _n<_N & daily_deaths[_n+1]>=0 & daily_deaths[_n+1]<. & daily_deaths==. & yyyy_qq==yyyy_qq[_n+1]
list country date daily_deaths if flag==1 & yyyy_qq=="2020_Q1", sepby(country)
list country date daily_deaths if flag==1 & yyyy_qq=="2020_Q2", sepby(country)
replace daily_deaths=0 if daily_deaths==.
drop flag

////////////////////////////////////////////////////////////////////////////////
//// issue 3: recode the first non-missing/non-zero daily values of to the /////
///// corresponding cumulative values in cases where they are not equal ////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////// deaths //////////////////////////////////////
 
sort country year quarter date 
by country: gen run_deaths = sum(daily_deaths)
gen flag_deaths=0 
by country: replace flag_deaths=1 if _n>1 & run_deaths > 0 & run_deaths[_n-1]==0 & cumulative_deaths > daily_deaths
by country: replace flag_deaths=1 if _n==1 & run_deaths > 0 & cumulative_deaths > daily_deaths & cumulative_deaths<.
list country date cumulative_deaths daily_deaths if flag_deaths==1, sep(0)

replace daily_deaths = cumulative_deaths if flag_deaths==1
list country date cumulative_deaths daily_deaths if flag_deaths==1, sep(0)
drop run_deaths flag_deaths 

////////////////////////////////////////////////////////////////////////////////
//////// aggregate daily deaths and infections to the quarter level ////////////
////////////////////////////////////////////////////////////////////////////////

drop cumulative_deaths

codebook daily_deaths
collapse (sum) daily_deaths , by(country year quarter yyyy_qq)
assert daily_deaths <.

sort country year quarter
by country: assert _N==10 

// count the number of quarters with non-zero deaths

gen flag=0 
replace flag=1 if daily_deaths==0
tab country yyyy_qq if flag==1
di "There are `r(r)' countries with at least one quarter of zero deaths"
// 50 countries 

tab yyyy_qq if flag==1 

drop flag 

compress 
save "$output\IHME\quarterly_unscaled_deaths_Hong_Kong_China_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
////////// sum the Hong Kong and Macao infections, deaths and vax data /////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\quarterly_unscaled_deaths_Hong_Kong_China_Macoa", clear
drop if country=="China"

collapse (sum) daily_deaths, by(year quarter yyyy_qq)

gen country="Hong Kong + Macao"
order  country 
isid year quarter

save "$output\IHME\quarterly_unscaled_deaths_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
///// subtract Hong Kong and Macao infections, deaths and vax from China ///////
////////////////////////////////////////////////////////////////////////////////

use          "$output\IHME\quarterly_unscaled_deaths_Hong_Kong_China_Macoa", clear 
append using "$output\IHME\quarterly_unscaled_deaths_Hong_Kong_plus_Macoa"
isid country year quarter
keep if inlist(country, "Hong Kong + Macao", "China")

tab country
assert r(r)==2
compress

sort year quarter country
foreach var in daily_deaths {
	by year quarter: replace `var' = `var'-`var'[_n+1] if country=="China" & country[_n+1]=="Hong Kong + Macao"
}

keep if country=="China"

compress 
save "$output\IHME\quarterly_unscaled_deaths_China", replace

log close

exit

// end
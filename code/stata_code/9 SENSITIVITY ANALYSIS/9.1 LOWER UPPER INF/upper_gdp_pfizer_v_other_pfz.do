set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_pfz_upper.dta
vax_launch_quarter_deaths_inf.dta
sur_regbase_infections_upper_gdp_qrtly.dta
quarterly_gdp_usd.dta
output:
upper_gdp_pfizer_v_other_pfz.dta 
*/

////////////////////////////////////////////////////////////////////////////////
////////////////// get the novax natural immunity file /////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\quarterly_gdp_regbase", clear 
keep country
duplicates drop 
count 
// 52

merge 1:1 country using "$root\REGRESSION RESULTS\SUR\country_group_lookup_deaths_inf" , keepusing(country country_group) 
assert _m!=1 
keep if _m==3 
drop _m 

merge 1:m country_group using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_novax_inf_pfz_upper"
drop if _m==2
drop _m 
qui tab country 
di `r(r)'
// 52 countries 
drop country_group 
sort country time

save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sim_0_novax_inf_pfz_quarterly_gdp_upper_pfz", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// run regression //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_all==1

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sur_regbase_infections_upper_gdp_qrtly"
assert _m!=2
keep if _m==3
drop _m prevax_osi

replace L1_mean_index=L1_mean_index/100
replace prevax_osi_pfz=prevax_osi_pfz/100

merge 1:1 country time using "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sim_0_novax_inf_pfz_quarterly_gdp_upper_pfz"
drop if _m==2
sort country year quarter

foreach var in L1_inf L2_cum_inf inf {
	ren `var'_upper `var'_mean
}

order country time launch_time yyyy_qq vax_launch L1_mean_index prevax_osi_pfz mean_index uptake* cum_* L1_* L2_* 

reg gdp_gap ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_52

predict yhat_1, xb

foreach brand in pfizer {
	replace        uptake_`brand'=0
	replace     L1_uptake_`brand'=0
	replace L2_cum_uptake_`brand'=0
}

replace L1_mean_index=prevax_osi_pfz if time==launch_time & prevax_osi_pfz <.
replace L1_mean_index=prevax_osi_pfz if time>=launch_time & prevax_osi_pfz <.

replace L1_inf_mean = novax_L1_inf_mean if novax_L1_inf_mean<. & _m==3
replace L2_cum_inf_mean = novax_L2_cum_inf_mean if novax_L2_cum_inf_mean<. &_m==3

order country time launch_time yyyy_qq vax_launch L1_mean_index prevax_osi mean_index uptake* cum_* L1_* L2_* 

predict yhat_2, xb

gen gdp_gain = yhat_1-yhat_2 

drop if year<2020

keep country year quarter yyyy_qq gdp_gap yhat_1 yhat_2 gdp_gain

isid country yyyy_qq

compress

merge 1:1 country yyyy_qq using "$output\ECONOMIC DATA\quarterly_gdp_usd", ///
keepusing(country yyyy_qq gdp_usd_projected)
drop if  inlist(yyyy_qq,"2022_Q1","2022_Q2")
assert _m!=1
drop if country=="Turkmenistan"
keep if _m==3
drop _m 
qui tab country 
assert `r(r)'==52
assert _N==408

sort country year quarter
isid country year quarter

compress

gen gdp1 = gdp_usd_projected*yhat_1
gen gdp2 = gdp_usd_projected*yhat_2
gen gdpdiff0 = gdp1 - gdp2
gen check = gdp_usd_projected*(yhat_1 - yhat_2)
gen check2 = gdpdiff0/check
sum check2, d
drop check*

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\upper_gdp_pfizer_v_other_pfz", replace

exit 

// end


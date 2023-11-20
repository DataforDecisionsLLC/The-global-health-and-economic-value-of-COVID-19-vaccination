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
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_all_vax_lower.dta created in: make_novax_infections_lower_upper.do
outputs:
lower_death_pfizer_v_other_overall.dta 
*/

use "$root\REGRESSION RESULTS\SUR\vax_launch_quarter_deaths_inf", clear
keep if launch_all==1

drop launch_*
ren yyyy_qq vax_launch
ren time launch_time

isid country 

merge 1:m country using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sur_regbase_infections_lower"
assert _m==3
drop _m

replace L1_mean_index=L1_mean_index/100
replace prevax_osi=prevax_osi/100

merge 1:1 country_group time using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_novax_inf_all_vax_lower"
drop if _m==2
sort country year quarter

foreach var in cum_inf L1_inf L1_cum_inf L2_inf L2_cum_inf inf {
	ren `var'_lower `var'_mean
}

order country time launch_time yyyy_qq vax_launch L1_mean_index prevax_osi_pfz mean_index uptake* cum_* L1_* L2_* 

reg daily_deaths ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_145

predict yhat_1, xb

foreach brand in pfizer other {
	replace     L1_uptake_`brand'=0
	replace L2_cum_uptake_`brand'=0
}

replace L1_mean_index=prevax_osi if time==launch_time
replace L1_mean_index=prevax_osi if time>=launch_time

replace L1_inf_mean = novax_L1_inf_mean if novax_L1_inf_mean<. & _m==3
replace L2_cum_inf_mean = novax_L2_cum_inf_mean if novax_L2_cum_inf_mean<. &_m==3

order country time launch_time yyyy_qq vax_launch L1_mean_index prevax_osi_pfz mean_index uptake* cum_* L1_* L2_* 

predict yhat_2, xb

sum yhat_1, d
sum yhat_2, d

gen gain = yhat_2-yhat_1 

sum gain, d
sum gain if year==2020, d
sum gain if year>2020, d

order country year quarter yyyy_qq yhat_1 yhat_2 gain

isid country yyyy_qq

compress

assert tot_pop<.

gen tot_gain = tot_pop*gain

keep country year quarter yyyy_qq tot_gain

drop if year<2020
compress 

ren tot_gain averted_death_overall

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\lower_death_pfizer_v_other_overall", replace

exit 

// end
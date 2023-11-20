
set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
sim_0_beta_&_X_vax_pfz_lower.dta created in: make_beta_&_X_vax_pfz_lower_upper.do
sim_0_beta_&_X_vax_pfz_upper.dta created in: make_beta_&_X_vax_pfz_lower_upper.do
outputs:
sim_0_novax_inf_pfz_lower.dta
sim_0_novax_inf_pfz_upper.dta
*/

////////////////////////////////////////////////////////////////////////////////
///////// set the Pfizer vaccine dose variables to zero ////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop novax_inf 
program novax_inf 
version 18.0 
set more off 
set type double 
args sim inf

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_vax_pfz_`inf'"

sort time sortme
// set vax to zero
order variable sortme time beta beta_1 beta_constant

assert inlist(variable,"time_06","tot_pop") if beta==.
drop if variable=="time_06"

forvalues c = 1/145 {
	replace x_`c' = 0 if inlist(variable,"L1_uptake_pfizer","L2_cum_uptake_pfizer")
}

forvalues c = 1/145 {
	gen xb_`c' = ., before(x_`c')
}

// time dummies
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if regexm(variable,"^time_")
}

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", replace

end 

novax_inf 0 lower
novax_inf 0 upper


capture program drop novax_inf 
program novax_inf 
version 18.0 
set more off 
set type double 
args sim inf

////////////////////////////////////////////////////////////////////////////////
//////// get the novax infections for countries with a 2020 Q4 all launch //////
////////////////////////////////////////////////////////////////////////////////

/////////// step 1: predict infections in 2021 Q1 (t=10) under no vax //////////

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

gen keepme=0 
replace keepme=1 if variable=="L2_cum_inf_mean" & time==11 
replace keepme=1 if variable=="tot_pop"
replace keepme=1 if time==10 & variable=="time_10"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_10"
}

forvalues c = 1/145 {
	replace yhat_`c' = x_`c' if variable== "L2_cum_inf_mean" & time==11
}

/*
compute cumulative infections under novax up to t=10 as the sum of 
cumulative infections up to t=9 (L2_cum_inf_mean for time=11) and 
contemporaneous infections under no vax in t=10
*/

// compute cumulative gross infections up to time=10

sort sortme
assert time==2020 if _n==3 
assert time==2021 if _n==4

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'*x_`c'[3] if time==11 & variable== "L2_cum_inf_mean" 
	replace yhat_`c' = yhat_`c'*x_`c'[4] if time==10 & variable=="time_10"
}

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + yhat_`c'[_n+1] if time==11 & variable== "L2_cum_inf_mean" 
}

// compute cumulative infections per capita

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'/x_`c'[4] if time==11 & variable== "L2_cum_inf_mean" 
	replace yhat_`c' = yhat_`c'/x_`c'[4] if time==10 & variable=="time_10"
}

drop if variable=="tot_pop"

keep variable time yhat_*
replace variable = "yhat_inf_t10_novax" if time==10 & variable== "time_10" 
replace variable = "yhat_cum_inf_mean_t10" if time==11 & variable== "L2_cum_inf_mean" 
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

compress
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'", replace

/////////// step 2: predict infections in 2021 Q2 (t=11) under no vax //////////

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear
append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'"

sort novax_10 time sortme

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[1] if variable=="L1_inf_mean" & time==11
}

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[2] if variable=="L2_cum_inf_mean" & time==12
}

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

/*
keep the cumulative up to t=9 (L2_cum_inf_mean in time==11), 
the population for the cumulative up to t=9 ,
the novax contemporaneous infections in t=10 (L1_inf_mean in time=11) ,
and the novax contemporaneous infections in t=11
*/

gen keepme=0 
replace keepme=1 if variable=="L2_cum_inf_mean" & time==11 
replace keepme=1 if variable=="tot_pop"
replace keepme=1 if time==11 & variable=="L1_inf_mean"
replace keepme=1 if time==11 & variable=="time_11"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_11"
}

forvalues c = 1/145 {
	replace yhat_`c' = x_`c' if variable== "L1_inf_mean" & time==11
}

forvalues c = 1/145 {
	replace yhat_`c' = x_`c' if variable== "L2_cum_inf_mean" & time==11
}

/*
compute cumulative infections under novax up to t=11 as the sum of 
cumulative infections up to t=9 (L2_cum_inf_mean for time=11), and 
contemporaneous infections under no vax in t=10 (L1_inf_mean in time=11) , and
contemporaneous infections under no vax in t=11
*/

// compute cumulative gross infections up to time=10

sort sortme
assert time==2020 if _n==4 
assert time==2021 if _n==5

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'*x_`c'[4] if time==11 & variable== "L2_cum_inf_mean" 
	replace yhat_`c' = yhat_`c'*x_`c'[5] if time==11 & variable== "L1_inf_mean"
	replace yhat_`c' = yhat_`c'*x_`c'[5] if time==11 & variable=="time_11"
}

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + yhat_`c'[_n+1] + yhat_`c'[_n+2] if time==11 & variable== "L1_inf_mean"
}

// compute cumulative infections per capita

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'/x_`c'[5] if time==11 & variable== "L1_inf_mean"
	replace yhat_`c' = yhat_`c'/x_`c'[5] if time==11 & variable=="time_11"
}

drop if inlist(variable,"tot_pop","L2_cum_inf_mean")

keep variable time yhat_*
replace variable = "yhat_inf_t11_novax" if time==11 & variable== "time_11" 
replace variable = "yhat_cum_inf_mean_t11" if time==11 & variable== "L1_inf_mean"
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'"

compress
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'", replace

/////////// step 3: predict infections in 2021 Q3 (t=12) under no vax //////////
 
use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear
append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'"

sort novax_10 time sortme

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[1] if variable=="L1_inf_mean" & time==11
}

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[2] if variable=="L1_inf_mean" & time==12
}

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[3] if variable=="L2_cum_inf_mean" & time==12
}

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[4] if variable=="L2_cum_inf_mean" & time==13
}

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

gen keepme=0 
replace keepme=1 if time==12 & variable=="time_12"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_12"
}

keep variable time yhat_*
replace variable = "yhat_inf_t12_novax" if time==12 & variable== "time_12" 
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2020Q4_pfz_`inf'"

gen time=., before(variable)

replace time=12 if variable=="yhat_cum_inf_mean_t10"
replace time=13 if variable=="yhat_cum_inf_mean_t11"
replace time=11 if variable=="yhat_inf_t10_novax"
replace time=12 if variable=="yhat_inf_t11_novax"
replace time=13 if variable=="yhat_inf_t12_novax"

replace variable = "L2_cum_inf_mean" if variable=="yhat_cum_inf_mean_t10"
replace variable = "L2_cum_inf_mean" if variable=="yhat_cum_inf_mean_t11"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t10_novax"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t11_novax"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t12_novax"
sort time variable

keep time variable ///
novax_7 ///
novax_12 ///
novax_15 ///
novax_18 ///
novax_22 ///
novax_25 ///
novax_29 ///
novax_30 ///
novax_31 ///
novax_34 ///
novax_36 ///
novax_41 ///
novax_45 ///
novax_49 ///
novax_51 ///
novax_53 ///
novax_57 ///
novax_62 ///
novax_63 ///
novax_64 ///
novax_70 ///
novax_72 ///
novax_77 ///
novax_80 ///
novax_83 ///
novax_95 ///
novax_96 ///
novax_98 ///
novax_102 ///
novax_103 ///
novax_104 ///
novax_105 ///
novax_107 ///
novax_116 ///
novax_118 ///
novax_119 ///
novax_121 ///
novax_125 ///
novax_137 ///
novax_138 ///
novax_144

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2020Q4_pfz_`inf'" , replace 

////////////////////////////////////////////////////////////////////////////////
//////// get the novax infections for countries with a 2021 Q1 all launch //////
////////////////////////////////////////////////////////////////////////////////

/////////// step 1: predict infections in 2021 Q2 (t=11) under no vax //////////

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

/*
keep the cumulative up to t=9 (L2_cum_inf_mean in time==11), 
the population for the cumulative up to t=9 ,
the novax contemporaneous infections in t=10 (L1_inf_mean in time=11) ,
and the novax contemporaneous infections in t=11
*/

gen keepme=0 
replace keepme=1 if variable=="L2_cum_inf_mean" & time==11 
replace keepme=1 if variable=="tot_pop"
replace keepme=1 if time==11 & variable=="L1_inf_mean"
replace keepme=1 if time==11 & variable=="time_11"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_11"
}

forvalues c = 1/145 {
	replace yhat_`c' = x_`c' if variable== "L1_inf_mean" & time==11
}

forvalues c = 1/145 {
	replace yhat_`c' = x_`c' if variable== "L2_cum_inf_mean" & time==11
}

/*
compute cumulative infections under novax up to t=11 as the sum of 
cumulative infections up to t=9 (L2_cum_inf_mean for time=11), and 
contemporaneous infections under no vax in t=10 (L1_inf_mean in time=11) , and
contemporaneous infections under no vax in t=11
*/

// compute cumulative gross infections up to time=10

sort sortme
assert time==2020 if _n==4 
assert time==2021 if _n==5

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'*x_`c'[4] if time==11 & variable== "L2_cum_inf_mean" 
	replace yhat_`c' = yhat_`c'*x_`c'[5] if time==11 & variable== "L1_inf_mean"
	replace yhat_`c' = yhat_`c'*x_`c'[5] if time==11 & variable=="time_11"
}

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + yhat_`c'[_n+1] + yhat_`c'[_n+2] if time==11 & variable== "L1_inf_mean"
}

// compute cumulative infections per capita

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c'/x_`c'[5] if time==11 & variable== "L1_inf_mean"
	replace yhat_`c' = yhat_`c'/x_`c'[5] if time==11 & variable=="time_11"
}

drop if inlist(variable,"tot_pop","L2_cum_inf_mean")

keep variable time yhat_*
replace variable = "yhat_inf_t11_novax" if time==11 & variable== "time_11" 
replace variable = "yhat_cum_inf_mean_t11" if time==11 & variable== "L1_inf_mean"
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

compress
save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2021Q1_pfz_`inf'", replace

/////////// step 2: predict infections in 2021 Q3 (t=12) under no vax //////////
 
use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear
append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2021Q1_pfz_`inf'"

sort novax_10 time sortme

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[1] if variable=="L1_inf_mean" & time==12
}

forvalues c = 1/145 {
	replace x_`c' =  novax_`c'[2] if variable=="L2_cum_inf_mean" & time==13
}

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

gen keepme=0 
replace keepme=1 if time==12 & variable=="time_12"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_12"
}

keep variable time yhat_*
replace variable = "yhat_inf_t12_novax" if time==12 & variable== "time_12" 
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

append using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_yhat_inc_novax_2021Q1_pfz_`inf'"

gen time=., before(variable)

replace time=13 if variable=="yhat_cum_inf_mean_t11"
replace time=12 if variable=="yhat_inf_t11_novax"
replace time=13 if variable=="yhat_inf_t12_novax"

replace variable = "L2_cum_inf_mean" if variable=="yhat_cum_inf_mean_t11"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t11_novax"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t12_novax"
sort time variable

keep time variable ///
novax_2 ///
novax_6 ///
novax_10 ///
novax_17 ///
novax_27 ///
novax_33 ///
novax_37 ///
novax_38 ///
novax_44 ///
novax_50 ///
novax_52 ///
novax_61 ///
novax_66 ///
novax_67 ///
novax_73 ///
novax_86 ///
novax_88 ///
novax_89 ///
novax_90 ///
novax_91 ///
novax_92 ///
novax_99 ///
novax_110 ///
novax_112 ///
novax_114 ///
novax_115 ///
novax_122 ///
novax_124 ///
novax_132 ///
novax_135 ///
novax_139

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2021Q1_pfz_`inf'" , replace 

////////////////////////////////////////////////////////////////////////////////
//////// get the novax infections for countries with a 2021 Q2 all launch //////
////////////////////////////////////////////////////////////////////////////////

/////////// step 1: predict infections in 2021 Q3 (t=12) under no vax //////////

use "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_0_beta_&_X_novax_pfz_`inf'", clear

// continuous variables 
forvalues c = 1/145 {
	replace xb_`c'=x_`c'*beta if inlist(variable,"L1_uptake_pfizer", "L2_cum_uptake_pfizer", "L1_uptake_other", "L2_cum_uptake_other", "L1_inf_mean", "L2_cum_inf_mean", "L1_mean_index")
}

sort time sortme
forvalues c = 1/145 {
	by time: egen yhat_`c' = total(xb_`c')
}

gen keepme=0 
replace keepme=1 if time==12 & variable=="time_12"
keep if keepme==1 
drop keepme

forvalues c = 1/145 {
	replace yhat_`c' = yhat_`c' + beta_`c' + beta_constant if variable=="time_12"
}

keep variable time yhat_*
replace variable = "yhat_inf_t12_novax" if time==12 & variable== "time_12" 
drop time

forvalues c = 1/145 {
	ren yhat_`c' novax_`c'
}

gen time=., before(variable)

replace time=13 if variable=="yhat_inf_t12_novax"
replace variable = "L1_inf_mean" if variable=="yhat_inf_t12_novax"
sort time variable

keep time variable ///
novax_3 ///
novax_4 ///
novax_5 ///
novax_8 ///
novax_9 ///
novax_13 ///
novax_14 ///
novax_16 ///
novax_19 ///
novax_20 ///
novax_21 ///
novax_23 ///
novax_24 ///
novax_28 ///
novax_32 ///
novax_35 ///
novax_39 ///
novax_40 ///
novax_42 ///
novax_43 ///
novax_46 ///
novax_47 ///
novax_48 ///
novax_55 ///
novax_58 ///
novax_59 ///
novax_60 ///
novax_65 ///
novax_69 ///
novax_71 ///
novax_74 ///
novax_75 ///
novax_76 ///
novax_78 ///
novax_81 ///
novax_82 ///
novax_84 ///
novax_85 ///
novax_87 ///
novax_93 ///
novax_94 ///
novax_97 ///
novax_100 ///
novax_101 ///
novax_106 ///
novax_109 ///
novax_111 ///
novax_113 ///
novax_117 ///
novax_120 ///
novax_123 ///
novax_126 ///
novax_128 ///
novax_129 ///
novax_130 ///
novax_131 ///
novax_133 ///
novax_134 ///
novax_136 ///
novax_140 ///
novax_141 ///
novax_142 ///
novax_143 ///
novax_145

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2021Q2_pfz_`inf'" , replace 

////////////////////////////////////////////////////////////////////////////////
///////////////////////////// combine all countries ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use                           "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2020Q4_pfz_`inf'" , clear 
merge 1:1 time variable using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2021Q1_pfz_`inf'"
assert _m!=2 
drop _m 
sort time variable 
merge 1:1 time variable using "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_2021Q2_pfz_`inf'"
assert _m!=2 
drop _m 
sort time variable 
isid time variable

reshape long novax_, i(time variable) j(country_group)
sort country_group time variable
order country_group time variable

drop if novax_==.

reshape wide novax_, i(country_group time) j(variable) string
sort country_group time 
compress

save "$root\REGRESSION RESULTS\SUR\LOWER UPPER INF\sim_`sim'_novax_inf_pfz_`inf'" , replace 

end 

novax_inf  0 lower
novax_inf  0 upper

// end

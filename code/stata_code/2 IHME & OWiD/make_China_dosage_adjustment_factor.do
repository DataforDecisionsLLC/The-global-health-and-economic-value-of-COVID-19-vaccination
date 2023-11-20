set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

/*
inputs: 
1. projections_Hong_Kong_China_Macoa.dta created in: make_historical_data_Hong_Kong_China_Macao.do 
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
*/

capture log close
log using "$output\IHME\make_China_dosage_adjustment_factor", text replace

////////////////////////////////////////////////////////////////////////////////
//////////////////// get the Hong Kong, Macao and China vax data ///////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\projections_Hong_Kong_China_Macoa", clear 
keep country date year quarter cumulative_all_fully_vaccinated
tab country 
assert r(r)==3
replace cumulative_all_fully_vaccinated=0 if cumulative_all_fully_vaccinated==.
compress

// compute daily vax 
sort country date
by   country: gen new_vax = cumulative_all_fully_vaccinated-cumulative_all_fully_vaccinated[_n-1]
sum new_vax , d
assert new_vax>=0

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
drop if year==2023

// aggregate daily vax to the country-quarter

collapse (sum) new_vax, by(country year quarter yyyy_qq)
compress 
save "$output\IHME\vax_Hong_Kong_China_Macoa", replace 

////////////////////////////////////////////////////////////////////////////////
//////////////////// sum the Hong Kong and Macao vax data //////////////////////
////////////////////////////////////////////////////////////////////////////////

use  "$output\IHME\vax_Hong_Kong_China_Macoa", clear
drop if country=="China"
sort year quarter country 
collapse (sum) new_vax, by(year quarter yyyy_qq)

gen country="Hong Kong + Macao"
order  country 
isid year quarter
compress
save "$output\IHME\quarterly_vax_Hong_Kong_plus_Macoa", replace

////////////////////////////////////////////////////////////////////////////////
////////////////// subtract Hong Kong and Macao vax data from China ////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\vax_Hong_Kong_China_Macoa", clear 
append using "$output\IHME\quarterly_vax_Hong_Kong_plus_Macoa"
isid country year quarter
keep if inlist(country, "Hong Kong + Macao", "China")

tab country
assert r(r)==2
compress

sort year quarter country
foreach var in new_vax {
	by year quarter: replace `var' = `var'-`var'[_n+1] if country=="China" & country[_n+1]=="Hong Kong + Macao"
}

keep if country=="China"

compress 
save "$output\IHME\vax_China", replace

////////////////////////////////////////////////////////////////////////////////
/////// compute a population-wtd sum of the Hong Kong and Macao vax data ///////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\vax_Hong_Kong_China_Macoa", clear
drop if country=="China"
sort country year quarter

// compute per capita daily vax 

merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3
drop _m
compress

gen pc_new_vax=new_vax/tot_pop
drop new_vax

sort year quarter country 
by year quarter: egen all_pop=total(tot_pop)
gen wt = tot_pop/all_pop 
by year quarter: egen check=total(wt)
sum check, d
drop check all_pop
by year quarter: egen wt_avg_pc_new_vax=total(wt*pc_new_vax)
drop pc_new_vax tot_pop wt
drop country 
duplicates drop 
compress
save "$output\IHME\China_dosage_adjustment_factor_v2", replace

// compute per capita daily vax for China data

use "$output\IHME\vax_China", clear
sort country year quarter 

merge m:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1
keep if _m==3
drop _m

gen pc_new_vax=new_vax/tot_pop
drop new_vax
compress 
merge 1:1 year quarter yyyy_qq using "$output\IHME\China_dosage_adjustment_factor_v2"

assert _m==3 
drop _m 
sort  country year quarter
order country year quarter yyyy_qq wt_avg_pc_new_vax pc_new_vax 
gen adj_factor_v2= pc_new_vax/wt_avg_pc_new_vax 
keep country year quarter yyyy_qq adj_factor_v2

save "$output\IHME\China_dosage_adjustment_factor_v2", replace

log close 

exit 

// end

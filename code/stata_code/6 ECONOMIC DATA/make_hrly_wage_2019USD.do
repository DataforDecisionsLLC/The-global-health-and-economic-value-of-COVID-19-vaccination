set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$output\ECONOMIC DATA\WAGES\make_hrly_wage_2019USD", text replace

/*
inputs:
1. EAR_4HRL_SEX_OCU_CUR_NB_A_EN.xlsx
2. national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
3. IHME_unique_countries.dta created in: make_IHME_unique_countries.do 
4. wdi_ihme_country_match.dta created in: wdi_ihme_country_match.do 
*/

////////////////////////////////////////////////////////////////////////////////
//////////// ILO average hourly earnings of employees: nominal USDs ////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$raw/ILO/WAGE/EAR_4HRL_SEX_OCU_CUR_NB_A_EN.xlsx", ///
clear first sheet("EAR_4HRL_SEX_OCU_CUR_NB_A_EN") case(lower) cellrange(A6:H16409)
ren referencearea country 
keep if sex=="Total"
drop sex
keep if occupation=="Total"
drop occupation
keep if time==2019
ren time year
drop source localcurrency ppp
ren usdollars hrly_wage_2019USD
drop year
drop if hrly_wage_2019USD==.

sum hrly_wage_2019USD, d

tab country if hrly_wage_2019USD<1.5

replace country = "Brunei" if country=="Brunei Darussalam"
replace country = "Tanzania" if country=="Tanzania, United Republic of"
replace country = "Laos" if country=="Lao People's Democratic Republic"
replace country = "Democratic Republic of Congo" if country=="Congo, Democratic Republic of the"
replace country = "Cote d'Ivoire" if country=="Côte d'Ivoire"
replace country = "Curacao" if country=="Curaçao"
replace country = "Macao" if country=="Macau, China"
replace country = "Moldova" if country=="Moldova, Republic of"
replace country = "Palestine" if country=="Occupied Palestinian Territory"
replace country = "Russia" if country=="Russian Federation"
replace country = "South Korea" if country=="Korea, Republic of"
replace country = "North Korea" if country=="Korea, Democratic People's Republic of"
replace country = "Turkey" if country=="Türkiye"
replace country = "Vietnam" if country=="Viet Nam"
replace country = "Venezuela" if country=="Venezuela, Bolivarian Republic of"
replace country = "Hong Kong" if country=="Hong Kong, China"
replace country = "Taiwan" if country=="Taiwan, China"
replace country = "Syria" if country=="Syrian Arab Republic"
replace country = "Iran" if regexm(country,"Iran")

// drop countries with population <= 1M

gen year = 2020

merge 1:1 country year using "$output\national_population_2020_2021_2022" 
assert _m!=1

keep if _m==3
drop _m

count

drop if tot_pop<=1000000
drop tot_pop year

count

// keep the IHME relevant countries

merge 1:1 country using "$output\ECONOMIC DATA\IHME_unique_countries"

drop if _m==1 
drop _m 

gen has_data=0
replace has_data=1 if hrly_wage_2019USD<.
assert hrly_wage_2019USD<. if has_data==1
assert hrly_wage_2019USD==. if has_data==0

order has_data
sort country 
isid country

tab has_data, m 

save "$output\ECONOMIC DATA\WAGES\hrly_wage_usd", replace

////////////////////////////////////////////////////////////////////////////////
///////////// map the per capita gdp for nearest neighbor matching /////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\wdi_ihme_country_match", clear

keep country WHO_region WB_income_group_1 yr2019_pcgdp_current_2019USD

merge 1:1 country WHO_region WB_income_group_1 using  "$output\ECONOMIC DATA\WAGES\hrly_wage_usd"

assert _m==3 
drop _m 

egen group = group(who_income)
tab group
di "There are `r(r)' region-income groups"

order has_data group
sort group has_data country
by group: egen numdonors=total(has_data)
tab country group if numdonors==0

tab who_income has_data,m

compress
save "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD", replace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// Data quality checks ////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD", clear

keep if has_data==1
keep country group who_income WHO_region WB_income_group_1 hrly_wage_2019USD

levelsof who_income, local(region)
foreach r of local region {
	di "******************************"
	di "The region-income group is `r'"
	di "******************************"
	sum hrly_wage_2019USD if who_income =="`r'" 
}

levelsof WB_income_group_1, local(income)
foreach r of local income {
	di "******************************"
	di "The income group is `r'"
	di "******************************"
	sum hrly_wage_2019USD if WB_income_group_1 =="`r'" 
}

////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// IMPUTATIONS ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

///////////// make the files of region-income group donor pools ////////////////

capture program drop matchpools
program matchpools 
version 18.0
set more off
set type double
args pool matchvar folder

use if group==`pool' using "$output\ECONOMIC DATA\\`folder'\\`matchvar'", clear
drop WHO_region WB_income_group_1 
sort has_data country
gen needmatch=""
replace needmatch=country if has_data==0
egen index=group(needmatch)
gen keepme=0
replace keepme=1 if has_data==1 
save "$output\ECONOMIC DATA\\`folder'\\matchpool_`pool'" , replace 

end

forvalues p = 1/14 {
	matchpools `p' hrly_wage_2019USD WAGES
}

////////////// make the files of income group donor pools //////////////////////

capture program drop matchpools
program matchpools
version 18.0
set more off
set type double 
args matchvar folder

use "$output\ECONOMIC DATA\\`folder'\\`matchvar'", clear
drop WHO_region WB_income_group_1 
gen flag=0
replace flag=1 if numdonors==0
assert flag==1 if numdonors==0
drop if has_data==0 & flag==0
drop if has_data==0 & numdonors>0
assert yr2019_pcgdp_current_2019USD<.

gen needmatch=""
replace needmatch=country if has_data==0
egen index=group(needmatch)
drop flag
gen keepme=0
replace keepme=1 if has_data==1 

sort index yr2019_pcgdp_current_2019USD 

save "$output\ECONOMIC DATA\\`folder'\\income_pool" , replace 	

end 

matchpools hrly_wage_2019USD WAGES

clear
capture erase "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD_matches.dta"
save          "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD_matches", replace emptyok

////////////////////////////////////////////////////////////////////////////////
///// nn matching by yr2019_pcgdp_current_2019USD in region-income pools ///////
////////////////////////////////////////////////////////////////////////////////

capture program drop matchme
program matchme 
version 18.0
set more off
set type double 
args pool matchvar folder

use "$output\ECONOMIC DATA\\`folder'\\matchpool_`pool'" , clear
drop if yr2019_pcgdp_current_2019USD==.

levelsof index, local(enn) 
foreach n of local enn {
	use "$output\ECONOMIC DATA\\`folder'\\matchpool_`pool'" , clear
	if numdonors>0 {
		replace keepme=1 if index==`n'	
		keep if keepme==1
		drop keepme index

		sort has_data
		assert has_data==0 if _n==1 
		assert has_data==1 if _n>1
		gen index=_n
		replace index=index-1
		order index

		levelsof index, local(cty)
		foreach c of local cty {
			gen gdp_`c' = .
			replace gdp_`c' = yr2019_pcgdp_current_2019USD if index==`c' & has_data==1
		}

		replace gdp_0 = yr2019_pcgdp_current_2019USD[1]
		assert  gdp_0 == yr2019_pcgdp_current_2019USD if has_data==0

		levelsof index, local(cty)
		foreach c of local cty {
			gen diff_`c' = .
			replace diff_`c' = abs(gdp_0 - gdp_`c') if index==`c' & has_data==1
		}

		gen distance=.
		levelsof index, local(cty)
		foreach c of local cty {
			replace distance = diff_`c' if index==`c' & has_data==1
		}

		egen match = min(distance)
		gen keepme=0
		replace keepme=1 if has_data==0 | match == distance
		keep if keepme==1
		drop gdp_* diff_* index distance match keepme needmatch

		sort has_data
		gen ratio=yr2019_pcgdp_current_2019USD[1]/yr2019_pcgdp_current_2019USD[2]
		replace `matchvar' = `matchvar'[_n+1] if has_data==0
		gen match=country[_n+1] if has_data==0
		keep if has_data==0	
		append using "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches"
		sort group country 
		compress 
		save         "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches", replace
	}	
}

end 

forvalues p = 1/14 {
	matchme `p' hrly_wage_2019USD WAGES
}

////////////////////////////////////////////////////////////////////////////////
///// nn matching by yr2019_pcgdp_current_2019USD globally for countries in ////
/////////////// region-income pools with no donors /////////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop matchme
program matchme 
version 18.0
set more off
set type double 
args matchvar folder

use "$output\ECONOMIC DATA\\`folder'\\income_pool" , clear 

levelsof index, local(enn) 
foreach n of local enn {
	use "$output\ECONOMIC DATA\\`folder'\\income_pool" , clear 
	replace keepme=1 if index==`n'	
	keep if keepme==1
	drop keepme index 

	sort has_data
	assert has_data==0 if _n==1 
	assert has_data==1 if _n>1
	gen index=_n
	replace index=index-1
	order index

	levelsof index, local(cty)
	foreach c of local cty {
		gen gdp_`c' = .
		replace gdp_`c' = yr2019_pcgdp_current_2019USD if index==`c' & has_data==1
	}

	replace gdp_0 = yr2019_pcgdp_current_2019USD[1]
	assert  gdp_0 == yr2019_pcgdp_current_2019USD if has_data==0

	levelsof index, local(cty)
	foreach c of local cty {
		gen diff_`c' = .
		replace diff_`c' = abs(gdp_0 - gdp_`c') if index==`c' & has_data==1
	}

	gen distance=.
	levelsof index, local(cty)
	foreach c of local cty {
		replace distance = diff_`c' if index==`c' & has_data==1
	}

	egen match = min(distance)
	gen keepme=0
	replace keepme=1 if has_data==0 | match == distance
	keep if keepme==1
	drop gdp_* diff_* index distance match keepme needmatch

	sort has_data
	gen ratio=yr2019_pcgdp_current_2019USD[1]/yr2019_pcgdp_current_2019USD[2]
	replace `matchvar' = `matchvar'[_n+1] if has_data==0
	gen match=country[_n+1] if has_data==0
	keep if has_data==0	
	append using "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches"
	sort group country 
	compress 
	save         "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches", replace
}

end 

matchme hrly_wage_2019USD WAGES

////////////////////////////////////////////////////////////////////////////////
/*
Syria does not have GDP data past year 2010. 
Syria's PCGDP in 2010 USD is $2806.69 in the IMF: WEOOct2022all.xlsx.
It's 2010 PCGDP is close to the following countries in IHME: 
Guatemala ($2836.06) and Sri Lanka ($2894.26).
Of these, only Sri Lanka has ILO data. 
*/

capture program drop matchme
program matchme 
version 18.0
set more off
set type double 
args matchvar folder

use "$output\ECONOMIC DATA\\`folder'\\`matchvar'", clear

keep if inlist(country,"Syria", "Sri Lanka")
sort has_data
assert has_data==0 if country =="Syria"
assert has_data==1 if country =="Sri Lanka"
replace `matchvar'=`matchvar'[_n+1] if country =="Syria"
gen ratio=1
drop if country =="Sri Lanka"
drop WHO_region WB_income_group_1
gen match="Sri Lanka"

append using "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches"
sort group country 
compress 
save         "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches", replace
	
end 

matchme hrly_wage_2019USD WAGES

////////////////////////////////////////////////////////////////////////////////
////// adjust imputed variable by the ratio of own to donor pcgdp_current //////
////////////////////////////////////////////////////////////////////////////////

use  "$output\ECONOMIC DATA\\WAGES\\hrly_wage_2019USD_matches", clear

sort country 

assert hrly_wage_2019USD<.
assert ratio<.
sum ratio, d

replace hrly_wage_2019USD = hrly_wage_2019USD*ratio
drop ratio match

merge 1:1 has_data group country yr2019_pcgdp_current_2019USD numdonors using ///
"$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD"
assert _m!=1 
assert has_data==0 if _m==3
drop _m numdonors has_data group yr2019_pcgdp_current_2019USD
assert hrly_wage_2019USD<. 
sort country 
isid country
count 

compress

save "$output\ECONOMIC DATA\WAGES\hrly_wage_2019USD_final", replace

log close 

exit

// end


set more off
clear all
set type double
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
input: 
wdi_ihme_country_match.dta created in: wdi_ihme_country_match.do
*/

capture log close
log using "$output\ECONOMIC DATA\GNI\pc_income_current_2019USD", text replace

use "$output\wdi_ihme_country_match", clear
keep country WHO_region WB_income_group_1 yr2019_pcgdp_current_2019USD yr2019_pcgni_current_USD

gen has_data=1
replace has_data=0 if yr2019_pcgni_current_USD==.
tab has_data, m

egen group = group(WHO_region WB_income_group_1)
tab group 
di "There are `r(r)' groups"

order has_data group
sort group has_data country
by group: egen numdonors=total(has_data)
tab country group if numdonors==0

ren yr2019_pcgni_current_USD pcgni_current_2019USD

compress

save "$output\ECONOMIC DATA\GNI\pcgni_current_2019USD", replace

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
	matchpools `p' pcgni_current_2019USD GNI 
}

clear
capture erase "$output\ECONOMIC DATA\GNI\pcgni_current_2019USD_matches.dta"
save          "$output\ECONOMIC DATA\GNI\pcgni_current_2019USD_matches", replace emptyok

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
	matchme `p' pcgni_current_2019USD GNI
}

/*
Syria does not have GDP data past year 2010. 
Syria's PCGDP in 2010 USD is $2806.69 in the IMF: WEOOct2022all.xlsx.
It's 2010 PCGDP is closest to Guatemala ($2836.06). 
*/

capture program drop matchme
program matchme 
version 18.0
set more off
set type double 
args matchvar folder

use "$output\ECONOMIC DATA\\`folder'\\`matchvar'", clear

keep if inlist(country,"Syria", "Guatemala")
sort has_data
assert has_data==0 if country =="Syria"
assert has_data==1 if country =="Guatemala"
replace `matchvar'=`matchvar'[_n+1] if country =="Syria"
gen ratio=1
drop if country =="Guatemala"
drop WHO_region WB_income_group_1
gen match="Guatemala"

append using "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches"
sort group country 
compress 
save         "$output\ECONOMIC DATA\\`folder'\\`matchvar'_matches", replace
	
end 

matchme pcgni_current_2019USD GNI

////////////////////////////////////////////////////////////////////////////////
////// adjust imputed variable by the ratio of own to donor pcgdp_current //////
////////////////////////////////////////////////////////////////////////////////

use  "$output\ECONOMIC DATA\GNI\pcgni_current_2019USD_matches", clear 

sort country 

assert pcgni_current_2019USD<.
assert ratio<.
sum ratio, d

replace pcgni_current_2019USD = pcgni_current_2019USD*ratio
drop ratio match

merge 1:1 has_data group country yr2019_pcgdp_current_2019USD yr2019_pcgdp_current_2019USD numdonors using ///
"$output\ECONOMIC DATA\GNI\pcgni_current_2019USD"
assert _m!=1 
assert has_data==0 if _m==3

drop _m numdonors has_data group yr2019_pcgdp_current_2019USD yr2019_pcgdp_current_2019USD
assert pcgni_current_2019USD<. 
sort country 
isid country
count 

compress

save "$output\ECONOMIC DATA\GNI\final_pcgni_current_2019USD", replace

log close 

exit

// end
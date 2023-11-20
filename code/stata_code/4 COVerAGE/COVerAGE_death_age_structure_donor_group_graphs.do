
set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
gl knee   "$root\DATA\KNEE"
gl graphs  "$root\GRAPHS\AGE STRUCTURE DEATHS EXTRAPOLATIONS" 
cd        "$root"

/*
input: daily_coverage_deaths.xlsx
*/

////////////////////////////////////////////////////////////////////////////////
/////////////////////////// get the COVerAGE data //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$knee\daily_coverage_deaths.xlsx", ///
clear first case(lower)

keep country date newdeaths_* whoregion worldbankincomegroup

tab country if worldbankincomegroup=="Not Classified"
tab country if worldbankincomegroup==""

replace worldbankincomegroup = "High Income" if country == "Puerto Rico" & worldbankincomegroup == "Not Classified"
replace worldbankincomegroup = "High Income" if country == "Taiwan"
replace worldbankincomegroup = "Middle Income" if country == "Palestine"
assert worldbankincomegroup!=""

tab country if whoregion=="Not Classified"
tab country if whoregion==""

replace whoregion = "AMRO" if country == "Puerto Rico" & whoregion == "Not Classified"
replace whoregion = "WPRO" if country=="Taiwan"
replace whoregion = "EURO" if country == "Palestine"
assert whoregion!=""

split worldbankincomegroup, parse("") gen(income_)

gen income=""
replace income="LIC" if income_1=="Low"
replace income="MIC" if income_1=="Middle"
replace income="HIC" if income_1=="High"
drop income_1 income_2 worldbankincomegroup

reshape long newdeaths_, i(country date whoregion income) j(age)

gen age_cut=irecode(age,10,50)
tab age age_cut,m

collapse (sum) newdeaths_ (min) min_age=age, by(country date whoregion income age_cut)

compress
sort country date age_cut 
by  country date: assert _N==3
gen agegroup=""
by  country date: replace agegroup=strofreal(min_age) + "_" + strofreal(min_age[_n+1]-1) if age_cut<=1
replace agegroup=strofreal(min_age) + "_" + "100" if age_cut==2
tab age_cut agegroup ,m
tab min_age agegroup ,m
drop min_age age_cut

order country date whoregion income agegroup newdeaths_
replace newdeaths_=0 if newdeaths_<0

reshape wide newdeaths_, i(country date whoregion income) j(agegroup) string

gen who_income=whoregion + "_" + income
gen new_who_income=who_income

replace new_who_income="muddled_1" if inlist(who_income,"AFRO_LIC","AFRO_MIC","SEARO_LIC", "AMRO_LIC")
replace new_who_income="muddled_2" if inlist(who_income,"EMRO_LIC","EMRO_MIC")
replace new_who_income="muddled_3" if inlist(who_income,"SEARO_MIC","WPRO_MIC")
replace new_who_income="HIC" if income=="HIC"

tab who_income new_who_income, m
drop who_income income whoregion
ren new_who_income who_income

isid country date

compress 

// aggregate to the geo-income group level

collapse (sum) newdeaths_0_19 newdeaths_20_59 newdeaths_60_100, by(who_income date)

foreach var in newdeaths_0_19 newdeaths_20_59 newdeaths_60_100 {
	assert `var'>=0
}

gen year=substr(date,1,4)
gen month=substr(date,6,2)
gen day=substr(date,9,2)

destring year, replace
destring month, replace 
destring day, replace

gen time=mdy(month,day,year)
format time %td

drop date month day
ren time day 
gen quarter = quarter(day)
drop if year==2022 & quarter>2 

order who_income day year quarter 

collapse (sum) newdeaths_0_19 newdeaths_20_59 newdeaths_60_100, by(who_income year quarter)

egen total_deaths=rowtotal(newdeaths_0_19 newdeaths_20_59 newdeaths_60_100)

foreach age in 0_19 20_59 60_100 {
	gen prop_`age'= newdeaths_`age'/total_deaths
}

assert total_deaths>0 & total_deaths<.

egen check = rowtotal(prop_0_19 prop_20_59 prop_60_100)

sum check, d
assert abs(check-1)<.00000000001 
drop check total_deaths

compress 

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)

gen desc=""
replace desc="AFRO_SEARO_AMRO_LICs_AFRO_MICs" if who_income=="muddled_1"
replace desc="EMRO_LICs_MICs" if who_income=="muddled_2"
replace desc="SEARO_WPRO_MICs" if who_income=="muddled_3"
replace desc="AMRO_EURO_WPRO_HICs" if who_income=="HIC"
replace desc = who_income if inlist(who_income,"AMRO_MIC","EURO_MIC")

order who_income desc year quarter yyyy_qq

sort who_income year quarter
by who_income: assert _N==10

isid who_income year quarter

save "$output\COVerAGE_deaths_by_geo_income_quarter", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// GRAPHS //////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

capture program drop plotme
program plotme
version 18.0
args group

cd "$root\GRAPHS\AGE STRUCTURE DEATHS EXTRAPOLATIONS"

use "$output\COVerAGE_deaths_by_geo_income_quarter", clear

egen strata = group(who_income)
egen time=group(yyyy_qq)

keep if strata == `group'
sort strata time
local output = who_income[1]
local title=desc[1]

#delimit ;
tw (line prop_0_19 time, lcolor(green) sort)
(line prop_20_59 time , lcolor(blue) sort)
(line prop_60_100 time , lcolor(red) sort),
ylabel(0(.1)1, angle(360) labsize(small) grid)
xlabel(
1  "Q1-2020"
2  "Q2-2020"
3  "Q3-2020"
4  "Q4-2020"
5  "Q1-2021"
6  "Q2-2021"
7  "Q3-2021"
8  "Q4-2021"
9  "Q1-2022"
10 "Q2-2022", labsize(small) angle(45) grid)
xtitle("")
ytitle("Proportion of total deaths", size(small))
ysca(titlegap(3))
title("`title'", size(medium))
legend(order(1 "ages 0-19" ///
2 "ages 20-59"  ///
3 "ages 60+") size(small))
legend(cols(3))
;
#delimit cr

graph export "$root\GRAPHS\AGE STRUCTURE DEATHS EXTRAPOLATIONS\\`output'.tif", replace 

end 

plotme 6

forvalues g = 1/6 {
	plotme `g'
}

set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
gl knee   "$root\DATA\KNEE"
cd        "$root"

/*
inputs:
daily_coverage_deaths_5year.xlsx
projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
regions.dta created in: make_regions.do"
*/

capture log close
log using "$output\COVerAGE_quarterly_death_age_structures_5year", text replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////// processed COVerAGE data //////////////////////////////
////////////////////////////////////////////////////////////////////////////////

import excel using "$knee\daily_coverage_deaths_5year.xlsx", ///
clear first case(lower)

keep country date new_* who_region world_bank_income_group

qui tab country 
di "There are `r(r)' countries"

assert world_bank_income_group!="Not Classified"
assert world_bank_income_group!=""

assert who_region!="Not Classified"
assert who_region!=""

tab country world_bank_income_group if inlist(country,"Puerto Rico","Taiwan","Palestine") 
tab country who_region if inlist(country,"Puerto Rico","Taiwan","Palestine") 

split world_bank_income_group, parse("") gen(income_)

gen income=""
replace income="LIC" if income_1=="Low"
replace income="MIC" if income_1=="Middle"
replace income="HIC" if income_1=="High"
tab income income_1, m 

drop income_1 income_2 world_bank_income_group

gen who_income=who_region + "_" + income
gen new_who_income=who_income

order country date who_region income who_income

replace new_who_income="muddled_1" if inlist(who_income,"AFRO_LIC","AFRO_MIC","SEARO_LIC", "AMRO_LIC")
replace new_who_income="muddled_2" if inlist(who_income,"EMRO_LIC","EMRO_MIC")
replace new_who_income="muddled_3" if inlist(who_income,"SEARO_MIC","WPRO_MIC")
replace new_who_income="HIC" if income=="HIC"

tab who_income new_who_income, m
drop who_income income who_region
ren new_who_income who_income

isid country date

compress 

gen year=substr(date,1,4)
gen month=substr(date,6,2)
gen day=substr(date,9,2)

destring year, replace
destring month, replace 
destring day, replace

gen time=mdy(month,day,year)
format time %td
drop day date
gen quarter = quarter(time)
drop if year==2022 & quarter>2 
ren time date 
drop month 

order country who_income date year quarter 
sort country date

gen new_0_14  = new_0 + new_5 + new_10
gen new_15_24 = new_15 + new_20
gen new_25_34 = new_25 + new_30
gen new_35_44 = new_35 + new_40
gen new_45_54 = new_45 + new_50
gen new_55_64 = new_55 + new_60
gen new_65_74 = new_65 + new_70
gen new_75_100 = new_75 + new_80 + new_85 + new_90 + new_95 + new_100 

drop new_0 new_5 new_10 new_15 new_20 new_25 new_30 new_35 new_40 new_45 new_50 new_55 new_60 new_65 new_70 new_75 new_80 new_85 new_90 new_95 new_100

ren new_0_14  new_0
ren new_15_24 new_15
ren new_25_34 new_25
ren new_35_44 new_35
ren new_45_54 new_45
ren new_55_64 new_55
ren new_65_74 new_65
ren new_75_100 new_75

collapse (sum) new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75 , by(country who_income year quarter)

isid country year quarter
sort country year quarter

// list out all records with negative values for deaths, and then recode these to zero

foreach a in 0 15 25 35 45 55 65 75 {
	list country year quarter new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75 if new_`a'<0, sepby(country)
	replace new_`a' = 0 if new_`a'<0
}

foreach a in 0 15 25 35 45 55 65 75 {
	assert new_`a'>=0 & new_`a'<.
}

egen tot_deaths = rowtotal(new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75) 
drop if tot_deaths==0
assert tot_deaths>0

egen min_deaths = rowmin(new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75)
assert min_deaths>=0
drop min_deaths

order country year quarter tot_deaths new* 

gen desc=""
replace desc="AFRO_SEARO_AMRO_LICs_AFRO_MICs" if who_income=="muddled_1"
replace desc="EMRO_LICs_MICs" if who_income=="muddled_2"
replace desc="SEARO_WPRO_MICs" if who_income=="muddled_3"
replace desc="AMRO_EURO_WPRO_HICs" if who_income=="HIC"
replace desc = who_income if inlist(who_income,"AMRO_MIC","EURO_MIC")

compress 

save "$output\COVerAGE_deaths_by_country_quarter", replace

// compute the age structures for the non-missing quarters 

use "$output\COVerAGE_deaths_by_country_quarter", clear 

foreach a in 0 15 25 35 45 55 65 75 {
	gen share_`a'= new_`a'/tot_deaths
}

foreach a in 0 15 25 35 45 55 65 75 {
	assert share_`a'<.
}

drop tot_deaths

egen check = rowtotal(share_0 share_15 share_25 share_35 share_45 share_55 share_65 share_75)

sum check, d
assert abs(1-check)<.00000000001
drop check

sort country year quarter 
by country: gen nobs_country = _N
by country: gen fobs=_n==1
order nobs_country 
tab nobs_country if fobs==1, m

drop fobs
order nobs_country country  year quarter who_income desc

save "$output\COVerAGE_death_shares_by_country_quarter", replace

// create a shell with all 10 quarters

use "$output\COVerAGE_death_shares_by_country_quarter", clear
keep country who_income desc nobs_country
duplicates drop 
count 

expand 10
sort country 
by country: assert _N==10

gen year=.
gen quarter=.

by country: replace year=2020 if _n<=4
by country: replace year=2021 if _n>4 & _n<=8
by country: replace year=2022 if _n>8

sort country year
by country year: replace quarter = 1 if _n==1
by country year: replace quarter = 2 if _n==2
by country year: replace quarter = 3 if _n==3
by country year: replace quarter = 4 if _n==4

merge 1:1 nobs_country country year quarter who_income desc using "$output\COVerAGE_death_shares_by_country_quarter"
assert _m!=2
gen originally=1
// _m==1 are the country-quarters in the balanced panel that are not in the COVerAGE data
replace originally=0 if _m==1 
capture label drop original
label define original 0 "missing" 1 "non-missing"
label value originally original 

egen check = rownonmiss(new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75)
assert check==0 if originally==0
assert check==0 if _m==1
drop _m check

order originally

sort country year quarter
by country: assert _N==10

compress

save "$output\COVerAGE_death_shares_by_country_quarter_10", replace

// create the pooled age structures 

use "$output\COVerAGE_death_shares_by_country_quarter_10", clear 

drop if originally==0
keep  who_income desc year quarter new_*
order who_income desc year quarter new_*
sort who_income year quarter

collapse (sum) new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75 , by(who_income desc year quarter)

isid who_income year quarter
sort who_income year quarter

egen tot_deaths = rowtotal(new_0 new_15 new_25 new_35 new_45 new_55 new_65 new_75)

assert tot_deaths>0

foreach a in 0 15 25 35 45 55 65 75 {
	gen share_`a'= new_`a'/tot_deaths
}

foreach a in 0 15 25 35 45 55 65 75 {
	assert share_`a'<.
}

foreach a in 0 15 25 35 45 55 65 75 {
	assert new_`a'>=0
}

egen check = rowtotal(share_0 share_15 share_25 share_35 share_45 share_55 share_65 share_75)

sum check, d
assert abs(1-check)<.00000000001
drop check tot_deaths new*

sort who_income year quarter
by   who_income: assert _N==10

compress

save "$output\COVerAGE_death_shares_by_who_income_quarter_10", replace

// extrapolate the who_income shares to the countries quarters with missing data 

use "$output\COVerAGE_death_shares_by_country_quarter_10", clear 

keep if originally==0

drop new_* share*
merge m:1 who_income desc year quarter using "$output\COVerAGE_death_shares_by_who_income_quarter_10"

assert _m==3
drop _m

gen pool_data=1

sort  country year quarter
order pool_data originally country year quarter

save "$output\COVerAGE_death_shares_extrapolations_by_country_quarter_10", replace

// append the extrapolated data to the master file 

use "$output\COVerAGE_death_shares_by_country_quarter_10", clear 

drop if originally==0

drop new_* 
append using "$output\COVerAGE_death_shares_extrapolations_by_country_quarter_10"

order pool_data originally nobs_country country year quarter who_income desc

sort country year quarter
by country: assert _N==10

egen nomiss = rownonmiss(share_0 share_15 share_25 share_35 share_45 share_55 share_65 share_75)

assert nomiss==8
drop nomiss 

foreach a in 0 15 25 35 45 55 65 75 {
	assert share_`a'<.
}

replace pool_data=0 if originally==1

compress
save "$output\COVerAGE_quarterly_death_age_structures", replace

// identify the IHME countries not in COVerAGE 

use "$output\IHME\projections_unique_countries.dta", clear 

keep country
duplicates drop 
isid country

count 

merge 1:1 country using "$output\regions.dta", keepusing(country WHO_region WB_income_group_1)
drop if _m==2
tab country if _m==1

replace WHO_region = "WPRO" if inlist(country,"Hong Kong","Taiwan") & _m== 1
replace WHO_region = "EMRO" if country=="Palestine" & _m== 1
replace WHO_region = "AMRO" if country == "Puerto Rico" & WHO_region == "Not Classified"

replace WB_income_group_1 = "High Income" if inlist(country,"Hong Kong","Taiwan") & _m== 1
replace WB_income_group_1 = "Middle Income" if country == "Palestine" & _m== 1 
replace WB_income_group_1 = "High Income" if country == "Puerto Rico" & WB_income_group_1 == "Not Classified"

assert WHO_region!="" 
assert WB_income_group_1!=""

assert WHO_region!="Not Classified" 
assert WB_income_group_1!="Not Classified"

drop _m

sort country

ren WHO_region whoregion
ren WB_income_group_1 worldbankincomegroup

split worldbankincomegroup, parse("") gen(income_)

gen income=""
replace income="LIC" if income_1=="Low"
replace income="MIC" if income_1=="Middle"
replace income="HIC" if income_1=="High"
drop income_1 income_2 worldbankincomegroup

gen who_income=whoregion + "_" + income
gen new_who_income=who_income

replace new_who_income="muddled_1" if inlist(who_income,"AFRO_LIC","AFRO_MIC","SEARO_LIC", "AMRO_LIC")
replace new_who_income="muddled_2" if inlist(who_income,"EMRO_LIC","EMRO_MIC")
replace new_who_income="muddled_3" if inlist(who_income,"SEARO_MIC","WPRO_MIC")
replace new_who_income="HIC" if income=="HIC"

tab who_income new_who_income, m
drop who_income income whoregion
ren new_who_income who_income

gen desc=""
replace desc="AFRO_SEARO_AMRO_LICs_AFRO_MICs" if who_income=="muddled_1"
replace desc="EMRO_LICs_MICs" if who_income=="muddled_2"
replace desc="SEARO_WPRO_MICs" if who_income=="muddled_3"
replace desc="AMRO_EURO_WPRO_HICs" if who_income=="HIC"
replace desc = who_income if inlist(who_income,"AMRO_MIC","EURO_MIC")

tab desc, m

count

merge 1:m country who_income desc using "$output\COVerAGE_quarterly_death_age_structures"

// _m==1 are the countries in the IHME data not in the COVerAGE file

keep if _m==1
drop _m pool_data originally nobs_country share*

isid country 

expand 10
sort country 
by country: assert _N==10

by country: replace year=2020 if _n<=4
by country: replace year=2021 if _n>4 & _n<=8
by country: replace year=2022 if _n>8

sort country year
by country year: replace quarter = 1 if _n==1
by country year: replace quarter = 2 if _n==2
by country year: replace quarter = 3 if _n==3
by country year: replace quarter = 4 if _n==4

compress

// map on the who_region age structures

merge m:1 who_income desc year quarter using "$output\COVerAGE_death_shares_by_who_income_quarter_10"
assert _m==3 
drop _m

isid country year quarter

sort country year quarter

by country: assert _N==10

foreach a in 0 15 25 35 45 55 65 75 {
	assert share_`a'<. 
}

gen originally=0
capture label drop original
label define original 0 "missing" 1 "non-missing"
label value originally original 

gen pool_data=1
gen nobs_country=0

append using "$output\COVerAGE_quarterly_death_age_structures"

tab originally pool_data,m
drop pool_data 

order originally nobs_country country year quarter who_income desc

qui tab country 
di "There are `r(r)' countries"

sort country year quarter
isid country year quarter

compress

save "$output\COVerAGE_quarterly_death_age_structures", replace 

// keep only the IHME countries

use "$output\IHME\projections_unique_countries.dta", clear 

keep country
duplicates drop 
isid country
count

merge 1:m country using "$output\COVerAGE_quarterly_death_age_structures"
assert _m!=1

// _m==2 are the countries in the COVerAGE file not in IHME 

tab country if _m==2
drop if _m==2 
drop _m 

qui tab country 
di "There are `r(r)' countries"

sort country year quarter
isid country year quarter

compress

gen data_source=country 
replace data_source = desc if originally==0
tab data_source if originally==0, m
tab data_source if originally==1, m
drop who_income desc

foreach a in 0 15 25 35 45 55 65 75 {
	ren share_`a' prop_`a'
}

egen check = rowtotal(prop_0 prop_15 prop_25 prop_35 prop_45 prop_55 prop_65 prop_75)
sum check, d
assert abs(1-check)<.00000000001

order country year quarter originally data_source prop_* nobs_country check

compress

save "$output\COVerAGE_quarterly_death_age_structures", replace 

export excel using "$output\COVerAGE_death_age_structures.xlsx", first(var) sheet("quarterly") sheetreplace

log close
exit

// end 
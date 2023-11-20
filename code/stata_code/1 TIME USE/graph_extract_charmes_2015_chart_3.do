set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_3", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 3 //////
// Distribution of time spent in various activities in a 24-hour average day ///
///////////////// in countries in the Middle East and North Africa /////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 3 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

replace survey = round(survey)
assert _N==24
sort survey

replace survey =_n

gen country="", before(survey)
replace country = "Algeria" if inlist(survey,1,2,3)
replace country = "Iran" if inlist(survey,4,5,6)
replace country = "Iraq" if inlist(survey,7,8,9)
replace country = "Oman" if inlist(survey,10,11,12)
replace country = "Palestine" if inlist(survey,13,14,15)
replace country = "Qatar" if inlist(survey,16,17,18)
replace country = "Tunisia" if inlist(survey,19,20,21)
replace country = "Turkey" if inlist(survey,22,23,24)

sort country survey 
by country:keep if _n==3
drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 3 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

replace survey = round(survey)
assert _N==24
sort survey

replace survey =_n

gen country="", before(survey)
replace country = "Algeria" if inlist(survey,1,2,3)
replace country = "Iran" if inlist(survey,4,5,6)
replace country = "Iraq" if inlist(survey,7,8,9)
replace country = "Oman" if inlist(survey,10,11,12)
replace country = "Palestine" if inlist(survey,13,14,15)
replace country = "Qatar" if inlist(survey,16,17,18)
replace country = "Tunisia" if inlist(survey,19,20,21)
replace country = "Turkey" if inlist(survey,22,23,24)

sort country survey 
by country:keep if _n==3
drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 unpaid_work", replace

/////////////////////////// learning, leisure //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 3 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

replace survey = round(survey)
assert _N==24
sort survey

replace survey =_n

gen country="", before(survey)
replace country = "Algeria" if inlist(survey,1,2,3)
replace country = "Iran" if inlist(survey,4,5,6)
replace country = "Iraq" if inlist(survey,7,8,9)
replace country = "Oman" if inlist(survey,10,11,12)
replace country = "Palestine" if inlist(survey,13,14,15)
replace country = "Qatar" if inlist(survey,16,17,18)
replace country = "Tunisia" if inlist(survey,19,20,21)
replace country = "Turkey" if inlist(survey,22,23,24)

sort country survey 
by country:keep if _n==3
drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 leisure", replace

//////////////////////////////////////// other //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 3 other.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_other

replace survey = round(survey)
assert _N==24
sort survey

replace survey =_n

gen country="", before(survey)
replace country = "Algeria" if inlist(survey,1,2,3)
replace country = "Iran" if inlist(survey,4,5,6)
replace country = "Iraq" if inlist(survey,7,8,9)
replace country = "Oman" if inlist(survey,10,11,12)
replace country = "Palestine" if inlist(survey,13,14,15)
replace country = "Qatar" if inlist(survey,16,17,18)
replace country = "Tunisia" if inlist(survey,19,20,21)
replace country = "Turkey" if inlist(survey,22,23,24)

sort country survey 
by country:keep if _n==3
drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3 other"
assert _m==3 
drop _m 

sort country 

#delimit ;
graph bar pct_paid_work, over(country)
blabel(bar,size (vsmall))
ytitle("both")
;
#delimit cr

#delimit ;
graph bar pct_unpaid_work, over(country)
blabel(bar,size (vsmall))
ytitle("both")
;
#delimit cr

#delimit ;
graph bar pct_leisure, over(country)
blabel(bar,size (vsmall))
ytitle("both")
;
#delimit cr

#delimit ;
graph bar pct_other, over(country)
blabel(bar,size (vsmall))
ytitle("both")
;
#delimit cr

replace pct_other = pct_leisure if inlist(country,"Iran","Oman","Palestine","Qatar")
replace pct_other = pct_other - pct_leisure 
replace pct_leisure = pct_leisure -  pct_unpaid_work 
replace pct_unpaid_work = pct_unpaid_work -  pct_paid_work 
gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure + pct_other

#delimit ;
graph bar pct_total, over(country)
blabel(bar,size (vsmall))
ytitle("both")
;
#delimit cr

gen sex=2
gen chart = 3
gen geo = "Middle East and North Africa"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3", replace

log close 

exit 

// end


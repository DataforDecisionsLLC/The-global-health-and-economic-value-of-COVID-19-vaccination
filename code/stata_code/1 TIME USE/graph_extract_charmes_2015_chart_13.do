set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_13", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 13 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
////////////// average day in sub-Saharan African countries ////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 13 formal_&_informal_paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

replace survey = round(survey)
assert _N==6
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Benin" if survey==1
replace country = "Ghana" if survey==2
replace country = "Ethiopia" if survey==3
replace country = "Madagascar" if survey==4
replace country = "Mali" if survey==5
replace country = "South Africa" if survey==6

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 13 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

replace survey = round(survey)
assert _N==6
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Benin" if survey==1
replace country = "Ghana" if survey==2
replace country = "Ethiopia" if survey==3
replace country = "Madagascar" if survey==4
replace country = "Mali" if survey==5
replace country = "South Africa" if survey==6

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 unpaid_work", replace

////////////////////////// learning & leisure //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 13 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

replace survey = round(survey)
assert _N==6
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Benin" if survey==1
replace country = "Ghana" if survey==2
replace country = "Ethiopia" if survey==3
replace country = "Madagascar" if survey==4
replace country = "Mali" if survey==5
replace country = "South Africa" if survey==6

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 leisure", replace

///////////////////////////////// other ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 13 other.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_other

replace survey = round(survey)
assert _N==6
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Benin" if survey==1
replace country = "Ghana" if survey==2
replace country = "Ethiopia" if survey==3
replace country = "Madagascar" if survey==4
replace country = "Mali" if survey==5
replace country = "South Africa" if survey==6

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13 other"
assert _m==3 
drop _m 

sort country 

#delimit ;
graph bar pct_paid_work, over(country)
blabel(bar,size (small))
ytitle("paid work")
;
#delimit cr

#delimit ;
graph bar pct_unpaid_work, over(country)
blabel(bar,size (small))
ytitle("unpaid work")
;
#delimit cr

#delimit ;
graph bar pct_leisure, over(country)
blabel(bar,size (small))
ytitle("leisure")
;
#delimit cr

#delimit ;
graph bar pct_other, over(country)
blabel(bar,size (small))
ytitle("other")
;
#delimit cr

replace pct_other= pct_leisure if inlist(country,"Ghana","Ethiopia","South Africa")
replace pct_other = pct_other - pct_leisure 
replace pct_leisure = pct_leisure - pct_unpaid_work 
replace pct_unpaid_work = pct_unpaid_work - pct_paid_work
gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure + pct_other

#delimit ;
graph bar pct_total, over(country)
blabel(bar,size (small))
ytitle("total")
;
#delimit cr

gen sex=0
gen chart = 13
gen geo = "Sub-Saharan Africa"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13", replace

log close 

exit 

// end


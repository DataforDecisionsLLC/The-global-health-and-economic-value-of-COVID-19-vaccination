set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_67", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 67 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
/////////////////////////// average day in North America ///////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 67 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_paid_work

replace survey = round(survey)
assert _N==2
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Canada" if survey==1
replace country = "United States" if survey==2

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 67 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_unpaid_work

replace survey = round(survey)
assert _N==2
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Canada" if survey==1
replace country = "United States" if survey==2

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 67 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_leisure

replace survey = round(survey)
assert _N==2
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Canada" if survey==1
replace country = "United States" if survey==2

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 leisure", replace

//////////////////////////// personal care /////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 67 pc.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_pc

replace survey = round(survey)
assert _N==2
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Canada" if survey==1
replace country = "United States" if survey==2

replace pct_pc = 100 if  country == "Canada"

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 pc", replace

/////////////////////////////////// other //////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 67 other.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_other

replace survey = round(survey)
assert _N==2
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Canada" if survey==1
replace country = "United States" if survey==2

replace pct_other = 100

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 pc"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67 other"
assert _m==3 
drop _m 

sort country 

#delimit ;
graph bar pct_paid_work, over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("paid work")
;
#delimit cr

#delimit ;
graph bar pct_unpaid_work, over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("unpaid work")
;
#delimit cr

#delimit ;
graph bar pct_leisure, over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("leisure")
;
#delimit cr

#delimit ;
graph bar pct_pc, over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("pc")
;
#delimit cr

#delimit ;
graph bar pct_other, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("other")
;
#delimit cr

replace pct_other = pct_other - pct_pc
replace pct_pc = pct_pc - pct_leisure
replace pct_leisure = pct_leisure - pct_unpaid_work 
replace pct_unpaid_work = pct_unpaid_work - pct_paid_work

gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure + pct_pc + pct_other

#delimit ;
graph bar pct_total,  over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("total")
;
#delimit cr

drop pct_total pct_pc

gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure + pct_other

#delimit ;
graph bar pct_total, over(country, label(angle(45)))
blabel(bar,size (vsmall))
ytitle("total")
;
#delimit cr

gen sex = 0
gen chart = 67
gen geo = "North America"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67", replace

log close 

exit 

// end


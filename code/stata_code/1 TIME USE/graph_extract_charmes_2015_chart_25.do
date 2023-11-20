set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_25", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 25 /////
//// Distribution of time spent by men in various activities in a 24-hour //////
////////////////////// average day in Asian countries //////////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 25 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

replace survey = round(survey)
replace survey=_n
assert _N==9
sort survey

gen country="", before(survey)
replace country = "Armenia" if survey==1
replace country = "Cambodia" if survey==2
replace country = "China" if survey==3
replace country = "India" if survey==4
replace country = "South Korea" if survey==5
replace country = "Kyrgyzstan" if survey==6
replace country = "Mongolia" if survey==7
replace country = "Pakistan" if survey==8
replace country = "Thailand" if survey==9

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 25 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

replace survey = round(survey)
replace survey=_n
assert _N==9
sort survey

gen country="", before(survey)
replace country = "Armenia" if survey==1
replace country = "Cambodia" if survey==2
replace country = "China" if survey==3
replace country = "India" if survey==4
replace country = "South Korea" if survey==5
replace country = "Kyrgyzstan" if survey==6
replace country = "Mongolia" if survey==7
replace country = "Pakistan" if survey==8
replace country = "Thailand" if survey==9

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 25 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

replace survey = round(survey)
replace survey=_n
assert _N==9
sort survey

gen country="", before(survey)
replace country = "Armenia" if survey==1
replace country = "Cambodia" if survey==2
replace country = "China" if survey==3
replace country = "India" if survey==4
replace country = "South Korea" if survey==5
replace country = "Kyrgyzstan" if survey==6
replace country = "Mongolia" if survey==7
replace country = "Pakistan" if survey==8
replace country = "Thailand" if survey==9

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 leisure", replace

//////////////////////////// personal care /////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 25 pc.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_pc

replace survey = round(survey)
replace survey=_n
assert _N==9
sort survey

gen country="", before(survey)
replace country = "Armenia" if survey==1
replace country = "Cambodia" if survey==2
replace country = "China" if survey==3
replace country = "India" if survey==4
replace country = "South Korea" if survey==5
replace country = "Kyrgyzstan" if survey==6
replace country = "Mongolia" if survey==7
replace country = "Pakistan" if survey==8
replace country = "Thailand" if survey==9

replace pct_pc = 100 if inlist(country,"Cambodia","China","India","Kyrgyzstan","Mongolia","Pakistan","Thailand")

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 pc", replace

/////////////////////////////////// other //////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 25 other.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_other

replace survey = round(survey)
replace survey=_n
assert _N==9
sort survey

gen country="", before(survey)
replace country = "Armenia" if survey==1
replace country = "Cambodia" if survey==2
replace country = "China" if survey==3
replace country = "India" if survey==4
replace country = "South Korea" if survey==5
replace country = "Kyrgyzstan" if survey==6
replace country = "Mongolia" if survey==7
replace country = "Pakistan" if survey==8
replace country = "Thailand" if survey==9

replace pct_other=100

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 pc"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25 other"
assert _m==3 
drop _m 

sort country 

#delimit ;
graph bar pct_paid_work, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("paid work")
;
#delimit cr

#delimit ;
graph bar pct_unpaid_work, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("unpaid work")
;
#delimit cr

#delimit ;
graph bar pct_leisure, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("leisure")
;
#delimit cr

#delimit ;
graph bar pct_pc, over(country, label(angle(45)))
blabel(bar,size (small))
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
graph bar pct_total, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("total")
;
#delimit cr

drop pct_total pct_pc

gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure + pct_other

#delimit ;
graph bar pct_total, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("total")
;
#delimit cr

gen sex = 1
gen chart = 25
gen geo = "Asia"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25", replace

log close 

exit 

// end


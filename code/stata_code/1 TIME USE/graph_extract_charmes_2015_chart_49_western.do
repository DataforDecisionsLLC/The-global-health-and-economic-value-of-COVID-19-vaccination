set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_49_western", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 49 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
/////////////////////////// average day in Western Europe /////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 49 Western Europe paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

replace survey = round(survey)
assert _N==5
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Austria" if survey==1
replace country = "Belgium" if survey==2
replace country = "France" if survey==3
replace country = "Germany" if survey==4
replace country = "Netherlands" if survey==5

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 49 Western Europe unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

replace survey = round(survey)
assert _N==5
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Austria" if survey==1
replace country = "Belgium" if survey==2
replace country = "France" if survey==3
replace country = "Germany" if survey==4
replace country = "Netherlands" if survey==5

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 49 Western Europe leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

replace survey = round(survey)
assert _N==5
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Austria" if survey==1
replace country = "Belgium" if survey==2
replace country = "France" if survey==3
replace country = "Germany" if survey==4
replace country = "Netherlands" if survey==5

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe leisure", replace

//////////////////////////// personal care /////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 49 Western Europe pc.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_pc

replace survey = round(survey)
assert _N==5
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Austria" if survey==1
replace country = "Belgium" if survey==2
replace country = "France" if survey==3
replace country = "Germany" if survey==4
replace country = "Netherlands" if survey==5

replace pct_pc=100 if country =="Austria"

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe pc", replace

/////////////////////////////////// other //////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 49 Western Europe other.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_other

replace survey = round(survey)
assert _N==5
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Austria" if survey==1
replace country = "Belgium" if survey==2
replace country = "France" if survey==3
replace country = "Germany" if survey==4
replace country = "Netherlands" if survey==5

replace pct_other=100

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe pc"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe other"
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
gen chart = 49
gen geo = "Western Europe"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe", replace

log close 

exit 

// end


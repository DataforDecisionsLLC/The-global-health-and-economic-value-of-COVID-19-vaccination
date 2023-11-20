set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_59", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 59 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
//////////// average day in the transition countries of Eastern Europe /////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 59 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

replace survey = round(survey)
assert _N==11
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Albania" if survey==1
replace country = "Bulgaria" if survey==2
replace country = "Estonia" if survey==3
replace country = "Hungary" if survey==4
replace country = "Latvia" if survey==5
replace country = "Lithuania" if survey==6
replace country = "Moldova" if survey==7
replace country = "Poland" if survey==8
replace country = "Romania" if survey==9
replace country = "Serbia" if survey==10
replace country = "Slovenia" if survey==11

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 59 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

replace survey = round(survey)
assert _N==11
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Albania" if survey==1
replace country = "Bulgaria" if survey==2
replace country = "Estonia" if survey==3
replace country = "Hungary" if survey==4
replace country = "Latvia" if survey==5
replace country = "Lithuania" if survey==6
replace country = "Moldova" if survey==7
replace country = "Poland" if survey==8
replace country = "Romania" if survey==9
replace country = "Serbia" if survey==10
replace country = "Slovenia" if survey==11

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 59 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

replace survey = round(survey)
assert _N==11
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Albania" if survey==1
replace country = "Bulgaria" if survey==2
replace country = "Estonia" if survey==3
replace country = "Hungary" if survey==4
replace country = "Latvia" if survey==5
replace country = "Lithuania" if survey==6
replace country = "Moldova" if survey==7
replace country = "Poland" if survey==8
replace country = "Romania" if survey==9
replace country = "Serbia" if survey==10
replace country = "Slovenia" if survey==11

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 leisure", replace

//////////////////////////// personal care /////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 59 pc.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_pc

replace survey = round(survey)
assert _N==11
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Albania" if survey==1
replace country = "Bulgaria" if survey==2
replace country = "Estonia" if survey==3
replace country = "Hungary" if survey==4
replace country = "Latvia" if survey==5
replace country = "Lithuania" if survey==6
replace country = "Moldova" if survey==7
replace country = "Poland" if survey==8
replace country = "Romania" if survey==9
replace country = "Serbia" if survey==10
replace country = "Slovenia" if survey==11

replace pct_pc = 100 if country=="Moldova"
drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 pc", replace

/////////////////////////////////// other //////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 59 other.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_other

replace survey = round(survey)
assert _N==11
replace survey = _n
sort survey

gen country="", before(survey)
replace country = "Albania" if survey==1
replace country = "Bulgaria" if survey==2
replace country = "Estonia" if survey==3
replace country = "Hungary" if survey==4
replace country = "Latvia" if survey==5
replace country = "Lithuania" if survey==6
replace country = "Moldova" if survey==7
replace country = "Poland" if survey==8
replace country = "Romania" if survey==9
replace country = "Serbia" if survey==10
replace country = "Slovenia" if survey==11

replace pct_other=100

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 other", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 pc"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59 other"
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

gen sex = 1
gen chart = 59
gen geo = "Eastern Europe"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59", replace

log close 

exit 

// end


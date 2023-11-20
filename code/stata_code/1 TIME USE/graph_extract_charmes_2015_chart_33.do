set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_33", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 33 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
//////////////// average day in Latin American countries ///////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 33 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_paid_work

replace survey = round(survey)
assert survey == _n
sort survey

gen country="", before(survey)
replace country = "Colombia" if survey==1
replace country = "Costa Rica" if survey==2
replace country = "Ecuador" if survey==3
replace country = "El Salvador" if survey==4
replace country = "Mexico" if survey==5
replace country = "Panama" if survey==6
replace country = "Peru" if survey==7

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 33 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_unpaid_work

replace survey = round(survey)
assert survey == _n
sort survey

gen country="", before(survey)
replace country = "Colombia" if survey==1
replace country = "Costa Rica" if survey==2
replace country = "Ecuador" if survey==3
replace country = "El Salvador" if survey==4
replace country = "Mexico" if survey==5
replace country = "Panama" if survey==6
replace country = "Peru" if survey==7

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 33 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren dataset4x survey
ren dataset4y pct_leisure

replace survey = round(survey)
assert survey == _n
sort survey

gen country="", before(survey)
replace country = "Colombia" if survey==1
replace country = "Costa Rica" if survey==2
replace country = "Ecuador" if survey==3
replace country = "El Salvador" if survey==4
replace country = "Mexico" if survey==5
replace country = "Panama" if survey==6
replace country = "Peru" if survey==7

drop survey
compress

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 leisure", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33 leisure"
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

replace pct_leisure = pct_leisure - pct_unpaid_work 
replace pct_unpaid_work = pct_unpaid_work - pct_paid_work

gen pct_total = pct_paid_work + pct_unpaid_work + pct_leisure

#delimit ;
graph bar pct_total, over(country, label(angle(45)))
blabel(bar,size (small))
ytitle("total")
;
#delimit cr

gen sex = 0
gen chart = 33
gen geo = "Latin America"
order chart geo sex country

gen pct_other=0

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33", replace

log close 

exit 

// end


set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$raw\TIME USE\CHARMES\Processed\graph_extract_charmes_2015_chart_34", text replace

////////////////////////////////////////////////////////////////////////////////
//// Process data points extracted using DigitizeIt: Charmes 2015-Chart 34 /////
//// Distribution of time spent by women in various activities in a 24-hour ////
//////////////// average day in Latin American countries ///////////////////////

///////////////////////////////// paid work ////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 34 paid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_paid_work

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

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 paid_work", replace

///////////////////////////////// unpaid work //////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 34 unpaid_work.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_unpaid_work

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

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 unpaid_work", replace

/////////////////////////////// leisure ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 34 leisure.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_leisure

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

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 leisure", replace

/////////////////////////////// pc ////////////////////////////////////////

import excel using ///
"$raw\TIME USE\CHARMES\DigitizeIt\Charmes 2015-Chart 34 pc.xlsx", ///
clear sheet("Data") first case(lower)

ren datasetx survey
ren datasety pct_pc

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

replace pct_pc=100 if country!="Mexico"

save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 pc", replace

////////////////////////////// combine /////////////////////////////////////////

use                     "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 paid_work", clear 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 unpaid_work"
assert _m==3 
drop _m
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 leisure"
assert _m==3 
drop _m 
merge 1:1 country using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34 pc"
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
ytitle("leisure")
;
#delimit cr

gen pct_other = 100 - pct_pc
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
gen chart = 34
gen geo = "Latin America"
order chart geo sex country

compress 
save "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34", replace

log close 

exit 

// end


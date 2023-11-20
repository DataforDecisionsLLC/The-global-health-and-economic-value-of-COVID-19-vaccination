set more off
clear all
set type double
version 18.0

gl raw    "\RAW DATA"
gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

capture log close
log using "$output\ECONOMIC DATA\TIME USE\Charmes_2015", text replace

////////////////////////////////////////////////////////////////////////////////
//////////// STACK PROCESSED CHARMES 2015 GRAPH EXTRACTS ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use          "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 3", clear
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 13"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 14"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 24"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 25"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 33"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 34"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Northern Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Western Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 49 Southern Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 50 Northern Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 50 Western Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 50 Southern Europe"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 58"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 59"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 67"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 68"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 76"
append using "$raw\TIME USE\CHARMES\Processed\Charmes 2015-Chart 77"

capture label drop sex 
label define sex 0 "women" 1 "men" 2 "both"
label value sex sex

foreach t in paid_work unpaid_work leisure other total {
	replace pct_`t' = pct_`t'/100
}

foreach t in paid_work unpaid_work leisure other total {
	gen min_`t' = pct_`t'*1440
}

foreach t in paid_work unpaid_work leisure other total {
	gen hrs_`t' = min_`t'/60
}

egen check = rowtotal(pct_paid_work min_paid_work min_unpaid_work min_leisure min_other)
gen diff = check/min_total 
sum diff, d 
drop diff check
assert min_total <1440

foreach t in paid_work unpaid_work leisure other total {
	sum hrs_`t' if sex==0,d
}

foreach t in paid_work unpaid_work leisure other total {
	sum hrs_`t' if sex==1,d
}

foreach t in paid_work unpaid_work leisure other total {
	sum hrs_`t' if sex==2,d
}

levelsof geo, local(geo)
foreach g of local geo {
	di "*********************************"
	di "The geo area is `g'"
	di "*********************************"
	foreach t in paid_work unpaid_work leisure other total {
		sum hrs_`t' if geo=="`g'" & sex==0,d
	}
}

levelsof geo, local(geo)
foreach g of local geo {
	di "*********************************"
	di "The geo area is `g'"
	di "*********************************"
	foreach t in paid_work unpaid_work leisure other total {
		sum hrs_`t' if geo=="`g'" & sex==1,d
	}
}

levelsof geo, local(geo)
foreach g of local geo {
	di "*********************************"
	di "The geo area is `g'"
	di "*********************************"
	foreach t in paid_work unpaid_work leisure other total {
		sum hrs_`t' if geo=="`g'" & sex==2,d
	}
}

sort chart sex country
compress

save "$output\ECONOMIC DATA\TIME USE\Charmes_2015.dta", replace

drop hrs*

export excel using "$output\ECONOMIC DATA\TIME USE\Charmes_2015.xlsx", first(var) sheet("Stata") sheetreplace

log close 

exit 

// end


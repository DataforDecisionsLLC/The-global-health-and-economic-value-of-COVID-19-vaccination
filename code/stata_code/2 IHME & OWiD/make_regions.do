set more off
clear all
set type double
version 18.0

gl raw    ".......\RAW DATA"
gl root   ".......\DB Work"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
master_country_list_owid.xlsx
*/

/*
master_country_list_owid.xlsx has mapped the geo classifications and income 
group classifications to the master list of countries.
*/

import excel using "$output\master_country_list_owid.xlsx", ///
clear sheet("master_list") cellrange(A1:L246) first 

drop if mi(country)
drop if mi(UN_region)

compress

save "$output\regions", replace
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
1. projections_countries_w_pop_gt_1M.dta created in: make_historical_data_countries_w_pop_gt_1M.do
*/

capture log close
log using "$output\IHME\make_quarterly_deaths_&_infections", text replace

////////////////////////////////////////////////////////////////////////////////
///// construct dependent variables for the death and infection regressions ////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\projections_countries_w_pop_gt_1M", clear 
keep country date year quarter cumulative_deaths daily_deaths inf_cuml_mean inf_mean

gen yyyy_qq = strofreal(year) + "_" + "Q" + strofreal(quarter)
order country date year quarter yyyy_qq

sort country year quarter date 

////////////////////////////////////////////////////////////////////////////////
//////// confirm there are no missing deaths between non-missing values ////////
////////////////////////////////////////////////////////////////////////////////

assert daily_deaths ==. if cumulative_deaths==. 
assert cumulative_deaths==. if daily_deaths == . 

gen flag=0
sort country year quarter date 
by country: replace flag=1 if _n>1 & _n<_N & cumulative_deaths==. & cumulative_deaths[_n-1] < . & cumulative_deaths[_n+1] <.
assert flag==0 
drop flag

////////////////////////////////////////////////////////////////////////////////
//////// confirm there are no missing infections between non-missing values ////
////////////////////////////////////////////////////////////////////////////////

assert inf_mean ==. if inf_cuml_mean==. 
assert inf_cuml_mean==. if inf_mean == . 

gen flag=0
sort country year quarter date 
by country: replace flag=1 if _n>1 & _n<_N & inf_cuml_mean==. & inf_cuml_mean[_n-1] < . & inf_cuml_mean[_n+1] <.
assert flag==0 
drop flag

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// recode MVs to zero ///////////////////////////
////////////////////////////////////////////////////////////////////////////////

/////////////////////////////// death issue 1a /////////////////////////////////

replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Lesotho", "Malawi", "South Sudan")

/////////////////////////////// death issue 1b /////////////////////////////////

replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2022_Q2" & inlist(country, "Benin", "Burkina Faso", "Cambodia", "Congo", "Cuba", "Gabon")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2022_Q2" & inlist(country, "Kazakhstan", "Kyrgyzstan", "Liberia", "Oman", "Somalia", "South Sudan", "Uzbekistan")
replace daily_deaths=0 if daily_deaths==. & country == "Kazakhstan" & inlist(yyyy_qq, "2021_Q4", "2022_Q1")

/////////////////// death issue 2: Kazakhstan //////////////////////////////////

sort country date
gen flag=. 
replace flag=1 if country=="Kazakhstan" & date>=mdy(9,1,2021) & date<=mdy(9,16,2021)
sort country flag date 
by country flag:egen mean_deaths=mean(daily_deaths)
sort country date
by country: replace daily_deaths = mean_deaths[_n-1]  if country=="Kazakhstan" & date==mdy(9,17,2021)
by country: replace daily_deaths = daily_deaths[_n-1] if country=="Kazakhstan" & date>=mdy(9,18,2021) & date<=mdy(9,30,2021)
drop flag mean_deaths

//////////////////// death issue 2: Kyrgyzstan /////////////////////////////////

sort country date
gen flag=. 
replace flag=1 if country=="Kyrgyzstan" & date>=mdy(3,1,2022) & date<=mdy(3,14,2022)
sort country flag date 
by country flag:egen mean_deaths=mean(daily_deaths)
sort country date
by country: replace daily_deaths = mean_deaths[_n-1]  if country=="Kyrgyzstan" & date==mdy(3,15,2022)
by country: replace daily_deaths = daily_deaths[_n-1] if country=="Kyrgyzstan" & date>=mdy(3,16,2022) & date<=mdy(3,31,2022)
drop flag mean_deaths

////////////////////// death issue 2: Uzbekistan ///////////////////////////////

sort country date
gen flag=. 
replace flag=1 if country=="Uzbekistan" & date>=mdy(2,1,2022) & date<=mdy(2,28,2022)
sort country flag date 
by country flag:egen mean_deaths=mean(daily_deaths)
sort country date
by country: replace daily_deaths = mean_deaths[_n-1]  if country=="Uzbekistan" & date==mdy(3,1,2022)
by country: replace daily_deaths = daily_deaths[_n-1] if country=="Uzbekistan" & date>=mdy(3,2,2022) & date<=mdy(3,31,2022)
drop flag mean_deaths

/////////////////////////////// death issue 4 //////////////////////////////////

sort country year quarter date 
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Benin","Cambodia","Central African Republic","Chad","Equatorial Guinea","Eswatini","Ethiopia")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Georgia","Guinea","Guinea-Bissau","Haiti","Kazakhstan","Kuwait","Kyrgyzstan")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Latvia","Lesotho","Liberia","Libya","Madagascar","Mongolia","Mozambique")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Namibia","Nepal","Papua New Guinea","Rwanda","Senegal","Sierra Leone","Slovakia")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q1" & inlist(country,"Somalia","Timor-Leste","Uganda","Vietnam","Yemen","Zambia")

/////////////////////////////// death issue 5 //////////////////////////////////

replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2022_Q2" & inlist(country,"Angola","Central African Republic","Equatorial Guinea","Gambia","Sierra Leone")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2021_Q1" & inlist(country,"Australia")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q2" & inlist(country,"Botswana")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2021_Q3" & inlist(country,"Chad")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2021_Q4" & inlist(country,"China")
replace daily_deaths=0 if daily_deaths==. & yyyy_qq == "2020_Q4" & inlist(country,"New Zealand")
replace daily_deaths=0 if daily_deaths==. & inlist(yyyy_qq,"2020_Q3","2020_Q4") & inlist(country,"Taiwan")
replace daily_deaths=0 if daily_deaths==. & inlist(yyyy_qq,"2020_Q2","2020_Q4","2021_Q1") & inlist(country,"Vietnam")

/////////////////////////////// infections issue 4 /////////////////////////////

replace inf_mean=0 if inf_mean==. & country== "Lesotho" & inlist(yyyy_qq, "2020_Q1","2020_Q2")

////////////////////////////////////////////////////////////////////////////////
/// examine any remaining missing values for daily deaths & infections /////////
////////////////////////////////////////////////////////////////////////////////

sort country year quarter date 
tab yyyy_qq if daily_deaths==.
assert inlist(yyyy_qq,"2020_Q1","2020_Q2") if daily_deaths==.

gen flag=0 
by country: replace flag=1 if _n>1 & _n<_N & daily_deaths>=0 & daily_deaths<. & daily_deaths[_n-1] ==. & yyyy_qq==yyyy_qq[_n-1]
by country: replace flag=1 if _n>1 & _n<_N & daily_deaths[_n+1]>=0 & daily_deaths[_n+1]<. & daily_deaths==. & yyyy_qq==yyyy_qq[_n+1]
list country date daily_deaths if flag==1 & yyyy_qq=="2020_Q1", sepby(country)
list country date daily_deaths if flag==1 & yyyy_qq=="2020_Q2", sepby(country)
replace daily_deaths=0 if daily_deaths==.
drop flag

assert inf_mean<. 

////////////////////////////////////////////////////////////////////////////////
//// issue 3: recode the first non-missing/non-zero daily values of to the /////
///// corresponding cumulative values in cases where they are not equal ////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////// deaths //////////////////////////////////////
 
sort country year quarter date 
by country: gen run_deaths = sum(daily_deaths)
gen flag_deaths=0 
by country: replace flag_deaths=1 if _n>1 & run_deaths > 0 & run_deaths[_n-1]==0 & cumulative_deaths > daily_deaths
by country: replace flag_deaths=1 if _n==1 & run_deaths > 0 & cumulative_deaths > daily_deaths & cumulative_deaths<.
list country date cumulative_deaths daily_deaths if flag_deaths==1, sep(0)

replace daily_deaths = cumulative_deaths if flag_deaths==1
list country date cumulative_deaths daily_deaths if flag_deaths==1, sep(0)
drop run_deaths flag_deaths 

///////////////////////////////// infections ///////////////////////////////////

sort country year quarter date 
by country: gen run_infections = sum(inf_mean)
gen flag_infections=0 
by country: replace flag_infections=1 if _n>1 & run_infections > 0 & run_infections[_n-1]==0 & inf_cuml_mean > inf_mean
by country: replace flag_infections=1 if _n==1 & run_infections > 0 & inf_cuml_mean > inf_mean
list country date inf_cuml_mean inf_mean if flag_infections==1, sep(0)

replace inf_mean = inf_cuml_mean if flag_infections==1
list country date inf_cuml_mean inf_mean if flag_infections==1, sep(0)
drop run_infections flag_infections 

////////////////////////////////////////////////////////////////////////////////
//////////////// aggregate daily deaths to the quarter level ///////////////////
////////////////////////////////////////////////////////////////////////////////

drop cumulative_deaths inf_cuml_mean 

codebook daily_deaths inf_mean
collapse (sum) daily_deaths inf_mean, by(country year quarter yyyy_qq)
assert daily_deaths <.
assert inf_mean<.

sort country year quarter
by country: assert _N==10 

// count the number of quarters with non-zero deaths

gen flag=0 
replace flag=1 if daily_deaths==0
tab country yyyy_qq if flag==1
di "There are `r(r)' countries with at least one quarter of zero deaths"

tab yyyy_qq if flag==1 

drop flag 

compress 
save "$output\IHME\quarterly_deaths_&_infections", replace

log close

exit

// end
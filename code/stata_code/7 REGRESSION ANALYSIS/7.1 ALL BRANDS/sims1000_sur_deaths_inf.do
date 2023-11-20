set more off
clear all
set type double
set matsize 5000
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

/*
inputs:
S_death.dta created in: make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do
S_inf.dta created in: make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do
X_vax_sureg.dta created in: make_X_vax_X_novax_sims1000.do
sim_`sim'_X_novax_sureg.dta created in: make_X_vax_X_novax_sims1000.do
vov_vars_sureg_deaths_inf.dta created in: make_vov_vars_sureg_deaths_inf.do
VoV_gdp_qrtly.dta created in: sims1000_gdp_qrtly.do 
VoV_gdp_annual.dta created in: sims1000_gdp_annual.do 
*/

////////////////////////////////////////////////////////////////////////////////
/////////// 1. make the matrix that stacks the coefficient estimates ///////////
////////////// from the death regression for each of the 1000 draws ////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\S_death", clear 

mkmat ///
S_death1 S_death2 S_death3 S_death4 S_death5 S_death6 S_death7 S_death8 S_death9 S_death10 S_death11 S_death12 S_death13 S_death14 S_death15 S_death16 S_death17 S_death18 S_death19 S_death20 S_death21 S_death22 S_death23 S_death24 S_death25 S_death26 S_death27 S_death28 S_death29 S_death30 S_death31 S_death32 S_death33 S_death34 S_death35 S_death36 S_death37 S_death38 S_death39 S_death40 S_death41 S_death42 S_death43 S_death44 S_death45 S_death46 S_death47 S_death48 S_death49 S_death50 S_death51 S_death52 S_death53 S_death54 S_death55 S_death56 S_death57 S_death58 S_death59 S_death60 S_death61 S_death62 S_death63 S_death64 S_death65 S_death66 S_death67 S_death68 S_death69 S_death70 S_death71 S_death72 S_death73 S_death74 S_death75 S_death76 S_death77 S_death78 S_death79 S_death80 S_death81 S_death82 S_death83 S_death84 S_death85 S_death86 S_death87 S_death88 S_death89 S_death90 S_death91 S_death92 S_death93 S_death94 S_death95 S_death96 S_death97 S_death98 S_death99 S_death100 S_death101 S_death102 S_death103 S_death104 S_death105 S_death106 S_death107 S_death108 S_death109 S_death110 S_death111 S_death112 S_death113 S_death114 S_death115 S_death116 S_death117 S_death118 S_death119 S_death120 S_death121 S_death122 S_death123 S_death124 S_death125 S_death126 S_death127 S_death128 S_death129 S_death130 S_death131 S_death132 S_death133 S_death134 S_death135 S_death136 S_death137 S_death138 S_death139 S_death140 S_death141 S_death142 S_death143 S_death144 S_death145 S_death146 S_death147 S_death148 S_death149 S_death150 S_death151 S_death152 S_death153 S_death154 S_death155 S_death156 S_death157 S_death158 S_death159 , matrix(S_death)

////////////////////////////////////////////////////////////////////////////////
//////////// 2. make the matrix that stacks the coefficient estimates //////////
////////// from the infection regression for each of the 1000 draws ////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\S_inf", clear 

mkmat ///
S_inf1 S_inf2 S_inf3 S_inf4 S_inf5 S_inf6 S_inf7 S_inf8 S_inf9 S_inf10 S_inf11 S_inf12 S_inf13 S_inf14 S_inf15 S_inf16 S_inf17 S_inf18 S_inf19 S_inf20 S_inf21 S_inf22 S_inf23 S_inf24 S_inf25 S_inf26 S_inf27 S_inf28 S_inf29 S_inf30 S_inf31 S_inf32 S_inf33 S_inf34 S_inf35 S_inf36 S_inf37 S_inf38 S_inf39 S_inf40 S_inf41 S_inf42 S_inf43 S_inf44 S_inf45 S_inf46 S_inf47 S_inf48 S_inf49 S_inf50 S_inf51 S_inf52 S_inf53 S_inf54 S_inf55 S_inf56 S_inf57 S_inf58 S_inf59 S_inf60 S_inf61 S_inf62 S_inf63 S_inf64 S_inf65 S_inf66 S_inf67 S_inf68 S_inf69 S_inf70 S_inf71 S_inf72 S_inf73 S_inf74 S_inf75 S_inf76 S_inf77 S_inf78 S_inf79 S_inf80 S_inf81 S_inf82 S_inf83 S_inf84 S_inf85 S_inf86 S_inf87 S_inf88 S_inf89 S_inf90 S_inf91 S_inf92 S_inf93 S_inf94 S_inf95 S_inf96 S_inf97 S_inf98 S_inf99 S_inf100 S_inf101 S_inf102 S_inf103 S_inf104 S_inf105 S_inf106 S_inf107 S_inf108 S_inf109 S_inf110 S_inf111 S_inf112 S_inf113 S_inf114 S_inf115 S_inf116 S_inf117 S_inf118 S_inf119 S_inf120 S_inf121 S_inf122 S_inf123 S_inf124 S_inf125 S_inf126 S_inf127 S_inf128 S_inf129 S_inf130 S_inf131 S_inf132 S_inf133 S_inf134 S_inf135 S_inf136 S_inf137 S_inf138 S_inf139 S_inf140 S_inf141 S_inf142 S_inf143 S_inf144 S_inf145 S_inf146 S_inf147 S_inf148 S_inf149 S_inf150 S_inf151 S_inf152 S_inf153 S_inf154 S_inf155 S_inf156 S_inf157 S_inf158 S_inf159, matrix(S_inf)

////////////////////////////////////////////////////////////////////////////////
//////// 3. make the matrix where each row is an observation in the SUR ////////
// regression and each column is an independent variable where the vax dosage //
////////////////// variables retain the values under vax ///////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\X_vax_sureg", clear

mkmat X1-X159, matrix(X_vax)

********************************************************************************
********************************************************************************
********************** simulation specific program *****************************
********************************************************************************
********************************************************************************

clear all 
input rownum
0
end

expand 1160 
replace rownum = _n 
count 
assert `r(N)'==1160

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg.dta", replace

capture log close
log using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_1000_sur_deaths_inf", text replace

capture program drop getvov 
program getvov 
version 18.0 
set type double 
set more off 
args sim

di "***************************************************************************"
di "*********************** RUNNING SIMULATION `sim' *************************"
di "***************************************************************************"

////////////////////////////////////////////////////////////////////////////////
//// 4. compute the predicted values under vax for each of the 1000 vectors ////
////////////// of coefficient estimates from the SUR regression ////////////////
////////////////////////////////////////////////////////////////////////////////

/////////////////////////// 7a. death regression ///////////////////////////////

matrix F_vax_death = S_death*X_vax'

clear 
svmat F_vax_death

keep in `sim'

tempfile yhat_1_deaths
save `yhat_1_deaths' 

/////////////////////////// 7b. infections regression //////////////////////////

matrix F_vax_inf = S_inf*X_vax'

clear 
svmat F_vax_inf

keep in `sim'

tempfile yhat_1_infections
save `yhat_1_infections'

////////////////////////////////////////////////////////////////////////////////
/////// 5. make the matrix where each row is an observation in the SUR /////////
// regression and each column is an independent variable where all vax dosage //
///// variables are equal to zero (novax), the osi variable is prevax, and /////
/////////////// the infections variables are at the novax levels ///////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim_`sim'_X_novax_sureg", clear

mkmat X1-X159, matrix(X_novax)

////////////////////////////////////////////////////////////////////////////////
//////////////////// compute the predicted values under novax //////////////////
////////// for each of the 1000 vectors of coefficient estimates ///////////////
////////////////////////////////////////////////////////////////////////////////

/////////////////////////// 5a. death regression ///////////////////////////////

matrix F_novax_death = S_death*X_novax'

clear 
svmat F_novax_death

keep in `sim'

tempfile yhat_2_deaths
save `yhat_2_deaths'

/////////////////////////// 5b. infections regression //////////////////////////

matrix F_novax_inf = S_inf*X_novax'

clear 
svmat F_novax_inf

keep in `sim'

tempfile yhat_2_infections
save `yhat_2_infections'

////////////////////////////////////////////////////////////////////////////////
/////// 6. compute the difference in predicted outcomes under vax v novax ///// 
////////////////////////////////////////////////////////////////////////////////

/////////////////////////// 6a. death regression //////////////////////////////

use `yhat_1_deaths', clear 

mkmat F_vax_death1-F_vax_death1160, matrix(Y_1_death)

use `yhat_2_deaths', clear 

mkmat F_novax_death1-F_novax_death1160, matrix(Y_2_death)

matrix D_death=Y_2_death-Y_1_death

matrix G_death = D_death'

clear 
svmat G_death

gen rownum = _n
order rownum

tempfile gains_sureg
save `gains_sureg'

/////////////////////////// 6b. infections regression /////////////////////////

use `yhat_1_infections', clear 

mkmat F_vax_inf1-F_vax_inf1160, matrix(Y_1_inf)

use `yhat_2_infections', clear 

mkmat F_novax_inf1-F_novax_inf1160, matrix(Y_2_inf)

matrix D_inf=Y_2_inf-Y_1_inf

matrix G_inf = D_inf'

clear 
svmat G_inf

gen rownum = _n
order rownum 

merge 1:1 rownum using  `gains_sureg'
assert _m==3 
drop _m 
sort rownum

////////////////////////////////////////////////////////////////////////////////
/// 7. compute averted non-fatal infections for each of the 1000 simulations ///
////////////////////////////////////////////////////////////////////////////////

ren G_inf1 G_inf`sim' 
ren G_death1 G_death`sim'
gen G_nf`sim' = G_inf`sim' - G_death`sim'

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg"
assert _m==3 
drop _m 
sort rownum

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg", replace

end 

forvalues s=1/1000 {
	getvov `s'
}

log close

////////////////////////////////////////////////////////////////////////////////
/////// 8. map on population, QALY gains, direct costs, indirect costs, ///////
// & full income to each country-quarter obs, indexed by the rownum variable ///
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg", clear 

merge 1:1 rownum using "$root\REGRESSION RESULTS\SUR\vov_vars_sureg_deaths_inf"
assert _m==3 
drop _m 
sort rownum
order rownum tot_pop nf_qaly fatal_qaly indirect_costs_fatal_case indirect_costs_nf_case direct_costs yf /*gdp_usd_projected*/

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg_w_vov_vars", replace

////////////////////////////////////////////////////////////////////////////////
//////////// 9. compute population-wide averted deaths, infections ////////////
//// & non-fatal infections from all brands for each of the 1000 simulations ///
////////////////////////////////////////////////////////////////////////////////

use   "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg_w_vov_vars", clear

forvalues s = 1/1000 {
	gen gain_death`s' = tot_pop*G_death`s'
	drop G_death`s'
}

forvalues s = 1/1000 {
	gen gain_inf`s' = tot_pop*G_inf`s'
	drop G_inf`s'
}

forvalues s = 1/1000 {
	gen gain_nf`s' = tot_pop*G_nf`s'
	drop G_nf`s'
}

reshape long gain_death gain_inf gain_nf, i(rownum tot_pop nf_qaly fatal_qaly indirect_costs_fatal_case indirect_costs_nf_case direct_costs yf) j(sim) 
order sim
isid rownum sim 
sort sim rownum 

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg_long", replace

////////////////////////////////////////////////////////////////////////////////
//////////////////// 10. for each simulation/country-quarter ///////////////////
/// compute averted direct and indirect costs for fatal and non-fatal cases ////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\gains_sureg_long", clear

gen fatal_indirect_cost_overall = gain_death*indirect_costs_fatal_case 
gen nf_indirect_cost_overall = gain_nf*indirect_costs_nf_case
gen direct_cost_averted_overall = gain_inf*direct_costs

gen averted_cost_overall = nf_indirect_cost_overall + direct_cost_averted_overall

drop direct_costs indirect_costs_nf_case indirect_costs_fatal_case

////////////////////////////////////////////////////////////////////////////////
//////////////// 11. for each simulation/country-quarter ///////////////////////
/////////////////// compute fatal and non-fatal QALY gains /////////////////////
////////////////////////////////////////////////////////////////////////////////

gen fatal_qaly_gain = gain_death*fatal_qaly 
gen nf_qaly_gain = gain_nf*nf_qaly
gen qaly_gain_overall = fatal_qaly_gain + nf_qaly_gain

drop nf_qaly fatal_qaly

ren fatal_qaly_gain fatal_qaly_gain_overall
ren nf_qaly_gain nf_qaly_gain_overall 

////////////////////////////////////////////////////////////////////////////////
////////// 12. monetize health gains using pre-pandemic 2019 full income ///////
////////////////////////////////////////////////////////////////////////////////

gen vov_overall = qaly_gain_overall*yf
drop yf

keep sim rownum vov_overall averted_cost_overall

gen vov_deaths_inf_ = vov_overall + averted_cost_overall
drop vov_overall averted_cost_overall

reshape wide vov_deaths_inf_ , i(sim) j(rownum)

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim1000_vov_sureg", replace

////////////////////////////////////////////////////////////////////////////////
/////// 13. compute the VoV of all brands for each of the 1000 simulations /////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sim1000_vov_sureg", clear
keep sim vov_deaths_inf_*

egen VoV_deaths_infections=rowtotal(vov_deaths_inf_1-vov_deaths_inf_1112)
keep sim VoV_deaths_infections

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_sureg", replace

///////////////// combine with gdp /////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_sureg", clear

merge 1:1 sim using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_gdp_qrtly"
assert _m==3 
drop _m 
merge 1:1 sim using "$root\REGRESSION RESULTS\SUR\SIMULATIONS\VoV_gdp_annual"
assert _m==3 
drop _m 

gen Full_VoV_all = VoV_deaths_infections + VoV_gdp_qrtly + VoV_gdp_annual

egen pct_lower = pctile(Full_VoV_all), p(2.5)
egen pct_median = pctile(Full_VoV_all), p(50)
egen pct_upper = pctile(Full_VoV_all), p(97.5)

keep pct*
duplicates drop 

foreach p in lower median upper {
	format pct_`p'  %20.0gc
}

gen lookup = "sur_all_brands"
order lookup 

list

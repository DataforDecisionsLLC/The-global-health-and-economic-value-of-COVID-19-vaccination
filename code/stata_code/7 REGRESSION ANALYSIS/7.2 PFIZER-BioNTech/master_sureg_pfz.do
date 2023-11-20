do make_X_vax_deaths_inf_pfz.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta 
sur_regbase_deaths_inf.dta 
prevax_osi.dta 
outputs:
X_vax_deaths_inf_pfz.dta
*/

do make_X_vax_pfz.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
prevax_osi.dta
outputs:
X_vax_pfz.dta
*/

////////////////////////////////////////////////////////////////////////////////
////////////////// these programs run through the simulation ///////////////////
////////////////////////////////////////////////////////////////////////////////

do make_beta_&_X_vax_deaths_inf_pfz.do 
/*
inputs: 
X_vax_deaths_inf_pfz.dta 
tot_pop_deaths_inf.dta
country_betas_deaths_inf.dta 
infections_betas_deaths_inf.dta 
output:
sim_0_beta_&_X_vax_deaths_inf_pfz.dta
*/

do make_beta_&_X_vax_pfz.do 
/*
inputs: 
X_vax_pfz.dta 
tot_pop_deaths_inf.dta 
country_betas_sims1000.dta 
infections_betas_sims1000.dta 
output:
sim_`sim'_beta_&_X_vax_pfz.dta 
*/

do make_novax_infections_deaths_inf_pfz.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: 
sim_0_beta_&_X_vax_deaths_inf_pfz.dta
output:
sim_0_novax_inf_pfz_deaths_inf.dta
*/

do make_novax_infections_pfz.do
/*
inputs:
sim_`sim'_beta_&_X_vax_pfz.dta
outputs:
sim_`sim'_novax_inf_pfz.dta
*/

do make_X_vax_X_novax_pfz.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta 
sur_regbase_deaths_inf.dta 
sim_`sim'_novax_inf_pfz.dta 
outputs:
sim_`sim'_X_novax_sureg_pfz.dta 
*/

do make_X_vax_X_novax_sims1000_gdp_qrtly_pfz.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
quarterly_gdp_regbase.dta
sim_`sim'_novax_inf_pfz.dta
output:
sim_`sim'_X_novax_gdp_qrtly_pfz.dta 
*/

do sims1000_gdp_qrtly_pfz.do 
/*
inputs:
sims_quarterly_gdp.dta
X_vax_gdp_qrtly.dta 
sim_`sim'_X_novax_gdp_qrtly_pfz.dta
vov_vars_gdp_qrtly.dta
outputs:
VoV_gdp_qrtly_pfz.dta 
*/

do sims1000_gdp_annual_pfz.do 
/*
input:
sims_annual_gdp.dta
X_vax_gdp_annual.dta 
X_novax_gdp_annual_pfz.dta 
vov_vars_gdp_annual.dta
output:
VoV_gdp_annual_pfz.dta 
*/

do sims1000_sur_deaths_inf_pfz.do 
/*
inputs:
S_death.dta
S_inf.dta
X_vax_sureg.dta
sim_`sim'_X_novax_sureg_pfz.dta
vov_vars_sureg_deaths_inf.dta
VoV_gdp_qrtly_pfz.dta
VoV_gdp_annual_pfz.dta
outputs:
VoV_sureg_pfz.dta 
*/

do quarterly_death_pfizer_v_other_pfz.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
sim_0_novax_inf_pfz_deaths_inf.dta
output:
no_cont_2_lags_death_pfizer_v_other_pfz.dta
*/

do quarterly_infections_pfizer_v_other_pfz.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
sim_0_novax_inf_pfz_deaths_inf.dta
output:
no_cont_2_lags_infections_pfizer_v_other_pfz.dta 
*/

do quarterly_regs_pfz.do 
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_pfz_deaths_inf.dta
vax_launch_quarter_deaths_inf.dta
quarterly_gdp_usd.dta
output:
no_cont_2_lags_gdp_pfizer_v_other_pfz.dta 
*/

do annual_gdp_regs_pfz.do 
/*
inputs: 
quarterly_gdp_usd.dta 
annual_gdp_regbase.dta
output:
pfz_annual_gdp.dta 
*/
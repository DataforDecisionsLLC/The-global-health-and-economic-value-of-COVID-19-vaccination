do make_vov_vars_sureg_deaths_inf.do
/*
inputs:
sur_regbase_deaths_inf.dta 
qaly_losses_per_nonfatal_case.dta 
qaly_losses_per_fatal_case.dta 
unpaid_work_loss_nonfatal_case.dta 
direct_costs_current_2019USD.dta 
full_income.dta
quarterly_gdp_usd.dta
outputs: 
vov_vars_sureg_deaths_inf.dta
*/

do make_country_time_lookups_deaths_inf.do
/*
inputs: 
sur_regbase_deaths_inf.dta
outputs:
country_group_lookup_deaths_inf.dta
time_period_lookup_deaths_inf.dta
*/

do make_vax_launch_quarter_deaths_inf.do
/*
inputs: 
sur_regbase_deaths_inf.dta
country_group_lookup_deaths_inf.dta
outputs: 
vax_launch_quarter_deaths_inf.dta
*/

do make_X_vax_deaths_inf.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
prevax_osi.dta
outputs:
X_vax_deaths_inf.dta
tot_pop_deaths_inf.dta
*/

do make_S_inf_S_death_S_quarterly_gdp_S_annual_gdp.do
/*
inputs:
sur_regbase_deaths_inf.dta
quarterly_gdp_regbase.dta
annual_gdp_regbase.dta
outputs:
S_death.dta 
S_inf.dta 
sims_quarterly_gdp.dta
sims_annual_gdp.dta
*/

////////////////////////////////////////////////////////////////////////////////
////////////////// these programs run through the simulation ///////////////////
////////////////////////////////////////////////////////////////////////////////

do make_infections_betas_deaths_inf.do 
/*
inputs: 
sur_regbase_deaths_inf.dta
country_group_lookup_deaths_inf.dta
outputs: 
infections_betas_deaths_inf.dta 
*/

do make_infections_betas_sims1000.do 
/*
inputs: 
S_inf.dta 
country_group_lookup_deaths_inf.dta 
outputs: 
infections_betas_sims1000.dta 
*/

do make_beta_&_X_vax_deaths_inf.do 
/*
inputs: 
infections_betas_deaths_inf.dta
X_vax_deaths_inf.dta
tot_pop_deaths_inf.dta
outputs:
country_betas_deaths_inf.dta
sim_0_beta_&_X_vax_deaths_inf.dta 
*/

do make_beta_&_X_vax_sims1000.do 
/*
inputs: 
infections_betas_sims1000.dta 
X_vax_deaths_inf.dta 
tot_pop_deaths_inf.dta 
outputs:
country_betas_sims1000.dta
sim_`sim'_beta_&_X_vax.dta 
*/

do make_novax_infections_deaths_inf.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sim_0_beta_&_X_vax_deaths_inf.dta
output:
sim_0_novax_inf_all_vax_deaths_inf.dta
*/

do make_novax_infections_sims1000.do
/*
inputs: 
sim_`sim'_beta_&_X_vax.dta 
output:
sim_`sim'_novax_inf_all_vax.dta 
*/

do make_X_vax_X_novax_sims1000.do
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
sim_`sim'_novax_inf_all_vax.dta
outputs:
sim_`sim'_X_novax_sureg.dta 
X_vax_sureg.dta 
*/

do make_X_vax_X_novax_sims1000_gdp_qrtly.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta 
quarterly_gdp_regbase.dta 
sim_`sim'_novax_inf_all_vax.dta 
outputs:
sim_`sim'_X_novax_gdp_qrtly.dta 
X_vax_gdp_qrtly.dta 
*/

do make_X_vax_X_novax_sims1000_gdp_annual.do 
/*
inputs: 
annual_gdp_regbase.dta 
outputs:
X_novax_gdp_annual.dta 
X_novax_gdp_annual_pfz.dta 
X_vax_gdp_annual.dta 
*/

do sims1000_gdp_qrtly.do 
/*
inputs:
sims_quarterly_gdp.dta 
X_vax_gdp_qrtly.dta 
sim_`sim'_X_novax_gdp_qrtly.dta 
quarterly_gdp_regbase.dta 
quarterly_gdp_usd.dta 
output:
vov_vars_gdp_qrtly.dta
VoV_gdp_qrtly.dta 
*/

do sims1000_gdp_annual.do 
/*
inputs:
sims_annual_gdp.dta
X_vax_gdp_annual.dta 
X_novax_gdp_annual.dta
annual_gdp_regbase.dta
outputs: 
vov_vars_gdp_annual.dta
VoV_gdp_annual.dta
*/

do sims1000_sur_deaths_inf.do
/*
inputs:
S_death.dta
S_inf.dta
X_vax_sureg.dta
sim_`sim'_X_novax_sureg.dta
vov_vars_sureg_deaths_inf.dta
VoV_gdp_qrtly.dta 
VoV_gdp_annual.dta 
outputs:
VoV_sureg.dta 
*/

do quarterly_death_pfizer_v_other_overall.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta 
sur_regbase_deaths_inf.dta  
sim_0_novax_inf_all_vax_deaths_inf.dta 
output:
no_cont_2_lags_death_pfizer_v_other_overall.dta 
*/

do quarterly_infections_pfizer_v_other_overall.do 
/*
inputs: 
vax_launch_quarter_deaths_inf.dta
sur_regbase_deaths_inf.dta
sim_0_novax_inf_all_vax_deaths_inf.dta
output:
no_cont_2_lags_infections_pfizer_v_other_overall.dta
*/

do quarterly_regs_overall.do 
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_all_vax_deaths_inf.dta
vax_launch_quarter_deaths_inf.dta
quarterly_gdp_usd.dta
output:
no_cont_2_lags_gdp_pfizer_v_other_overall_quarterly_gdp.dta 
*/

do annual_gdp_regs_overall.do 
/*
inputs: 
quarterly_gdp_usd.dta 
annual_gdp_regbase.dta
output:
overall_annual_gdp.dta 
*/
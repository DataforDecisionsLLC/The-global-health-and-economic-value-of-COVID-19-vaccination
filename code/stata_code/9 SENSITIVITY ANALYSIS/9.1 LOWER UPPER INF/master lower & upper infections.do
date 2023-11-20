do "make_inf_lower_upper_countries_w_pop_gt_1M.do"
/*
inputs:
Historical-and-Projected-Covid-19-data.dta
projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
outputs:
infections_countries_w_pop_gt_1M.dta 
*/

do "make_inf_lower_upper_Hong_Kong_China_Macao.do"
/*
inputs:
Historical-and-Projected-Covid-19-data.dta created in: make_historical_data_countries_w_pop_gt_1M.do
outputs:
infections_Hong_Kong_China_Macoa.dta
*/

do "make_quarterly_infections_lower_upper.do"
/*
inputs:
infections_countries_w_pop_gt_1M.dta created in: make_inf_lower_upper_countries_w_pop_gt_1M.do
quarterly_deaths_&_infections.dta created in: make_quarterly_deaths_&_infections.do
outputs:
quarterly_deaths_&_infections_lower_upper.dta
*/

do "make_quarterly_infections_lower_upper_China.do"
/*
inputs:
infections_Hong_Kong_China_Macoa.dta created in: make_inf_lower_upper_Hong_Kong_China_Macao.do
quarterly_deaths_&_infections_China.dta created in: make_quarterly_deaths_&_infections_China.do
outputs:
quarterly_deaths_&_infections_lower_upper_China.dta
*/

do "make_quarterly_regbase_infections_lower_upper.do"
/*
inputs:
quarterly_deaths_&_infections_lower_upper.dta created in: make_quarterly_infections_lower_upper.do
quarterly_deaths_&_infections_lower_upper_China.dta
gdp_gap_ihme.xlsx 
quarterly_vaccine_coverage_pfizer_v_other.dta created in: make_quarterly_vaccine_coverage_pfizer_v_other.do
national_population_2020_2021_2022.dta 
China_quarterly_vaccine_coverage_pfizer_v_other_v2.dta created in:  make_China_quarterly_vaccine_coverage_pfizer_v_other.do
outputs:
quarterly_regbase_infections_lower_upper.dta
*/

do "make_sur_regbase_infections_lower_upper_deaths_inf.do"
/*
input: 
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
outputs:
sur_regbase_infections_lower_upper_deaths_inf.dta
sur_regbase_infections_lower.dta 
sur_regbase_infections_upper.dta 
*/

do "make_sur_regbase_infections_lower_upper_gdp_qrtly.do"
/*
inputs: 
quarterly_gdp_regbase.dta created in: make_quarterly_gdp_usd.do
quarterly_regbase_infections_lower_upper.dta created in: make_quarterly_regbase_infections_lower_upper.do
outputs:
sur_regbase_infections_lower_gdp_qrtly.dta 
sur_regbase_infections_upper_gdp_qrtly.dta 
*/

do "make_sur_regbase_infections_lower_upper_gdp_annual.do"
/*
inputs: 
quarterly_regbase_infections_lower_upper.dta created in: make_quarterly_regbase_infections_lower_upper.do
annual_gdp_regbase.dta created in: make_annual_gdp_regbase.do
outputs:
sur_regbase_infections_lower_gdp_annual.dta 
sur_regbase_infections_upper_gdp_annual.dta 
*/

do "make_X_vax_lower_upper.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_deaths_inf.do 
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_deaths_inf.do 
prevax_osi.dta created in: make_sur_regbase_deaths_inf.do
outputs: 
X_vax_lower.dta
X_vax_upper.dta
*/

do "make_X_vax_pfz_lower_upper.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_deaths_inf.do 
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_deaths_inf.do 
prevax_osi.dta created in: make_sur_regbase_deaths_inf.do
outputs: 
X_vax_pfz_lower.dta
X_vax_pfz_upper.dta
*/

do "make_beta_&_X_vax_lower_upper.do"
/*
inputs: 
X_vax_lower.dta created in: make_X_vax_lower_upper.do
X_vax_upper.dta created in: make_X_vax_lower_upper.do
tot_pop_deaths_inf.dta created in: make_X_vax_deaths_inf.do
country_betas_deaths_inf.dta created in: make_beta_&_X_vax_deaths_inf.do 
infections_betas_deaths_inf.dta created in: make_infections_betas_deaths_inf.do 
outputs:
sim_0_beta_&_X_vax_lower.dta
sim_0_beta_&_X_vax_upper.dta
*/

do "make_beta_&_X_vax_pfz_lower_upper.do"
/*
inputs: 
X_vax_pfz_upper.dta created in: make_X_vax_pfz_lower_upper.do
X_vax_pfz_lower.dta created in: make_X_vax_pfz_lower_upper.do
tot_pop_deaths_inf.dta created in: make_X_vax_deaths_inf.do
country_betas_deaths_inf.dta created in: make_beta_&_X_vax_deaths_inf.do 
infections_betas_deaths_inf.dta created in: make_infections_betas_deaths_inf.do 
outputs:
sim_0_beta_&_X_vax_pfz_lower.dta
sim_0_beta_&_X_vax_pfz_upper.dta
*/

do "make_novax_infections_lower_upper.do"
/*
inputs: 
sim_0_beta_&_X_vax_lower.dta created in: make_beta_&_X_vax_lower_upper.do
sim_0_beta_&_X_vax_upper.dta created in: make_beta_&_X_vax_lower_upper.do
outputs:
sim_0_novax_inf_all_vax_lower.dta
sim_0_novax_inf_all_vax_upper.dta
*/

do "make_novax_infections_pfz_lower_upper.do"
/*
inputs: 
sim_0_beta_&_X_vax_pfz_lower.dta created in: make_beta_&_X_vax_pfz_lower_upper.do
sim_0_beta_&_X_vax_pfz_upper.dta created in: make_beta_&_X_vax_pfz_lower_upper.do
outputs:
sim_0_novax_inf_pfz_lower.dta
sim_0_novax_inf_pfz_upper.dta
*/

do "lower_death_pfizer_v_other_overall.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_all_vax_lower.dta created in: make_novax_infections_lower_upper.do
outputs:
lower_death_pfizer_v_other_overall.dta 
*/

do "lower_death_pfizer_v_other_pfz.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_pfz_lower.dta created in: make_novax_infections_pfz_lower_upper.do
outputs:
lower_death_pfizer_v_other_pfz.dta 
*/

do "lower_infections_pfizer_v_other_overall.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_all_vax_lower.dta created in: make_novax_infections_lower_upper.do
outputs:
lower_infections_pfizer_v_other_overall.dta 
*/

do "lower_infections_pfizer_v_other_pfz.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_lower.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_pfz_lower.dta created in: make_novax_infections_pfz_lower_upper.do
outputs:
lower_infections_pfizer_v_other_pfz.dta 
*/

do "lower_gdp_pfizer_v_other_overall.do"
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_all_vax_lower.dta
vax_launch_quarter_deaths_inf.dta
sur_regbase_infections_lower_gdp_qrtly.dta
quarterly_gdp_usd.dta
output:
lower_gdp_pfizer_v_other_overall.dta 
*/

do "lower_gdp_pfizer_v_other_pfz.do"
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_pfz_lower.dta
vax_launch_quarter_deaths_inf.dta
sur_regbase_infections_lower_gdp_qrtly.dta
quarterly_gdp_usd.dta
output:
lower_gdp_pfizer_v_other_pfz.dta 
*/

do "annual_gdp.do"
/*
inputs: 
sur_regbase_infections_lower_gdp_annual.dta 
sur_regbase_infections_upper_gdp_annual.dta
outputs:
lower_gdp_annual_overall.dta 
lower_gdp_annual_pfz.dta 
upper_gdp_annual_overall.dta 
upper_gdp_annual_pfz.dta 
*/

do "upper_death_pfizer_v_other_overall.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_all_vax_upper.dta created in: make_novax_infections_lower_upper.do
outputs:
upper_death_pfizer_v_other_overall.dta 
*/

do "upper_death_pfizer_v_other_pfz.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_pfz_upper.dta created in: make_novax_infections_pfz_lower_upper.do
outputs:
upper_death_pfizer_v_other_pfz.dta 
*/

do "upper_infections_pfizer_v_other_overall.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_all_vax_upper.dta created in: make_novax_infections_lower_upper.do
outputs:
upper_infections_pfizer_v_other_overall.dta 
*/

do "upper_infections_pfizer_v_other_pfz.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_infections_upper.dta created in: make_sur_regbase_infections_lower_upper_gdp_qrtly.do
sim_0_novax_inf_pfz_upper.dta created in: make_novax_infections_pfz_lower_upper.do
outputs:
upper_infections_pfizer_v_other_pfz.dta 
*/

do "upper_gdp_pfizer_v_other_overall.do"
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_all_vax_upper.dta
vax_launch_quarter_deaths_inf.dta
sur_regbase_infections_upper_gdp_qrtly.dta
quarterly_gdp_usd.dta
output:
upper_gdp_pfizer_v_other_overall.dta 
*/

do "upper_gdp_pfizer_v_other_pfz.do"
/*
inputs:
quarterly_gdp_regbase.dta
country_group_lookup_deaths_inf.dta
sim_0_novax_inf_pfz_upper.dta
vax_launch_quarter_deaths_inf.dta
sur_regbase_infections_upper_gdp_qrtly.dta
quarterly_gdp_usd.dta
output:
upper_gdp_pfizer_v_other_pfz.dta 
*/

do "COVID-19 vaccine health impacts and values - inf_lower.do"
/*
inputs:
lower_death_pfizer_v_other_overall.dta 
lower_infections_pfizer_v_other_overall.dta 
indirect_costs_nonfatal_case.dta 
direct_costs_current_2019USD.dta 
qaly_losses_per_nonfatal_case.dta 
qaly_losses_per_fatal_case.dta 
lower_death_pfizer_v_other_pfz.dta 
lower_infections_pfizer_v_other_pfz.dta 
lower_gdp_pfizer_v_other_overall.dta 
lower_gdp_pfizer_v_other_pfz.dta 
lower_gdp_annual_overall.dta 
lower_gdp_annual_pfz.dta 
full_income.dta 
*/

do "COVID-19 vaccine health impacts and values - inf_upper.do"
/*
inputs:
upper_death_pfizer_v_other_overall.dta 
upper_infections_pfizer_v_other_overall.dta 
indirect_costs_nonfatal_case.dta 
direct_costs_current_2019USD.dta 
qaly_losses_per_nonfatal_case.dta 
qaly_losses_per_fatal_case.dta 
upper_death_pfizer_v_other_pfz.dta 
upper_infections_pfizer_v_other_pfz.dta 
upper_gdp_pfizer_v_other_overall.dta 
upper_gdp_pfizer_v_other_pfz.dta 
upper_gdp_annual_overall.dta 
upper_gdp_annual_pfz.dta 
full_income.dta 
*/
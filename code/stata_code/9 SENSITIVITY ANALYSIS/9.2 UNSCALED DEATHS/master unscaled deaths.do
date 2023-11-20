do "make_unscaled_deaths_countries_w_pop_gt_1M.do"
/*
inputs:
Historical-and-Projected-Covid-19-data.xlsx
projections_unique_countries.dta created in: make_historical_data_countries_w_pop_gt_1M.do
outputs:
unscaled_deaths_countries_w_pop_gt_1M.dta 
unscaled_deaths_Hong_Kong_China_Macoa.dta 
*/

do "make_quarterly_unscaled_deaths.do"
/*
inputs:
unscaled_deaths_countries_w_pop_gt_1M.dta created in: make_unscaled_deaths_countries_w_pop_gt_1M.do 
outputs:
quarterly_unscaled_deaths.dta
*/

do "make_quarterly_unscaled_deaths_China.do"
/*
inputs:
unscaled_deaths_Hong_Kong_China_Macoa.dta created in: make_unscaled_deaths_countries_w_pop_gt_1M.do
outputs:
quarterly_unscaled_deaths_China.dta 
*/

do "make_sur_regbase_w_unscaled_deaths.do"
/*
inputs:
quarterly_unscaled_deaths.dta created in: make_quarterly_unscaled_deaths.do 
quarterly_unscaled_deaths_China.dta created in: make_quarterly_unscaled_deaths_China.do 
national_population_2020_2021_2022.dta created in: national_population_2020_2021_2022.do
sur_regbase_deaths_inf.dta created in: make_sur_regbase_deaths_inf.do
outputs:
sur_regbase_w_unscaled_deaths.dta 
*/

do "no_cont_2_lags_death_pfizer_v_other_overall.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created ub: vax_launch_quarter_deaths_inf.do
sur_regbase_w_unscaled_deaths.dta created in: make_sur_regbase_w_unscaled_deaths.do
sim_0_novax_inf_all_vax_deaths_inf.dta created in: make_novax_infections_sims1000.do
outputs:
no_cont_2_lags_death_pfizer_v_other_overall
*/

do "no_cont_2_lags_death_pfizer_v_other_pfz.do"
/*
inputs: 
vax_launch_quarter_deaths_inf.dta created in: make_vax_launch_quarter_deaths_inf.do
sur_regbase_w_unscaled_deaths.dta created in: make_sur_regbase_w_unscaled_deaths.do
sim_0_novax_inf_pfz_deaths_inf.dta created in: make_novax_infections_pfz.do
outputs:
no_cont_2_lags_death_pfizer_v_other_pfz.dta
*/

do "COVID-19 vaccine health impacts and values_sureg_means.do"
/*
inputs:
no_cont_2_lags_death_pfizer_v_other_overall.dta created in: no_cont_2_lags_death_pfizer_v_other_overall.do
no_cont_2_lags_infections_pfizer_v_other_overall.dta created in: quarterly_infections_pfizer_v_other_overall.do
indirect_costs_nonfatal_case.dta 
direct_costs_current_2019USD.dta 
qaly_losses_per_nonfatal_case.dta 
qaly_losses_per_fatal_case.dta 
no_cont_2_lags_death_pfizer_v_other_pfz.dta created in: no_cont_2_lags_death_pfizer_v_other_pfz.do
no_cont_2_lags_infections_pfizer_v_other_pfz.dta created in: quarterly_infections_pfizer_v_other_pfz.do 
value_of_vax_gdp_qrtly.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
value_of_vax_gdp_annual.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
full_income.dta 
*/
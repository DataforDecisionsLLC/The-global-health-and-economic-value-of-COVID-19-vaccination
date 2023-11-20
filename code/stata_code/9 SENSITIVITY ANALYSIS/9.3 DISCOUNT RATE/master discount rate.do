do "make_2019_qaly_adjusted_6pct_discounted_le.do"
/*
inputs:
baseline_health_utility.dta created in: make_baseline_health_utility.do
life_tables_2019.dta created in: make_life_tables_2019.do
outputs:
baseline_2019_health_utility_w_life_tables.dta
2019_qaly_adj_6pct_discounted_le.dta
*/

do "make_2019_qaly_adjusted_undiscounted_le.do"
/*
inputs:
baseline_2019_health_utility_w_life_tables.dta created in: make_2019_qaly_adjusted_6pct_discounted_le.do
outputs:
2019_qaly_adj_undiscounted_le.dta
*/

do "make_6pct_discounted_qaly_losses_per_fatal_case.do"
/*
inputs:
2019_qaly_adj_6pct_discounted_le.dta created in: make_2019_qaly_adjusted_6pct_discounted_le.do 
population_weights.dta created in: make_qaly_losses_per_fatal_case.do
COVerAGE_quarterly_death_age_structures.dta created in COVerAGE_quarterly_death_age_structures_5year.do
outputs:
6pct_discounted_qaly_losses_per_fatal_case.dta
*/

do "make_undiscounted_qaly_losses_per_fatal_case.do"
/*
inputs:
2019_qaly_adj_undiscounted_le.dta created in: make_2019_qaly_adjusted_undiscounted_le.do 
population_weights.dta created in: make_qaly_losses_per_fatal_case.do
COVerAGE_quarterly_death_age_structures.dta created in COVerAGE_quarterly_death_age_structures_5year.do
outputs:
undiscounted_qaly_losses_per_fatal_case.dta
*/

do "unpaid_work_loss_nonfatal_case_6pct_discount_rate.do"
/*
time_use_processed_ihme.xlsx
hrly_wage_2019USD_final.dta created in: make_hrly_wage_2019USD.do
avg_unpaid_work_days_lost_nonfatal_case.dta created in unpaid_work_loss_nonfatal_case.do
severity_splits.dta created in: make_severity_splits.do
output:
unpaid_work_loss_nonfatal_case_6pct_discount_rate.dta
*/

do "unpaid_work_loss_nonfatal_case_undiscounted.do"
/*
time_use_processed_ihme.xlsx
hrly_wage_2019USD_final.dta created in: make_hrly_wage_2019USD.do
avg_unpaid_work_days_lost_nonfatal_case.dta created in: unpaid_work_loss_nonfatal_case.do
severity_splits.dta created in: make_severity_splits.do
output:
unpaid_work_loss_nonfatal_case_undiscounted.dta
*/

do "COVID-19 vaccine health impacts and values 6pct discounted.do"
/*
inputs: 
unpaid_work_loss_nonfatal_case_6pct_discount_rate.dta created in: unpaid_work_loss_nonfatal_case_6pct_discount_rate.do
no_cont_2_lags_death_pfizer_v_other_overall.dta created in: quarterly_death_pfizer_v_other_overall.do 
no_cont_2_lags_infections_pfizer_v_other_overall.dta created in: quarterly_infections_pfizer_v_other_overall.do
direct_costs_current_2019USD.dta created in: direct_costs_current_2019USD.do
qaly_losses_per_nonfatal_case.dta created in: make_qaly_losses_per_nonfatal_case.do
6pct_discounted_qaly_losses_per_fatal_case.dta created in: make_6pct_discounted_qaly_losses_per_fatal_case.do
no_cont_2_lags_death_pfizer_v_other_pfz.dta created in: quarterly_death_pfizer_v_other_pfz.do 
no_cont_2_lags_infections_pfizer_v_other_pfz.dta created in: quarterly_infections_pfizer_v_other_pfz.do
value_of_vax_gdp_qrtly.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
value_of_vax_gdp_annual.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
full_income.dta created in: make_full_income.do
*/


do "COVID-19 vaccine health impacts and values undiscounted.do"
/*
inputs: 
unpaid_work_loss_nonfatal_case_undiscounted.dta created in: unpaid_work_loss_nonfatal_case_undiscounted.do
no_cont_2_lags_death_pfizer_v_other_overall.dta created in: quarterly_death_pfizer_v_other_overall.do 
no_cont_2_lags_infections_pfizer_v_other_overall.dta created in: quarterly_infections_pfizer_v_other_overall.do
direct_costs_current_2019USD.dta created in: direct_costs_current_2019USD.do
qaly_losses_per_nonfatal_case.dta created in: make_qaly_losses_per_nonfatal_case.do
undiscounted_qaly_losses_per_fatal_case.dta created in: make_undiscounted_qaly_losses_per_fatal_case.do
no_cont_2_lags_death_pfizer_v_other_pfz.dta created in: quarterly_death_pfizer_v_other_pfz.do 
no_cont_2_lags_infections_pfizer_v_other_pfz.dta created in: quarterly_infections_pfizer_v_other_pfz.do
value_of_vax_gdp_qrtly.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
value_of_vax_gdp_annual.dta created in: "....\8 TOTAL VoV\COVID-19 vaccine health impacts and values_sureg_means.do"
full_income.dta created in: make_full_income.do
*/
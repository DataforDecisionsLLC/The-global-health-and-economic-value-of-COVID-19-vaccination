do ".......\DB Work\DO-FILES\QALY LOSSES\make_severity_splits.do"
/*
inputs:
Historical-and-Projected-Covid-19-data.dta
projections_unique_countries.dta
gdp_deaths_infections.dta
output: 
severity_splits.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\wdi_ihme_country_match.do"
/*
inputs:
P_Data_Extract_From_World_Development_Indicators.xlsx
P_Data_Extract_From_World_Development_Indicators_per_capita_GDP.xlsx
WEOOct2019all_import.xlsx
national_population_2020_2021_2022.dta
IHME_unique_countries.dta
output: 
wdi_ihme_country_match.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\hospital_cost_per_bed_day.do"
/*
inputs:
forex_2010_to_2019_jk.xlsx 
who_choice_2010.xlsx
national_population_2020_2021_2022.dta 
projections_unique_countries.dta 
regions.dta  
P_Data_Extract_From_World_Development_Indicators-GDP deflators.xlsx
WEOOct2019all_import.xls
wdi_ihme_country_match.dta
output: 
hospital_cost_per_bed_day_2019USD.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\direct_costs_current_2019USD.do"
/*
inputs:
Productivity costs-Di Fusco 2022.xlsx
WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
national_population_2020_2021_2022.dta 
projections_unique_countries.dta
hospital_cost_per_bed_day_2019USD.dta 
severity_splits.dta
output:  
direct_costs_current_2019USD.dta 
*/

do ".......\DB Work\DO-FILES\ILO\make_hrly_wage_2019USD.do"
/*
inputs:
EAR_4HRL_SEX_OCU_CUR_NB_A_EN.xlsx
national_population_2020_2021_2022.dta
IHME_unique_countries.dta 
wdi_ihme_country_match.dta 
output: 
hrly_wage_2019USD_final.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\unpaid_work_loss_nonfatal_case.do"
/*
inputs: 
Productivity costs-Di Fusco 2022.xlsx
WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
national_population_2020_2021_2022.dta
projections_unique_countries.dta
time_use_processed_ihme.xlsx
hrly_wage_2019USD_final.dta 
severity_splits.dta
output: 
unpaid_work_loss_nonfatal_case.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\pc_income_current_2019USD.do"
/*
input: 
wdi_ihme_country_match.dta
output: 
final_pcgni_current_2019USD.dta 
*/

do ".......\DB Work\DO-FILES\ECONOMIC DATA\make_full_income.do"
/*
inputs:
time_use_processed.xlsx
hrly_wage_2019USD_final.dta
final_pcgni_current_2019USD.dta
output: 
full_income.dta 
*/
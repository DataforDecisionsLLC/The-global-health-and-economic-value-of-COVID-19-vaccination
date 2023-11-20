
do ".......\DB Work\DO-FILES\QALY LOSSES\make_baseline_health_utility.do"
/*
inputs:
Szende et al.-2014-EQ-5D Index Population Norms-import.xlsx
WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx
national_population_2020_2021_2022.dta
IHME_unique_countries.dta
output:
baseline_health_utility.dta
*/

do ".......\DB Work\DO-FILES\LIFE TABLES\make_life_tables_2019.do"
/*
inputs: 
WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xls
national_population_2020_2021_2022.dta
projections_unique_countries.dta 
output: 
life_tables_2019.dta
*/

do ".......\DB Work\DO-FILES\QALY LOSSES\make_2019_qaly_adjusted_discounted_le.do"
/*
inputs:
baseline_health_utility.dta
life_tables_2019.dta
output: 
2019_qaly_adj_le.dta
*/

do ".......\DB Work\DO-FILES\QALY LOSSES\make_qaly_losses_per_fatal_case.do"
/*
inputs:
WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES_import.xlsx
national_population_2020_2021_2022.dta
projections_unique_countries.dta
2019_qaly_adj_le.dta
age_buckets_qaly_losses.xlsx
COVerAGE_quarterly_death_age_structures.dta
output:
qaly_losses_per_fatal_case.dta
*/

do ".......\DB Work\DO-FILES\QALY LOSSES\make_qaly_losses_per_nonfatal_case.do"
/*
inputs:
Historical-and-Projected-Covid-19-data.dta
projections_unique_countries.dta
gdp_deaths_infections.dta
output:
qaly_losses_per_nonfatal_case.dta
*/
/////////////////////////////////// population //////////////////////////////////

do ".......\DB Work\DO-FILES\POPULATION\national_population_2020_2021_2022.do"
/*
inputs:
WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx
WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-median_variant.xlsx
output: 
national_population_2020_2021_2022.dta   
*/

////////////////////////////// OWiD data ///////////////////////////////////////

do: ".......\DB Work\DO-FILES\OWID\owid_raw_countries_w_pop_gt_1M.do"
/*
inputs:
owid-covid-data_9.22.2022.xlsx
master_country_list_owid.xlsx
national_population_2020_2021_2022.dta
output:
owid_raw_countries_w_pop_gt_1M.dta 
*/

//////////////////// geographic and income group classificatons ////////////////

do ".......\DB Work\DO-FILES\ECONOMIC DATA\make_regions.do"
/*
inputs:
master_country_list_owid.xlsx
output: 
regions.dta 
*/

/////////// publicly available IHME Covid-19 data country list /////////////////

do ".......\DB Work\DO-FILES\IHME\make_IHME_unique_countries.do" 
/*
inputs:
data_download_file_reference_2020.xlsx
data_download_file_reference_2021.xlsx
data_download_file_reference_2022.xlsx
national_population_2020_2021_2022.dta
regions.dta
output: 
IHME_unique_countries.dta 
*/

/////////////////////////////////// dataset 1 //////////////////////////////////

do ".......\DB Work\DO-FILES\IHME\make_historical_data_countries_w_pop_gt_1M.do"
/* 
inputs:
Historical-and-Projected-Covid-19-data.xlsx
national_population_2020_2021_2022.dta 
outputs: 
Historical-and-Projected-Covid-19-data.dta
projections_countries_w_pop_gt_1M.dta
projections_unique_countries.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_historical_data_Hong_Kong_China_Macao.do"
/* 
inputs:
Historical-and-Projected-Covid-19-data.dta
output: 
projections_Hong_Kong_China_Macoa.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_quarterly_deaths_&_infections.do"
/* 
inputs:
projections_countries_w_pop_gt_1M.dta
output: 
quarterly_deaths_&_infections.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_quarterly_deaths_&_infections_China.do"
/*
inputs:
projections_Hong_Kong_China_Macoa.dta
output: 
quarterly_deaths_&_infections_China.dta
*/

/////////////////////////////////// dataset 2 //////////////////////////////////

do ".......\DB Work\DO-FILES\IHME\make_quarterly_doses_by_manu.do"
/* 
inputs: 
Vaccine-coverage-by-manufacturer-quarterly-countries-import.xlsx
national_population_2020_2021_2022.dta 
projections_unique_countries.dta 
owid_raw_countries_w_pop_gt_1M.dta 
outputs: 
vax_coverage_by_manu_unique_countries_w_pop_gt_1M.dta
quarterly_doses_by_manu.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_quarterly_vaccine_coverage_pfizer_v_other.do"
/* 
inputs:
quarterly_doses_by_manu.dta
output: 
quarterly_vaccine_coverage_pfizer_v_other.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_China_dosage_adjustment_factor.do"
/* 
inputs: 
projections_Hong_Kong_China_Macoa.dta
national_population_2020_2021_2022.dta
outputs: 
China_dosage_adjustment_factor_v2.dta
vax_Hong_Kong_China_Macoa.dta
*/

do ".......\DB Work\DO-FILES\IHME\make_China_quarterly_vaccine_coverage_pfizer_v_other.do"
/* 
inputs:
vax_Hong_Kong_China_Macoa.dta
national_population_2020_2021_2022.dta
quarterly_doses_by_manu.dta
China_dosage_adjustment_factor_v2.dta
output: 
China_quarterly_vaccine_coverage_pfizer_v_other_v2.dta
*/
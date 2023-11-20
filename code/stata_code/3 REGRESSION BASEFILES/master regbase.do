/////////////////////////////////// regression basefile ////////////////////////

do ".......\DB Work\DO-FILES\IHME\make_quarterly_regbase.do"
/* 
inputs: 
quarterly_deaths_&_infection.dta  
quarterly_deaths_&_infections_China.dta 
quarterly_vaccine_coverage_pfizer_v_other.dta
China_quarterly_vaccine_coverage_pfizer_v_other.dta
gdp_gap_df.xlsx
national_population_2020_2021_2022.dta
outputs: 
gdp_deaths_infections.dta
quarterly_regbase.dta
*/

//////////////////////// government response tracker ///////////////////////////

do ".......\DB Work\DO-FILES\OXFORD\make_gri.do"
/* 
inputs:
government_response_index_avg.xlsx
quarterly_regbase.dta
output: 
gri_quarterly_avg_ihme_countries.dta
*/

/////////////// deaths and infectins regression basefile ///////////////////////

do ".......\DB Work\DO-FILES\ANALYSIS\REGRESSIONS\SUR\make_sur_regbase_deaths_inf.do"
/*
inputs: 
quarterly_regbase.dta
gri_quarterly_avg_ihme_countries.dta
outputs:
prevax_osi.dta
sur_regbase_deaths_inf.dta
*/

/////////////////////////// gdp regression basefiles ///////////////////////////

do ".......\DB Work\DO-FILES\ECONOMIC DATA\make_quarterly_gdp_usd.do"
/*
inputs: 
gdp_usd_ihme.xlsx
vax_coverage_by_manu_unique_countries_w_pop_gt_1M.dta
output: 
quarterly_gdp_usd.dta
*/

do ".......\DB Work\DO-FILES\ANALYSIS\REGRESSIONS\ANNUAL & QUARTERLY GDP\make_quarterly_gdp_regbase.do"
/*
inputs: 
gdp_gap_ihme.xlsx
quarterly_regbase.dta
gri_quarterly_avg_ihme_countries.dta
prevax_osi.dta
output: 
quarterly_gdp_regbase.dta
*/

do ".......\DB Work\DO-FILES\ANALYSIS\REGRESSIONS\ANNUAL & QUARTERLY GDP\make_annual_gdp_regbase.do"
/*
inputs: 
annual_gdp_regbase.xlsx
gdp_gap_ihme.xlsx
quarterly_regbase.dta
quarterly_gdp_usd.dta
output: 
annual_gdp_regbase.dta
*/

do ".......\DB Work\DO-FILES\COVerAG\COVerAGE_death_age_structure_donor_group_graphs.do"
/*
inputs:
daily_coverage_deaths.xlsx
outputs:
COVerAGE_deaths_by_geo_income_quarter.dta
region-income group specific graphs
*/

do ".......\DB Work\DO-FILES\COVerAG\COVerAGE_quarterly_death_age_structures_5year.do"
/*
inputs:
daily_coverage_deaths_5year.xlsx
projections_unique_countries.dta
regions.dta
outputs:
COVerAGE_deaths_by_country_quarter.dta
COVerAGE_death_shares_by_country_quarter.dta
COVerAGE_death_shares_by_country_quarter_10.dta
COVerAGE_death_shares_by_who_income_quarter_10.dta
COVerAGE_death_shares_extrapolations_by_country_quarter_10.dta
COVerAGE_quarterly_death_age_structures.dta
COVerAGE_death_age_structures.xlsx
*/
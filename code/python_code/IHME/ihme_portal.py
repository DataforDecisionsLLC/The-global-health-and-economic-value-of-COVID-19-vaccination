# -*- coding: utf-8 -*-
"""
ihme_portal.py: Using the existing IHME code (from ihme_audit.py) to process the
final IHME data.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 24 February 2023
__updated__ = 15 November 2023

inputs:
    - WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx (raw file)
    - master_country_list.xlsx (processed file; created in Excel)
    - Vaccine-coverage-by-manufacturer-quarterly-countries.csv (raw file)
    - Historical-and-Projected-Covid-19-data.csv (raw file)
    - owid_raw_countries_w_pop_gt_1M.dta (processed file; created in owid_raw_countries_w_pop_gt_1M.do)
    - gdp_gap_ihme.xlsx (processed file; created in gdp_formatting.py)
    
outputs:
    - ihme_quarterly_regbase_boosters.xlsx

"""

# %% load in libraries
import pandas as pd
import numpy as np

# %% format 2020, 2021, and 2022 populations (national_population_2020_2021_202.do)

# load in raw 2020 and 2021 population data from the United Nations World Population Prospects (UN WPP).
popdata_2020_2021 = pd.read_excel("../input/WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx", 
                                  sheet_name = "import", header = 1, index_col = "Index")

# load in raw 2022-and-later population data from the UN WPP.
popdata_2022 = pd.read_excel("../input/WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-median_variant.xlsx", 
                                  sheet_name = "import", header = 1, index_col = "Index")

# create a dictionary of columns to drop from the raw population files.
drop_cols = {'Variant', 'Notes', 'Location_code', 'ISO3_code', 'ISO2_code', 'SDMX_code', 'Type', 'Parent_code'}

# drop those columns from both population files.
popdata_2020_2021 = popdata_2020_2021.drop(columns = drop_cols)
popdata_2022 = popdata_2022.drop(columns = drop_cols)

# for the 2022-and-later data, only keep data from 2022.
popdata_2022 = popdata_2022[popdata_2022["year"] == 2022]

# sort the files by country name and by year
popdata_2020_2021 = popdata_2020_2021.sort_values(["country", "year"])
popdata_2022 = popdata_2022.sort_values(["country", "year"])

# calculate the total population in a country by summing the population of all ages.
popdata_2020_2021["tot_pop"] = popdata_2020_2021.filter(like="age_").sum(1)
popdata_2022["tot_pop"] = popdata_2022.filter(like="age_").sum(1)

# create a dictionary to rename countries to authors' preferred versions.
renaming = {"Bolivia (Plurinational State of)": "Bolivia", "China, Hong Kong SAR": "Hong Kong",
            "China, Taiwan Province of China": "Taiwan", "Côte d'Ivoire": "Cote d'Ivoire",
            "Dem. People's Republic of Korea": "North Korea",
            "Democratic Republic of the Congo": "Democratic Republic of Congo",
            "Iran (Islamic Republic of)": "Iran", "Lao People's Democratic Republic": "Laos",
            "State of Palestine": "Palestine", "Syrian Arab Republic": "Syria",
            "Türkiye": "Turkey", "United Republic of Tanzania": "Tanzania",
            "United States of America": "United States", "Venezuela (Bolivarian Republic of)": "Venezuela",
            "Viet Nam": "Vietnam", "Russian Federation": "Russia", "Republic of Moldova": "Moldova",
            "Republic of Korea": "South Korea", "Bonaire, Sint Eustatius and Saba": "Bonaire Sint Eustatius and Saba",
            "Brunei Darussalam": "Brunei", "Cabo Verde": "Cape Verde", "China, Macao SAR": "Macao",
            "Curaçao": "Curacao", "Falkland Islands (Malvinas)": "Falkland Islands",
            "Faroe Islands": "Faeroe Islands", "Kosovo (under UNSC res. 1244)": "Kosovo",
            "Micronesia (Fed. States of)": "Micronesia (country)", "Wallis and Futuna Islands": "Wallis and Futuna"}

# rename countries in both population files
popdata_2020_2021 = popdata_2020_2021.replace(renaming)
popdata_2022 = popdata_2022.replace(renaming)

# create a single file that combines the 2020, 2021, and 2022 population data
popdata = pd.concat([popdata_2020_2021, popdata_2022])

# sort this population file by the country name and year.
popdata = popdata.sort_values(["country", "year"]).reset_index(drop = True)

# check that there are 3 years of data for each country
country_counts = popdata.country.value_counts()

# multiply population values by 1000
popdata["tot_pop"] = popdata["tot_pop"]*1000

# remove the individual age columns
popdata = popdata[popdata.columns.drop(list(popdata.filter(regex='age_')))]

# save the population data to a single file.
#popdata.to_excel("../output/national_population_2020_2021_2022.xlsx", index = False)
#popdata = pd.read_excel("../output/national_population_2020_2021_2022.xlsx")
# %% make regions from the master country list (make_regions.do)

# load in a file with countries' regional classifications
master = pd.read_excel("../input/master_country_list.xlsx", sheet_name = "master_list")

# reduce the number of columns in the file to the most relevant ones
master = master[["country", "UN_region", "UN_subregion", "UNICEF_region", "WHO_region", "WB_income_group_1",
                 "WB_income_group_2", "WB_region", "MDG_region", "SDG_region", "LDC", "development_group"]]

# remove entries where the country field is empty
master = master[master['country'].notna()]

# remove entries where the UN region field is empty.
master = master[master['UN_region'].notna()]

# save the file
#master.to_excel("../output/regions.xlsx", index = False)
#master = pd.read_excel("../output/regions.xlsx")

# %% format and combine the IHME datasets 1 and 2 (ihme_raw_countries_w_pop_gt_1M.do)

# load in the IHME vaccine data 
ihme_vax_raw = pd.read_csv("../input/Vaccine-coverage-by-manufacturer-quarterly-countries.csv")

# rename columns for ease of use and sort the file by country name and date.
ihme_q_vax = ihme_vax_raw.rename(columns = {"location_name": "country", "quarter": "date"})
ihme_q_vax = ihme_q_vax.sort_values(["country", "date"]).reset_index(drop = True)

# extract a series of all countries in the IHME vaccine data.
ihme_countries = pd.Series(ihme_vax_raw.location_name.unique())

# create a dictionary to rename countries to authors' preferred versions.
replace_dict = {'Taiwan (Province of China)': 'Taiwan', 'Viet Nam': 'Vietnam',
 'Republic of Moldova': 'Moldova', 'Russian Federation': 'Russia',
 'Republic of Korea': 'South Korea', 'United States of America': 'United States',
 'Bolivia (Plurinational State of)': 'Bolivia', 'Venezuela (Bolivarian Republic of)': 'Venezuela',
 'Iran (Islamic Republic of)': 'Iran', 'Syrian Arab Republic': 'Syria',
 'Türkiye': 'Turkey', 'Democratic Republic of the Congo': 'Democratic Republic of Congo',
 "Côte d'Ivoire": "Cote d'Ivoire", "Cabo Verde": "Cape Verde", "United Republic of Tanzania": "Tanzania",
 "Timor": "Timor-Leste", "Micronesia (Federated States of)": "Micronesia",
 "Lao People's Democratic Republic": "Laos", "Democratic People's Republic of Korea": "North Korea",
 "Hong Kong Special Administrative Region of China": "Hong Kong", "Macao Special Administrative Region of China": "Macao"}

# rename countries in the series containing IHME countries
ihme_countries = ihme_countries.replace(replace_dict)

# add population data to the sereis IHME countries
ihme_countries = ihme_countries.replace(renaming).drop_duplicates().to_frame()
ihme_countries = popdata.merge(ihme_countries, left_on = "country", right_on = 0)

# keep countries whose population exceeds 1 million or Macao 
ihme_countries_1m = ihme_countries[(ihme_countries["tot_pop"] >= 1000000) | (ihme_countries["country"] == "Macao")]
ihme_countries_1m = pd.Series(ihme_countries_1m.country.unique())

# save the countries and population to a file
#ihme_countries_1m.to_excel("../output/ihme_countries.xlsx", index = False)

# create a year field
ihme_q_vax["year"] = ihme_q_vax["date"].astype(str).str[:4]
ihme_q_vax["year"] = ihme_q_vax["year"].astype(int)

# create a quarter field
ihme_q_vax["quarter"] = ihme_q_vax["date"].astype(str).str[-1:]
ihme_q_vax["quarter"] = ihme_q_vax["quarter"].astype(int)

# create a year-quarter field
ihme_q_vax["yyyy_qq"] = ihme_q_vax["year"].astype(str) + "_Q" + ihme_q_vax["quarter"].astype(str) 

# rename countries in the IHME vaccine data
ihme_q_vax = ihme_q_vax.replace(replace_dict)

# remove commas from numbers
ihme_q_vax["Total_doses"] = ihme_q_vax["Total_doses"].str.replace(',', '').astype(float)

# check that every entry has 10 quarters of vax data
ihme_vax_quarters = ihme_q_vax.country.value_counts()

# collapse the data to the country-quarter
ihme_q_vax = ihme_q_vax.groupby(["country", "year", "quarter", "yyyy_qq"], as_index = False).sum()
ihme_q_vax = ihme_q_vax.drop(columns = ["location_id"])

# add population data to the vaccine data and drop countries whose population is below 1M, except for Macao.
ihme_q_vax = ihme_q_vax.merge(popdata, on = ["country", "year"], how = "left")
ihme_q_vax = ihme_q_vax[(ihme_q_vax["tot_pop"] >= 1000000) | (ihme_q_vax["country"] == "Macao")]

# load in the IHME COVID data
ihmeraw = pd.read_csv("../input/Historical-and-Projected-Covid-19-data.csv")
ihme = ihmeraw[ihmeraw["version_name"] == "reference"]

# create a list of columns that we want to keep
keep_cols = ["date", "location_name", "inf_mean", "inf_cuml_mean", "inf_cuml_upper", "inf_cuml_lower",
             "inf_upper", "inf_lower", "cumulative_deaths", "cumulative_deaths_unscaled",
             "daily_deaths", "daily_deaths_unscaled", "infection_fatality", "cumulative_all_fully_vaccinated",
             "cumulative_all_effectively_vaccinated"]

# reduce the IHME COVID data to include only these columns
ihme = ihme[keep_cols]

# rename countries in the IHME COVID data
ihme = ihme.replace(replace_dict)

# rename the location_name column 
ihme = ihme.rename(columns = {"location_name": "country"})

# calculate the number of countries in the data
n_ihme_countries = len(ihme.country.unique())

# create a year field in the IHME COVID data
ihme["year"] =  pd.to_datetime(ihme['date']).dt.year

# create a quarter field
ihme["quarter"] =  pd.to_datetime(ihme['date']).dt.quarter

# sort the data by country and date
ihme = ihme.sort_values(["country", "year", "quarter", "date"])

# remove data after Q2 2022
ihme = ihme[ihme["date"] < "2022-07-01"]

# add population data to the IHME COVID data
ihme_df = ihme.merge(popdata, on = ["country", "year"], how = "left")

# keep countries that are in the vaccination data 
ihme_df = ihme_df[ihme_df.country.isin(ihme_countries_1m)]
n_ihme_pop_countries = len(ihme_df.country.unique())

# and make sure that all countries have at least 1M population or are Macao
ihme_1m = ihme_df[(ihme_df["tot_pop"] >= 1000000) | (ihme_df["country"] == "Macao")]
n_ihme_1m_countries = len(ihme_1m.country.unique())

#ihme_1m.to_excel("../output/ihme_temp.xlsx", index = False)

# create a data frame that only contains entries with non-empty deaths records
death_df = ihme_1m[ihme_1m['daily_deaths'].notna()]

# create a data frame that only contains entries with non-empty infections records
inf_df = ihme_1m[ihme_1m['inf_mean'].notna()]

# for countries in the IHME COVID data
for c in ihme_1m.country.unique():
    # find the date of first death record
    first_deaths = death_df.loc[death_df["country"] == c, "date"].min()
    # find the date of first infectoin record
    first_infs = inf_df.loc[inf_df["country"] == c, "date"].min()
    # make sure that new deaths record on the first day equals the cumulative death record on that day.
    ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "daily_deaths"] = ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "cumulative_deaths"]
    ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "daily_deaths_unscaled"] = ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "cumulative_deaths_unscaled"]
    # make sure that the new infections record on the first day equals the cumulative infections record on that day.
    ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_mean"] = ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_cuml_mean"]
    ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_lower"] = ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_cuml_lower"]
    ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_upper"] = ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_cuml_upper"]

# create a data frame that only contains epidemimological columns
numerics = ['int16', 'int32', 'int64', 'float16', 'float32', 'float64']
epi_cols = list(set(ihme_1m.select_dtypes(include=numerics).columns) - set(["year", "quarter", "yyyy_qq", "tot_pop",
                                                                            "infection_fatality"]))

# create a data frame that only contains Macao and Hong Kong data
mc_hk = ihme_1m[ihme_1m["country"].isin(["Macao", "Hong Kong"])]
# for epidemiological columns,sum the Macao and Hong Kong values for each date
mc_hk = mc_hk.groupby("date")[epi_cols].sum()
# create a data frame that contains only China's data
china =  ihme_1m[ihme_1m["country"] == "China"].set_index("date")
# only retain the epidemiological columns in the China data
china = china[epi_cols]
# subtract the values in Hong Kong/Macao from the China values
china_update = china.subtract(mc_hk, level=0)
china_update = china_update.reset_index()
# add a field that notes the updated China data is for China
china_update["country"] = "China"
# add the rest of the IHME data for China to the updated China data
china_update = china_update.merge(ihme_df, on = ["country", "date"], how = "left")
# remove the old China data from the IHME data
china_update = china_update.loc[:,~china_update.columns.str.contains('_y')] 
china_update.columns = china_update.columns.str.replace(r'_x$', '')

# add the China's updated data to the IHME data
ihme_1m = ihme_1m[ihme_1m["country"] != "China"]
ihme_1m = pd.concat([ihme_1m, china_update], axis = 0)

#ihme_1m.to_excel("../output/ihme_cases_deaths_vax_ifr_countries_w_pop_gt_1M.xlsx", index = False)

# create a year-quarter field
ihme_1m["yyyy_qq"] = ihme_1m["year"].astype(str) + "_Q" + ihme_1m["quarter"].astype(str)

# retain columns that are useful
ihme_q = ihme_1m[["date", "country", "year", "quarter", "yyyy_qq", "inf_cuml_mean", "inf_mean", "inf_upper", "inf_lower",
                  "cumulative_deaths", "daily_deaths", "cumulative_deaths_unscaled",
                  "daily_deaths_unscaled", "tot_pop"]]

# make sure the date column is being interpreted as a datetime object
ihme_q["date"] =  pd.to_datetime(ihme_q['date'])
# sort the data by country and date
ihme_q = ihme_q.sort_values(["country", "year", "quarter", "date"])

# add a month column to the death data frame
death_df["month"] =  pd.to_datetime(death_df['date']).dt.month
# for Kazakhstan, Kyrgyzstan, and Uzbekistan, make sure their last quarter with some date 
# has complete data by extrapolating to the end of the quarter
kazakh_extrap = death_df.loc[(death_df["country"] == "Kazakhstan") & (death_df["year"] == 2021) &
                             (death_df["month"] == 9), "daily_deaths"].mean()
kazakh_extrap_unsc = death_df.loc[(death_df["country"] == "Kazakhstan") & (death_df["year"] == 2021) &
                             (death_df["month"] == 9), "daily_deaths_unscaled"].mean()

ihme_q.loc[(ihme_q["country"] == "Kazakhstan") & (ihme_q["year"] == 2021) &
                             (ihme_q["quarter"] == 3) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = kazakh_extrap
ihme_q.loc[(ihme_q["country"] == "Kazakhstan") & (ihme_q["year"] == 2021) &
                             (ihme_q["quarter"] == 3) & (ihme_q["daily_deaths_unscaled"].isna()),
                             "daily_deaths_unscaled"] = kazakh_extrap_unsc

kyrgyz_extrap = death_df.loc[(death_df["country"] == "Kyrgyzstan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 3), "daily_deaths"].mean()
kyrgyz_extrap_unsc = death_df.loc[(death_df["country"] == "Kyrgyzstan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 3), "daily_deaths_unscaled"].mean()

ihme_q.loc[(ihme_q["country"] == "Kyrgyzstan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = kyrgyz_extrap
ihme_q.loc[(ihme_q["country"] == "Kyrgyzstan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths_unscaled"].isna()),
                             "daily_deaths_unscaled"] = kyrgyz_extrap_unsc

uzbek_extrap = death_df.loc[(death_df["country"] == "Uzbekistan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 2), "daily_deaths"].mean()
uzbek_extrap_unsc = death_df.loc[(death_df["country"] == "Uzbekistan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 2), "daily_deaths_unscaled"].mean()

ihme_q.loc[(ihme_q["country"] == "Uzbekistan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = uzbek_extrap
ihme_q.loc[(ihme_q["country"] == "Uzbekistan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths_unscaled"].isna()),
                             "daily_deaths_unscaled"] = uzbek_extrap_unsc

# collapse the IHME COVID data by country and quarter
ihme_q_cd = ihme_q.groupby(["country", "year", "quarter", "yyyy_qq", "tot_pop"])["inf_mean", "inf_lower", "inf_upper", "daily_deaths", "daily_deaths_unscaled"].sum().reset_index()

# check that every entry has 10 quarters of infections and deaths data
ihme_cd_quarters = ihme_q_cd.country.value_counts()

# drop entries with empty values
ihme_q_cd = ihme_q_cd.dropna()

# sort by country and date
ihme_q_cd = ihme_q_cd.sort_values(["country", "year", "quarter", "yyyy_qq"]).reset_index(drop = True)

#ihme_q_cd.to_excel("../output/ihme_cases_deaths_quarterly.xlsx", index = False)

# combine quarterly infections, deaths, and vaccinations to one data set
ihme_quarterly = ihme_q_cd.merge(ihme_q_vax, on = ["country", "year", "quarter", "yyyy_qq"], how = "left")

# sort by country and date
ihme_quarterly = ihme_quarterly.sort_values(["country", "year", "quarter"])

#ihme_quarterly.to_excel("../output/ihme_quarterly_w_region_income_group.xlsx", index = False)
#ihme_quarterly = pd.read_excel("../output/ihme_quarterly_w_region_income_group.xlsx")
# %% Extrapolate for the missing vaccination quarters

# load in Our World in Data COVID data
owid = pd.read_stata("../input/owid_raw_countries_w_pop_gt_1M.dta")
# create a copy of the processed IHME COVID data
ihme_ds1 = ihme_1m.copy()
# create a copy of the processed IHME vax data
ihme_ds2 = ihme_q_vax.copy()

# subset the OWID data to only include the country, date, and vaccination data
owid_vax_cols = ["total_vaccinations", "people_vaccinated"]
owid = owid.set_index(["country", "date", "year", "quarter", "yyyy_qq"])
owid_vax = owid[owid_vax_cols].reset_index(drop = False)

# for the IHME vaccine data, only keep the country, date, and total doses variables.
ihme_vax_ds2 = ihme_ds2[["country", "year", "quarter", "yyyy_qq", "Total_doses"]]

# for the IHME COVID data, keep the country, date, and number vaccinated variables
ihme_vax_ds1 = ihme_ds1[["country", "year", "quarter", "date", "cumulative_all_effectively_vaccinated",
                         "cumulative_all_fully_vaccinated"]]
# create a year-quarter variable
ihme_vax_ds1["yyyy_qq"] = ihme_vax_ds1["year"].astype(str) + "_Q" + ihme_vax_ds1["quarter"].astype(str)

# rename country names in all three data frames
owid_vax = owid_vax.replace(replace_dict)
ihme_vax_ds1 = ihme_vax_ds1.replace(replace_dict)
ihme_vax_ds2 = ihme_vax_ds2.replace(replace_dict)

# collapse the OWID data by country and quarter. Find the max value for the vaccine data in each country-quarter.
owid_q = owid_vax.groupby(["country", "yyyy_qq"], as_index = False)[owid_vax_cols].max()
# collapse the IHME COVID data by country and quarter, keeping the last value of cumulative
# people vaccinated
ihme_ds1_q = ihme_vax_ds1.groupby(["country", "year", "yyyy_qq"], as_index = False)[["cumulative_all_effectively_vaccinated",
                         "cumulative_all_fully_vaccinated"]].last()

# merge the IHME vaccine data, IHME COVID data, and OWID vaccine data to a single data frame.
vax_q = ihme_vax_ds2.merge(ihme_ds1_q, on = ["country", "yyyy_qq", "year"], how = "left")
vax_q = vax_q.merge(owid_q, on = ["country", "yyyy_qq"], how = "left")

# create a copy of the combined vaccine data
vax_extrap = vax_q.copy()
# creat an empty field for the rule we apply to it
vax_extrap["rule"] = np.nan

# create a function that extrapolates vaccine data in 2022
def extrapolate_growth_to_IHME(country):
    """
    Some countries don't have 2022 dose data. For these countries we extrapolate dose data using growth rates in our other vaccination data sources. 

    Parameters
    ----------
    country : string
        A string containing the name of the country to extrapolate vaccine data for.

    Returns
    -------
    vax_extrap : data frame
        A data frame that contains all vaccine data, including extrapolated data.

    """
    # if the dose data in the last quarter of data (2022_Q2) is greater than zero, do nothing
    if vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "Total_doses"].values[0] > 0:
        return vax_extrap
    # but if the dose data is zero in 2022_Q2 and greater than zero in 2022_Q1,
    elif ((vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "Total_doses"].values[0] == 0) &
        (vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"), "Total_doses"].values[0] > 0)):
        # find the value of people vaccinated in 2021_Q3 from IHME
        ds1_q3_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q3"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q4 from IHME
        ds1_q4_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q4"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q1 from IHME
        ds1_q1_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q2 from IHME
        ds1_q2_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q3 from OWID
        owid_q3_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q3"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q4 from OWID
        owid_q4_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q4"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q1 from OWID
        owid_q1_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q2 from OWID
        owid_q2_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"),
                              "people_vaccinated"].values[0]
        # and if the number of people vaccinated in IHME is bigger in 2022_Q2 than 2022_Q1,
        if ds1_q2_22 > ds1_q1_22:
            # using the IHME data, calculate the difference in people vaccinated between 2022_Q2 and 2022_Q1
            A = ds1_q2_22 - ds1_q1_22
            # using the IHME data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            B = ds1_q1_22 - ds1_q4_21
            # define the rule
            rule = "issue 3a (Rule 1)"
        # or if the country is Bosnia and Herzegovina
        elif (country == "Bosnia and Herzegovina"):
            # using the IHME data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            A = ds1_q1_22 - ds1_q4_21
            # using the IHME data, calculate the difference in people vaccinated between 2021_Q4 and 2021_Q3
            B = ds1_q4_21 - ds1_q3_21
            # define the rule
            rule = "issue 4 (back-stepped Rule 3a)"
        # but otherwise:
        else:
            # using the OWID data, calculate the difference in people vaccinated between 2022_Q2 and 2022_Q1
            A = owid_q2_22 - owid_q1_22
            # using the OWID data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            B = owid_q1_22 - owid_q4_21
            # define the rule
            rule = "issue 2a (Rule 3a)"
        # calculate the growth rate
        Growth = 1 + ((A-B)/B)     
        # for the country, calculate the 2022_Q2 doses using the 2021_Q1 doses and the growth rate
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "Total_doses"] = (
            (vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),"Total_doses"].values[0])*Growth)
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "rule"] = rule
        return vax_extrap
    # but if the data in 2022_Q2 and 2022_Q1 are both zero:
    elif ((vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "Total_doses"].values[0] == 0) &
        (vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"), "Total_doses"].values[0] == 0)):
        # find the value of people vaccinated in 2021_Q3 from IHME 
        ds1_q3_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q3"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q4 from IHME
        ds1_q4_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q4"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q1 from IHME
        ds1_q1_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q2 from IHME
        ds1_q2_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"),
                              "cumulative_all_fully_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q3 from OWID
        owid_q3_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q3"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2021_Q4 from OWID
        owid_q4_21 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q4"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q1 from OWID
        owid_q1_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),
                              "people_vaccinated"].values[0]
        # find the value of people vaccinated in 2022_Q2 from OWID
        owid_q2_22 = vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"),
                              "people_vaccinated"].values[0]
        # if the number of people vaccinated is greater in 2022_Q2 than 2022_Q1 than 2021_Q4
        if ds1_q2_22 > ds1_q1_22 > ds1_q4_21:
            # using IHME data, calculate the difference in people vaccinatde between 2022_Q2 and 2022_Q1
            A = ds1_q2_22 - ds1_q1_22
            # using IHME data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            B = ds1_q1_22 - ds1_q4_21
            # using IHME data, calculate the difference in people vaccinated between 2021_Q4 and 2021_Q3
            C = ds1_q4_21 - ds1_q3_21
            # calculate the growth rate for 2022_Q1
            Growth_Q1 = 1 + ((B-C)/C)
            # calculate the growth rate for 2022_Q2
            Growth_Q2 = 1 + ((A-B)/B)
            # create the rule
            rule = "issue 3b (Rule 2)"
        # but if the number of pople vaccinated in 2022_Q1 than in 2021_Q4 and 2022_Q2 is lower than 2022_Q1
        elif (ds1_q1_22 > ds1_q4_21) & (ds1_q2_22 <= ds1_q1_22):
            # using OWID data, calculate the difference in people vaccinatde between 2022_Q2 and 2022_Q1
            A = owid_q2_22 - owid_q1_22
            # using OWID data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            B_owid = owid_q1_22 - owid_q4_21
            # using IHME data, calculate the difference in people vaccinated between 2022_Q1 and 2021_Q4
            B_ihme = ds1_q1_22 - ds1_q4_21
            # using IHME data, calculate the difference in people vaccinated between 2021_Q4 and 2021_Q3
            C = ds1_q4_21 - ds1_q3_21
            # calculate the growth rate for 2022_Q1 using IHME data
            Growth_Q1 = 1 + ((B_ihme-C)/C)
            # calculate the growth rate for 2022_Q2 using OWID data
            Growth_Q2 = 1 + ((A-B_owid)/B_owid)
            # create the rule
            rule = "issue 3c (hybrid of Rule 2 and Rule 3a)"
        # otherwise
        else:
            # using OWID data, calculate the difference in people vaccinatde between 2022_Q2 and 2022_Q1 
            A = owid_q2_22 - owid_q1_22
            # using OWID data, calculate the difference in people vaccinatde between 2022_Q1 and 2021_Q4
            B = owid_q1_22 - owid_q4_21
            # using OWID data, calculate the difference in people vaccinatde between 2021_Q4 and 2021_Q3
            C = owid_q4_21 - owid_q3_21
            # calculate the growth rate for 2022_Q1
            Growth_Q1 = 1 + ((B-C)/C)
            # calculate the growth rate for 2022_Q2
            Growth_Q2 = 1 + ((A-B)/B)
            # create the rule
            rule = "issue 2b (Rule 3b)"
        # for the country, extrapolate 2022_Q1 doses using 2021_Q4 doses and the 2022_Q1 growth rate
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"), "Total_doses"] = (
            (vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2021_Q4"),"Total_doses"].values[0])*Growth_Q1)
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"), "rule"] = rule
        # for the country, extrapolate 2022_Q2 doses using 2022_Q1 doses and the 2022_Q2 growth rate
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "Total_doses"] = (
            (vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q1"),"Total_doses"].values[0])*Growth_Q2)
        vax_extrap.loc[(vax_extrap["country"] == country) & (vax_extrap["yyyy_qq"] == "2022_Q2"), "rule"] = rule
        return vax_extrap
    # if none of the rules apply, print a string describing the fact that there is an error
    else:
        print(f"The case of {country} is not covered by your rules!")
    
# for every country in the vaccine data, perform the extrapolation function
for c in vax_extrap.country.unique():
    vax_extrap = extrapolate_growth_to_IHME(c)

# keep only a small number of columns in the vaccine data
vax_df = vax_extrap[['country', 'year', 'quarter', 'yyyy_qq', 'Total_doses', "rule"]]

# create a data frame with the brand-specific data
brand_df = ihme_ds2.copy()
brand_df = brand_df.set_index(["country", "yyyy_qq"])

# get a list of the columns  that have brand-specific total doses
total_cols = [i for i in brand_df.columns if "total_doses" in i]
# get a list of the columns that have brand-specific first booster doses
first_booster_cols = [i for i in brand_df.columns if "first_booster" in i]
# get a list of the columns that have brand-specific second booster doses
second_booster_cols = [i for i in brand_df.columns if "second_booster" in i]
# create a list that contains all these column names
brand_cols = total_cols + first_booster_cols + second_booster_cols

# simplify the brand-specific doses data to include those columns
brand_df = brand_df[brand_cols].reset_index()

# add the total dosage data to the brand-specific data
brand_vax = brand_df.merge(vax_df[["country", "yyyy_qq", "Total_doses", "rule"]],
                           on = ["country", "yyyy_qq"], how = "left")

# find the countries for which we had to extrapolate total dose data
extrap_brand_countries = brand_vax.loc[brand_vax["rule"].notna(), "country"].unique()

# create a smaller brand-specific data frame with those extrapolated countries
extrap_brand_df = brand_vax[brand_vax["country"].isin(extrap_brand_countries)]

# distribute the proportion of brand-specific doses across the extrapolated total doses
for country in extrap_brand_countries: 
    if ((brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"),"rule"].values[0] == "issue 3a (Rule 1)") | 
        (brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"), "rule"].values[0] == "issue 4 (back-stepped Rule 3a)") |
        (brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"), "rule"].values[0] == "issue 2a (Rule 3a)")):
        total_doses = brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"),"Total_doses"].values[0]
        for brand in total_cols:
            brand_prop = (brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q1"), brand].values[0]/brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q1"),"Total_doses"].values[0])
            brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"), brand] = total_doses*brand_prop
    else:
        total_doses_Q2 = brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"),"Total_doses"].values[0]
        total_doses_Q1 = brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q1"),"Total_doses"].values[0]
        for brand in brand_cols:
            brand_prop = (brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2021_Q4"), brand].values[0]/brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2021_Q4"),"Total_doses"].values[0])
            brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q2"), brand] = total_doses_Q2*brand_prop
            brand_vax.loc[(brand_vax["country"] == country) & (brand_vax["yyyy_qq"] == "2022_Q1"), brand] = total_doses_Q1*brand_prop

# ensure that the total of the brand-specific doses equals the total doses
brand_vax.loc[:, "check_total"] = brand_vax.loc[:, total_cols].sum(axis= 1, min_count = 1)

# add pre-vax period quarters to the data frame
for country in brand_vax.country.unique():
    for quarter in ["2020_Q1", "2020_Q2", "2020_Q3"]:
        brand_vax = brand_vax.append({"country": country, "yyyy_qq": quarter}, ignore_index = True)
    
# sort by date and country
brand_vax = brand_vax.sort_values(["yyyy_qq", "country"])
#brand_vax.to_excel("../output/vaccination_extrapolated.xlsx", index = False)

# add the brand-specific data to the IHME COVID data
quarterly_df = brand_vax.merge(ihme_quarterly, on = ["country", "yyyy_qq"], how = "outer")
# remove any duplicate columns
quarterly_df = quarterly_df.loc[:,~quarterly_df.columns.str.contains('_y')] 
quarterly_df.columns = quarterly_df.columns.str.replace(r'_x$', '')

# create a data frame with countries' WHO and World Bank classifications
regions = master[["country", "WHO_region", "WB_income_group_1"]]

# add the classification data to the COVID data
quarterly_df = quarterly_df.merge(regions, on = "country", how = "left")

# for countries without classifications, assign them
quarterly_df.loc[(quarterly_df["country"] == "Hong Kong") |
                   (quarterly_df["country"] == "Taiwan"), "WHO_region"] = "WPRO"

quarterly_df.loc[(quarterly_df["country"] == "Palestine"), "WHO_region"] = "EMRO"
quarterly_df.loc[(quarterly_df["country"] == "Puerto Rico"), "WHO_region"] = "AMRO"

quarterly_df.loc[(quarterly_df["country"] == "Hong Kong") | (quarterly_df["country"] == "Taiwan") |
                   (quarterly_df["country"] == "Puerto Rico"), "WB_income_group_1"] = "High Income"

quarterly_df.loc[(quarterly_df["country"] == "Palestine"), "WB_income_group_1"] = "Middle Income"

# check for empty cells or not classified values
ihme_q_regions = quarterly_df.WHO_region.value_counts()
ihme_q_incomes = quarterly_df.WB_income_group_1.value_counts()

# create a year and a quarter field
quarterly_df["year"] = quarterly_df["yyyy_qq"].str[:4].astype(int)
quarterly_df["quarter"] = quarterly_df["yyyy_qq"].str[-1:].astype(int)

# %% Make the quarterly regression file (make_ihme_quarterly_regbase.do)

# load in the GDP data (produced in gdp_formatting.py)
gdp_gap = pd.read_excel("../output/gdp_gap_ihme.xlsx")

# create a year, quarter, and year-quarter field in the GDP data
gdp_gap["year"] = gdp_gap["date"].str[:4]
gdp_gap["quarter"] = gdp_gap["date"].str[-1:]
gdp_gap["yyyy_qq"] = gdp_gap["year"] + "_Q" + gdp_gap["quarter"]

# drop the existing date column
gdp_gap = gdp_gap.drop(columns = "date")

# interpret the year and quarter variables as integers
gdp_gap.year = gdp_gap.year.astype(int)
gdp_gap.quarter = gdp_gap.quarter.astype(int)

# check how many countries
n_gdp_countries = len(gdp_gap.country.unique())

# merge with ihme data
q_reg_df = quarterly_df.merge(gdp_gap, on = ["country", "year", "quarter", "yyyy_qq"], how = "left")

# remove pre-2020 data
remove_quarters = ["2019_Q1", "2019_Q2", "2019_Q3", "2019_Q4", "2022_Q3", "2022_Q4"]
q_reg_df = q_reg_df[~(q_reg_df.yyyy_qq.isin(remove_quarters))]

# sort by country name and date
q_reg_df = q_reg_df.sort_values(["country", "year", "quarter", "yyyy_qq"]).reset_index(drop = True)

# if an entry is missing all of the regression dependent variables, drop it.
q_reg_df = q_reg_df.dropna(subset=["inf_mean", "daily_deaths", "gdp_gap"], how = "all")

# check how many countries in data 
n_q_reg_countries = len(q_reg_df.country.unique())
# save data frame to file
#q_reg_df.to_excel("../output/raw_quarterly_basefile.xlsx", index = False)
#q_reg_df = pd.read_excel("../output/raw_quarterly_basefile.xlsx")

# rename columns for ease of use
q_reg_df = q_reg_df.rename(columns = {"Pfizer_BioNTech_total_doses": "uptake_pfizer",
                                      "Moderna_total_doses": "uptake_moderna", "Total_doses": "uptake",
                                      "AstraZeneca_total_doses": "uptake_astrazeneca",
                                      "Pfizer_BioNTech_first_booster": "uptake_pfizer_first_booster",
                                      "Pfizer_BioNTech_second_booster": "uptake_pfizer_second_booster",
                                      "Moderna_first_booster": "uptake_moderna_first_booster",
                                      "Moderna_second_booster": "uptake_moderna_second_booster",
                                      "AstraZeneca_first_booster": "uptake_astrazeneca_first_booster",
                                      "AstraZeneca_second_booster": "uptake_astrazeneca_second_booster"})

# create an uptake variable for all manufacturers other than pfizer, moderna, and astrazeneca 
q_reg_df["uptake_other"] = q_reg_df["uptake"] - q_reg_df["uptake_pfizer"] - q_reg_df["uptake_moderna"]- q_reg_df["uptake_astrazeneca"]

# create a first booster variable for these "other" manufacturers
other_first_booster_vars = [var for var in q_reg_df.columns if "first_booster" in var and not any(brand in var for brand in list(["pfizer", "moderna", "astrazeneca"]))]
q_reg_df["uptake_other_first_booster"] = q_reg_df[other_first_booster_vars].sum(axis = 1)

# create a second booster variable for these "other" manufacturers
other_second_booster_vars = [var for var in q_reg_df.columns if "second_booster" in var and not any(brand in var for brand in list(["pfizer", "moderna", "astrazeneca"]))]
q_reg_df["uptake_other_second_booster"] = q_reg_df[other_second_booster_vars].sum(axis = 1)

# create an uptake variable for only the primary series
q_reg_df["uptake_pfizer_primary"] = q_reg_df["uptake_pfizer"] - q_reg_df["uptake_pfizer_first_booster"] - q_reg_df["uptake_pfizer_second_booster"]
q_reg_df["uptake_moderna_primary"] = q_reg_df["uptake_moderna"] - q_reg_df["uptake_moderna_first_booster"] - q_reg_df["uptake_moderna_second_booster"]
q_reg_df["uptake_astrazeneca_primary"] = q_reg_df["uptake_astrazeneca"] - q_reg_df["uptake_astrazeneca_first_booster"] - q_reg_df["uptake_astrazeneca_second_booster"]
q_reg_df["uptake_other_primary"] = q_reg_df["uptake_other"] - q_reg_df["uptake_other_first_booster"] - q_reg_df["uptake_other_second_booster"]

# create an uptake variable for non-Pfizer and non-Moderna manufacturers
q_reg_df["uptake_notpfz_notmod"] = q_reg_df["uptake"] - q_reg_df["uptake_pfizer"] - q_reg_df["uptake_moderna"]

# create an uptake variable or non-Pfizer manufacturers
q_reg_df["uptake_notpfz"] = q_reg_df["uptake"] - q_reg_df["uptake_pfizer"]

# create uptake for mRNA and non-mRNA manufacturers
q_reg_df["uptake_mrna"] = q_reg_df["uptake_pfizer"] + q_reg_df["uptake_moderna"]
q_reg_df["uptake_notmrna"] = q_reg_df["uptake"] - q_reg_df["uptake_pfizer"] - q_reg_df["uptake_moderna"]

# select the data columns we want to keep
q_reg_df = q_reg_df[["country", "year", "quarter", "yyyy_qq", "inf_mean", "inf_lower", "inf_upper",
                     "daily_deaths", "daily_deaths_unscaled", "gdp_gap", "uptake", "uptake_pfizer", "uptake_moderna", "uptake_astrazeneca",
                     "uptake_other", "uptake_notpfz_notmod", "uptake_notpfz", "uptake_mrna", "uptake_notmrna",
                     "uptake_pfizer_primary", "uptake_moderna_primary", "uptake_astrazeneca_primary",
                     "uptake_other_primary", "uptake_pfizer_first_booster", "uptake_moderna_first_booster", "uptake_astrazeneca_first_booster",
                     "uptake_other_first_booster", "uptake_pfizer_second_booster", "uptake_moderna_second_booster", "uptake_astrazeneca_second_booster",
                     "uptake_other_second_booster", "WHO_region", "WB_income_group_1"]]

# add population data to the data frame
q_reg_df = q_reg_df.merge(popdata, on = ["country", "year"], how = "left")
# create indicator fields for the country and time period
q_reg_df['country_group'] = q_reg_df.groupby(['country'], sort = False).ngroup() + 1
q_reg_df['time'] = q_reg_df.groupby(['yyyy_qq'], sort = False).ngroup() + 1   

# for our vaccine variables
for var in ["uptake", "uptake_pfizer", "uptake_moderna", "uptake_astrazeneca",
          "uptake_other", "uptake_notpfz_notmod", "uptake_notpfz", "uptake_mrna", "uptake_notmrna",
          "uptake_pfizer_primary", "uptake_moderna_primary", "uptake_astrazeneca_primary",
          "uptake_other_primary", "uptake_pfizer_first_booster", "uptake_moderna_first_booster",
          "uptake_astrazeneca_first_booster", "uptake_other_first_booster", "uptake_pfizer_second_booster",
          "uptake_moderna_second_booster", "uptake_astrazeneca_second_booster",
          "uptake_other_second_booster"]:
    # create a variable that is specifically not per capita
    q_reg_df["notpc_" + var] = q_reg_df[var]
    # and create a variable that is per capita
    q_reg_df[var] = q_reg_df[var]/q_reg_df["tot_pop"]

# make infections and deaths data per capita
for var in ["inf_mean", "inf_lower", "inf_upper", "daily_deaths", "daily_deaths_unscaled"]:
    q_reg_df[var] = q_reg_df[var]/q_reg_df["tot_pop"]
    
# create a data frame with China, Hong Kong, and Macao people vaccinated data
china_countries = ["China", "Hong Kong", "Macao"]
ch_hk_mc_vax = ihme_ds1_q[ihme_ds1_q["country"].isin(china_countries)]
# add populatoin data for these countries
ch_hk_mc_vax = ch_hk_mc_vax.merge(popdata, on = ["country", "year"], how = "left")
# only keep pertinent columns
ch_hk_mc_vax = ch_hk_mc_vax[["country", "yyyy_qq", "cumulative_all_fully_vaccinated", "tot_pop"]]

# if data is missing, replace with zero.
ch_hk_mc_vax.loc[ch_hk_mc_vax["cumulative_all_fully_vaccinated"].isna(), "cumulative_all_fully_vaccinated"] = 0
# calculate the new people vaccinated every day in these three countries
for c in china_countries:
    ch_hk_mc_vax.loc[ch_hk_mc_vax["country"] == c, "new_fully_vaccinated"] = (
        ch_hk_mc_vax.loc[ch_hk_mc_vax["country"] == c, "cumulative_all_fully_vaccinated"]
        - ch_hk_mc_vax.loc[ch_hk_mc_vax["country"] == c, "cumulative_all_fully_vaccinated"].shift(1))

# make new people vaccinated per capita
ch_hk_mc_vax["pc_vax"] = ch_hk_mc_vax["new_fully_vaccinated"]/ch_hk_mc_vax["tot_pop"]

# create an empty dataframe
adj_df = pd.DataFrame(columns = ["quarter", "wtd_adj_factor"])
# for each quarter 
for quarter in q_reg_df.yyyy_qq.unique():
    # get the number of people vaccinated per capita in China
    china_pc_vax = ch_hk_mc_vax.loc[(ch_hk_mc_vax["country"] == "China") & (ch_hk_mc_vax["yyyy_qq"] == quarter), "pc_vax"].values[0]
    # get the population-weighted average number of people vaccinated per capita in Hong Kong and Macao
    hk_mc_pc_vax = ch_hk_mc_vax.loc[(ch_hk_mc_vax["country"].isin(["Hong Kong", "Macao"])) & (ch_hk_mc_vax["yyyy_qq"] == quarter)]
    hk_mc_vax_avg = np.average(hk_mc_pc_vax["pc_vax"], weights= hk_mc_pc_vax["tot_pop"])
    # calculate the ratio between China's vaxxed people and Hong Kong/Macao's 
    ratio = china_pc_vax/hk_mc_vax_avg
    # add this value to the empty data frame
    adj_df = pd.concat([adj_df, pd.DataFrame({"quarter": [quarter], "wtd_adj_factor": [ratio]})], axis = 0, ignore_index = True)
    # for uptake data
    for col in [x for x in q_reg_df.columns if "uptake" in x]:
        # find the population-weighted average number of uptake per capita in Hong Kong and Macao
        hk_mc_brand_vax = q_reg_df.loc[(q_reg_df["country"].isin(["Hong Kong", "Macao"])) & (q_reg_df["yyyy_qq"] == quarter)]
        hk_mc_brand_avg = np.average(hk_mc_brand_vax[col], weights=hk_mc_brand_vax["tot_pop"])
        # if there is no data, assign China 0 doses
        if np.isnan(hk_mc_brand_avg*ratio):
            q_reg_df.loc[(q_reg_df["country"] == "China") & (q_reg_df["yyyy_qq"] == quarter), col] = 0
        # otherwise, assign China the Hong Kong/Macao data scaled using the adjustment facotr
        else:    
            q_reg_df.loc[(q_reg_df["country"] == "China") & (q_reg_df["yyyy_qq"] == quarter), col] = (
            hk_mc_brand_avg*ratio)
            
#adj_df.to_excel("../output/china_adjustment_factors.xlsx")

# a function to create lags of brand-specific data
def create_lags(brand):
    """
    Create lags of brand-specific vaccination data

    Parameters
    ----------
    brand : string
        A string of the brand name.

    Returns
    -------
    q_reg_df : data frame
        A data frame containing the epidemiological and vaccination data.

    """
    # if data is missing, assign it zero
    q_reg_df.loc[q_reg_df[brand].isna(), brand] = 0
    # for each country
    for c in q_reg_df.country.unique():
        # create a string for cumulative doses
        cuml_string = "cum_" + brand
        # if the country is China, sum the data
        if c == "China":
            q_reg_df.loc[(q_reg_df["country"] == c), cuml_string] = q_reg_df.loc[(q_reg_df["country"] == c), brand].cumsum()
            q_reg_df.loc[q_reg_df[cuml_string].isna(), cuml_string] = 0
        # otherwise, sum the not per capita doses then divide by the population 
        else:
            q_reg_df.loc[(q_reg_df["country"] == c), cuml_string] = q_reg_df.loc[(q_reg_df["country"] == c), "notpc_" + brand].cumsum()
            q_reg_df.loc[q_reg_df[cuml_string].isna(), cuml_string] = 0
            q_reg_df.loc[(q_reg_df["country"] == c), cuml_string] = (
                        q_reg_df.loc[(q_reg_df["country"] == c), cuml_string]/q_reg_df.loc[q_reg_df["country"] == c, "tot_pop"])
        # create nine lags of new and cumulativ uptake
        for i in range(1, 9):
            lag_string = "L" + str(i) + "_" + brand
            q_reg_df.loc[q_reg_df["country"] == c, lag_string] = q_reg_df.loc[q_reg_df["country"] == c, brand].shift(i, fill_value = 0)
            rem_uptake_string = "L" + str(i) + "_" + cuml_string
            q_reg_df.loc[q_reg_df["country"] == c, rem_uptake_string] = q_reg_df.loc[q_reg_df["country"] == c, cuml_string].shift(i, fill_value = 0)        
    return q_reg_df

# for each uptake variable, create those lags
for b in ["uptake", "uptake_pfizer", "uptake_moderna", "uptake_astrazeneca",
          "uptake_other", "uptake_notpfz_notmod", "uptake_notpfz", "uptake_mrna", "uptake_notmrna",
          "uptake_pfizer_primary", "uptake_moderna_primary", "uptake_astrazeneca_primary",
          "uptake_other_primary", "uptake_pfizer_first_booster", "uptake_moderna_first_booster",
          "uptake_astrazeneca_first_booster", "uptake_other_first_booster", "uptake_pfizer_second_booster",
          "uptake_moderna_second_booster", "uptake_astrazeneca_second_booster",
          "uptake_other_second_booster"]:
    q_reg_df = create_lags(b)

# drop not per capita data
drop_notpc_cols = [col for col in q_reg_df.columns if "notpc" in col]
q_reg_df = q_reg_df.drop(columns = drop_notpc_cols)

# remove Macao (population less than 1 million) and Turkmenistan (lots of missing data)
q_reg_df = q_reg_df[(q_reg_df["country"] != "Macao") & (q_reg_df["country"] != "Turkmenistan")]
# save the data file
q_reg_df.to_excel("../output/ihme_quarterly_regbase_boosters.xlsx", index = False)

# -*- coding: utf-8 -*-
"""
forex_only.py: Calculates foreign exchange rates using a variety of sources.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 14 April 2023
__updated__ = 15 November 2023

inputs:
    - ihme_countries.xlsx (processed file; created in ihme_portal.py)
    - WEO_Documentation.xlsx (raw file)
    - P_Data_Extract_From_World_Development_Indicators.xlsx (raw file)
    - RprtRateXchg_20010331_20220930.csv (raw file)
    - Exchange rate, new LCU per USD extended backward, period average.xlsx (raw file)

outputs:
    - forex_2010_to_2019_jk.xlsx    

"""

# %% load in libraries
import pandas as pd
import numpy as np

# %% process data 

#load in a list of the IHME countries
ihme_countries = pd.read_excel("../output/ihme_countries.xlsx")
ihme_countries = ihme_countries[0].unique()

#creating a dictionary that is used to rename countries
renaming = {
    "Cabo Verde": "Cape Verde",
    "Congo, Rep.": "Congo",
    "Congo, Dem. Rep.": "Democratic Republic of Congo",
    "Faroe Islands": "Faeroe Islands",
    "Gambia, The": "Gambia",
    "Hong Kong SAR, China": "Hong Kong",
    "Korea, Dem. People's Rep.": "North Korea",
    "Korea, Rep.": "South Korea",
    "Kyrgyz Republic": "Kyrgyzstan",
    "Lao PDR": "Laos",
    "Macao SAR, China": "Macao",
    "Micronesia, Fed. Sts.": "Micronesia (country)",
    "Moldova, Rep.": "Moldova",
    "Slovak Republic": "Slovakia",
    "St. Kitts and Nevis": "Saint Kitts and Nevis",
    "St. Lucia": "Saint Lucia",
    "St. Martin (French part)": "Saint Martin (French part)",
    "St. Vincent and the Grenadines": "Saint Vincent and the Grenadines",
    "Turkiye": "Turkey",
    "Venezuela, RB": "Venezuela",
    "Yemen, Rep.": "Yemen",
    "Egypt, Arab Rep.": "Egypt",
    "West Bank and Gaza": "Palestine",
    "Iran, Islamic Rep.": "Iran",
    "Russian Federation": "Russia",
    "Syrian Arab Republic": "Syria"
    }

#look at the currencies in the WEO GDP data
weo19_doc = pd.read_excel("../input/WEO_Documentation.xlsx", sheet_name = "WEO_Oct2019_Documentation")
weo_currency = weo19_doc[["Country", "Currency"]]

#load in one of the IMF sources for foreign exchange rates.
forex_wdi = pd.read_excel("../input/P_Data_Extract_From_World_Development_Indicators-Forex.xlsx")

#just passing through a couple of renaming functions because so many of the countries have
#different spelling than in IHME
forex_wdi = forex_wdi.replace(renaming)
#rename columns 
forex_wdi = forex_wdi.rename(columns = {"Country Name": "country"})
forex_wdi = forex_wdi[["country"] + [col for col in forex_wdi.columns if "[YR" in col]]
forex_wdi.columns = forex_wdi.columns.str.split(' ', 1).str[0]
rename_dict = {col: 'forex_' + col for col in forex_wdi.columns[forex_wdi.columns.str.startswith('2')]}
forex_wdi = forex_wdi.rename(columns = rename_dict)
forex_wdi = forex_wdi.replace("..", np.nan)
forex_wdi = forex_wdi.drop(columns = ["forex_2020", "forex_2021"])

#only keep countries that are in IHME
forex_wdi_ihme = forex_wdi[forex_wdi["country"].isin(ihme_countries)]

#load in another IMF-based foreign exchange rate file.
forex_irs = pd.read_csv("../input/RprtRateXchg_20010331_20220930.csv")

# make columns lowercase font
forex_irs.columns = forex_irs.columns.str.lower()
forex_irs.country = forex_irs.country.str.title()
forex_irs.currency = forex_irs.currency.str.title()

# create a dictionary for renaming countries
country_replacements = {
    "Antigua & Barbuda": "Antigua",
    "Bosnia": "Bosnia and Herzegovina",
    "Cote D'Ivoire": "Cote d'Ivoire",
    "Swaziland": "Eswatini",
    "Guinea Bissau": "Guinea-Bissau",
    "Macedonia Fyrom": "North Macedonia",
    "Somali": "Somalia",
    "South Sudanese": "South Sudan",
    "Timor": "Timor-Leste",
    "Trinidad & Tobago": "Trinidad and Tobago",
    "Czech": "Czechia",
    "Czech Republic": "Czechia",
    "Congo, Dem. Rep": "Democratic Republic of Congo",
    "Dem. Rep. Of Congo": "Democratic Republic of Congo",
    "Democratic Republic Of Congo": "Democratic Republic of Congo",
    "Korea": "South Korea",
    "Faroe Islands": "Faeroe Islands",
    "Korea, Dem. People's Rep.": "North Korea",
    "Lao PDR": "Laos",
    "Lao, PDR": "Laos",
    "Macao SAR, China": "Macao",
    "Turkiye": "Turkey",
    "Cambodia (Khmer)": "Cambodia",
    "Rep. Of N Macedonia": "North Macedonia",
    "Taiwan, China": "Taiwan",
    "Tanzania, United Rep.": "Tanzania"
    }

#again perform some renaming of countries.
forex_irs = forex_irs.replace(country_replacements)

#only save pertinent dates
forex_irs["date"] = pd.to_datetime(forex_irs["record date"])
forex_irs = forex_irs[(forex_irs["date"] > "2009-12-31") & (forex_irs["date"] <= "2019-12-31")]
forex_irs['month'] = forex_irs['date'].dt.month
forex_irs = forex_irs[forex_irs["month"] == 12]
forex_irs['year'] = forex_irs['date'].dt.year

#again only keep countries that are in IHME
forex_irs_ihme = forex_irs[forex_irs["country"].isin(ihme_countries)]
forex_irs_ihme = forex_irs_ihme.drop_duplicates(subset = ["country", "date"], keep = False)
forex_irs_ihme = forex_irs_ihme.pivot(index = 'country', columns='year',
                                      values='exchange rate')

forex_irs_ihme.columns = ["forex_" + col for col in forex_irs_ihme.columns.astype(str)]
forex_irs_ihme = forex_irs_ihme.reset_index(drop = False)

#load in WDI foreign exchange rate file
forex_gem = pd.read_excel("../input/Exchange rate, new LCU per USD extended backward, period average.xlsx",
                       sheet_name = "annual")

# rename the first column to be "year"
forex_gem.rename(columns = {forex_gem.columns[0]: "year"}, inplace = True)
# only keep years between 2010 and 2019
forex_gem = forex_gem[(forex_gem["year"] >= 2010) & (forex_gem["year"] <= 2019)]
# change the orientation of the data
forex_gem = forex_gem.transpose()
# create columns named "forex_yyyy" where yyyy stands for the year (e.g., 2011)
forex_gem.columns = ["forex_" + forex_gem.loc["year", col].astype(int).astype(str) for col in forex_gem.columns]
forex_gem = forex_gem.drop(axis = 0, labels = "year")
forex_gem = forex_gem.reset_index()
forex_gem.rename(columns = {forex_gem.columns[0]: "country"}, inplace = True)

# rename countries
forex_gem = forex_gem.replace(renaming)
forex_gem = forex_gem.replace(country_replacements)

#only keep countries in the IHME data
forex_gem_ihme = forex_gem[forex_gem["country"].isin(ihme_countries)]

# create a data frame with for country-year-specific foreign exchange rates
forex_ihme = pd.DataFrame(columns = ["forex_2010", "forex_2011",
                                     "forex_2012", "forex_2013", "forex_2014",
                                     "forex_2015", "forex_2016", "forex_2017",
                                     "forex_2018", "forex_2019"],
                          index = ihme_countries)

# set the index for the various foreign exchange rate sources
forex_wdi_ihme = forex_wdi_ihme.set_index("country")
forex_irs_ihme = forex_irs_ihme.set_index("country")
forex_gem_ihme = forex_gem_ihme.set_index("country")

# add the various sources to the country-specific data
forex_ihme = forex_ihme.combine_first(forex_wdi_ihme)
forex_ihme = forex_ihme.combine_first(forex_irs_ihme)
forex_ihme = forex_ihme.combine_first(forex_gem_ihme)

# make sure the foreign exchange rates are floats
forex_ihme = forex_ihme.astype(float)
# make the first column the countries
forex_ihme = forex_ihme.reset_index(drop = False)
forex_ihme = forex_ihme.rename(columns = {"index": "country"})

# save the file to Excel
forex_ihme.to_excel("../output/forex_2010_to_2019_jk.xlsx", index = False)

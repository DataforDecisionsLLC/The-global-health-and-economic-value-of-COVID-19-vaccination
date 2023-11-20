# -*- coding: utf-8 -*-
"""
coverage_age_structures_5year.py: Computes age-structures of deaths for the 5-year
age buckets.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 9 December 2022
__updated__ = 15 November 2023

inputs:
    - Output_5.csv (raw file)
    - master_country_list.xlsx (processed file; created in Excel)

outputs:
    - daily_coverage_deaths_5year.xlsx

"""

# %% Prep data and code
#open libraries
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import seaborn as sns

#load in data
coverage_5 = pd.read_csv("../input/Output_5.csv", skiprows = 3, encoding = "ISO-8859-1")

#make sure the date string is interpreted as a date
coverage_5["Date"] = pd.to_datetime(coverage_5["Date"], format = "%d.%m.%Y")

#format it as year-month-day
coverage_5["Date"] = coverage_5["Date"].dt.strftime("%Y-%m-%d")

#choose only the country-aggregated data
coverage_5 = coverage_5[coverage_5["Region"] == "All"]

#get a list of all countries
cov_countries = coverage_5["Country"].unique()

# %% summarize the data based on start date, initial deaths, end date, final deaths
daily_deaths_sum = pd.DataFrame(coverage_5.groupby(["Country", "Date", "Sex"])["Deaths"].sum())

# %% choose only the "both" sexes data
coverage_5_both = coverage_5[coverage_5["Sex"] == "b"]

#get a list of all columns
cov_countries_both =  coverage_5_both["Country"].unique()

#remove "countries" that are not unique countries from the list of countries.
cov_countries_both = cov_countries_both[~np.isin(cov_countries_both,
                                    ["England", "England and Wales", "Island of Jersey",
                                     "Island of Man", "Northern Ireland", "Puerto Rico", "Scotland"])]

# read in the population data file and only keep countries whose population are above 1000 thousand (1M)
master_list = pd.read_excel("../input/master_country_list.xlsx", sheet_name = "master_list")
pop_mil = master_list[master_list["2020 pop (thousands)"] >= 1000]

wrong_names = set(cov_countries_both) - set(pop_mil.country.unique())

coverage_5_both = coverage_5_both.replace({"Isreal": "Israel", "USA": "United States"})

coverage_5_both = coverage_5_both[coverage_5_both["Country"].isin(pop_mil.country.unique())]

#reshape the data from long to wide
cov5_wide = coverage_5_both.pivot_table(index = ["Country", "Date"],
                                        columns = "Age", values = "Deaths").reset_index()

#produce a list of countries
countries = cov5_wide["Country"].unique()

#produce a list of ages
ages = list(cov5_wide.columns[2:])

cov5_wide = cov5_wide.sort_values(["Country", "Date"])

cov5_wide["Date"] = pd.to_datetime(cov5_wide["Date"])

#only keep 2020 and later data
cov5_wide = cov5_wide[cov5_wide["Date"] > "2019-12-31"]

#create empty columns for new cases and new deaths by age
for age in ages:
    cov5_wide["new"+"_"+str(age)] = 0

#subtract cumulative cases/deaths from previous day's cumulative cases/deaths
for age in ages:
    cov5_wide["new"+"_"+str(age)] = (cov5_wide[age] - cov5_wide[age].shift(1, fill_value = 0))

#reset the first row of each country to equal its first cases/deaths
for country in countries:
    country_df = cov5_wide[cov5_wide["Country"] == country]
    first_date = country_df.groupby('Country')['Date'].min().values[0]
    for age in ages:
        cov5_wide.loc[(cov5_wide["Country"] == country) & (cov5_wide["Date"] == first_date), "new"+"_"+str(age)] = cov5_wide.loc[(cov5_wide["Country"] == country) & (cov5_wide["Date"] == first_date), age].values[0]
# %% calculate proportion of deaths

age_structure_df = cov5_wide.drop(columns = ages)   
age_structure_df["Date"] = pd.to_datetime(age_structure_df["Date"])

age_structure_df['month_year'] = age_structure_df['Date'].dt.to_period('M')

structure = age_structure_df.copy()

structure["totaldeaths"] = structure.filter(like='new_').sum(1)

for age in ages:
    structure[f"prop_{age}"] = structure["new"+"_"+str(age)]/structure["TotalDeaths"]

structure = structure.rename(columns = {"Date": "date", "Country": "country"}).sort_values(["country", "date"])

structure["date"] = pd.to_datetime(structure["date"]).dt.strftime("%Y-%m-%d")

structure_region = structure.merge(pop_mil[["country", "WHO Region", "World Bank income group"]],
                                   on = "country", how = "left")

structure_region = structure_region.rename(columns = {"WHO Region": "who_region",
                                                      "World Bank income group": "world_bank_income_group"})

structure_region.loc[structure_region.country == "Puerto Rico", "who_region"] = "AMRO"
structure_region.loc[structure_region.country == "Palestine", "who_region"] = "EMRO"

structure_region.loc[structure_region.country == "Puerto Rico", "world_bank_income_group"] = "High Income"
structure_region.loc[structure_region.country == "Palestine", "world_bank_income_group"] = "Middle Income"

cols = list(structure_region)
cols.insert(2, cols.pop(cols.index('month_year')))

structure_region = structure_region.loc[:, cols]

structure_region = structure_region.rename(columns = {"month_year": "year_month"})

structure_region.to_excel("../output/daily_coverage_deaths_5year.xlsx", index = False)

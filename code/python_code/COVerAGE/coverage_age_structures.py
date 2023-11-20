# -*- coding: utf-8 -*-
"""
coverage_age_structures.py: Computes age-structures for cases and deaths.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 18 October 2022
__updated__ = 15 November 2023

inputs:
    - Output_10.csv (raw file)
    - master_country_list.xlsx (processed file; created in Excel)

outputs:
    - daily_coverage_deaths.xlsx
"""

# %% Prep data and code
#open libraries.
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import seaborn as sns

#load in data
coverage_10 = pd.read_csv("../input/Output_10.csv", skiprows = 3, encoding = "ISO-8859-1")

#make sure the date string is interpreted as a date
coverage_10["Date"] = pd.to_datetime(coverage_10["Date"], format = "%d.%m.%Y")

#format it as year-month-day
coverage_10["Date"] = coverage_10["Date"].dt.strftime("%Y-%m-%d")

#choose only the country-aggregated data
coverage_10 = coverage_10[coverage_10["Region"] == "All"]

#get a list of all countries
cov_countries = coverage_10["Country"].unique()

# %% summarize the data based on start date, initial cases/deaths, end date, final cases/deaths
daily_cases_sum = pd.DataFrame(coverage_10.groupby(["Country", "Date", "Sex"])["Cases"].sum())
daily_deaths_sum = pd.DataFrame(coverage_10.groupby(["Country", "Date", "Sex"])["Deaths"].sum())

# %% choose only the "both" sexes data
coverage_10_both = coverage_10[coverage_10["Sex"] == "b"]

#get a list of all columns
cov_countries_both =  coverage_10_both["Country"].unique()

#remove "countries" that are not unique countries from the list of countries.
cov_countries_both = cov_countries_both[~np.isin(cov_countries_both,
                                    ["England", "England and Wales", "Island of Jersey",
                                     "Island of Man", "Northern Ireland", "Puerto Rico", "Scotland"])]

# read in the population data file and only keep countries whose population are above 1000 thousand (1M)
master_list = pd.read_excel("../input/master_country_list.xlsx", sheet_name = "master_list")
pop_mil = master_list[master_list["2020 pop (thousands)"] >= 1000]

wrong_names = set(cov_countries_both) - set(pop_mil.country.unique())

coverage_10_both = coverage_10_both.replace({"Isreal": "Israel", "USA": "United States"})

coverage_10_both = coverage_10_both[coverage_10_both["Country"].isin(pop_mil.country.unique())]

#reshape the data from long to wide
cov10_wide = coverage_10_both.pivot_table(index = ["Country", "Date"], columns = "Age",
                                   values = ["Cases", "Deaths"]).reset_index()

#produce a list of countries
countries = cov10_wide["Country"].unique()

#produce a list of ages
ages = cov10_wide["Cases"].columns

cov10_wide = cov10_wide.sort_values(["Country", "Date"])

cov10_wide["Date"] = pd.to_datetime(cov10_wide["Date"])

#only keep 2020 and later data
cov10_wide = cov10_wide[cov10_wide["Date"] > "2019-12-31"]

#create empty columns for new cases and new deaths by age
for age in ages:
    cov10_wide[("NewCases", age)] = 0
    cov10_wide[("NewDeaths", age)] = 0

#subtract cumulative cases/deaths from previous day's cumulative cases/deaths
for age in ages:
    cov10_wide[("NewCases", age)] = (cov10_wide[("Cases", age)] -
                                     cov10_wide[("Cases", age)].shift(1, fill_value = 0))
    cov10_wide[("NewDeaths", age)] = (cov10_wide[("Deaths", age)] -
                                      cov10_wide[("Deaths", age)].shift(1, fill_value = 0))

#reset the first row of each country to equal its first cases/deaths
for country in countries:
    country_df = cov10_wide[cov10_wide["Country"] == country]
    first_date = country_df.groupby('Country')['Date'].min().values[0]
    for age in ages:
        cov10_wide.loc[(cov10_wide["Country"] == country) & (cov10_wide["Date"] == first_date), ("NewCases", age)] = cov10_wide.loc[(cov10_wide["Country"] == country) & (cov10_wide["Date"] == first_date), ("Cases", age)].values[0]
        cov10_wide.loc[(cov10_wide["Country"] == country) & (cov10_wide["Date"] == first_date), ("NewDeaths", age)] = cov10_wide.loc[(cov10_wide["Country"] == country) & (cov10_wide["Date"] == first_date), ("Deaths", age)].values[0]

# %% calculate the total proportion of new deaths by age group
agestructure_overall = {}
total_deaths_ages = cov10_wide["NewDeaths"].sum()
total_deaths = total_deaths_ages.sum()

for age in ages:
    prop_deaths = total_deaths_ages[age]/total_deaths
    agestructure_overall[age] = [prop_deaths]

overall_agestructure_df = pd.DataFrame.from_dict(agestructure_overall, orient = "index",
                                                 columns = ["PropDeaths"])
#overall_agestructure_df.to_excel("../COVerAGE_Overall_Agestructure.csv", index = False)

# %% calculate country-specific age structure
agestructure_countries = {}
for country in countries:
    country_deaths_ages = cov10_wide.loc[cov10_wide["Country"] == country, "NewDeaths"].sum()
    country_deaths = country_deaths_ages.sum()
    for age in ages:
        prop_country_deaths = country_deaths_ages[age]/country_deaths
        agestructure_countries[country, age] = [prop_country_deaths]

country_agestructure_df = pd.DataFrame.from_dict(agestructure_countries, orient = "index",
                                                columns = ["PropDeaths"])
#country_agestructure_df.to_excel("../COVerAGE_Countries_Agestructure.xlsx", index = False)

# %% calculate age structure quarterly

age_structure_df = cov10_wide[["Country", "Date", "NewDeaths"]]    
age_structure_df["Date"] = pd.to_datetime(age_structure_df["Date"])

age_structure_df["quarter"] = "2022Q4"
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2022-10-01", "2022Q3", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2022-07-01", "2022Q2", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2022-04-01", "2022Q1", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2022-01-01", "2021Q4", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2021-10-01", "2021Q3", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2021-07-01", "2021Q2", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2021-04-01", "2021Q1", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2021-01-01", "2020Q4", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2020-10-01", "2020Q3", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2020-07-01", "2020Q2", age_structure_df["quarter"])     
age_structure_df["quarter"] = np.where(age_structure_df['Date'] < "2020-04-01", "2020Q1", age_structure_df["quarter"])    

#structure = age_structure_df.groupby(["Country", "quarter"]).sum().reset_index()

structure = age_structure_df.copy()
#for age in ages:
    #structure.loc[structure[("NewDeaths", age)] < 0, ("NewDeaths", age)] = 0

structure["TotalDeaths"] = structure[["NewDeaths"]].sum(axis=1)

for age in ages:
    structure[f"Prop_{age}"] = structure[("NewDeaths", age)]/structure["TotalDeaths"]

structure["Date"] = pd.to_datetime(structure["Date"]).dt.strftime("%Y-%m-%d")

structure = structure.rename(columns = {"Date": "date", "Country": "country"}).sort_values(["country", "date"])

structure.columns = structure.columns.map('{0[0]}_{0[1]}'.format) 
structure.columns = map(str.lower, structure.columns)
structure.columns = structure.columns.str.rstrip('_')
structure_region = structure.merge(pop_mil[["country", "WHO Region", "World Bank income group"]], on = "country", how = "left")

structure_region.to_excel("../output/daily_coverage_deaths.xlsx", index = False)

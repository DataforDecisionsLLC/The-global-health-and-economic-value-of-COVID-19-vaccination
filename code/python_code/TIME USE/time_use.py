# -*- coding: utf-8 -*-
"""
time_use.py: Assigns time use data to countries.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 17 November 2022
__updated__ = 15 November 2023

inputs:
    - Economic parameters.xlsx (processed file)
    - ihme_countries.xlsx (processed file; created in ihme_portal.py)
    - master_country_list.xlsx (processed file; created in Excel)
    
outputs:
    - time_use_processed_ihme.xlsx

"""

# %% load in packages
import pandas as pd
import numpy as np

# %% load in files
# load in OECD time use data
oecd = pd.read_excel("../input/Economic parameters.xlsx", sheet_name = "Time Use (OECD)")

# change country names to author preferred versions
oecd = oecd.replace({"USA": "United States", "UK": "United Kingdom",
                     "Italy ": "Italy", "Norway ": "Norway"})

# create a list of all time use categories from the data
categories = oecd.Category.unique()

# define the time use categories as paid work, unpaid work, leisure time, or 
# not applicable
paid_work = ["Paid work"]
unpaid_work = ["Care for household members", "Housework", "Shopping",
               "Other unpaid work & volunteering"]
leisure = ["Sports", "Attending events", "Seeing friends", "TV and Radio",
           "Other leisure activities"]
not_used = ["Education", "Sleep", "Eating and drinking", "Personal care"]

# create a list of lists describing whether an entry in the data is in our categories
conditions = [
    (oecd['Category'].isin(paid_work)),
    (oecd['Category'].isin(unpaid_work)),
    (oecd['Category'].isin(leisure))]

# define time uses
uses = ['paid work time', 'unpaid work time', 'leisure time']

# using the list of lists and the time uses, create a column describing the time uses 
oecd['use'] = np.select(conditions, uses, default = "other time")

# collapse the data to have one entry per country-time use combination
simple_oecd = oecd.groupby(["Country", "use"])["Time (minutes)"].sum().reset_index()

# read in the population data file and only keep countries whose population are above 1000 thousand (1M)
countries = pd.read_excel("../output/ihme_countries.xlsx")
countries.columns = ["country"]

# merge OECD time use data with IHME countries
countries_time = pd.merge(countries, simple_oecd, left_on = "country", right_on = "Country", how = "outer")
countries_time.loc[countries_time["country"].isna(), "country"] = "Luxembourg"

# we have two columns describing the country, simplify it to just one.
countries_time["Country"] = countries_time["country"]
countries_time = countries_time.drop(columns = "country")
countries_time = countries_time.rename(columns = {"Country": "country"})

# add regions to the data
master = pd.read_excel("../input/master_country_list.xlsx", sheet_name = "master_list")
countries_time = countries_time.merge(master, on = "country", how = "left")

# for countries without regions, define them
countries_time.loc[countries_time["country"] == "Puerto Rico", "WHO_region"] = "AMRO"
countries_time.loc[countries_time["country"] == "Hong Kong", "WHO_region"] = "WPRO"
countries_time.loc[countries_time["country"] == "Macao", "WHO_region"] = "WPRO"
countries_time.loc[countries_time["country"] == "Palestine", "WHO_region"] = "EMRO"
countries_time.loc[countries_time["country"] == "Taiwan", "WHO_region"] = "WPRO"

countries_time.loc[countries_time["country"] == "Japan", "UN_region"] = "Asia"
countries_time.loc[countries_time["country"] == "Hong Kong", "UN_region"] = "Asia"
countries_time.loc[countries_time["country"] == "Macao", "UN_region"] = "Asia"
countries_time.loc[countries_time["country"] == "Palestine", "UN_region"] = "Asia"
countries_time.loc[countries_time["country"] == "Taiwan", "UN_region"] = "Asia"

# drop instances of missing data
c_t = countries_time.dropna()

# 
who_time = countries_time.groupby(["WHO_region", "use"])["Time (minutes)"].mean().reset_index()
un_time = countries_time.groupby(["UN_region", "use"])["Time (minutes)"].mean().reset_index()

# %% load in the Charmes 2019 data

charmes = pd.read_excel("../input/Charmes2019_unpaid_paid_work.xlsx", sheet_name = "time_use")

charmes_time = pd.merge(countries, charmes, on = "country", how = "left")

charmes_time = charmes_time.merge(master, on = "country", how = "left")

charmes_time.loc[charmes_time["country"] == "Puerto Rico", "WHO_region"] = "AMRO"
charmes_time.loc[charmes_time["country"] == "Hong Kong", "WHO_region"] = "WPRO"
charmes_time.loc[charmes_time["country"] == "Macao", "WHO_region"] = "WPRO"
charmes_time.loc[charmes_time["country"] == "Palestine", "WHO_region"] = "EMRO"
charmes_time.loc[charmes_time["country"] == "Taiwan", "WHO_region"] = "WPRO"

charmes_time.loc[charmes_time["country"] == "Japan", "UN_region"] = "Asia"
charmes_time.loc[charmes_time["country"] == "Hong Kong", "UN_region"] = "Asia"
charmes_time.loc[charmes_time["country"] == "Macao", "UN_region"] = "Asia"
charmes_time.loc[charmes_time["country"] == "Palestine", "UN_region"] = "Asia"
charmes_time.loc[charmes_time["country"] == "Taiwan", "UN_region"] = "Asia"

ch_t = charmes_time.dropna()

# %% load in the demographic information from the Male and Female WPP data.

male = pd.read_excel("../input/WPP2022_POP_F01_2_POPULATION_SINGLE_AGE_MALE.xlsx",
                     sheet_name = "Estimates", header = 16)

female = pd.read_excel("../input/WPP2022_POP_F01_3_POPULATION_SINGLE_AGE_FEMALE.xlsx",
                     sheet_name = "Estimates", header = 16)

male2019 = male[male["Year"] == 2019]
female2019 = female[female["Year"] == 2019]

#change the column name of the country variable to an easily usable title
male2019 = male2019.rename(columns = {"Region, subregion, country or area *":
                                          "country"})

female2019 = female2019.rename(columns = {"Region, subregion, country or area *":
                                          "country"})
    
#create a list of countries in the population file, a list of countries in the lifetables,
#and find where the differences are (i.e., county names that need to be renamed).
lifetable_countries = male2019.country.unique()
lifetable_countries.sort()
country_diffs = set(lifetable_countries) - set(countries.country)

# create a dictionary to rename countries in the lifetables to the names in our master files.
renaming = {"Bolivia (Plurinational State of)": "Bolivia", "China, Hong Kong SAR": "Hong Kong",
            "China, Taiwan Province of China": "Taiwan", "Côte d'Ivoire": "Cote d'Ivoire",
            "Dem. People's Republic of Korea": "North Korea",
            "Democratic Republic of the Congo": "Democratic Republic of Congo",
            "Iran (Islamic Republic of)": "Iran", "Lao People's Democratic Republic": "Laos",
            "State of Palestine": "Palestine", "Syrian Arab Republic": "Syria",
            "Türkiye": "Turkey", "United Republic of Tanzania": "Tanzania",
            "United States of America": "United States", "Venezuela (Bolivarian Republic of)": "Venezuela",
            "Viet Nam": "Vietnam", "Russian Federation": "Russia", "Republic of Moldova": "Moldova",
            "Republic of Korea": "South Korea", "Cabo Verde": "Cape Verde", "Faroe Islands": "Faeroe Islands",
            "Curaçao": "Curacao", "China, Macao SAR": "Macao"}

#perform the renaming and remove all countries that are not in the population data file.
male2019 = male2019.replace(renaming)
female2019 = female2019.replace(renaming)

# only keep countries that are in the IHME data
male2019 = male2019[male2019["country"].isin(countries.country.unique())]
female2019 = female2019[female2019["country"].isin(countries.country.unique())]

# create objects of the location of the country, year, and upper age of the life tables
a = male2019.columns.get_loc('country')
b = male2019.columns.get_loc('Year')
c = male2019.columns.get_loc(65)

# simplify the male and female life tables to only have the country, year, and ages columns
male_df = male2019.iloc[:, np.r_[a, b:c]]
female_df = female2019.iloc[:, np.r_[a, b:c]]

# compute an "adult" population extending from age 15 to 64
male_df["adult"] = male_df.loc[:, 15:64].sum(axis = 1)
female_df["adult"] = female_df.loc[:, 15:64].sum(axis = 1)

# simplify the data frame to only have the country year and adult population.
male_adult = male_df[["country", "Year", "adult"]]
female_adult = female_df[["country", "Year", "adult"]]

# merge the male and female life tables together
sexes_df = male_adult.merge(female_adult, on = ["country", "Year"],
                            suffixes = ["_male", "_female"], how = "left")

# get the total adult population and find the male and female proportion
sexes_df["pop"] = sexes_df["adult_male"] + sexes_df["adult_female"]
sexes_df["prop_male"] = sexes_df["adult_male"]/sexes_df["pop"]
sexes_df["prop_female"] = sexes_df["adult_female"]/sexes_df["pop"]

# %% combine lifetables data, charmes data, and OECD data for comparison

# reformat Charmes data from long to wide
charmes_df = ch_t.pivot(index='country', columns='sex', values=["unpaid_total", "paid"]).reset_index()

# merge Charmes data with life tables
charmes_merged = charmes_df.merge(sexes_df[["country", "prop_male", "prop_female"]],
                                  left_on = "country", right_on = "country", how = "left")

# calculate the average unpaid work time based on male and female population proportions
charmes_merged["unpaid_avg"] = (charmes_merged[("unpaid_total", "men")]*charmes_merged["prop_male"]
                                + charmes_merged[("unpaid_total", "women")]*charmes_merged["prop_female"])

# calculate the average paid work time based on male and female population proportions
charmes_merged["paid_avg"] = (charmes_merged[("paid", "men")]*charmes_merged["prop_male"]
                                + charmes_merged[("paid", "women")]*charmes_merged["prop_female"])

# create a simplified data frame that only contains the country, unpaid, and paid work time
charmes_avg = charmes_merged[["country", "unpaid_avg", "paid_avg"]]

# create a simplified OECD data frame
oecd_df = c_t[["country", "use", "Time (minutes)"]]

# only retain paid and unpaid work time in the OECD data
oecd_df = oecd_df[(oecd_df["use"] == "paid work time") | (oecd_df["use"] == "unpaid work time")]

# reformat the OECD data from long to wide
oecd_df = oecd_df.pivot(index='country', columns='use', values="Time (minutes)").reset_index()

# merge Charmes and OECD data
comparison_df = charmes_avg.merge(oecd_df, on = "country", how = "left")

# rename columns to reflect source of data
comparison_df.columns = ["country", "unpaid_charmes", "paid_charmes", "paid_oecd", "unpaid_oecd"]

# rearrange the columns to sort alphabetically
comparison_df = comparison_df.reindex(sorted(comparison_df.columns), axis=1)

# calculate the difference between OECD and Charmes paid work time
comparison_df["paid_diff"] = comparison_df["paid_oecd"] - comparison_df["paid_charmes"]

# calculate the difference between the OECD and Charmes unpaid work time
comparison_df["unpaid_diff"] = comparison_df["unpaid_oecd"] - comparison_df["unpaid_charmes"]

# summarize the differences
paid_diff_desc = comparison_df.paid_diff.describe()
unpaid_diff_desc = comparison_df.unpaid_diff.describe()

# calculate the percent difference
comparison_df["paid_pct"] = (comparison_df["paid_diff"]/comparison_df["paid_oecd"])*100
comparison_df["unpaid_pct"] = (comparison_df["unpaid_diff"]/comparison_df["unpaid_oecd"])*100

# drop rows with empty values
comp_df = comparison_df.dropna().reset_index(drop = True)

# calculate the total difference in time use
comp_df["abs_diff"] = abs(comp_df["paid_diff"]) + abs(comp_df["unpaid_diff"])

# summarize the percentage differences
paid_pct_desc = comp_df.paid_pct.describe()
unpaid_pct_desc = comp_df.unpaid_pct.describe()

# create an object that contains the various difference summaries
descs = pd.concat([pd.concat([paid_diff_desc, paid_pct_desc], axis = 1),
                   pd.concat([unpaid_diff_desc, unpaid_pct_desc], axis = 1)], axis = 1)

# %% create a function that maps time use data from regions to countries

# a func
def map_time_use(country):
    """
    For countries without category(ies) of time use data, use regional averages
    to extrapolate.

    Parameters
    ----------
    country : string
        A string containing the name of the country of interest.

    Returns
    -------
    countries_time : data frame
        A data frame containing time use data.

    """
    # make the data frame a global object
    global countries_time
    # if the country does not have OECD data
    if country not in simple_oecd.Country.unique():
        # find the country's WHO region
        who_region = countries_time.loc[countries_time["country"] == country, "WHO_region"].values[0]
        # create a data frame of other countries' time use from the country's WHO region
        who_df = who_time[who_time["WHO_region"] == who_region]
        # find the country's UN region
        un_region = countries_time.loc[countries_time["country"] == country, "UN_region"].values[0]
        # create a data frame of other countries' time use from the country's UN region
        un_df = un_time[un_time["UN_region"] == un_region]
        # if the WHO region doesn't have any entries
        if len(who_df["Time (minutes)"]) < 1:
            # assign the country data from the UN region average
            un_df["country"] = country    
            country_df = pd.merge(countries_time.loc[countries_time["country"] == country, ["country", "UN_region", "WHO_region", "2020 pop"]],
                                  un_df, on = ["country", "UN_region"], how = "left")
            countries_time = pd.concat([countries_time, country_df])
        # but if the WHO regoin does have an entry
        else:
            # assign the country data from the WHO region average
            who_df["country"] = country    
            country_df = pd.merge(countries_time.loc[countries_time["country"] == country, ["country", "UN_region", "WHO_region", "2020 pop"]], who_df, on = ["country", "WHO_region"],
                                 how = "left")
            countries_time = pd.concat([countries_time, country_df])
    # but if the country does have OECD data, there is no need to make an adjustment, so we move on
    else:
        pass
    # return the time use data frame
    return countries_time

# use the function to make sure all countries have all time use categories
for c in countries_time.country.unique():
    time_mapped = map_time_use(c)
    
# simplify the data to only keep the relevant columns
time_mapped = time_mapped[["country", "use", "Time (minutes)", "UN_region", "WHO_region", "2020 pop"]].dropna().sort_values("country").reset_index(drop = True)

# reformat the data from long to wide
countries_wide = pd.pivot(time_mapped, index = ["country", "UN_region", "WHO_region", "2020 pop"], columns = "use", values = "Time (minutes)").reset_index()

# calculate nonmaket time as the combination of unpaid work and leisure time
countries_wide["nonmarket time"] = countries_wide["unpaid work time"] + countries_wide["leisure time"]

# save the file
countries_wide.to_excel("../output/time_use_processed_ihme.xlsx", index = False)

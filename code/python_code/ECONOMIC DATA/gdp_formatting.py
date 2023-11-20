# -*- coding: utf-8 -*-
"""
gdp_formatting.py: Imposes quarterly structure on annual projections. Compares
quarterly projections with quarterly observations and compares annual projections
with annual observations.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 26 January 2023
__updated__ = 15 November 2023

inputs:
    - WEOOct2019all.xlsx (raw file)
    - WEOApr2023all.xlsx (raw file)
    - GDP_quarterly_real_seas_adj.xlsx (raw file)
    - GDP_quarterly_nominal_seas_adj.xlsx (raw file)
    - ihme_countries.xlsx (processed file; created in ihme_portal.py)
    - forex_2010_to_2019_jk.xlsx (processed file; created in forex_only.py)
    
outputs:
    - gdp_gap_ihme.xlsx
    - gdp_usd_ihme.xlsx

"""
# %% load in packages

# pandas and numpy for data management
import pandas as pd
import numpy as np
# sympy and math to solve for variables and to perform some mathematical operations efficiently
from sympy import symbols, Eq, solveset, S
import math

# %% load in data

# weo2019 contains the annual projected GDP.
weo2019 = pd.read_excel("../input/WEOOct2019all.xlsx")
# weo2023 contains the annual actual GDP.
weo2023 = pd.read_excel("../input/WEOApr2023all.xlsx")
# quarterly_real is the quarterly actual GDP in constant prices
quarterly_real = pd.read_excel("../input/GDP_quarterly_real_seas_adj.xlsx", header = 6, index_col = 0).reset_index(drop = True)
# quarterly_nominal is the quarterly actual GDP in current prices
quarterly_nominal = pd.read_excel("../input/GDP_quarterly_nominal_seas_adj.xlsx", header = 6, index_col = 0).reset_index(drop = True)

# %% manipulate the data

# the WEO files contain many indicators for a country. We select two of them: NGDP_R and NGDP.
# these represent real GDP (constant prices) and nominal GDP (current prices), respectively.
weo2019_gdp = weo2019[(weo2019["WEO Subject Code"] == "NGDP_R") | (weo2019["WEO Subject Code"] == "NGDP")]
weo2023_gdp = weo2023[(weo2023["WEO Subject Code"] == "NGDP_R") | (weo2023["WEO Subject Code"] == "NGDP")]

# we add a column to the quarterly data that mimics the notation in the WEO files.
quarterly_real["WEO Subject Code"] = "NGDP_R"
quarterly_nominal["WEO Subject Code"] = "NGDP"

# perform a merge of the two quarterly files and get a list of countries that are not in both.
quarterly_check = quarterly_real[["Country"]].merge(quarterly_nominal[["Country"]], how='left', indicator=True)
quarterly_bad = quarterly_check.loc[quarterly_check["_merge"] != "both", "Country"]

# combine the two quarterly files and remove the countries that are not in both.
# we now have a single quarterly actual GDP file.
quarterly_gdp = pd.concat([quarterly_real, quarterly_nominal])
quarterly_gdp = quarterly_gdp[~quarterly_gdp["Country"].isin(quarterly_bad)]

# the GDP values come in Billions of LCUs. We replace the word "Billions" with "Millions"
# and where the unit is empty (denote by "--"), we set it to NA.
weo2019_gdp = weo2019_gdp.replace({"Billions": "Millions", "--": np.nan})
weo2023_gdp = weo2023_gdp.replace({"Billions": "Millions", "--": np.nan})

# for all GDP values, multiply them by 1000 to get the values from billions to millions.
cols = list(range(1980, 2024))
weo2019_gdp[cols] = weo2019_gdp[cols].mul(1000, fill_value = np.nan)
weo2023_gdp[cols] = weo2023_gdp[cols].mul(1000, fill_value = np.nan)

# some country names differ between files, so we find those differences.
misnomers_quarterly = set(quarterly_gdp.Country.unique()) - set(weo2023_gdp.Country.unique())
# create a dictionary with the format {wrong_name: right_name} to be used to rename countries.
renaming = {"Netherlands, The": "Netherlands", "Kyrgyz Rep.": "Kyrgyzstan", "Serbia, Rep. of": "Serbia",
            "Slovak Rep.": "Slovakia", "Estonia, Rep. of": "Estonia", "China, P.R.: Hong Kong": "Hong Kong",
            "Czech Rep.": "Czechia", "Croatia, Rep. of": "Croatia", "Türkiye, Rep of": "Turkey",
            "Slovenia, Rep. of": "Slovenia", "Poland, Rep. of": "Poland", "Korea, Rep. of": "South Korea",
            "Russian Federation": "Russia", "Moldova, Rep. of": "Moldova", "Czech Republic": "Czechia",
            "Côte d'Ivoire": "Cote d'Ivoire", "Democratic Republic of the Congo": "Democratic Republic of Congo",
            "Hong Kong SAR": "Hong Kong", "Islamic Republic of Iran": "Iran", "Korea": "South Korea",
            "Kyrgyz Republic": "Kyrgyzstan", "Lao P.D.R.": "Laos", "Macao SAR": "Macao", "Republic of Congo": "Congo",
            "Slovak Republic": "Slovakia", "Taiwan Province of China": "Taiwan", "Türkiye": "Turkey", 
            "The Gambia": "Gambia", "Cabo Verde": "Cape Verde"}

# run the renaming dictionary through the all GDP data sets.
weo2019_gdp = weo2019_gdp.replace(renaming)
weo2023_gdp = weo2023_gdp.replace(renaming)
quarterly_gdp = quarterly_gdp.replace(renaming)

quarterly_gdp = quarterly_gdp.groupby('Country').filter(lambda x : len(x) == 2)

# the quarterly GDP data has one entry that is not a country, the "Euro Area", we remove that entry.
quarterly_gdp = quarterly_gdp[quarterly_gdp["Country"] != "Euro Area"]
# when GDP data is missing in the quarterly data, it was assigned "..." by the IMF.
# we replace that syntax with NA.
quarterly_gdp = quarterly_gdp.replace({"...": np.nan})

# %% use Statistics Canada approach to calculate Q4 2020 GDP and then interpolate linearly after that.

def generate_quarterly_projections(country, gdp):
    """
    Interpolates quarterly GDP from annual GDP. Specifically, we use it to input the annual projected GDP
    for countries with quarterly actual GDP. 

    Parameters
    ----------
    country : string
        A string containing the country to generate quarterly GDP for.
    gdp : string
        A string containing the type GDP to draw from (either NGDP_R or NGDP).

    Raises
    ------
    ValueError
        An error message that prints if the quarterly GDP projections for 2019 do not
        sum to the original annual GDP projections. Effectively, it's just a check that
        the Statistics Canada approach retained the overall level of GDP we began with.

    Returns
    -------
    None.

    """
    # get the weo data for 2018 - 2022.
    projected2018 = weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), 2018].values[0]
    projected2019 = weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), 2019].values[0]
    projected2020 = weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), 2020].values[0]
    projected2021 = weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), 2021].values[0]
    projected2022 = weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), 2022].values[0]

    # estimate the annual growth between 2018 and 2019, and 2019 and 2020.
    annualgrowth_19_20 = (projected2020/projected2019) - 1
    annualgrowth_18_19 = (projected2019/projected2018) - 1
    
    # instantiate symbols that will work as mathematical variables
    gA = symbols("gA")
    gB = symbols("gB")
    
    # solve for gA using equation S11
    eq_19_20 = Eq(((annualgrowth_19_20 + 1)*(1 + gA + (gA**2) + (gA**3))) - (gA**4) - (gA**5) - (gA**6) - (gA**7), 0)
    sol_19_20 = list(solveset(eq_19_20, domain = S.Reals))
    # solve for gB using equation S12
    eq_18_19 = Eq(((annualgrowth_18_19 + 1)*(1 + gB + (gB**2) + (gB**3))) - (gB**4) - (gB**5) - (gB**6) - (gB**7), 0)
    sol_18_19 = list(solveset(eq_18_19, domain = S.Reals))
    
    # the solver produces a variety of values that could "solve" the above equations.
    # however, we only want the real and positive value, so we keep that.
    gA = max(sol_19_20)
    gB = max(sol_18_19)
    # calculate an average growth rate, gC, using the geometric mean
    gC = math.sqrt(gA*gB)
    
    # instantiate a symbol that will work as a mathematical variable
    Q1 = symbols("Q1")
    
    # solve for GDP in Q1 of 2019 using equation S13
    eq_2019Q1 = Eq((projected2019/(1 + gC + (gC**2) + (gC**3))) - Q1, 0)
    sol_2019Q1 = list(solveset(eq_2019Q1, domain = S.Reals))
    
    # calculate GDP in quarters 2, 3, and 4 of 2019
    q1_2019 = sol_2019Q1[0]
    q2_2019 = q1_2019*gC
    q3_2019 = q1_2019*(gC**2)
    q4_2019 = q1_2019*(gC**3)
    
    # we calculate the value of annual GDP (the sum of quarterly GDP) in 2019 and ensure
    # that it still equals the annual GDP we started with (within a rounding error)
    gdp2019_projected = sum([q1_2019, q2_2019, q3_2019, q4_2019])
      
    if round(gdp2019_projected) != round(projected2019):
        raise ValueError(f"Summed quarterly projections for {country} in 2019 do not equal the annual total!")
    
    # we define the value of GDP in Q4 of 2019 as x1 and then, using equation S1 - S4,
    # calculate the GDP in each quarter of 2020.
    x1 = q4_2019
    d1 = (projected2020 - 4*x1)/10
    
    q1_2020 = x1 + d1
    q2_2020 = x1 + 2*d1
    q3_2020 = x1 + 3*d1
    q4_2020 = x1 + 4*d1
    
    # we repeat the above process to calculate the GDP in each quarter of 2021 and 2022.
    x2 = q4_2020
    d2 = (projected2021 - 4*x2)/10
    
    q1_2021 = x2 + d2
    q2_2021 = x2 + 2*d2
    q3_2021 = x2 + 3*d2
    q4_2021 = x2 + 4*d2
    
    x3 = q4_2021
    d3 = (projected2022 - 4*x3)/10
    
    q1_2022 = x3 + d3
    q2_2022 = x3 + 2*d3
    q3_2022 = x3 + 3*d3
    q4_2022 = x3 + 4*d3
    
    # we then create a dictionary that links the GDP values in a quarter to its quarterly name.
    quarterly_estimates = {"2019Q1": q1_2019, "2019Q2": q2_2019, "2019Q3": q3_2019, "2019Q4": q4_2019,
                           "2020Q1": q1_2020, "2020Q2": q2_2020, "2020Q3": q3_2020, "2020Q4": q4_2020,
                           "2021Q1": q1_2021, "2021Q2": q2_2021, "2021Q3": q3_2021, "2021Q4": q4_2021,
                           "2022Q1": q1_2022, "2022Q2": q2_2022, "2022Q3": q3_2022, "2022Q4": q4_2022}
    
    # we use the dictionary to fill in the values of projected quarterly data.
    for key, value in quarterly_estimates.items():
        weo2019_gdp.loc[(weo2019_gdp["Country"] == country) & (weo2019_gdp["WEO Subject Code"] == gdp), key] = value

# we run the above function for all countries and for both the nominal and real GDP estimates.
for c in quarterly_gdp["Country"].unique():
    for g in ["NGDP", "NGDP_R"]:
        generate_quarterly_projections(c, g)

# %% combine quarterly and annual actual and projected GDP into a single data set.

# get a list of quarters that we have new quarterly projections for and remove Q4 of 2022, since we don't
# have actual data for that quarter.
quarters = [col for col in weo2019_gdp.columns if "Q" in str(col)]
quarters.remove("2022Q4")

# create a data set of just the newly created quarterly projections that is in long format.
weo2019_q = weo2019_gdp.reset_index()
weo2019_q = pd.melt(weo2019_q, id_vars = ["Country", "WEO Subject Code", "Scale"],
                       value_vars = quarters)

# remove any country-quarters that are without data.
weo2019_q = weo2019_q.dropna()

# take the quarterly actual GDP and create an analogous long format data.
quarterly_long = quarterly_gdp.reset_index()
quarterly_long = pd.melt(quarterly_long, id_vars = ["Country", "WEO Subject Code", "Scale"],
                       value_vars = quarters)

# add a column that indicates whether the data is projected or observed (actual)
weo2019_q["source"] = "projected"
quarterly_long["source"] = "observed"

# combine the projected and actual quarterly data into a single data set
combined_quarterly = pd.concat([weo2019_q, quarterly_long])
combined_quarterly = combined_quarterly[["Country", "WEO Subject Code", "variable", "value", "source"]]

# perform some data maintenance: make date a categorical variable, sort by country and date,
# make sure the GDP value (value) a float, and create a year column.
combined_quarterly['date'] = pd.Categorical(combined_quarterly['variable'], quarters)
combined_quarterly = combined_quarterly.sort_values(by = ["Country", "date"]).reset_index(drop = True)
combined_quarterly["value"] = combined_quarterly["value"].astype(float)
combined_quarterly["year"] = combined_quarterly["date"].str[:-2]

# create an annual projected GDP data that contains only the countries that don't have quarterly data.
weo2019_annual = weo2019_gdp[~(weo2019_gdp["Country"].isin(combined_quarterly["Country"].unique()))]

# make that data long format
weo2019_annual = pd.melt(weo2019_annual, id_vars = ["Country", "WEO Subject Code", "Scale"],
                       value_vars = [2019, 2020, 2021, 2022])
# note that it is projected
weo2019_annual["source"] = "projected"

# do the same with the annual actual data
weo2023_annual = weo2023_gdp[(weo2023_gdp["Country"].isin(weo2019_annual["Country"].unique()))]

weo2023_annual = pd.melt(weo2023_annual, id_vars = ["Country", "WEO Subject Code", "Scale"],
                       value_vars = [2019, 2020, 2021, 2022])

weo2023_annual["source"] = "observed"

# combine the annual data into a single data set
weo_annual = pd.concat([weo2019_annual, weo2023_annual])
weo_annual = weo_annual[["Country", "WEO Subject Code", "variable", "value", "source"]]
weo_annual = weo_annual.sort_values(by = ["Country", "variable"]).reset_index(drop = True)
weo_annual["value"] = weo_annual["value"].astype(float)
weo_annual["type"] = "annual"
combined_quarterly["type"] = "quarterly"
# combine the quarterly and annual data into a single data set
combined_quarterly_annual = pd.concat([combined_quarterly[["Country", "WEO Subject Code", "variable", "value", "source", "type"]], weo_annual[["Country", "WEO Subject Code", "variable", "value", "source", "type"]]])

# %% Rebasing

# create a second data set, just to work with without disruptin the original
combined_df = combined_quarterly_annual.copy()
# create an empty data set with all the necessary columns but without any data
rebased_df = pd.DataFrame(columns = ["country", "date", "Real GDP", "source", "type", "ratio"])

def rebase_annual_gdp(country):
    """
    Rebases the annual actual and projected GDP to a common base year of 2019.

    Parameters
    ----------
    country : string
        A string describing the country whose GDP is to be rebased.

    Returns
    -------
    None.

    """
    global rebased_df
    # extract the values of nominal and real projected GDP in 2019, and calculate their ratio.
    nom_gdp_proj = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP") &
                         (combined_df["source"] == "projected") & (combined_df["variable"] == 2019), "value"].values[0]  
    real_gdp_proj = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "projected") & (combined_df["variable"] == 2019), "value"].values[0]     
    ratio_proj = nom_gdp_proj/real_gdp_proj
    # extract the values of nominal and real actual GDP in 2019, and calculate their ratio.
    nom_gdp_obs = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP") &
                         (combined_df["source"] == "observed") & (combined_df["variable"] == 2019), "value"].values[0]  
    real_gdp_obs = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "observed") & (combined_df["variable"] == 2019), "value"].values[0]     
    ratio_obs = nom_gdp_obs/real_gdp_obs
    # get all values of real projected GDP in our study period
    gdp_proj_og = combined_df[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "projected")].reset_index(drop = True)    
    # get all values of real actual GDP in our study period
    gdp_obs_og = combined_df[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "observed")].reset_index(drop = True)    
    # for each real projected GDP value, rebase it using the projected GDP ratio calculated above
    # and fill in the empty rebased data frame
    for i in range(len(gdp_proj_og)):
        _date = gdp_proj_og.loc[i, "variable"]
        _real_gdp = gdp_proj_og.loc[i, "value"]*ratio_proj
        _source = gdp_proj_og.loc[i, "source"]
        _type = gdp_proj_og.loc[i, "type"]
        rebase = pd.DataFrame([[country, _date, _real_gdp, _source, _type, ratio_proj]],
                              columns = ["country", "date", "Real GDP", "source", "type", "ratio"])
        rebased_df = pd.concat([rebased_df, rebase])
    # do the same for the actual data
    for j in range(len(gdp_obs_og)):
        _date2 = gdp_obs_og.loc[j, "variable"]
        _real_gdp2 = gdp_obs_og.loc[j, "value"]*ratio_obs
        _source2 = gdp_obs_og.loc[j, "source"]
        _type2 = gdp_obs_og.loc[j, "type"]
        rebase2 = pd.DataFrame([[country, _date2, _real_gdp2, _source2, _type2, ratio_obs]],
                              columns = ["country", "date", "Real GDP", "source", "type", "ratio"])
        rebased_df = pd.concat([rebased_df, rebase2])

# get a list of countries whose GDP data is annual
ann_countries = combined_df[combined_df["type"] == "annual"].Country.unique()
# do the same for quarterly
q_countries = combined_df[combined_df["type"] == "quarterly"].Country.unique()

# now for every country whose data is annual, rebase to 2019.
for c in ann_countries:
    rebase_annual_gdp(c)

# see comments in the annual function above
def rebase_quarterly_gdp(country):
    """
    Rebases the quarterly actual and projected GDP to a common base year of 2019.

    Parameters
    ----------
    country : string
        A string describing the country whose GDP is to be rebased.

    Returns
    -------
    None.

    """
    global rebased_df
    nom_gdp_proj = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP") &
                         (combined_df["source"] == "projected") & (combined_df["variable"].str.contains ("2019")),
                         "value"].mean() 
    real_gdp_proj = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "projected") & (combined_df["variable"].str.contains ("2019")),
                         "value"].mean()     
    ratio_proj = nom_gdp_proj/real_gdp_proj
    nom_gdp_obs = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP") &
                         (combined_df["source"] == "observed") & (combined_df["variable"].str.contains ("2019")),
                         "value"].mean() 
    real_gdp_obs = combined_df.loc[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "observed") & (combined_df["variable"].str.contains ("2019")),
                         "value"].mean()     
    ratio_obs = nom_gdp_obs/real_gdp_obs
    gdp_proj_og = combined_df[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "projected")].reset_index(drop = True)     
    gdp_obs_og = combined_df[(combined_df["Country"] == country) & (combined_df["WEO Subject Code"] == "NGDP_R") &
                         (combined_df["source"] == "observed")].reset_index(drop = True)    
    for i in range(len(gdp_proj_og)):
        _date = gdp_proj_og.loc[i, "variable"]
        _real_gdp = gdp_proj_og.loc[i, "value"]*ratio_proj
        _source = gdp_proj_og.loc[i, "source"]
        _type = gdp_proj_og.loc[i, "type"]
        rebase = pd.DataFrame([[country, _date, _real_gdp, _source, _type, ratio_proj]],
                              columns = ["country", "date", "Real GDP", "source", "type", "ratio"])
        rebased_df = pd.concat([rebased_df, rebase])
    for j in range(len(gdp_obs_og)):
        _date2 = gdp_obs_og.loc[j, "variable"]
        _real_gdp2 = gdp_obs_og.loc[j, "value"]*ratio_obs
        _source2 = gdp_obs_og.loc[j, "source"]
        _type2 = gdp_obs_og.loc[j, "type"]
        rebase2 = pd.DataFrame([[country, _date2, _real_gdp2, _source2, _type2, ratio_obs]],
                              columns = ["country", "date", "Real GDP", "source", "type", "ratio"])
        rebased_df = pd.concat([rebased_df, rebase2])
  
# for every country with quarterly data, perform the rebasing
for c2 in q_countries:
    rebase_quarterly_gdp(c2)

# just do some basic data maintenance
rebased_df = rebased_df.reset_index(drop = True)
rebased_df["date"] = rebased_df["date"].astype(str)   
rebased_df["year"] = rebased_df["date"].str[:4].astype(str)

# save the file.
# rebased_df.to_excel("../output/rebased_gdp.xlsx", index = False)

# select only the quarterly data and write it to its own file.
quarterly_rebased = rebased_df[rebased_df["type"] == "quarterly"]
quarterly_rebased = quarterly_rebased.drop(columns = "ratio")
quarterly_rebased["quarter"] = quarterly_rebased['date'].str.strip().str[-1]
# quarterly_rebased.to_excel("../output/quarterly_gdp_processed.xlsx", index = False)

# select only the annual data, assign it pseudo-quarterly values by dividing the 
# annual GDP by 4. Write it to its own file.
annual_rebased = rebased_df[rebased_df["type"] == "annual"]
annual_rebased = annual_rebased.drop(columns = "ratio")
annual_rebased = annual_rebased.loc[annual_rebased.index.repeat(4)].reset_index(drop = True)
annual_rebased["quarter"] = list(range(1,5))*(1120)
annual_rebased["date"] = annual_rebased["year"].astype(str) + "Q" + annual_rebased["quarter"].astype(str)
annual_rebased["Real GDP"] = annual_rebased["Real GDP"]/4
# annual_rebased.to_excel("../output/annual_gdp_processed.xlsx", index = False)

# combine the quarterly and annual data into a single analytical file where the unit
# of analysis is the country-quarter.
ann_quart_rebased = pd.concat([quarterly_rebased, annual_rebased])
ann_quart_rebased["quarter"] = ann_quart_rebased["quarter"].astype(int)
# ann_quart_rebased.to_excel("../output/annual_quarterly_gdp_processed.xlsx", index = False)
# %% check the number of countries

# load in the data with all relevant IHME countries
ihme_countries = pd.read_excel("../output/ihme_countries.xlsx")

# only keep the countries that are in our IHME data
gdp_ihme = ann_quart_rebased[ann_quart_rebased.country.isin(ihme_countries[0].unique())]

# calculate the GDP gap
gdp_gap = gdp_ihme.pivot(index = ['country', 'date', 'type'], columns = 'source', values = 'Real GDP').reset_index()
gdp_gap = gdp_gap.rename(columns = {"observed": "observed_millions_of_lcus", "projected": "projected_millions_of_lcus"})
gdp_gap["gdp_gap"] = gdp_gap["observed_millions_of_lcus"]/gdp_gap["projected_millions_of_lcus"]

# remove any countries who have no data at all in the shortfall column
gdp_gap = gdp_gap.groupby('country').filter(lambda group: group.gdp_gap.sum()>0)

# create a variable that distinguishes between the annual and quarterly data
gdp_gap_ann_countries = gdp_gap[gdp_gap["type"] == "annual"]
gdp_gap_qrt_countries = gdp_gap[gdp_gap["type"] == "quarterly"]

# check how many countires are in each sample
len(gdp_gap_ann_countries.country.unique())
len(gdp_gap_qrt_countries.country.unique())

# save the file
gdp_gap.to_excel("../output/gdp_gap_ihme.xlsx", index = False)

# %% calculate GDP losses in USD

# load in the foreign exchange rates
forex = pd.read_excel("../output/forex_2010_to_2019_jk.xlsx")

# since data are in millions of LCUs, multiply them by 1 million
gdp_gap["observed_lcus"] = gdp_gap["observed_millions_of_lcus"]*1000000
gdp_gap["projected_lcus"] = gdp_gap["projected_millions_of_lcus"]*1000000

# merge the foreign exchange data to the GDP gap data
gdp_forex = gdp_gap.merge(forex[["country", "forex_2019"]], on = "country", how = "left")

# divide by the foreign exchange rate to get everything into 2019 USD.
gdp_forex["gdp_projected_usd"] = gdp_forex["projected_lcus"]/gdp_forex["forex_2019"]
gdp_forex["gdp_observed_usd"] = gdp_forex["observed_lcus"]/gdp_forex["forex_2019"]

# calculate the absolute loss
gdp_forex["loss"] = gdp_forex["gdp_projected_usd"] - gdp_forex["gdp_observed_usd"]

# if there are any missing values in the GDP gaps, drop them.
gdp_forex = gdp_forex.dropna(subset=["gdp_gap"], how='all')

# save the file.
gdp_forex.to_excel("../output/gdp_usd_ihme.xlsx", index = False)

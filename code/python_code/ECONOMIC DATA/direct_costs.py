# -*- coding: utf-8 -*-
"""
direct_costs.py: Calculates direct costs of COVID infection.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 14 April 2023
__updated__ = 15 November 2023

inputs:
    - who_choice_2010.xlsx (raw file)
    - national_population_2020_2021_2022.xlsx (processed file; created in ihme_portal.py)
    - ihme_countries.xlsx (processed file; created in ihme_portal.py)
    - master_country_list.xlsx (processed file; created in Excel)
    - forex_2010_to_2019_jk (processed file; created in forex_only.py)
    - P_Data_Extract_From_World_Development_Indicators-GDP deflators.xlsx (raw file)
    - WEOOct2019all.xlsx (raw file)
    - wdi_ihme_country_match.dta (processed file; created in wdi_ihme_country_match.do)
    - Historical-and-Projected-Covid-19-data.csv (raw file)
    - WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx (raw file)

outputs:
    - direct_costs_jk.xlsx
    
"""

# %% load in the required libraries
import pandas as pd
import numpy as np

# %% load in the data

#load in inpatient and outpatient costs
inpatient = pd.read_excel("../input/who_choice_2010.xlsx", sheet_name="bed_day_USD", usecols="A:D", skiprows=3)
outpatient = pd.read_excel("../input/who_choice_2010.xlsx", sheet_name="outpatient_USD", usecols="A:B", skiprows=3)

#merge inpatient and outpatient costs to a single file
whochoice = inpatient.merge(outpatient, how = "outer", on = "Region/Country")
#rename columns to more usable values
whochoice = whochoice.rename(columns={"Health Centre (no beds)": "cost_per_day_mild",
                                      "Primary Hospital": "cost_per_day_severe",
                                      "Tertiary Hospital": "cost_per_day_critical",
                                      "Region/Country": "country"})

#replace NA with empty string
whochoice["cost_per_day_mild"] = whochoice["cost_per_day_mild"].replace("NA", "")
whochoice["cost_per_day_severe"] = whochoice["cost_per_day_severe"].replace("NA", "")
whochoice["cost_per_day_critical"] = whochoice["cost_per_day_critical"].replace("NA", "")

#convert costs to numeric
whochoice["cost_per_day_mild"] = pd.to_numeric(whochoice["cost_per_day_mild"], errors="coerce")
whochoice["cost_per_day_severe"] = pd.to_numeric(whochoice["cost_per_day_severe"], errors="coerce")
whochoice["cost_per_day_critical"] = pd.to_numeric(whochoice["cost_per_day_critical"], errors="coerce")

#remove secondary hospitals and drop empty rows
whochoice = whochoice.drop(columns=["Secondary Hospital"]).dropna()

#replace country names with authors' preferred versions
whochoice["country"] = whochoice["country"].replace({
    "United Republic of Tanzania": "Tanzania",
    "Swaziland": "Eswatini",
    "Micronesia (Federated States of)": "Micronesia (country)",
    "Lao People's Democratic Republic": "Laos",
    "Bolivia Plurinational States of": "Bolivia",
    "Cabo Verde Republic of": "Cape Verde",
    "Czech Republic": "Czechia",
    "Côte d'Ivoire": "Cote d'Ivoire",
    "Curaçao": "Curacao",
    "Macau, China": "Macao",
    "Moldova, Republic of": "Moldova",
    "Occupied Palestinian Territory": "Palestine",
    "Russian Federation": "Russia",
    "Korea, Republic of": "South Korea",
    "Democratic People's Republic of Korea": "North Korea",
    "Türkiye": "Turkey",
    "Viet Nam": "Vietnam",
    "Hong Kong, China": "Hong Kong",
    "Taiwan, China": "Taiwan",
    "Iran, Islamic Republic of": "Iran",
    "Brunei Darussalam": "Brunei",
    "Democratic Republic of the Congo": "Democratic Republic of Congo",
    "Republic of Korea": "South Korea",
    "Iran (Islamic Republic of)": "Iran",
    "Republic of Moldova": "Moldova",
    "The former Yugoslav Republic of Macedonia": "North Macedonia",
    "Syrian Arab Republic": "Syria",
    "United States of America": "United States",
    "Venezuela (Bolivarian Republic of)": "Venezuela"
})

#add year column and set it to 2020
whochoice["year"] = 2020

#merge WHO CHOICE data with population data
pop = pd.read_excel("../output/national_population_2020_2021_2022.xlsx")
pop = pop.drop_duplicates(subset = "country")
whochoice = whochoice.merge(pop[["country", "tot_pop"]], how="left", on="country")

#drop countries with population <=1M
whochoice = whochoice.dropna(subset=["tot_pop"])
whochoice = whochoice[whochoice["tot_pop"] >= 1000000]

#merge with relevant countries data
countries = pd.read_excel("../output/ihme_countries.xlsx")
countries = countries.rename(columns = {0: "country"})
whochoice = whochoice.merge(countries, on = "country", how = "outer")

#merge with regions
regions = pd.read_excel("../input/master_country_list.xlsx", sheet_name = "master_list")
whochoice = whochoice.merge(regions[["country", "WHO_region",
                                     "WB_income_group_1"]], on = "country",
                            how = "left")

#assign a region for countries without it
whochoice.loc[whochoice["country"].isin(["Hong Kong", "Taiwan", "Macao"]),
              "WHO_region"] = "WPRO"

whochoice.loc[(whochoice["country"] == "Palestine"), "WHO_region"] = "EMRO"
whochoice.loc[(whochoice["country"] == "Puerto Rico"), "WHO_region"] = "AMRO"

whochoice.loc[whochoice["country"].isin(["Hong Kong", "Taiwan", "Macao", "Puerto Rico"]),
              "WB_income_group_1"] = "High Income"

whochoice.loc[(whochoice["country"] == "Palestine"), "WB_income_group_1"] = "Middle Income"

#create a dictionary to rename income groups to an abbreviation
inc_dict = {"High Income": "HIC", "Middle Income": "MIC", "Low income": "LIC"}

#create a new income group variable using the abbreviation
whochoice["inc"] = whochoice["WB_income_group_1"].replace(inc_dict)    

#classify countries by the intersection of their region and income group.
whochoice["who_income"] = whochoice["WHO_region"].astype(str) + "_" + whochoice["inc"].astype(str)

#remove Djibouti
whochoice = whochoice[whochoice["country"] != "Djibouti"]

#load in foreign exchange rates data
forex = pd.read_excel("../output/forex_2010_to_2019_jk.xlsx")
forex2010 = forex[["country", "forex_2010"]]

#merge WHO CHOICE data with foreign exchange rates data
whochoice = whochoice.merge(forex2010, on = "country", how = "left")

#convert WHO CHOiCE prices from 2010 LCUs to 2010 USDs.
whochoice["mild_2010_lcus"] = whochoice["cost_per_day_mild"]*whochoice["forex_2010"]
whochoice["severe_2010_lcus"] = whochoice["cost_per_day_severe"]*whochoice["forex_2010"]
whochoice["critical_2010_lcus"] = whochoice["cost_per_day_critical"]*whochoice["forex_2010"]

#load in GDP deflators
deflators = pd.read_excel("../input/P_Data_Extract_From_World_Development_Indicators-GDP deflators.xlsx")
deflators = deflators[deflators["Series Name"] == "GDP deflator (base year varies by country)"].rename(
    columns = {"Country Name": "country"})

#keep country names and year-specific deflator values. 
deflators = deflators[["country"] + [col for col in deflators.columns if "[YR" in col]]
deflators.columns = deflators.columns.str.split(' ', 1).str[0]
deflators = deflators.replace("..", np.nan)

#replace country names with author preferred versions.
deflators = deflators.replace({'Cabo Verde': 'Cape Verde',
    'Congo, Rep.': 'Congo',
    'Congo, Dem. Rep.': 'Democratic Republic of Congo',
    'Faroe Islands': 'Faeroe Islands',
    'Gambia, The': 'Gambia',
    'Hong Kong SAR, China': 'Hong Kong',
    "Korea, Dem. People's Rep.": 'North Korea',
    'Korea, Rep.': 'South Korea',
    'Kyrgyz Republic': 'Kyrgyzstan',
    'Lao PDR': 'Laos',
    'Macao SAR, China': 'Macao',
    'Micronesia, Fed. Sts.': 'Micronesia (country)',
    'Slovak Republic': 'Slovakia',
    'St. Kitts and Nevis': 'Saint Kitts and Nevis',
    'St. Lucia': 'Saint Lucia',
    'St. Martin (French part)': 'Saint Martin (French part)',
    'St. Vincent and the Grenadines': 'Saint Vincent and the Grenadines',
    'Turkiye': 'Turkey',
    'Venezuela, RB': 'Venezuela',
    'Yemen, Rep.': 'Yemen',
    'Egypt, Arab Rep.': 'Egypt',
    'West Bank and Gaza': 'Palestine',
    'Brunei Darussalam': 'Brunei',
    'Russian Federation': 'Russia',
    'Syrian Arab Republic': 'Syria',
    'Iran, Islamic Rep.': 'Iran'})

# Syria doesn't have a full set of deflators, so we assign the 2018 deflator to be the best proxy of the 2019 deflator
deflators.loc[deflators["country"] == "Syria", "2019"] = deflators.loc[deflators["country"] == "Syria", "2018"].values[0]

# simplify the data to only contain the country and 2010 and 2019 deflators, and rename the columns
deflators = deflators[["country", "2010", "2019"]].rename(columns = {"2010": "deflator_2010",
                                                                     "2019": "deflator_2019"})

# merge the WHO CHOICE costs with the deflator data
whochoice = whochoice.merge(deflators, on = "country", how = "left")

# find the countries who don't have deflator data for 2010 or 2019.
countries_needed = whochoice.loc[(whochoice["deflator_2010"].isna()) | (whochoice["deflator_2019"].isna()), 'country'].values

# read in the World Economic Outlook data from the end of 2019.
other_deflators = pd.read_excel("../input/WEOOct2019all.xlsx")
# keep the rows that contain GDP deflators
other_deflators = other_deflators[other_deflators["Subject Descriptor"] =="Gross domestic product, deflator"]
# Rename Taiwan to author-preferred name
other_deflators = other_deflators.replace({"Taiwan Province of China": "Taiwan"})
# retain the entries that pertain to countries without a full set of deflators from WDI
other_deflators = other_deflators[other_deflators["Country"].isin(countries_needed)]
# simplify the data to contain country name and select years of deflators
other_deflators = other_deflators[["Country", 2010, 2011, 2012, 2017, 2018, 2019]].rename(
    columns = {"Country": "country"})
# find the countries that don't have 2010 deflators in WEO data
missing2010 = other_deflators.loc[other_deflators[2010].isna(), 'country'].values
# find the countries that don't have 2019 deflators in WEO data
missing2019 = other_deflators.loc[other_deflators[2019].isna(), 'country'].values

# if a country doesn't have a 2010 deflator, assign it the 2011 deflator value
for country in missing2010:
    other_deflators.loc[other_deflators["country"] == country, 2010] = (
        other_deflators.loc[other_deflators["country"] == country, 2011].values[0])

# if a country doesn't have a 2019 deflator, assign it the 2018 deflator value
for country in missing2019:
    other_deflators.loc[other_deflators["country"] == country, 2019] = (
        other_deflators.loc[other_deflators["country"] == country, 2018].values[0])    

# simplify the data frame to keep only the country name, 2010 and 2019 deflators and rename the columns
other_deflators = other_deflators[["country", 2010, 2019]]
other_deflators = other_deflators.rename(columns = {2010: "deflator_2010", 2019: "deflator_2019"})

# for countries without WDI deflators
for country in countries_needed:
    try:   
        # if the country doesn't have a 2010 deflator, assign it the 2010 deflator from WEO
        if np.isnan(whochoice.loc[whochoice["country"] == country,  "deflator_2010"].values[0]):
            whochoice.loc[whochoice["country"] == country,  "deflator_2010"] = (
                other_deflators.loc[other_deflators["country"] == country, "deflator_2010"].values[0])
        # but if the country does have a deflator from WDI, do nothing
        else:
            pass
        # if the country doesn't have a 2019 deflator, assign it the 2019 deflator from WEO
        if np.isnan(whochoice.loc[whochoice["country"] == country,  "deflator_2019"].values[0]):
            whochoice.loc[whochoice["country"] == country,  "deflator_2019"] = (
                other_deflators.loc[other_deflators["country"] == country, "deflator_2019"].values[0])
        # but if the country does have a deflator from WDI, do nothing
        else:
            pass
    # if there is an exception (i.e., error) for a country, just skip it.
    except:
        continue

# calculate the deflator conversion factor
whochoice["conversion_factor"] = whochoice["deflator_2019"]/whochoice["deflator_2010"]

# convert 2010 WHO choice costs in LCUs to 2019 values
whochoice["mild_2019_lcus"] = whochoice["mild_2010_lcus"]*whochoice["conversion_factor"]
whochoice["severe_2019_lcus"] = whochoice["severe_2010_lcus"]*whochoice["conversion_factor"]
whochoice["critical_2019_lcus"] = whochoice["critical_2010_lcus"]*whochoice["conversion_factor"]

# load in the foreign exchange data (see forex.py for details)
forex = pd.read_excel("../output/forex_2010_to_2019_jk.xlsx")
# simplify the forex data to only contain the country name and 2019 foreign exchange rate
forex2019 = forex[["country", "forex_2019"]]

# merge WHO CHOICE data with foreign exchange data
whochoice = whochoice.merge(forex2019, on = "country", how = "left")

# convert 2019 LCUs to 2019 using 2019 foreign exchange rates
whochoice["mild_2019_usd"] = whochoice["mild_2019_lcus"]/whochoice["forex_2019"]
whochoice["severe_2019_usd"] = whochoice["severe_2019_lcus"]/whochoice["forex_2019"]
whochoice["critical_2019_usd"] = whochoice["critical_2019_lcus"]/whochoice["forex_2019"]

# read in WDI GDP
gdp = pd.read_stata("../input/wdi_ihme_country_match.dta")
# merge WHO CHOICE data with the WDI GDP
whochoice = whochoice.merge(gdp[["country", "yr2019_pcgdp_current_2019USD"]],
                            on = "country", how = "left")

# rename the 2019 PCGDP column for ease of use
whochoice = whochoice.rename(columns = {"yr2019_pcgdp_current_2019USD": "pcgdp"})

# create two empty columns to be used for extrapolating direct costs
whochoice["match"] = np.nan
whochoice["ratio"] = np.nan
# create a data frame that only contains complete data 
whochoice_complete = whochoice.dropna(subset=["mild_2019_usd", "severe_2019_usd",
                                              "critical_2019_usd", "pcgdp"],
                             how = 'any').reset_index(drop = True)

# create a function that maps direct costs 
def map_direct_df(country):
    """
    Map direct costs to a country without direct cost data.

    Parameters
    ----------
    country : string
        A string containing the name of the country of interest.

    Returns
    -------
    whochoice : data frame
        A data frame that contains direct cost data for all countries.

    """
    # find the WHO Region - World Bank Income Group of the country
    whoincome = whochoice.loc[whochoice["country"] == country, "who_income"].values[0]
    # create a data frame of countries in that region-income group.
    whoinc_df = whochoice_complete[whochoice_complete["who_income"] == whoincome].reset_index(drop = True)
    # create a data frame that only has the country of interest
    country_df = whochoice[whochoice["country"] == country]
    # if the country doesn't have WHO CHOICE data
    if np.isnan(country_df.loc[:, "critical_2019_usd"].values[0]):
        # extract the country's per capita GDP
        pcgdp = country_df["pcgdp"].values[0]
        # if the country also doesn't have per capita GDP, just skip it
        if np.isnan(pcgdp):
            pass
        # but if it does have pcgdp
        else:
            # get an array of PCGDP of countries in the same region-income group.
            whoinc_pcgdp = np.array(whoinc_df.loc[:, "pcgdp"])
            # calculate the difference between the country of interest's pcgdp and 
            # the region-income group countries' pcgdp
            pcgdp_diff = np.absolute(whoinc_pcgdp - pcgdp)
            # find the value where the difference is the smallest (i.e., closest pcgdp to the country of interest)
            index_val = pcgdp_diff.argmin()
            # get the name of the country that has the most similar pcgdp
            mapping_country = whoinc_df.loc[index_val, "country"]
            # get the pcgdp value of that country
            pcgdp_mapping = whoinc_df.loc[whoinc_df["country"] == mapping_country, "pcgdp"].values[0]
            # take the ratio of the pcgdp of the mapping country and the country of interest
            ratio = pcgdp/pcgdp_mapping
            # note which country was used to map in the direct costs data
            whochoice.loc[whochoice["country"] == country, "match"] = mapping_country
            # add the pcgdp ratio to the data
            whochoice.loc[whochoice["country"] == country, "ratio"] = ratio
            # for mild, severe, and critical direct costs, assign them to be the value of 
            # mapping country, scaled for the ratio of pcgdp
            whochoice.loc[whochoice["country"] == country, "mild_2019_usd": "critical_2019_usd"] = (
                whochoice.loc[whochoice["country"] == mapping_country,
                              "mild_2019_usd": "critical_2019_usd"].values)*ratio
    # but if the country does have WHO CHOICE data
    else:
        # do nothing
        pass
    # return the direct costs data
    return whochoice
    
# for all the countries in our data, perform the utility mapping
for c in whochoice.country.unique():
    whochoice = map_direct_df(c)    

# simplify the data to only have the country name, region-income group, and direct costs in 2019USD
direct_df = whochoice[["country", "who_income", "mild_2019_usd","severe_2019_usd", "critical_2019_usd"]]

# %% establish health states

# load in population data
popdata = pd.read_excel("../output/national_population_2020_2021_2022.xlsx")

# load in the IHME COVID-19 projections data
ihmeraw = pd.read_csv("../input/Historical-and-Projected-Covid-19-data.csv")
ihme = ihmeraw[ihmeraw["version_name"] == "reference"]

# create a list of the relevant columns to keep
keep_cols = ["date", "location_name", "inf_mean", "inf_cuml_mean",
             "cumulative_deaths", "daily_deaths", "admis_mean", "icu_beds_mean"]

# only keep the relevant columns
ihme = ihme[keep_cols]

# rename countries to author-preferred versions
ihme = ihme.replace({'Taiwan (Province of China)': 'Taiwan', 'Viet Nam': 'Vietnam',
 'Republic of Moldova': 'Moldova', 'Russian Federation': 'Russia',
 'Republic of Korea': 'South Korea', 'United States of America': 'United States',
 'Bolivia (Plurinational State of)': 'Bolivia', 'Venezuela (Bolivarian Republic of)': 'Venezuela',
 'Iran (Islamic Republic of)': 'Iran', 'Syrian Arab Republic': 'Syria',
 'Türkiye': 'Turkey', 'Democratic Republic of the Congo': 'Democratic Republic of Congo',
 "Côte d'Ivoire": "Cote d'Ivoire", "Cabo Verde": "Cape Verde", "United Republic of Tanzania": "Tanzania",
 "Timor": "Timor-Leste", "Micronesia (Federated States of)": "Micronesia",
 "Lao People's Democratic Republic": "Laos", "Democratic People's Republic of Korea": "North Korea",
 "Hong Kong Special Administrative Region of China": "Hong Kong", "Macao Special Administrative Region of China": "Macao"})

# simplify column name to just "country"
ihme = ihme.rename(columns = {"location_name": "country"})

# make sure python interprets the year and quarter variables as datetime variables
ihme["year"] =  pd.to_datetime(ihme['date']).dt.year
ihme["quarter"] =  pd.to_datetime(ihme['date']).dt.quarter

# sort the data
ihme = ihme.sort_values(["country", "year", "quarter", "date"])

# remove data after Q2 2022
ihme = ihme[ihme["date"] < "2022-07-01"]

# merge population data to the IHME data and only keep countries with population > 1M
ihme_df = ihme.merge(popdata, on = ["country", "year"], how = "left")
ihme_1m = ihme_df[(ihme_df["tot_pop"] >= 1000000) | (ihme_df["country"] == "Macao")]

# set the first entry of infections and deaths to the cumulative value.
death_df = ihme_1m[ihme_1m['daily_deaths'].notna()]
inf_df = ihme_1m[ihme_1m['inf_mean'].notna()]
for c in ihme_1m.country.unique():
    first_deaths = death_df.loc[death_df["country"] == c, "date"].min()
    first_infs = inf_df.loc[inf_df["country"] == c, "date"].min()
    ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "daily_deaths"] = ihme_1m.loc[(ihme_1m["date"] == first_deaths) & (ihme_1m["country"] == c), "cumulative_deaths"]
    ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_mean"] = ihme_1m.loc[(ihme_1m["date"] == first_infs) & (ihme_1m["country"] == c), "inf_cuml_mean"]

# create a list of the epidemiologicla numeric columns
numerics = ['int16', 'int32', 'int64', 'float16', 'float32', 'float64']
epi_cols = list(set(ihme_1m.select_dtypes(include=numerics).columns) - set(["year", "quarter", "yyyy_qq", "tot_pop",
                                                                            "infection_fatality"]))

# extrapolate data for China based on Macao and Hong Kong (see ihme_portal.py for details)
mc_hk = ihme_1m[ihme_1m["country"].isin(["Macao", "Hong Kong"])]
mc_hk = mc_hk.groupby("date")[epi_cols].sum()
china =  ihme_1m[ihme_1m["country"] == "China"].set_index("date")
china = china[epi_cols]
china_update = china.subtract(mc_hk, level=0)
china_update = china_update.reset_index()
china_update["country"] = "China"
china_update = china_update.merge(ihme_df, on = ["country", "date"], how = "left")
china_update = china_update.loc[:,~china_update.columns.str.contains('_y')] 
china_update.columns = china_update.columns.str.replace(r'_x$', '')

ihme_1m = ihme_1m[ihme_1m["country"] != "China"]
ihme_1m = pd.concat([ihme_1m, china_update], axis = 0)

##collapse infections and deaths to the country-quarter level
ihme_q = ihme_1m[["date", "country", "year", "quarter", "inf_cuml_mean", "inf_mean",
                  "cumulative_deaths", "daily_deaths", "admis_mean", "icu_beds_mean", "tot_pop"]]

# make sure python interprets the date as a datetime variable and sort the data
ihme_q["date"] =  pd.to_datetime(ihme_q['date'])
ihme_q = ihme_q.sort_values(["country", "year", "quarter", "date"])

# create a year-quarter variable
ihme_q["yyyy_qq"] = ihme_q["year"].astype(str) + "_Q" + ihme_q["quarter"].astype(str)

# drop Macao (population below 1M) and Djibouti (incomplete data)
ihme_q = ihme_q[(ihme_q["country"] != "Macao") & (ihme_q["country"] != "Djibouti")]

# for countries whose deaths data end in the middle of a quarter, extrapolate to 
# the end of the quarter (see ihme_portal.py for details)
death_df["month"] =  pd.to_datetime(death_df['date']).dt.month
kazakh_extrap = death_df.loc[(death_df["country"] == "Kazakhstan") & (death_df["year"] == 2021) &
                             (death_df["month"] == 9), "daily_deaths"].mean()

ihme_q.loc[(ihme_q["country"] == "Kazakhstan") & (ihme_q["year"] == 2021) &
                             (ihme_q["quarter"] == 3) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = kazakh_extrap

kyrgyz_extrap = death_df.loc[(death_df["country"] == "Kyrgyzstan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 3), "daily_deaths"].mean()

ihme_q.loc[(ihme_q["country"] == "Kyrgyzstan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = kyrgyz_extrap

uzbek_extrap = death_df.loc[(death_df["country"] == "Uzbekistan") & (death_df["year"] == 2022) &
                             (death_df["month"] == 2), "daily_deaths"].mean()

ihme_q.loc[(ihme_q["country"] == "Uzbekistan") & (ihme_q["year"] == 2022) &
                             (ihme_q["quarter"] == 1) & (ihme_q["daily_deaths"].isna()),
                             "daily_deaths"] = uzbek_extrap

ihme_q_cd = ihme_q.groupby(["country", "year",
                            "quarter", "yyyy_qq",
                            "tot_pop"])["inf_mean", "daily_deaths",
                                        "admis_mean", "icu_beds_mean"].sum().reset_index()

#omit asympomatic infections -- using conservative number from Di Fusco et al. 2021
#from Di Fusco et al. 2021, we assume 19.2% of infections are asymptomatic
asymp_prop = 0.192
#we estimate the number of asymptomatic infections by multiplying the number of infections
#by the proportion of infections that are asymptomatic
ihme_q_cd["N_asymp"] = ihme_q_cd["inf_mean"]*asymp_prop
#we estimate symptomatic infectiosn by subtracting the asymptomatic infections from
#all infections.
ihme_q_cd["N_symp"] = ihme_q_cd["inf_mean"] - ihme_q_cd["N_asymp"]

#subtract fatalities from symptomatic infections (i.e., deaths) to get all
#symptomatic infections that are nonfatal.
ihme_q_cd["N_nonfatal"] = ihme_q_cd["N_symp"] - ihme_q_cd["daily_deaths"]

#use the given hospital admissions variable as our severe state.
ihme_q_cd["N_severe"] = ihme_q_cd["admis_mean"]

#from Di Fusco et al. 2021, we calculate the weighted average of the ICU stays.
icu_duration = (9.6*16496 + 18.6*21632)/(16496+21632)

#use ICU duration of stay to calculate ICU admissions, aka critical infections.
ihme_q_cd["icu_admis"] = ihme_q_cd["icu_beds_mean"]/icu_duration
ihme_q_cd["N_critical"] = ihme_q_cd["icu_admis"]

#calculate mild infections as the difference of the other infections
ihme_q_cd["N_mild"] = (ihme_q_cd["inf_mean"] - ihme_q_cd["N_asymp"] - ihme_q_cd["daily_deaths"]
                - ihme_q_cd["N_severe"] - ihme_q_cd["N_critical"])

#check that every entry has 10 quarters of vax data
ihme_quarters = ihme_q_cd.country.value_counts()

#sum the severity splits for each country-month.
severity_splits = ihme_q_cd[["country", "yyyy_qq", "inf_mean",
                              "daily_deaths", "N_asymp", "N_mild", "N_severe",
                              "N_critical"]]

# %% Paid work loss due to disability

disability = severity_splits.copy()
# we calculate the number of nonfatal infections by summing the nonfatal health states.
disability["N_nonfatal"] = (disability["N_asymp"] + disability["N_mild"]
                            + disability["N_severe"] + disability["N_critical"])

#we calculate the proportion of nonfatal infections by summing the nonfatal health states.
# Equation 2 in the text.
for col in ["N_asymp", "N_mild", "N_severe", "N_critical"]:
    new_col = col.replace("N", "P")
    disability[new_col] = disability[col]/disability["N_nonfatal"]
    
#from Di Fusco et al. 2022, we take the length of stay per manifestation
#los stands for length of stay
los_severe_noimv = 6.1
los_severe_withimv = 12.1

los_critical_noimv = 9.6
los_critical_withimv = 18.6

# create a dictionary that contains the age-specific rate of IMV use for a severe infection from
# Di Fusco et al. 2022
imv_severe_rate = dict()
imv_severe_rate["0_17"] = 0.009 
imv_severe_rate["18_29"] = 0.014
imv_severe_rate["30_49"] = 0.032
imv_severe_rate["50_64"] = 0.059
imv_severe_rate["65_74"] = 0.078
imv_severe_rate["75_100"] = 0.071

# create a dictionary that contains the age-specific rate of IMV use for a critical infection from
# Di Fusco et al. 2022
imv_critical_rate = dict()
imv_critical_rate["0_17"] = 0.276
imv_critical_rate["18_29"] = 0.391
imv_critical_rate["30_49"] = 0.500
imv_critical_rate["50_64"] = 0.605
imv_critical_rate["65_74"] = 0.636
imv_critical_rate["75_100"] = 0.531

# for severe infections, calculate the average length of stay for each age group
los_severe = dict()
for key, value in imv_severe_rate.items():
    los_severe[key] = (value*los_severe_withimv) + ((1-value)*los_severe_noimv)

# for critical infections, calculate the average length of stay for each age group
los_critical = dict()
for key, value in imv_critical_rate.items():
    los_critical[key] = (value*los_critical_withimv) + ((1-value)*los_critical_noimv)

# for mild infections, set the "length of stay" to 1 day
los_mild = los_severe.copy()
for key, value in los_mild.items():
    los_mild[key] = 1

#load in 2019 lifetables
lifetables = pd.read_excel("../input/WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx",
                           sheet_name = "import_2", header = 1)

# only keep the columns with 
lifetables = lifetables[["country"] + [col for col in lifetables.columns if "age_" in col]]

# add each age to a list
ages = list()
for age in range(0,101):
    age_col = "age_" + str(age)
    ages.append(age_col)
    
# create a data frame of lifetables with countries and all ages
lifetables_los = lifetables[["country"] + ages]
# calculate the total population
lifetables_los["total_pop"] = lifetables_los[ages].sum(axis = 1)

# calculate the proprotion of the poputlion in each age group
lifetables_los["0_17"] = lifetables_los.loc[: , "age_0":"age_17"].sum(axis = 1)/lifetables_los["total_pop"]
lifetables_los["18_29"] = lifetables_los.loc[: , "age_18":"age_29"].sum(axis = 1)/lifetables_los["total_pop"]
lifetables_los["30_49"] = lifetables_los.loc[: , "age_30":"age_49"].sum(axis = 1)/lifetables_los["total_pop"]
lifetables_los["50_64"] = lifetables_los.loc[: , "age_50":"age_64"].sum(axis = 1)/lifetables_los["total_pop"]
lifetables_los["65_74"] = lifetables_los.loc[: , "age_65":"age_74"].sum(axis = 1)/lifetables_los["total_pop"]
lifetables_los["75_100"] = lifetables_los.loc[: , "age_75":"age_100"].sum(axis = 1)/lifetables_los["total_pop"]

# reshape the data frame from wide to long
los_df = pd.melt(lifetables_los[["country", "0_17", "18_29", "30_49", "50_64", "65_74", "75_100"]],
                 id_vars = ["country"], value_name = "prop", var_name = "age")

# calculate mild, severe, and critial length of stay based on proportions in each age group
los_df = los_df.sort_values(["country", "age"])
for age in los_df.age.unique():
    los_df.loc[los_df["age"] == age, "mild"] = (
        los_df.loc[los_df["age"] == age, "prop"]*los_mild[age])
    los_df.loc[los_df["age"] == age, "severe"] = (
        los_df.loc[los_df["age"] == age, "prop"]*los_severe[age])
    los_df.loc[los_df["age"] == age, "critical"] = (
        los_df.loc[los_df["age"] == age, "prop"]*los_critical[age])

# collapse the length of stay data for each country
los_df = los_df.groupby("country", as_index = False)[["mild", "severe", "critical"]].sum()

# create a dictionary to rename countries
country_dict = {
    "Bolivia (Plurinational State of)": "Bolivia",
    "Bonaire, Sint Eustatius and Saba": "Bonaire",
    "Brunei Darussalam": "Brunei",
    "Cabo Verde": "Cape Verde",
    "China, Hong Kong SAR": "Hong Kong",
    "China, Macao SAR": "Macao",
    "China, Taiwan Province of China": "Taiwan",
    "Côte d'Ivoire": "Cote d'Ivoire",
    "Curaçao": "Curacao",
    "Dem. People's Republic of Korea": "North Korea",
    "Democratic Republic of the Congo": "Democratic Republic of Congo",
    "Falkland Islands (Malvinas)": "Falkland Islands",
    "Faroe Islands": "Faeroe Islands",
    "Iran (Islamic Republic of)": "Iran",
    "Kosovo (under UNSC res. 1244)": "Kosovo",
    "Lao People's Democratic Republic": "Laos",
    "Micronesia (Fed. States of)": "Micronesia (country)",
    "Republic of Korea": "South Korea",
    "Republic of Moldova": "Moldova",
    "Russian Federation": "Russia",
    "State of Palestine": "Palestine",
    "Syrian Arab Republic": "Syria",
    "Türkiye": "Turkey",
    "United States of America": "United States",
    "Venezuela (Bolivarian Republic of)": "Venezuela",
    "Viet Nam": "Vietnam",
    "Wallis and Futuna Islands": "Wallis and Futuna",
    "United Republic of Tanzania": "Tanzania"
    }

# rename countries
los_df = los_df.replace(country_dict)

# only keep countries that are in the IHME data
los_df = los_df[los_df.country.isin(ihme_q_cd.country.unique())]

# add costs to the length of stay data
cost_los_df = los_df.merge(direct_df[["country", "mild_2019_usd", "severe_2019_usd",
                                         "critical_2019_usd"]], on = "country", how = "left")

# calculate the direct costs as the product of length of stay and cost per day
cost_los_df["mild_cost"] = cost_los_df["mild"]*cost_los_df["mild_2019_usd"]
cost_los_df["severe_cost"] = cost_los_df["severe"]*cost_los_df["severe_2019_usd"]
cost_los_df["critical_cost"] = cost_los_df["critical"]*cost_los_df["critical_2019_usd"]

# add severity splits to the length of stay
los_disability = disability.merge(cost_los_df[["country", "mild_cost", "severe_cost", "critical_cost"]],
                              on = "country", how = "left")

# assign asymptomatic cases a direct cost of zero
los_disability["asymp_cost"] = 0

# calculate the average nonfatal direct cost 
los_disability["nonfatal_los_cost"] = ((los_disability["P_asymp"]*los_disability["asymp_cost"])
                              + (los_disability["P_mild"]*los_disability["mild_cost"])
                              + (los_disability["P_severe"]*los_disability["severe_cost"])
                              + (los_disability["P_critical"]*los_disability["critical_cost"]))

# only retain the important columns
direct_costs = los_disability[["country", "yyyy_qq", "nonfatal_los_cost"]]

# save to a file
direct_costs.to_excel("../output/direct_costs_jk.xlsx", index = False)

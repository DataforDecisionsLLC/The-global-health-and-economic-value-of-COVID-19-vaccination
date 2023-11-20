# -*- coding: utf-8 -*-
"""
qaly_losses_mean.py: Calculates QALY losses for fatal and nonfatal infections.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 11 November 2022
__updated__ = 15 November 2023

inputs:
    - national_population_2020_2021_2022.xlsx (processed file; created in ihme_portal.py)
    - Historical-and-Projected-Covid-19-data.csv (raw file)
    - WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES.xlsx (raw file)
    - Szende et al.-2014-EQ-5D Index Population Norms.xlsx (raw file)
    - COVerAGE_death_age_structures (processed file; created in COVerAGE_quarterly_death_age_structures_5year.do)

outputs:
    - ihme_qaly_vars.xlsx
    - qaly_severity_splits.xlsx
    - qaly_losses_overall.xlsx

"""

# %% load in packages

import pandas as pd
import numpy as np

# %% establish health states

# load in the population data
popdata = pd.read_excel("../output/national_population_2020_2021_2022.xlsx")

# load in the IHME COVID data
ihmeraw = pd.read_csv("../input/Historical-and-Projected-Covid-19-data.csv")
ihme = ihmeraw[ihmeraw["version_name"] == "reference"]

keep_cols = ["date", "location_name", "inf_mean", "inf_cuml_mean",
             "cumulative_deaths", "daily_deaths", "admis_mean", "icu_beds_mean"]

# create a list of columns that we want to keep
ihme = ihme[keep_cols]

# create a dictionary to rename countries to authors' preferred versions.
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

# rename columns for ease of use and sort the file by country name and date.
ihme = ihme.rename(columns = {"location_name": "country"})

# create a year and quarter field.
ihme["year"] =  pd.to_datetime(ihme['date']).dt.year
ihme["quarter"] =  pd.to_datetime(ihme['date']).dt.quarter
ihme = ihme.sort_values(["country", "year", "quarter", "date"])

#remove data after Q2 2022
ihme = ihme[ihme["date"] < "2022-07-01"]

# add population data
ihme_df = ihme.merge(popdata, on = ["country", "year"], how = "left")
ihme_1m = ihme_df[(ihme_df["tot_pop"] >= 1000000) | (ihme_df["country"] == "Macao")]

# create a data frame that only contains entriWPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXESes with non-empty deaths records
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

# collapse infections and deaths to the country-quarter level
ihme_q = ihme_1m[["date", "country", "year", "quarter", "inf_cuml_mean", "inf_mean",
                  "cumulative_deaths", "daily_deaths", "admis_mean", "icu_beds_mean", "tot_pop"]]

# make sure the date column is being interpreted as a datetime object
ihme_q["date"] =  pd.to_datetime(ihme_q['date'])
# sort the data by country and date
ihme_q = ihme_q.sort_values(["country", "year", "quarter", "date"])

# create a year-quarter column
ihme_q["yyyy_qq"] = ihme_q["year"].astype(str) + "_Q" + ihme_q["quarter"].astype(str)

# remove Macao
ihme_q = ihme_q[ihme_q["country"] != "Macao"]

# add a month column to the death data frame
death_df["month"] =  pd.to_datetime(death_df['date']).dt.month
# for Kazakhstan, Kyrgyzstan, and Uzbekistan, make sure their last quarter with some date 
# has complete data by extrapolating to the end of the quarter
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

# collapse to the country-quarter
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

ihme_q_cd.to_excel("../output/ihme_qaly_vars.xlsx", index = False)

#sum the severity splits for each country-month.
severity_splits = ihme_q_cd[["country", "yyyy_qq", "inf_mean",
                              "daily_deaths", "N_asymp", "N_mild", "N_severe",
                              "N_critical"]]

# %% assign nonfatal QALY losses from Robinson et al.

#we assume no QALY loss from asymptomatic infections
asymp_inf = 0

#mild case QALY losses
mild = 0.009151

#severe case QALY losses
severe = 0.018781

#critical case QALY losses
critical = 0.231753

# we calculate the number of nonfatal infections by summing the nonfatal health states.
severity_splits["N_nonfatal"] = (severity_splits["N_asymp"] + severity_splits["N_mild"]
                            + severity_splits["N_severe"] + severity_splits["N_critical"])

#we calculate the proportion of nonfatal infections by summing the nonfatal health states.
# Equation 2 in the text.
for col in ["N_asymp", "N_mild", "N_severe", "N_critical"]:
    new_col = col.replace("N", "P")
    severity_splits[new_col] = severity_splits[col]/severity_splits["N_nonfatal"]

#we estimate an average QALY loss per nonfatal infection by taking the weighted average
#of the number of infections in each health state and the QALY loss associated with those states.
# Equation 1 in the text.
severity_splits["Q_nonfatal"] = ((severity_splits["P_asymp"]*asymp_inf)
                              + (severity_splits["P_mild"]*mild)
                              + (severity_splits["P_severe"]*severe)
                              + (severity_splits["P_critical"]*critical))

severity_splits.to_excel("../output/qaly_severity_splits.xlsx", index = False)

# %% calculate fatal QALY losses

#load in 2019 lifetables
lifetables = pd.read_excel("../input/WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES.xlsx",
              sheet_name = "Estimates 1986-2021", header = 16)

#change the column name of the country variable to an easily usable title
lifetables = lifetables.rename(columns = {"Region, subregion, country or area *":
                                          "country"})

#make sure the year and age variables are interepreted as numeric variables.
#non-convertible entries are coerced to na.
lifetables["Year"] = pd.to_numeric(lifetables["Year"], errors = "coerce")
lifetables["Age (x)"] =  pd.to_numeric(lifetables["Age (x)"],  errors = "coerce")

lifetable_countries = lifetables.country.unique()
lifetable_countries.sort()
country_diffs = set(lifetable_countries) - set(severity_splits.country.unique())

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
            "Republic of Korea": "South Korea"}

#perform the renaming and remove all countries that are not in the population data file.
lifetables = lifetables.replace(renaming)
lifetables = lifetables[lifetables["country"].isin(severity_splits.country.unique())]
#create a smaller data set that only keeps the 2019 lifetable.
lifetables2019 = lifetables[(lifetables["Year"] == 2019)]

#read in the health utilities from Szende et al.
utilities = pd.read_excel("../input/Szende et al.-2014-EQ-5D Index Population Norms.xlsx",
                          sheet_name = "Table 3.5. European VAS values", header = 1)

#give the country column a useful name
utilities = utilities.rename(columns = {"Unnamed: 0": "country"})

#rename certain countries to align with our other data
utilities = utilities.replace({"Korea": "South Korea", "UK": "United Kingdom",
                               "US": "United States", "Armenia (5 regions)": "Armenia",
                               "Canada (Alberta)": "Canada", "Japan (3 prefectures)": "Japan",
                               "Zimbabwe – Harare district": "Zimbabwe"})

# %% map utilties from Szende to all countries

#create a data set of life expectancies at birth
lifeexpectancies = lifetables[(lifetables["Year"] == 2019) & (lifetables[("Age (x)")] == 0)]
#keep only the country and life expectancy variables, we don't need more
lifeexpectancies = lifeexpectancies[["country", "Expectation of life e(x)"]]
#rename the life expectancy variable for ease of use.
lifeexpectancies = lifeexpectancies.rename(columns = {"Expectation of life e(x)": "life_exp"})

#merge the life expectancies data with the health utilities data to get an integrated data set.
q_utilities = lifeexpectancies.merge(utilities, on = "country", how = "left")
#make sure the life expectancy variable is treated as being of type float.
q_utilities["life_exp"] = q_utilities["life_exp"].astype(float)

# only keep the health utilities and life expectancies from the Szende article
szende_utilities = q_utilities[q_utilities["country"].isin(utilities["country"].unique())].reset_index(drop = True)
#create an array of just the life expectancies.
szende_expectancies = np.array(szende_utilities.iloc[:, 1])

# create a function that maps health utilities from Szende to countries without utilities.
# we do this by finding the country in Szende with the closest life expectancy to the country of interest then transferring the utilities.
def map_utilities(country):
    """
    Maps background health utilities from Szende et al. to countries not in Szende.

    Parameters
    ----------
    country : str
        A string containting the country of interest.

    Returns
    -------
    None.

    """
    # if the country is in Szende, we need not map its own utilities to itself.
    if country in szende_utilities.country.unique():
        pass
    else:
        # get the expectancy of the country without health utilities
        expectancy = q_utilities.loc[(q_utilities["country"] == country), "life_exp"].values[0]
        # calculate the difference between this life expectancy and the life expectancy of the Szende countries.
        expectancy_diff = np.absolute(szende_expectancies - expectancy)
        # find the smallest absolute difference (i.e., closest life expectancy)
        index_val = expectancy_diff.argmin()
        # get the name of the country with this smallest difference
        mapping_country = szende_utilities.loc[index_val, "country"]
        # set the utilities of the target country to the utilities from Szende
        q_utilities.loc[q_utilities["country"] == country, "18–24": "Total"] = q_utilities.loc[q_utilities["country"] == mapping_country, "18–24": "Total"].values
    # some of the utilities in Szende miss either the oldest age group (75+) or the youngest (18-24)
    # if that is the case, we set the utility to nearest age group.
    if np.isnan(q_utilities.loc[q_utilities["country"] == country, "75+"].values[0]):
        q_utilities.loc[q_utilities["country"] == country, "75+"] = q_utilities.loc[q_utilities["country"] == country, "65–74"].values[0]
    else:
        pass
    if np.isnan(q_utilities.loc[q_utilities["country"] == country, "18–24"].values[0]):
        q_utilities.loc[q_utilities["country"] == country, "18–24"] = q_utilities.loc[q_utilities["country"] == country, "25–34"].values[0]
    else:
        pass
    
# for all the countries in our data, perform the utility mapping
for c in q_utilities.country.unique():
    map_utilities(c)    

# create a fucntion that adds these mapped health utilities to the life tables.
def add_utilities_to_lifetables2019(country):
    """
    Adds the utility values to the lifetables to facilitate subsequent calculations.    

    Parameters
    ----------
    country : str
        A string containing the country of interest.

    Returns
    -------
    None.

    """
    # for the given country, set the health utility for ages according to the age groups in Szende.
    lifetables2019.loc[lifetables2019["country"] == country, "Q"] = q_utilities.loc[q_utilities["country"] == country, "75+"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 75), "Q"] = q_utilities.loc[q_utilities["country"] == country, "65–74"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 65), "Q"] = q_utilities.loc[q_utilities["country"] == country, "55–64"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 55), "Q"] = q_utilities.loc[q_utilities["country"] == country, "45–54"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 45), "Q"] = q_utilities.loc[q_utilities["country"] == country, "35–44"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 35), "Q"] = q_utilities.loc[q_utilities["country"] == country, "25–34"].values[0]
    lifetables2019.loc[(lifetables2019["country"] == country) & (lifetables2019["Age (x)"] < 25), "Q"] = q_utilities.loc[q_utilities["country"] == country, "18–24"].values[0]

# for all countries in our data, add the utilities to the life table.
for c in lifetables2019.country.unique():
    add_utilities_to_lifetables2019(c)
    
# %% calculate QALY loss from mortality

# create a function that uses the Briggs et al equation to calculate QALY losses
# from mortality.
def qaly_loss_mortality(country, age, discount_rate):
    """
    Calculates the QALY loss from mortality using the Briggs et al. formula.

    Parameters
    ----------
    country : str
        A string containing the country of interest.
    age : int
        An integer containing the age of interest.
    discount_rate : float
        A float (i.e., decimal) that equals the annual discount rate.

    Returns
    -------
    None.

    """
    # given an age, get all the ages between it and 100 (the final age of our life table)
    ages = list(range(age, 101))
    # create a smaller data set that is country-specific and only includes the
    # ages of interest.
    df = lifetables2019[(lifetables2019["country"] == country)
                        & (lifetables2019["Age (x)"].isin(ages))]
    # set the initial value of the numerator in Briggs et al. equation to 0.
    numerator = 0
    # for all the ages of interest
    for i in ages:
        # get the value of L, person-years lived
        L = df.loc[df["Age (x)"] == i, "Number of person-years lived L(x,n)"].values[0]
        # get the value of Q, health utility
        Q = df.loc[df["Age (x)"] == i, "Q"].values[0]
        # get the difference between that age and the original age
        age_diff = i - age
        # calculate the discount quantitiy
        discount = (1 + discount_rate)**(-1*(age_diff))
        # multiply L, Q, and discount to generate a discounted QALYs value
        discounted_QALYs = L*Q*discount
        # add this value to the numerator to get the sum total by the end
        numerator = numerator + discounted_QALYs
    # extract l, the number of survivors, to fill in the denominator.
    denominator = df.loc[df["Age (x)"] == age, "Number of survivors l(x)"].values[0]
    # calculate dQALY
    # Equation 3 in the text
    dQALY = numerator/denominator
    # add the dQALY value to the lifetable.
    lifetables2019.loc[(lifetables2019["country"] == country)
                       & (lifetables2019["Age (x)"] == age), "dQALY"] = dQALY

# for all ages and for all countries, calculate the QALY loss from mortality.
for age in range(0, 101):
    for c in lifetables2019.country.unique():
        qaly_loss_mortality(c, age, 0.03)

#lifetables2019.to_excel("../output/age_specific_qaly_losses.xlsx", index = False)

# %% calculate fatal QALYs into 5-year age buckets based on lifetables.

# create a function that uses population-weighted averages to calculate 5-year
# age buckets.

age_specific_df = pd.DataFrame(columns = ["country", "first_age", "last_age", "Q_fatal"])
def fatal_qaly_age_specific(country, first_age, last_age):
    global age_specific_df
    """
    Calculates population-weighted QALY losses from mortality for our age buckets.

    Parameters
    ----------
    country : str
        The country of interest.
    first_age : int
        The starting age of the age bucket. For the age bucket 0-14, use 0. For
        the age bucket 15-24, use 15, etc.
    last_age : int
        The end age of the age bucket. For the age bucket 0-14, use 14. For the
        age bucket 15-24, use 24 etc.

    Returns
    -------
    age_specific_df: data frame
        A data frame with three columns--country, age, and fatal_qaly. The first
        two are self-explanatory, the latter is the population-weighted QALY loss
        for death, which relies on data from the lifetables.
    """
    # given an age, generate all ages in the age bucket
    ages = list(range(first_age, last_age+1))
    # create a smaller data set that is country-specific and only includes the
    # ages of interest.
    df = lifetables2019[(lifetables2019["country"] == country)
                        & (lifetables2019["Age (x)"].isin(ages))]
    # calculate the population-weighted fatal QALY
    # Equation 4 in the text.
    weighted_qaly = np.average(df["dQALY"], weights=df["Number of survivors l(x)"])
    #create a dictionary that includes the column names of the target dataframe and 
    #the values to fill those columns
    d = {age_specific_df.columns[0]: country, age_specific_df.columns[1]: first_age,
         age_specific_df.columns[2]: last_age, age_specific_df.columns[3]: weighted_qaly}
    #add those new values to the data frame
    age_specific_df = pd.concat([age_specific_df, pd.DataFrame(d, index = [0])])
    return age_specific_df

#create a dictionary of the first and last ages of the buckets to use in the function.
age_buckets_dict = {0:14, 15:24, 25:34, 35:44, 45:54, 55:64, 65:74, 75:100}

#calculate weighted fatal QALYs for the age buckets for each country.
for c in lifetables2019.country.unique():
    for key, value in age_buckets_dict.items():
        fatal_qaly_age_specific(country = c, first_age = key, last_age = value)

#sort the resulting data frame by country and age.      
age_specific_df = age_specific_df.sort_values(["country", "first_age"]).reset_index(drop = True)

#age_specific_df.to_excel("../output/age_buckets_qaly_losses.xlsx", index = False)

# %% use the COVerAGE data to calculate fatal QALY losses based on the age-specificity of COVID deaths.

# load in COVerAGE data with filled in missing quarters
coverage = pd.read_excel("../input/COVerAGE_death_age_structures.xlsx",
                         sheet_name = "quarterly")

"""
We use the proportions of deaths in that file to calculate the QALY loss per
fatal case, using the age-specific QALYs from age_specific_df.
"""

#we keep all the rows of data (days) but only keep the important columns.
fatal_df = coverage.loc[:, "country": "prop_75"]
#create a date variable that combines the year and quarter.
fatal_df['yyyy_qq'] = fatal_df["year"].astype(str) + "_Q" + fatal_df["quarter"].astype(str)

#because we want to produce qalys for each age group, we replace "prop" with "qaly"
#to allow for this
fatal_df.columns = fatal_df.columns.str.replace("prop_", "qaly_")

#drop irrelevant columns
fatal_df = fatal_df.drop(columns = ["quarter", "originally", "data_source", "year"])

#make sure the date in the coverage data aligns with the qaly dataframe
coverage['yyyy_qq'] = coverage["year"].astype(str) + "_Q" + coverage["quarter"].astype(str)

#for a given country-month and age, use the proportion of deaths in that age
#and the QALY loss from mortality for that age to calculate the average fatal
#QALY.  
for country in fatal_df.country.unique():
    for quarter in fatal_df.yyyy_qq.unique():
        for key in age_buckets_dict:
            try:
                fatal_df.loc[(fatal_df["country"] == country) & (fatal_df["yyyy_qq"] == quarter),
                             "qaly_"+str(key)] = coverage.loc[(coverage["country"] == country)
                             & (coverage["yyyy_qq"] == quarter), "prop_"+str(key)].values[0]*age_specific_df.loc[
                             (age_specific_df["country"] == country) & (age_specific_df["first_age"] == key), 
                             "Q_fatal"].values[0]
                pass
            except:
                continue
         
fatal_df["Q_fatal"] = fatal_df.filter(regex = "^qaly_").sum(axis = 1)

# %% combine the fatal and nonfatal QALY loss information into a single table.

# add the QALYs per fatal case to severity_splits
severity_splits = severity_splits.merge(fatal_df[["country", "yyyy_qq", "Q_fatal"]],
                      on = ["country", "yyyy_qq"], how = "right")

# use the QALYs per nonfatal case and the QALYs per fatal case, along with the
# proportion of nonfatal and fatal cases to calculate overall QALYs per case.
severity_splits["Q_overall"] = ((severity_splits["N_asymp"]*asymp_inf/severity_splits["inf_mean"])
                              + (severity_splits["N_mild"]*mild/severity_splits["inf_mean"])
                              + (severity_splits["N_severe"]*severe/severity_splits["inf_mean"])
                              + (severity_splits["N_critical"]*critical/severity_splits["inf_mean"])
                              + (severity_splits["daily_deaths"]*severity_splits["Q_fatal"]/severity_splits["inf_mean"]))

severity_splits.to_excel("../output/qaly_losses_overall.xlsx", index = False)

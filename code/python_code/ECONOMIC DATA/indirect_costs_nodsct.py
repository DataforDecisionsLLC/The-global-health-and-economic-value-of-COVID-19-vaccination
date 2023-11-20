# -*- coding: utf-8 -*-
"""
indirect_costs_nodsct.py: Calculates indirect costs of COVID infection.

Please refer to indirect_costs.py for detailed comments. Note that the only
difference is that we use a 0% discount rate here instead of 3%.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 20 April 2023
__updated__ = 16 November 2023

"""
# %% load in libraries
import pandas as pd
import numpy as np

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
for col in ["N_asymp", "N_mild", "N_severe", "N_critical"]:
    new_col = col.replace("N", "P")
    disability[new_col] = disability[col]/disability["N_nonfatal"]

#from Di Fusco et al. 2022, we take the working time lost per manifestation
#wdl stands for working days lost
wdl_severe_noimv = 20.1
wdl_severe_withimv = 183

imv_severe_rate = dict()
imv_severe_rate["15_17"] = 0.009
imv_severe_rate["18_29"] = 0.014
imv_severe_rate["30_49"] = 0.032
imv_severe_rate["50_64"] = 0.059
#imv_severe_rate["65_74"] = 0.078 #we omit ages outside the working population
#imv_severe_rate["75_100"] = 0.071 #we omit ages outside the working population

wdl_critical_noimv = 23.6
wdl_critical_withimv = 183

imv_critical_rate = dict()
imv_critical_rate["15_17"] = 0.276 
imv_critical_rate["18_29"] = 0.391
imv_critical_rate["30_49"] = 0.500
imv_critical_rate["50_64"] = 0.605
#imv_critical_rate["65_74"] = 0.636 #we omit ages outside the working population
#imv_critical_rate["75_100"] = 0.531 #we omit ages outside the working population

# from Hastie et al. (2021), we estimate critical long covid as 1.5 years,
# we discount the time after the first year at 3%.
# from Robinson et al. (2022), we estimate severe long covid as 45 days
prop_pasc = 0.457
severe_pasc = 45

# calculate work days lost for severe, critical, and mild cases
wdl_severe = dict()
for key, value in imv_severe_rate.items():
    wdl_severe[key] = (value*wdl_severe_withimv) + ((1-value)*wdl_severe_noimv) + (prop_pasc*severe_pasc)

wdl_critical = dict()
for key, value in imv_critical_rate.items():
    wdl_critical[key] = (value*wdl_critical_withimv) + ((1-value)*wdl_critical_noimv)

wdl_mild = wdl_severe.copy()
for key, value in wdl_mild.items():
    wdl_mild[key] = 10

# load in 2019 lifetables
lifetables2019_raw = pd.read_excel("../input/WPP2022_POP_F01_1_POPULATION_SINGLE_AGE_BOTH_SEXES-import.xlsx",
                           sheet_name = "import_2", header = 1)

# keep country and age-specific columns
lifetables2019 = lifetables2019_raw[["country"] + [col for col in lifetables2019_raw.columns if "age_" in col]]

# we only keep people aged 15-64.
working_ages = list()
for age in range(15,65):
    age_col = "age_" + str(age)
    working_ages.append(age_col)
    
# we keep the working age populations only for paid work loss
lifetables_work = lifetables2019[["country"] + working_ages]

# we calculate the proportion of the population in each age group
lifetables_work["working_pop"] = lifetables_work[working_ages].sum(axis = 1)
lifetables_work["15_17"] = lifetables_work.loc[: , "age_15":"age_17"].sum(axis = 1)/lifetables_work["working_pop"]
lifetables_work["18_29"] = lifetables_work.loc[: , "age_18":"age_29"].sum(axis = 1)/lifetables_work["working_pop"]
lifetables_work["30_49"] = lifetables_work.loc[: , "age_30":"age_49"].sum(axis = 1)/lifetables_work["working_pop"]
lifetables_work["50_64"] = lifetables_work.loc[: , "age_50":"age_64"].sum(axis = 1)/lifetables_work["working_pop"]

# we convert the table from wide to long
wdl_df = pd.melt(lifetables_work[["country", "15_17", "18_29", "30_49", "50_64"]],
                 id_vars = ["country"], value_name = "prop", var_name = "age")

# for each severity level, we multiply the proportion of each age group by the duration 
# of severity in each age group, to get an average duration
wdl_df = wdl_df.sort_values(["country", "age"])
for age in wdl_df.age.unique():
    wdl_df.loc[wdl_df["age"] == age, "mild"] = (
        wdl_df.loc[wdl_df["age"] == age, "prop"]*wdl_mild[age])
    wdl_df.loc[wdl_df["age"] == age, "severe"] = (
        wdl_df.loc[wdl_df["age"] == age, "prop"]*wdl_severe[age])
    wdl_df.loc[wdl_df["age"] == age, "critical_nopasc"] = (
        wdl_df.loc[wdl_df["age"] == age, "prop"]*wdl_critical[age])

wdl_df = wdl_df.groupby("country", as_index = False)[["mild", "severe", "critical_nopasc"]].sum()

wdl_df["critical"] = wdl_df["critical_nopasc"] + prop_pasc*((365.25-wdl_df["critical_nopasc"]) + (wdl_df["critical_nopasc"] + (365.25/2))*((1.00)**(-1)))

wdl_df = wdl_df.drop(columns = "critical_nopasc")

# we create a dictionary to rename countries to author preferred versions
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

# we rename countries using that dictionary and only keep IHME countries
wdl_df = wdl_df.replace(country_dict)
wdl_df = wdl_df[wdl_df.country.isin(ihme_q_cd.country.unique())]

# we load in the daily earnings data and format it to our usage
daily_earn = pd.read_stata("../input/daily_earn_2019USD.dta")
earnings = daily_earn[(daily_earn["age"] >= 15) & (daily_earn["age"] <= 64)]
earnings = earnings.drop_duplicates(subset = ["country", "daily_earnings_2019USD"])
earnings = earnings.rename(columns = {"daily_earnings_2019USD": "daily_earnings"})

# given the durations and earnings per day, we calculate the average productivity cost of 
# a mild, severe, and critical case
paid_wl_df = wdl_df.merge(earnings[["country", "daily_earnings"]], on = "country", how = "left")
paid_wl_df["mild_cost"] = paid_wl_df["mild"]*paid_wl_df["daily_earnings"]
paid_wl_df["severe_cost"] = paid_wl_df["severe"]*paid_wl_df["daily_earnings"]
paid_wl_df["critical_cost"] = paid_wl_df["critical"]*paid_wl_df["daily_earnings"]

# we merge severity splits data with productivity costs data
paid_disability = disability.merge(paid_wl_df[["country", "mild_cost", "severe_cost", "critical_cost"]],
                              on = "country", how = "left")

# we assign asymptomatic cases a productivity cost of 0.
paid_disability["asymp_cost"] = 0

# using the probability of non-fatal infections and the cost per non-fatal infection type,
# we calculate an average nonfatal productivity cost
paid_disability["nonfatal_paid_work_loss"] = ((paid_disability["P_asymp"]*paid_disability["asymp_cost"])
                              + (paid_disability["P_mild"]*paid_disability["mild_cost"])
                              + (paid_disability["P_severe"]*paid_disability["severe_cost"])
                              + (paid_disability["P_critical"]*paid_disability["critical_cost"]))

# compare to Daria's non-fatal paid work loss data
db_paid_nonfatal = pd.read_stata("../input/paid_work_loss_nonfatal_case.dta")
paid_disability = paid_disability.merge(db_paid_nonfatal[["country", "yyyy_qq", "paid_work_loss_nonfatal_case"]],
                                        on = ["country", "yyyy_qq"], how = "outer")
paid_disability["check"] = np.isclose(paid_disability["nonfatal_paid_work_loss"], paid_disability["paid_work_loss_nonfatal_case"],
                                      equal_nan = True)

# %% paid loss due to death

#load in 2019 lifetables
lifetablesraw = pd.read_excel("../input/WPP2022_MORT_F06_1_SINGLE_AGE_LIFE_TABLE_ESTIMATES_BOTH_SEXES.xlsx",
              sheet_name = "Estimates 1986-2021", header = 16)

#change the column name of the country variable to an easily usable title
lifetables = lifetablesraw.rename(columns = {"Region, subregion, country or area *":
                                          "country", "Year": "year", "Age (x)": "age",
                                          "Number of person-years lived L(x,n)": "L",
                                          "Number of survivors l(x)": "l"})

lifetables = lifetables[["country", "year", "age", "L", "l"]]
#make sure the year and age variables are interepreted as numeric variables.
#non-convertible entries are coerced to na.
lifetables["year"] = pd.to_numeric(lifetables["year"], errors = "coerce")
lifetables["age"] =  pd.to_numeric(lifetables["age"],  errors = "coerce")
daily_earn["age"] =  pd.to_numeric(daily_earn["age"],  errors = "coerce")
lifetables_earn = lifetables[(lifetables["year"] == 2019)]
lifetables_earn = lifetables_earn.replace(country_dict)

#add earnings to lifetable
lifetables_earn = lifetables_earn.merge(daily_earn[["country", "age", "daily_earnings_2019USD"]],
                                   on = ["country", "age"], how = "right")

lifetables_earn["annual_earnings"] = lifetables_earn["daily_earnings_2019USD"]*365.25
lifetables_earn = lifetables_earn[lifetables_earn["country"] != "Djibouti"]

def paidwork_loss_mortality(country, age, discount_rate):
    """
    Calculates the paid work loss from mortality using equation 2 in the MSD.

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
    df = lifetables_earn[(lifetables_earn["country"] == country)
                        & (lifetables_earn["age"].isin(ages))]
    # set the initial value of the numerator in Briggs et al. equation to 0.
    numerator = 0
    # for all the ages of interest
    for i in ages:
        # get the value of L, person-years lived
        L = df.loc[df["age"] == i, "L"].values[0]
        # get the value of annual earnings
        annual_earnings = df.loc[df["age"] == i, "annual_earnings"].values[0]
        # get the difference between that age and the original age
        age_diff = i - age
        # calculate the discount quantitiy
        discount = (1 + discount_rate)**(-1*(age_diff))
        # multiply L, Q, and discount to generate a discounted paid work losss value
        discounted_earnings = L*annual_earnings*discount
        # add this value to the numerator to get the sum total by the end
        numerator = numerator + discounted_earnings
    # extract l, the number of survivors, to fill in the denominator.
    denominator = df.loc[df["age"] == age, "l"].values[0]
    # calculate dpaid work loss
    # Equation 3 in the text
    paid_work_loss = numerator/denominator
    # add the dpaid work loss value to the lifetable.
    lifetables_earn.loc[(lifetables_earn["country"] == country)
                       & (lifetables_earn["age"] == age), "paid_work_loss"] = paid_work_loss

# for all ages and for all countries, calculate the paid earnings loss from mortality.
for age in range(0, 101):
    for c in lifetables_earn.country.unique():
        paidwork_loss_mortality(c, age, 0.03)
        
age_specific_df = pd.DataFrame(columns = ["country", "first_age", "last_age", "fatal_paid_loss"])

def fatal_costs_age_specific(country, first_age, last_age):
    global age_specific_df
    """
    Calculates population-weighted paid work costs from mortality for our age buckets.

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
        A data frame with three columns--country, age, and fatal_paid_loss. The first
        two are self-explanatory, the latter is the population-weighted paid work loss
        for death, which relies on data from the lifetables.
    """
    # given an age, generate all ages in the age bucket
    ages = list(range(first_age, last_age+1))
    # create a smaller data set that is country-specific and only includes the
    # ages of interest.
    df = lifetables_earn[(lifetables_earn["country"] == country)
                        & (lifetables_earn["age"].isin(ages))]
    # calculate the population-weighted fatal paid work loss
    weighted_loss = np.average(df["paid_work_loss"], weights=df["l"])
    #create a dictionary that includes the column names of the target dataframe and 
    #the values to fill those columns
    d = {age_specific_df.columns[0]: country, age_specific_df.columns[1]: first_age,
         age_specific_df.columns[2]: last_age, age_specific_df.columns[3]: weighted_loss}
    #add those new values to the data frame
    age_specific_df = pd.concat([age_specific_df, pd.DataFrame(d, index = [0])])
    return age_specific_df

#create a dictionary of the first and last ages of the buckets to use in the function.
age_buckets_dict = {0:14, 15:24, 25:34, 35:44, 45:54, 55:64, 65:74, 75:100}

#calculate weighted fatal paid work losss for the age buckets for each country.
for c in lifetables_earn.country.unique():
    for key, value in age_buckets_dict.items():
        fatal_costs_age_specific(country = c, first_age = key, last_age = value)

#sort the resulting data frame by country and age.      
age_specific_df = age_specific_df.sort_values(["country", "first_age"]).reset_index(drop = True)

# load in COVerAGE data with filled in missing quarters
coverage = pd.read_excel("../input/COVerAGE_death_age_structures.xlsx",
                         sheet_name = "quarterly")

coverage = coverage[coverage["country"] != "Djibouti"]

"""
We use the proportions of deaths in that file to calculate the paid work loss per
fatal case, using the age-specific paid work loss from age_specific_df.
"""

#we keep all the rows of data (days) but only keep the important columns.
fatal_df = coverage.loc[:, "country": "prop_75"]
#create a date variable that combines the year and quarter.
fatal_df['yyyy_qq'] = fatal_df["year"].astype(str) + "_Q" + fatal_df["quarter"].astype(str)

#because we want to produce qalys for each age group, we replace "prop" with "qaly"
#to allow for this
fatal_df.columns = fatal_df.columns.str.replace("prop_", "paid_work_loss_")

#drop irrelevant columns
fatal_df = fatal_df.drop(columns = ["quarter", "originally", "data_source", "year"])

#make sure the date in the coverage data aligns with the qaly dataframe
coverage['yyyy_qq'] = coverage["year"].astype(str) + "_Q" + coverage["quarter"].astype(str)

#for a given country-month and age, use the proportion of deaths in that age
#and the paid work loss loss from mortality for that age to calculate the average fatal
#paid work loss.  
for country in fatal_df.country.unique():
    for quarter in fatal_df.yyyy_qq.unique():
        for key in age_buckets_dict:
            try:
                fatal_df.loc[(fatal_df["country"] == country) & (fatal_df["yyyy_qq"] == quarter),
                             "paid_work_loss_"+str(key)] = coverage.loc[(coverage["country"] == country)
                             & (coverage["yyyy_qq"] == quarter), "prop_"+str(key)].values[0]*age_specific_df.loc[
                             (age_specific_df["country"] == country) & (age_specific_df["first_age"] == key), 
                             "fatal_paid_loss"].values[0]
                pass
            except:
                continue
         
fatal_df["fatal_paid_work_loss"] = fatal_df.filter(regex = "^paid_work_loss_").sum(axis = 1)

paid_losses = fatal_df[["country", "yyyy_qq", "fatal_paid_work_loss"]]
paid_losses = paid_losses.merge(paid_disability[["country", "yyyy_qq", "nonfatal_paid_work_loss",
                                            "asymp_cost", "mild_cost", "severe_cost",
                                            "critical_cost"]], on = ["country", "yyyy_qq"],
                                how = "outer")

# %% unpaid work loss due to disability

#from Di Fusco et al. 2022, we take the working time lost per manifestation
#udl stands for unpaid days lost
udl_severe_noimv = 20.1
udl_severe_withimv = 183

imv_severe_rate = dict()
imv_severe_rate["15_17"] = 0.009
imv_severe_rate["18_29"] = 0.014
imv_severe_rate["30_49"] = 0.032
imv_severe_rate["50_64"] = 0.059
imv_severe_rate["65_74"] = 0.078 
imv_severe_rate["75_100"] = 0.071 

udl_critical_noimv = 23.6
udl_critical_withimv = 183

imv_critical_rate = dict()
imv_critical_rate["15_17"] = 0.276 
imv_critical_rate["18_29"] = 0.391
imv_critical_rate["30_49"] = 0.500
imv_critical_rate["50_64"] = 0.605
imv_critical_rate["65_74"] = 0.636
imv_critical_rate["75_100"] = 0.531

prop_pasc = 0.457
severe_pasc = 45

udl_severe = dict()
for key, value in imv_severe_rate.items():
    udl_severe[key] = (value*udl_severe_withimv) + ((1-value)*udl_severe_noimv) + (prop_pasc*severe_pasc)

udl_critical = dict()
for key, value in imv_critical_rate.items():
    udl_critical[key] = (value*udl_critical_withimv) + ((1-value)*udl_critical_noimv)

udl_mild = udl_severe.copy()
for key, value in udl_mild.items():
    udl_mild[key] = 10

unpaid_ages = list()
for age in range(15,101):
    age_col = "age_" + str(age)
    unpaid_ages.append(age_col)
    
lifetables_unpaid = lifetables2019[["country"] + unpaid_ages]
lifetables_unpaid["working_pop"] = lifetables_unpaid[unpaid_ages].sum(axis = 1)
lifetables_unpaid["15_17"] = lifetables_unpaid.loc[: , "age_15":"age_17"].sum(axis = 1)/lifetables_unpaid["working_pop"]
lifetables_unpaid["18_29"] = lifetables_unpaid.loc[: , "age_18":"age_29"].sum(axis = 1)/lifetables_unpaid["working_pop"]
lifetables_unpaid["30_49"] = lifetables_unpaid.loc[: , "age_30":"age_49"].sum(axis = 1)/lifetables_unpaid["working_pop"]
lifetables_unpaid["50_64"] = lifetables_unpaid.loc[: , "age_50":"age_64"].sum(axis = 1)/lifetables_unpaid["working_pop"]
lifetables_unpaid["65_74"] = lifetables_unpaid.loc[: , "age_65":"age_74"].sum(axis = 1)/lifetables_unpaid["working_pop"]
lifetables_unpaid["75_100"] = lifetables_unpaid.loc[: , "age_75":"age_100"].sum(axis = 1)/lifetables_unpaid["working_pop"]

udl_df = pd.melt(lifetables_unpaid[["country", "15_17", "18_29", "30_49", "50_64", "65_74", "75_100"]],
                 id_vars = ["country"], value_name = "prop", var_name = "age")

udl_df = udl_df.sort_values(["country", "age"])
for age in udl_df.age.unique():
    udl_df.loc[udl_df["age"] == age, "mild"] = (
        udl_df.loc[udl_df["age"] == age, "prop"]*udl_mild[age])
    udl_df.loc[udl_df["age"] == age, "severe"] = (
        udl_df.loc[udl_df["age"] == age, "prop"]*udl_severe[age])
    udl_df.loc[udl_df["age"] == age, "critical_nopasc"] = (
        udl_df.loc[udl_df["age"] == age, "prop"]*udl_critical[age])

udl_df = udl_df.groupby("country", as_index = False)[["mild", "severe", "critical_nopasc"]].sum()

udl_df["critical_pasc"] = udl_df["critical_nopasc"] + 365.25 + (365.25/2)

udl_df["critical_pasc"] = 365.25 + (udl_df["critical_pasc"] - 365.25)*((1.00)**(-1))

udl_df["critical"] = udl_df["critical_nopasc"]*(1-prop_pasc) +  udl_df["critical_pasc"]*(prop_pasc)

udl_df = udl_df.drop(columns = ["critical_nopasc", "critical_pasc"])

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

udl_df = udl_df.replace(country_dict)
udl_df = udl_df[udl_df.country.isin(ihme_q_cd.country.unique())]

time_use = pd.read_excel("../output/time_use_processed_ihme.xlsx")
unpaid_time = time_use[["country", "unpaid work time"]]
unpaid_time["hours"] = (unpaid_time["unpaid work time"]/60)

wages = pd.read_stata("../input/hrly_wage_2019USD_final.dta")
wages_df = wages[["country", "hrly_wage_2019USD"]].rename(columns = {"hrly_wage_2019USD": "wage"})

unpaid_df = udl_df.merge(unpaid_time, on = "country", how = "left")
unpaid_df = unpaid_df.merge(wages_df, on = "country", how = "left")
unpaid_df["cost_per_day"] = unpaid_df["wage"]*unpaid_df["hours"]

unpaid_df["mild_cost"] = unpaid_df["mild"]*unpaid_df["cost_per_day"]
unpaid_df["severe_cost"] = unpaid_df["severe"]*unpaid_df["cost_per_day"]
unpaid_df["critical_cost"] = unpaid_df["critical"]*unpaid_df["cost_per_day"]

unpaid_disability = disability.merge(unpaid_df[["country", "mild_cost", "severe_cost", "critical_cost"]],
                              on = "country", how = "left")

unpaid_disability["asymp_cost"] = 0
unpaid_disability["nonfatal_unpaid_work_loss"] = ((unpaid_disability["P_asymp"]*unpaid_disability["asymp_cost"])
                              + (unpaid_disability["P_mild"]*unpaid_disability["mild_cost"])
                              + (unpaid_disability["P_severe"]*unpaid_disability["severe_cost"])
                              + (unpaid_disability["P_critical"]*unpaid_disability["critical_cost"]))

# %% unpaid work loss due to death

unpaid_df["yearly_hours"] = unpaid_df["hours"]*365.25
unpaid_df["annual_unpaid_value"] = unpaid_df["yearly_hours"]*unpaid_df["wage"]

lifetables_unpaid2 = lifetables[(lifetables["year"] == 2019)]
lifetables_unpaid2 = lifetables_unpaid2.replace(country_dict)

#add earnings to lifetable
lifetables_unpaid2 = lifetables_unpaid2.merge(unpaid_df[["country", "annual_unpaid_value"]],
                                   on = "country", how = "right")

lifetables_unpaid2.loc[lifetables_unpaid2["age"] < 15, "annual_unpaid_value"] = 0
lifetables_unpaid2 = lifetables_unpaid2[lifetables_unpaid2["country"] != "Djibouti"]

def unpaidwork_loss_mortality(country, age, discount_rate):
    """
    Calculates the unpaid work loss from mortality using equation 2 in the MSD.

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
    df = lifetables_unpaid2[(lifetables_unpaid2["country"] == country)
                        & (lifetables_unpaid2["age"].isin(ages))]
    # set the initial value of the numerator in Briggs et al. equation to 0.
    numerator = 0
    # for all the ages of interest
    for i in ages:
        # get the value of L, person-years lived
        L = df.loc[df["age"] == i, "L"].values[0]
        # get the value of annual earnings
        annual_earnings = df.loc[df["age"] == i, "annual_unpaid_value"].values[0]
        # get the difference between that age and the original age
        age_diff = i - age
        # calculate the discount quantitiy
        discount = (1 + discount_rate)**(-1*(age_diff))
        # multiply L, Q, and discount to generate a discounted unpaid work losss value
        discounted_earnings = L*annual_earnings*discount
        # add this value to the numerator to get the sum total by the end
        numerator = numerator + discounted_earnings
    # extract l, the number of survivors, to fill in the denominator.
    denominator = df.loc[df["age"] == age, "l"].values[0]
    # calculate dunpaid work loss
    # Equation 3 in the text
    unpaid_work_loss = numerator/denominator
    # add the dunpaid work loss value to the lifetable.
    lifetables_unpaid2.loc[(lifetables_unpaid2["country"] == country)
                       & (lifetables_unpaid2["age"] == age), "unpaid_work_loss"] = unpaid_work_loss

# for all ages and for all countries, calculate the unpaid earnings loss from mortality.
for age in range(0, 101):
    for c in lifetables_unpaid2.country.unique():
        unpaidwork_loss_mortality(c, age, 0.03)
        
age_specific_df = pd.DataFrame(columns = ["country", "first_age", "last_age", "fatal_unpaid_loss"])

def fatal_costs_age_specific(country, first_age, last_age):
    global age_specific_df
    """
    Calculates population-weighted unpaid work costs from mortality for our age buckets.

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
        A data frame with three columns--country, age, and fatal_unpaid_loss. The first
        two are self-explanatory, the latter is the population-weighted unpaid work loss
        for death, which relies on data from the lifetables.
    """
    # given an age, generate all ages in the age bucket
    ages = list(range(first_age, last_age+1))
    # create a smaller data set that is country-specific and only includes the
    # ages of interest.
    df = lifetables_unpaid2[(lifetables_unpaid2["country"] == country)
                        & (lifetables_unpaid2["age"].isin(ages))]
    # calculate the population-weighted fatal unpaid work loss
    weighted_loss = np.average(df["unpaid_work_loss"], weights=df["l"])
    #create a dictionary that includes the column names of the target dataframe and 
    #the values to fill those columns
    d = {age_specific_df.columns[0]: country, age_specific_df.columns[1]: first_age,
         age_specific_df.columns[2]: last_age, age_specific_df.columns[3]: weighted_loss}
    #add those new values to the data frame
    age_specific_df = pd.concat([age_specific_df, pd.DataFrame(d, index = [0])])
    return age_specific_df

#create a dictionary of the first and last ages of the buckets to use in the function.
age_buckets_dict = {0:14, 15:24, 25:34, 35:44, 45:54, 55:64, 65:74, 75:100}

#calculate weighted fatal unpaid work losss for the age buckets for each country.
for c in lifetables_unpaid2.country.unique():
    for key, value in age_buckets_dict.items():
        fatal_costs_age_specific(country = c, first_age = key, last_age = value)

#sort the resulting data frame by country and age.      
age_specific_df = age_specific_df.sort_values(["country", "first_age"]).reset_index(drop = True)

# load in COVerAGE data with filled in missing quarters
coverage = pd.read_excel("../input/COVerAGE_death_age_structures.xlsx",
                         sheet_name = "quarterly")

coverage = coverage[coverage["country"] != "Djibouti"]

"""
We use the proportions of deaths in that file to calculate the unpaid work loss per
fatal case, using the age-specific unpaid work loss from age_specific_df.
"""

#we keep all the rows of data (days) but only keep the important columns.
fatal_df = coverage.loc[:, "country": "prop_75"]
#create a date variable that combines the year and quarter.
fatal_df['yyyy_qq'] = fatal_df["year"].astype(str) + "_Q" + fatal_df["quarter"].astype(str)

#because we want to produce qalys for each age group, we replace "prop" with "qaly"
#to allow for this
fatal_df.columns = fatal_df.columns.str.replace("prop_", "unpaid_work_loss_")

#drop irrelevant columns
fatal_df = fatal_df.drop(columns = ["quarter", "originally", "data_source", "year"])

#make sure the date in the coverage data aligns with the qaly dataframe
coverage['yyyy_qq'] = coverage["year"].astype(str) + "_Q" + coverage["quarter"].astype(str)

#for a given country-month and age, use the proportion of deaths in that age
#and the unpaid work loss loss from mortality for that age to calculate the average fatal
#unpaid work loss.  
for country in fatal_df.country.unique():
    for quarter in fatal_df.yyyy_qq.unique():
        for key in age_buckets_dict:
            try:
                fatal_df.loc[(fatal_df["country"] == country) & (fatal_df["yyyy_qq"] == quarter),
                             "unpaid_work_loss_"+str(key)] = coverage.loc[(coverage["country"] == country)
                             & (coverage["yyyy_qq"] == quarter), "prop_"+str(key)].values[0]*age_specific_df.loc[
                             (age_specific_df["country"] == country) & (age_specific_df["first_age"] == key), 
                             "fatal_unpaid_loss"].values[0]
                pass
            except:
                continue
         
fatal_df["fatal_unpaid_work_loss"] = fatal_df.filter(regex = "^unpaid_work_loss_").sum(axis = 1)

unpaid_losses = fatal_df[["country", "yyyy_qq", "fatal_unpaid_work_loss"]]
unpaid_losses = unpaid_losses.merge(unpaid_disability[["country", "yyyy_qq", "nonfatal_unpaid_work_loss",
                                            "asymp_cost", "mild_cost", "severe_cost",
                                            "critical_cost"]], on = ["country", "yyyy_qq"],
                                how = "outer")

# %% combine everything into one file

indirect_costs= paid_losses[["country", "yyyy_qq", "fatal_paid_work_loss",
                             "nonfatal_paid_work_loss"]].merge(unpaid_losses[[
                                 "country", "yyyy_qq", "fatal_unpaid_work_loss",
                                 "nonfatal_unpaid_work_loss"]], how = "outer", on = [
                                     "country", "yyyy_qq"])
                                     
indirect_costs["indirect_cost_nonfatal"] = indirect_costs["nonfatal_paid_work_loss"] + indirect_costs["nonfatal_unpaid_work_loss"]                   
indirect_costs["indirect_cost_fatal"] = indirect_costs["fatal_paid_work_loss"] + indirect_costs["fatal_unpaid_work_loss"]                   
indirect_costs = indirect_costs[["country", "yyyy_qq", "indirect_cost_nonfatal", "indirect_cost_fatal", "nonfatal_paid_work_loss", "nonfatal_unpaid_work_loss", "fatal_paid_work_loss", "fatal_unpaid_work_loss"]]
indirect_costs.to_excel("../output/indirect_costs_jk_nodsct.xlsx", index = False)

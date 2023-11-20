# -*- coding: utf-8 -*-
"""
fullincome.py: Calculates full income using time use, per capita GDP, and hourly wages.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 12 April 2023
__updated__ = 15 November 2023

inputs:
    - time_use_processed_ihme.xlsx (processed file; created in time_use.py)
    - final_pcgni_current_2019USD.dta (processed file; created in pc_income_current_2019USD.do)
    - hrly_wage_2019USD_final.dta (processed file; created in make_hrly_wage_2019USD.do)
   
outputs:
    - fullincome.xlsx
"""
# %% load in packages
import pandas as pd
import numpy as np

# %% calculate full income

# load in time use data
time_use = pd.read_excel("../output/time_use_processed_ihme.xlsx")
# load in gross national income data
gni = pd.read_stata("../input/final_pcgni_current_2019USD.dta")
# load in hourly wage data
wages = pd.read_stata("../input/hrly_wage_2019USD_final.dta")

# retain nonmarket time from the time use data
nonmarket_df = time_use[["country", "nonmarket time"]]
# calculate nonmarket time in hours per year
nonmarket_df["yearly_nonmarket"] = (nonmarket_df["nonmarket time"]/60)*365
# retain per capita GNI variable
gni_df = gni[["country", "pcgni_current_2019USD"]].rename(columns = {"pcgni_current_2019USD": "pcgni"})
# retain hourly wage variable
wages_df = wages[["country", "hrly_wage_2019USD"]].rename(columns = {"hrly_wage_2019USD": "wage"})

# create a data frame with nonmarket time, pcgni, and hourly wage
fullincome_df = gni_df.merge(wages_df, on = "country")
fullincome_df = fullincome_df.merge(nonmarket_df, on = "country")

# calculate full income as the sum of pcgni and yearly nonmarket time value
fullincome_df["fullincome"] = fullincome_df["pcgni"] + (fullincome_df["wage"]*fullincome_df["yearly_nonmarket"])

# save to an Excel file
fullincome_df.to_excel("../output/fullincome.xlsx", index = False)

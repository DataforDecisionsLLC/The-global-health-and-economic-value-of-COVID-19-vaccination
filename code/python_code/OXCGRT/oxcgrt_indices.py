# -*- coding: utf-8 -*-
"""
oxcgrt_indices.py: Formats Oxford COVID Government Response Tracker data

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 11 August 2023
__updated__ = 16 November 2023

inputs:
    - OxCGRT_timeseries_all.xlsx (raw file)
    - sur_recursive_and_gdp_subsamples_output.dta (processed file; created in sur_recursive_and_gdp_subsamples.py)
   
outputs:
    - oxcgrt_si_chi_gri.xlsx
"""

import pandas as pd
import numpy as np

si = pd.read_excel("../input/OxCGRT_timeseries_all.xlsx", sheet_name="stringency_index_avg")
si.name = "si"
chi = pd.read_excel("../input/OxCGRT_timeseries_all.xlsx", sheet_name="containment_health_index_avg")
chi.name = "chi"
gri = pd.read_excel("../input/OxCGRT_timeseries_all.xlsx", sheet_name="government_response_index_avg")
gri.name = "gri"

def format_indices(df):
    _df = df[df["jurisdiction"] == "NAT_TOTAL"]
    _df["2020_Q1"] = _df.loc[:, "01Jan2020":"31Mar2020"].mean(axis=1)
    _df["2020_Q2"] = _df.loc[:, "01Apr2020":"30Jun2020"].mean(axis=1)
    _df["2020_Q3"] = _df.loc[:, "01Jul2020":"30Sep2020"].mean(axis=1)
    _df["2020_Q4"] = _df.loc[:, "01Oct2020":"31Dec2020"].mean(axis=1)
    _df["2021_Q1"] = _df.loc[:, "01Jan2021":"31Mar2021"].mean(axis=1)
    _df["2021_Q2"] = _df.loc[:, "01Apr2021":"30Jun2021"].mean(axis=1)
    _df["2021_Q3"] = _df.loc[:, "01Jul2021":"30Sep2021"].mean(axis=1)
    _df["2021_Q4"] = _df.loc[:, "01Oct2021":"31Dec2021"].mean(axis=1)
    _df["2022_Q1"] = _df.loc[:, "01Jan2022":"31Mar2022"].mean(axis=1)
    _df["2022_Q2"] = _df.loc[:, "01Apr2022":"30Jun2022"].mean(axis=1)
    df_long = pd.melt(_df, id_vars='country_name', value_vars=["2020_Q1","2020_Q2",
                        "2020_Q3","2020_Q4","2021_Q1","2021_Q2","2021_Q3",
                        "2021_Q4","2022_Q1","2022_Q2"])
    df_long = df_long.rename(columns={"value": df.name})
    df_long = df_long.rename(columns = {"country_name": "country", "variable": "yyyy_qq"})
    return df_long

si_long = format_indices(si)
chi_long = format_indices(chi)
gri_long = format_indices(gri)

oxcgrt = si_long.merge(chi_long, how = "outer", on = ["country", "yyyy_qq"])
oxcgrt = oxcgrt.merge(gri_long, how = "outer", on = ["country", "yyyy_qq"])

oxcgrt_na = oxcgrt[(oxcgrt["si"].isna()) | (oxcgrt["chi"].isna()) | (oxcgrt["gri"].isna())]
oxcgrt_na = oxcgrt_na.sort_values(["country", "yyyy_qq"])

ihme_countries = pd.read_excel("../output/sur_recursive_and_gdp_subsamples_output.xlsx", sheet_name="country_quarter_vov")
ihme_countries = ihme_countries[["country", "yyyy_qq"]]

oxcgrt = oxcgrt.replace({"Czech Republic": "Czechia", "Kyrgyz Republic":"Kyrgyzstan", "Slovak Republic": "Slovakia"})

oxcgrt_ihme = ihme_countries.merge(oxcgrt, how = "left", on = ["country", "yyyy_qq"])

quarterly_avg = oxcgrt.groupby("yyyy_qq")[["si", "chi", "gri"]].mean()

for c in oxcgrt.country.unique():
    for var in ["si", "chi", "gri"]:
        oxcgrt.loc[oxcgrt["country"] == c, "L1_" + var] = oxcgrt.loc[oxcgrt["country"] == c, var].shift(1, fill_value = 0)

oxcgrt = oxcgrt.sort_values(["country", "yyyy_qq"])
oxcgrt.to_excel("../output/oxcgrt_si_chi_gri.xlsx", index = False)

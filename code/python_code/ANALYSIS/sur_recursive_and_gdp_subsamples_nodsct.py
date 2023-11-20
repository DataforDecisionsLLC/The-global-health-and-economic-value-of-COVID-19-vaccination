# -*- coding: utf-8 -*-
"""
sur_recursive_and_gdp_subsamples_nodsct.py: Performing the regression and valuation.
    
Please refer to sur_recursive_and_gdp_subsamples.py for detailed comments.
Note that the only difference is that this file uses 0% discount rates instead
of 3%.

__author__ = Joseph Knee
__email__ = jknee@datafordecisions.net
__created__ = 15 August 2023
__updated__ = 16 November 2023

"""
import numpy as np
import pandas as pd
import xlsxwriter
from linearmodels.system import SUR
from scipy.stats import multivariate_normal
import statsmodels.api as sm
import statsmodels.stats.api as sms
from statsmodels.compat import lzip
import statsmodels.formula.api as smf
from math import lcm

pd.options.display.float_format = '{:.2f}'.format

# %% load in and format any data
qdata = pd.read_excel("../output/ihme_quarterly_regbase_boosters.xlsx")
oxcgrt = pd.read_excel("../output/oxcgrt_si_chi_gri.xlsx")

var_names = ["country_group", "time"]
for var in var_names:
    qdata[var] = pd.Categorical(qdata[var])

gdp_usd = pd.read_excel("../output/gdp_usd_ihme.xlsx")
gdp_usd["yyyy_qq"] = gdp_usd["date"].str[:4] + "_" + gdp_usd["date"].str[4:]
qdata = qdata.merge(gdp_usd[["country", "yyyy_qq", "gdp_projected_usd", "gdp_observed_usd", "loss", "type"]],
                    on = ["country", "yyyy_qq"], how = "left")

qdata = qdata[qdata["year"] != 2022]

qalys = pd.read_excel("../output/qaly_losses_overall_nodsct.xlsx")
qalys = qalys[["country", "yyyy_qq", "Q_nonfatal", "Q_fatal", "Q_overall"]]

fullincome = pd.read_excel("../output/fullincome.xlsx")

direct_costs = pd.read_excel("../output/direct_costs_jk.xlsx")
indirect_costs = pd.read_excel("../output/indirect_costs_jk_nodsct.xlsx")
costs = direct_costs.merge(indirect_costs, on = ["country", "yyyy_qq"],
                           how = "outer")
costs = costs.replace(np.nan, 0)

osi = pd.read_stata("../input/owid_quarterly_mean_stringency_countries_w_pop_gt_1M.dta")
qdata = qdata.merge(osi, on = ["country", "yyyy_qq", "year", "quarter"], how = "left")

qdata_na = qdata[qdata["mean_index"].isna()]
qdata.loc[(qdata["country"].isin(["Lesotho", "South Sudan", "Tajikistan", "Yemen"])) & (qdata["yyyy_qq"] == "2020_Q1") & (qdata["mean_index"].isna()), "mean_index"] = 0

for c in qdata.country.unique():
    qdata["inf_abs"] = qdata["inf_mean"]*qdata["tot_pop"]
    qdata.loc[(qdata["country"] == c), "cum_inf"] = qdata.loc[(qdata["country"] == c), "inf_abs"].cumsum()
    qdata["cum_inf_pc"] = qdata["cum_inf"]/qdata["tot_pop"]
    for i in range(1, 9):
        lag_string = "L" + str(i) + "_" + "cum_inf_pc"
        qdata.loc[qdata["country"] == c, lag_string] = qdata.loc[qdata["country"] == c, "cum_inf_pc"].shift(i, fill_value = 0)
    for i in range(1, 9):
        lag_string = "L" + str(i) + "_" + "inf_pc"
        qdata.loc[qdata["country"] == c, lag_string] = qdata.loc[qdata["country"] == c, "inf_mean"].shift(i, fill_value = 0)

qdata = qdata.merge(oxcgrt, how = "left", on = ["country", "yyyy_qq"])

qdata = qdata[qdata["country"] != "Puerto Rico"]

quarterly_data = qdata[qdata["type"] == "quarterly"]

dropped = qdata.loc[qdata.index.difference(qdata.dropna(subset = ["inf_mean", "daily_deaths", "L1_gri"], how = "any").index)]

# %% seeming unrelated regressions

class SUR_model:
    def __init__(self):
        self.depvar = None
        self.data = None
        self.reg_data = None
        self.formulae = None
        self.model = None
        self.results = None
        self.params = None
        self.nopfz_uptake = None
        self.novax_uptake = None
        self.results_data = None
        self.n_samp = None
        self.percentiles_pfz = None
        self.percentiles_allvax = None
        self.outcome_list = None
        self.df_list = None
        self.nopfz_inf_lags = None
        self.novax_inf_lags = None
        self.comp_inf_lags = None
        self.bp_test_dep = None
        self.annual_data = None
        self.annual_formula = None
        self.annual_mod = None
        self.annual_results = None
        self.annual_results_data = None    
        self.annual_gdp_list = None
        self.annual_gdp_df_list = None

    def run_quarterly_basecase(self, depvar="inf_mean", data = qdata):
        self.depvar = depvar
        self.data = data
        #drop countries from the regression base file that don't have data
        inf_data = data.dropna(subset = ["inf_mean", "daily_deaths", "L1_gri"], how = "any").reset_index(drop = True)
        
        #set up and run the regression
        formulae = {'infections': 'inf_mean ~ 1 + L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq',
                    'deaths': 'daily_deaths ~ 1 + L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq'}
        self.formulae = formulae
        
        inf_model = SUR.from_formula(formulae, inf_data)
        inf_sur = inf_model.fit(method = "ols", cov_type = "robust")
        
        #extract the mean parameter coefficients and covariance matrix from regression
        inf_params = inf_sur.params
        
        #label the columns in the design matrix
        inf_exog = pd.DataFrame(inf_sur.model._exog[0].ndarray)
        inf_exog.columns = [x for x in inf_params.index if "infections_" in x]
        
        q_dict = {"2020_Q4" : ["2021_Q2", "2021_Q3", "2021_Q4"],
                  "2021_Q1" : ["2021_Q3", "2021_Q4"],
                  "2021_Q2": ["2021_Q4"],
                  "2021_Q3": [""],
                  "2021_Q4": [""]}
        
        q_list = list(q_dict.keys())
        #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
        nopfz_inf = inf_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in inf_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x]:
            nopfz_inf[col] = 0
        
        for c in inf_data.country.unique():
            try:
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake_pfizer.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = nopfz_inf.loc[(nopfz_inf[("infections_country[T." + c + "]")] == 1) & (nopfz_inf[("infections_yyyy_qq[T." + first_vax + "]")] == 1), ("infections_L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    nopfz_inf.loc[(nopfz_inf[("infections_country[T." + c + "]")] == 1) & (nopfz_inf[("infections_yyyy_qq[T." + val + "]")] == 1), ("infections_L1_gri")] = country_fixed_gri
            except:
                continue
        
        #create a "novax" design matrix (i.e., to set vax parameters to 0)
        novax_inf = inf_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in inf_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x or
                    "L1_uptake_notpfz" in x or "L2_cum_uptake_notpfz" in x]:
            novax_inf[col] = 0
        
        for c in inf_data.country.unique():
            try:
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = novax_inf.loc[(novax_inf[("infections_country[T." + c + "]")] == 1) & (novax_inf[("infections_yyyy_qq[T." + first_vax + "]")] == 1), ("infections_L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    novax_inf.loc[(novax_inf[("infections_country[T." + c + "]")] == 1) & (novax_inf[("infections_yyyy_qq[T." + val + "]")] == 1), ("infections_L1_gri")] = country_fixed_gri
            except:
                continue
           
        inf_betas = inf_params.loc[[x for x in inf_params.index if "infections_" in x],]
        
        for c in inf_data.country.unique():
            try:
                country_string = "infections_country[T." + c + "]"
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake_pfizer.ne(0))).idxmax(), "yyyy_qq"]
                for val in q_dict[first_vax]:
                    nopfz_inf = nopfz_inf[[x for x in inf_params.index if "infections_" in x]]
                    nopfz_predictions = np.dot(nopfz_inf, inf_betas)
                    nopfz_inf["pred"] = nopfz_predictions
                    nopfz_inf = pd.concat([nopfz_inf, inf_data["tot_pop"]], axis = 1)
                    q_string = "infections_yyyy_qq[T." + val + "]"
                    try:
                        nopfz_inf.loc[(nopfz_inf[country_string] == 1) & (nopfz_inf[q_string] == 1), ("infections_L1_inf_pc")] = nopfz_inf.loc[(nopfz_inf[country_string] == 1), "pred"].shift(1, fill_value = 0)
                        nopfz_inf.loc[(nopfz_inf[country_string] == 1), "L1_tot_pop"] = nopfz_inf.loc[(nopfz_inf[country_string] == 1), "tot_pop"].shift(1, fill_value = 1)
                        nopfz_inf["L1_abs"] = nopfz_inf["infections_L1_inf_pc"]*nopfz_inf["L1_tot_pop"]
                        nopfz_inf.loc[(nopfz_inf[country_string] == 1), "L1_cuml"] = nopfz_inf.loc[(nopfz_inf[country_string] == 1), "L1_abs"].cumsum()
                        nopfz_inf["pred_L1_cum_pc"] = nopfz_inf["L1_cuml"]/nopfz_inf["L1_tot_pop"]
                        nopfz_inf.loc[(nopfz_inf[country_string] == 1) & (nopfz_inf[q_string] == 1), ("infections_L2_cum_inf_pc")] = nopfz_inf.loc[(nopfz_inf[country_string] == 1), ("pred_L1_cum_pc")].shift(1, fill_value = 0)
                    except:
                        continue
            except:
                continue
        
        for c in inf_data.country.unique():
            try:
                country_string = "infections_country[T." + c + "]"
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake.ne(0))).idxmax(), "yyyy_qq"]
                for val in q_dict[first_vax]:
                    novax_inf = novax_inf[[x for x in inf_params.index if "infections_" in x]]
                    novax_predictions = np.dot(novax_inf, inf_betas)
                    novax_inf["pred"] = novax_predictions
                    novax_inf = pd.concat([novax_inf, inf_data["tot_pop"]], axis = 1)
                    q_string = "infections_yyyy_qq[T." + val + "]"
                    try:
                        novax_inf.loc[(novax_inf[country_string] == 1) & (novax_inf[q_string] == 1), ("infections_L1_inf_pc")] = novax_inf.loc[(novax_inf[country_string] == 1), "pred"].shift(1, fill_value = 0)
                        novax_inf.loc[(novax_inf[country_string] == 1), "L1_tot_pop"] = novax_inf.loc[(novax_inf[country_string] == 1), "tot_pop"].shift(1, fill_value = 1)
                        novax_inf["L1_abs"] = novax_inf["infections_L1_inf_pc"]*novax_inf["L1_tot_pop"]
                        novax_inf.loc[(novax_inf[country_string] == 1), "L1_cuml"] = novax_inf.loc[(novax_inf[country_string] == 1), "L1_abs"].cumsum()
                        novax_inf["pred_L1_cum_pc"] = novax_inf["L1_cuml"]/novax_inf["L1_tot_pop"]
                        novax_inf.loc[(novax_inf[country_string] == 1) & (novax_inf[q_string] == 1), ("infections_L2_cum_inf_pc")] = novax_inf.loc[(novax_inf[country_string] == 1), ("pred_L1_cum_pc")].shift(1, fill_value = 0)
                    except:
                        continue
            except:
                continue
        
        self.nopfz_inf_lags = nopfz_inf[["infections_L1_inf_pc", "infections_L2_cum_inf_pc"]]
        self.novax_inf_lags = novax_inf[["infections_L1_inf_pc", "infections_L2_cum_inf_pc"]]
        comp_inf_lags = inf_data[["country", "yyyy_qq", "L1_inf_pc", "L2_cum_inf_pc"]].join(self.nopfz_inf_lags, how = "outer")
        comp_inf_lags = comp_inf_lags.join(self.novax_inf_lags, how = "outer", lsuffix = "_nopfz", rsuffix = "_novax")
        self.comp_inf_lags = comp_inf_lags
        
        if depvar == "inf_mean" or depvar == "daily_deaths":
            reg_data = data.dropna(subset = ["inf_mean", "daily_deaths", "L1_gri"], how = "any").reset_index(drop = True)
            model = SUR.from_formula(formulae, reg_data)
            model_sur = model.fit(method = "ols", cov_type = "robust")
            mean_params = model_sur.params
            self.results = model_sur
        elif depvar == "gdp_gap":
            reg_data = data[data["type"] == "quarterly"]
            formula = "gdp_gap ~ L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq"
            model = smf.ols(formula, reg_data)
            model_res = model.fit(cov_type = "HC1")
            mean_params = model_res.params
            self.results = model_res
        
        self.reg_data = reg_data
        self.model = model
        
        self.params = mean_params
        
        if depvar == "inf_mean":
            prefix = "infections_"
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_sur.model._exog[0].ndarray)
            vax_exog.columns = [x for x in mean_params.index if prefix in x]
            resids = model_sur.resids["infections"]
            bp_test_names = ['Lagrange multiplier statistic', 'p-value',
             'f-value', 'f p-value']
            bp_test_result = sms.het_breuschpagan(resids, vax_exog)
            
            self.bp_test_dep = lzip(bp_test_names, bp_test_result)
        elif depvar == "daily_deaths":
            prefix = "deaths_"
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_sur.model._exog[1].ndarray)
            vax_exog.columns = [x for x in mean_params.index if prefix in x]
            resids = model_sur.resids["deaths"]
            bp_test_names = ['Lagrange multiplier statistic', 'p-value',
             'f-value', 'f p-value']
            bp_test_result = sms.het_breuschpagan(resids, vax_exog)
            
            self.bp_test_dep = lzip(bp_test_names, bp_test_result)
        elif depvar == "gdp_gap":
            prefix = ""
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_res.model.exog)
            #label the columns in the design matrix
            vax_exog.columns = mean_params.index   
        
        #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
        nopfz_exog = vax_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in vax_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x]:
            nopfz_exog[col] = 0
        
        for c in reg_data.country.unique():
            try:
                first_vax = reg_data.loc[((reg_data["country"] == c) & (reg_data.uptake_pfizer.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = nopfz_exog.loc[(nopfz_exog[(prefix + "country[T." + c + "]")] == 1) & (nopfz_exog[(prefix + "yyyy_qq[T." + first_vax + "]")] == 1), (prefix + "L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    nopfz_exog.loc[(nopfz_exog[(prefix + "country[T." + c + "]")] == 1) & (nopfz_exog[(prefix + "yyyy_qq[T." + val + "]")] == 1), (prefix + "L1_gri")] = country_fixed_gri
            except:
                continue

        #create a "novax" design matrix (i.e., to set vax parameters to 0)
        novax_exog = vax_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in vax_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x or
                    "L1_uptake_notpfz" in x or "L2_cum_uptake_notpfz" in x]:
            novax_exog[col] = 0

        for c in reg_data.country.unique():
            try:
                first_vax = reg_data.loc[((reg_data["country"] == c) & (reg_data.uptake.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = novax_exog.loc[(novax_exog[(prefix + "country[T." + c + "]")] == 1) & (novax_exog[(prefix + "yyyy_qq[T." + first_vax + "]")] == 1), (prefix + "L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    novax_exog.loc[(novax_exog[(prefix + "country[T." + c + "]")] == 1) & (novax_exog[(prefix + "yyyy_qq[T." + val + "]")] == 1), (prefix + "L1_gri")] = country_fixed_gri
            except:
                continue 
            
        betas = mean_params.loc[[x for x in mean_params.index if prefix in x],]
        
        #predict inf_mean values using the original design matrix and the i-th iteration of parameter estimates
        vax_predictions = np.dot(vax_exog, betas)
        
        if depvar == "inf_mean" or depvar == "daily_deaths":
            nopfz_exog[(prefix + "L1_inf_pc")] = nopfz_inf["infections_L1_inf_pc"]
            nopfz_exog[(prefix + "L2_cum_inf_pc")] = nopfz_inf["infections_L2_cum_inf_pc"]
            
            #predict inf_mean values using the nopfz design matrix and the i-th iteration of parameter estimates 
            novax_exog[(prefix + "L1_inf_pc")] = novax_inf["infections_L1_inf_pc"]
            novax_exog[(prefix + "L2_cum_inf_pc")] = novax_inf["infections_L2_cum_inf_pc"]
        elif depvar == "gdp_gap":
            matching_rows = list(inf_data[inf_data.isin(reg_data.to_dict(orient='list')).all(axis=1)].index)
            inf_in_nopfz = nopfz_inf.loc[matching_rows].reset_index()
            inf_in_novax = novax_inf.loc[matching_rows].reset_index()
            
            #predict inf_mean values using the nopfz design matrix and the i-th iteration of parameter estimates
            nopfz_exog[(prefix + "L1_inf_pc")] = inf_in_nopfz["infections_L1_inf_pc"]
            nopfz_exog[(prefix + "L2_cum_inf_pc")] = inf_in_nopfz["infections_L2_cum_inf_pc"]
            
            #predict inf_mean values using the nopfz design matrix and the i-th iteration of parameter estimates 
            novax_exog[(prefix + "L1_inf_pc")] = inf_in_novax["infections_L1_inf_pc"]
            novax_exog[(prefix + "L2_cum_inf_pc")] = inf_in_novax["infections_L2_cum_inf_pc"]
    
        nopfz_predictions = np.dot(nopfz_exog, betas)
        novax_predictions = np.dot(novax_exog, betas)
        
        #add the predictions to the data frame
        reg_data["pred_vax"] = vax_predictions
        reg_data["pred_nopfz"] = nopfz_predictions
        reg_data["pred_novax"] = novax_predictions
        if depvar == "inf_mean" or depvar == "daily_deaths":
            #calculate averted infections for each country-quarter
            reg_data[f"averted_{depvar}_pfz"] = (reg_data["pred_nopfz"] - reg_data["pred_vax"])*reg_data["tot_pop"]
            reg_data[f"averted_{depvar}_allvax"] = (reg_data["pred_novax"] - reg_data["pred_vax"])*reg_data["tot_pop"]
        else:
            reg_data[f"averted_{depvar}_pfz"] = (reg_data["pred_vax"] - reg_data["pred_nopfz"])*reg_data["gdp_projected_usd"]
            reg_data[f"averted_{depvar}_allvax"] = (reg_data["pred_vax"] - reg_data["pred_novax"])*reg_data["gdp_projected_usd"]
        self.results_data = reg_data
    
    def run_annual_gdp(self, data = qdata):        
        annual_data = qdata[qdata["type"] == "annual"]
        gdp_usd["year"] = gdp_usd["date"].str[:4].astype(int)
        pcgdp2019 = gdp_usd[(gdp_usd["year"] == 2019) & (gdp_usd["type"] == "annual")]
        pcgdp2019 = pcgdp2019.groupby("country")[["gdp_observed_usd"]].sum().reset_index()
        pcgdp2019 = pcgdp2019.rename(columns = {"gdp_observed_usd": "gdp2019"})
        pop2019 = pd.read_stata("../input/national_population_2019.dta")
        pcgdp2019 = pcgdp2019.merge(pop2019, how = "left", on = "country")
        pcgdp2019["pcgdp2019"] = pcgdp2019["gdp2019"]/pcgdp2019["tot_pop"]

        annual_data = annual_data.merge(pcgdp2019[["country", "pcgdp2019"]], how = "left", on = "country")
        
        annual_gaps = annual_data.groupby(["country", "year"])[["gdp_gap"]].mean().reset_index()

        # Pivot the DataFrame to have years as columns and 'value' as values
        annual_gaps = annual_gaps.pivot(index='country', columns='year', values='gdp_gap')

        # Calculate the difference between the years 2021 and 2020
        annual_gaps['g2021_g2020'] = annual_gaps[2021] - annual_gaps[2020]
        
        annual_data["n"] = annual_data["inf_mean"]*annual_data["tot_pop"]
        annual_data["d"] = annual_data["daily_deaths"]*annual_data["tot_pop"]

        for c in annual_data.country.unique():
            annual_data.loc[annual_data["country"] == c, "cn"] = annual_data.loc[annual_data["country"] == c, "n"].cumsum()
            annual_data.loc[annual_data["country"] == c, "cd"] = annual_data.loc[annual_data["country"] == c, "d"].cumsum()
        
        annual_data["cn"] = annual_data["cn"]/annual_data["tot_pop"]
        annual_data["cd"] = annual_data["cd"]/annual_data["tot_pop"]
        annual_data["cv_np"] = annual_data["cum_uptake_notpfz"]
        annual_data["cv_p"] = annual_data["cum_uptake_pfizer"]
        annual_countries = annual_data.loc[(annual_data["yyyy_qq"] == "2021_Q1") & (annual_data["cum_uptake"] > 0), "country"].unique()
        annual_data = annual_data[annual_data.country.isin(annual_countries)]

        annual_data2021Q4 = annual_data[annual_data["yyyy_qq"] == "2021_Q4"]
        annual_data2020Q4 = annual_data[annual_data["yyyy_qq"] == "2020_Q4"]


        annual_reg_df = annual_gaps.merge(annual_data2021Q4[["country", "cv_np", "cv_p"]], on = "country", how = "outer")
        annual_reg_df = annual_reg_df.merge(annual_data2020Q4[["country", "cn", "cd"]], on = "country", how = "outer")

        annual_reg_df = annual_reg_df.rename(columns = {2020: "g2020", 2021: "g2021", "cv_np": "cv_np2021Q4",  "cv_p": "cv_p2021Q4", "cn": "cn2020Q4", "cd": "cd2020Q4"})
        annual_reg_df = annual_reg_df.dropna(subset = ["g2021", "g2020", "cv_np2021Q4", "cv_p2021Q4", "cn2020Q4"], how = "any").reset_index(drop = True)

        formula = "g2021_g2020 ~ g2020 + cv_np2021Q4 + cv_p2021Q4 + cn2020Q4"
        annual_gdp_mod = smf.ols(formula, annual_reg_df)
        annual_gdp_res = annual_gdp_mod.fit(cov_type = "HC1")
        
        self.annual_data = annual_data
        self.annual_formula = formula
        self.annual_mod = annual_gdp_mod
        self.annual_results = annual_gdp_res
        
        annual_reg_df["g2021_g2020_vax"] = annual_gdp_res.predict(annual_reg_df)
        
        nopfz_annual = annual_reg_df.copy()
        nopfz_annual["cv_p2021Q4"] = 0
        nopfz_annual["g2021_g2020_nopfz"] = annual_gdp_res.predict(nopfz_annual)
        
        novax_annual = nopfz_annual.copy()
        novax_annual["cv_np2021Q4"] = 0
        novax_annual["cv_p2021Q4"] = 0
        novax_annual["g2021_g2020_novax"] = annual_gdp_res.predict(novax_annual)
        
        gdp2021 = gdp_usd[gdp_usd["year"] == 2021]
        gdp2021 = gdp2021.groupby("country")[["gdp_projected_usd"]].sum().reset_index()
        gdp_value = novax_annual.merge(gdp2021, on = "country", how = "left")
        
        gdp_value["gdp_vax"] = (gdp_value["g2021_g2020_vax"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
        gdp_value["gdp_novax"] = (gdp_value["g2021_g2020_novax"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
        gdp_value["gdp_nopfz"] = (gdp_value["g2021_g2020_nopfz"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
        
        gdp_value["gdp_allvax"] = gdp_value["gdp_vax"] - gdp_value["gdp_novax"]
        gdp_value["gdp_pfizer"] = gdp_value["gdp_vax"] - gdp_value["gdp_nopfz"]
        
        self.annual_results_data = gdp_value        

    def run_quarterly_psa(self, depvar="inf_mean", data = qdata, n_samp = 1000):
        self.n_samp = n_samp
        #drop countries from the regression base file that don't have data
        inf_data = data.dropna(subset = ["inf_mean", "daily_deaths", "L1_gri"], how = "any").reset_index(drop = True)
        
        #set up and run the regression
        formulae = {'infections': 'inf_mean ~ 1 + L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq',
                    'deaths': 'daily_deaths ~ 1 + L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq'}
        
        inf_model = SUR.from_formula(formulae, inf_data)
        inf_sur = inf_model.fit(method = "ols", cov_type = "robust")
        
        #extract the mean parameter coefficients and covariance matrix from regression
        inf_params = inf_sur.params
        inf_cov = inf_sur.cov
        
        #using those parameters, take 10000 draws of parameter estimates from a multivariate normal distribution
        mvn_inf = multivariate_normal(mean = inf_params, cov = inf_cov, allow_singular = True, seed = 102015)
        inf_samples = pd.DataFrame(mvn_inf.rvs(size = n_samp)).T
        inf_samples.index = inf_params.index
        
        #label the columns in the design matrix
        inf_exog = pd.DataFrame(inf_sur.model._exog[0].ndarray)
        inf_exog.columns = [x for x in inf_params.index if "infections_" in x]       
        
        q_dict = {"2020_Q4" : ["2021_Q2", "2021_Q3", "2021_Q4"],
                  "2021_Q1" : ["2021_Q3", "2021_Q4"],
                  "2021_Q2": ["2021_Q4"],
                  "2021_Q3": [""],
                  "2021_Q4": [""]}
        
        q_list = list(q_dict.keys())
        #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
        nopfz_inf = inf_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in inf_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x]:
            nopfz_inf[col] = 0
        
        for c in inf_data.country.unique():
            try:
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake_pfizer.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = nopfz_inf.loc[(nopfz_inf[("infections_country[T." + c + "]")] == 1) & (nopfz_inf[("infections_yyyy_qq[T." + first_vax + "]")] == 1), ("infections_L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    nopfz_inf.loc[(nopfz_inf[("infections_country[T." + c + "]")] == 1) & (nopfz_inf[("infections_yyyy_qq[T." + val + "]")] == 1), ("infections_L1_gri")] = country_fixed_gri
            except:
                continue
        
        #create a "novax" design matrix (i.e., to set vax parameters to 0)
        novax_inf = inf_exog.copy()
        #set those vax parameters to 0.
        for col in [x for x in inf_exog.columns if "L1_uptake_pfizer" in x or "L2_cum_uptake_pfizer" in x or
                    "L1_uptake_notpfz" in x or "L2_cum_uptake_notpfz" in x]:
            novax_inf[col] = 0
        
        for c in inf_data.country.unique():
            try:
                first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake.ne(0))).idxmax(), "yyyy_qq"]
                country_fixed_gri = novax_inf.loc[(novax_inf[("infections_country[T." + c + "]")] == 1) & (novax_inf[("infections_yyyy_qq[T." + first_vax + "]")] == 1), ("infections_L1_gri")].values[0]
                for val in q_list[q_list.index(first_vax): ]:
                    novax_inf.loc[(novax_inf[("infections_country[T." + c + "]")] == 1) & (novax_inf[("infections_yyyy_qq[T." + val + "]")] == 1), ("infections_L1_gri")] = country_fixed_gri
            except:
                continue
           
        #loop over each of the 1,000 iterations of parameter estimates
        inf_samples = inf_samples.loc[[x for x in inf_samples.index if "infections_" in x],]
        
        if depvar == "inf_mean" or depvar == "daily_deaths":
            reg_data = data.dropna(subset = ["inf_mean", "daily_deaths", "L1_gri"], how = "any").reset_index(drop = True)
            model = SUR.from_formula(formulae, reg_data)
            model_sur = model.fit(method = "ols", cov_type = "robust")
            mean_params = model_sur.params
            cov_params = model_sur.cov
            
        elif depvar == "gdp_gap":
            reg_data = data[data["type"] == "quarterly"]
            formula = "gdp_gap ~ L1_uptake_pfizer + L2_cum_uptake_pfizer + L1_uptake_notpfz + L2_cum_uptake_notpfz + L1_gri + L1_inf_pc + L2_cum_inf_pc + country + yyyy_qq"
            model = smf.ols(formula = formula, data = reg_data, missing = "drop")
            model_res = model.fit(cov_type="HC1")
            mean_params = model_res.params
            cov_params = model_res.cov_params()
        
        #using those parameters, take 10000 draws of parameter estimates from a multivariate normal distribution
        mvn = multivariate_normal(mean = mean_params, cov = cov_params, allow_singular = True, seed = 102015)
        samples = pd.DataFrame(mvn.rvs(size = n_samp)).T
        samples.index = mean_params.index
        
        if depvar == "inf_mean":
            prefix = "infections_"
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_sur.model._exog[0].ndarray)
            vax_exog.columns = [x for x in mean_params.index if prefix in x]
            
        elif depvar == "daily_deaths":
            prefix = "deaths_"
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_sur.model._exog[1].ndarray)
            vax_exog.columns = [x for x in mean_params.index if prefix in x]
            
        elif depvar == "gdp_gap":
            prefix = ""
            #grab the design matrix from the model
            vax_exog = pd.DataFrame(model_res.model.exog)
            #label the columns in the design matrix
            vax_exog.columns = mean_params.index   
            
        #create an empty list to put in values of estimated averted outcome
        averted_outcome_list = list([[], []])
        averted_df_list = list([[], []])
        #loop over each of the 1,000 iterations of parameter estimates
        dep_samples = samples.loc[[x for x in samples.index if prefix in x],]
        inf_samples = inf_samples.loc[[x for x in inf_samples.index if "infections_" in x],]
        
        for i in dep_samples.columns: 
            nopfz_inf_iter = nopfz_inf.copy()
            novax_inf_iter = novax_inf.copy()
            for c in inf_data.country.unique():
                try:
                    country_string = "infections_country[T." + c + "]"
                    first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake_pfizer.ne(0))).idxmax(), "yyyy_qq"]
                    for val in q_dict[first_vax]:
                        nopfz_inf_iter = nopfz_inf_iter[[x for x in inf_params.index if "infections_" in x]]
                        nopfz_predictions = np.dot(nopfz_inf_iter, inf_samples[i])
                        nopfz_inf_iter["pred"] = nopfz_predictions
                        nopfz_inf_iter = pd.concat([nopfz_inf_iter, inf_data["tot_pop"]], axis = 1)
                        q_string = "infections_yyyy_qq[T." + val + "]"
                        try:
                            nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1) & (nopfz_inf_iter[q_string] == 1), ("infections_L1_inf_pc")] = nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), "pred"].shift(1, fill_value = 0)
                            nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), "L1_tot_pop"] = nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), "tot_pop"].shift(1, fill_value = 1)
                            nopfz_inf_iter["L1_abs"] = nopfz_inf_iter["infections_L1_inf_pc"]*nopfz_inf_iter["L1_tot_pop"]
                            nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), "L1_cuml"] = nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), "L1_abs"].cumsum()
                            nopfz_inf_iter["pred_L1_cum_pc"] = nopfz_inf_iter["L1_cuml"]/nopfz_inf_iter["L1_tot_pop"]
                            nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1) & (nopfz_inf_iter[q_string] == 1), ("infections_L2_cum_inf_pc")] = nopfz_inf_iter.loc[(nopfz_inf_iter[country_string] == 1), ("pred_L1_cum_pc")].shift(1, fill_value = 0)
                        except:
                            continue
                except:
                    continue
            
            for c in inf_data.country.unique():
                try:
                    country_string = "infections_country[T." + c + "]"
                    first_vax = inf_data.loc[((inf_data["country"] == c) & (inf_data.uptake.ne(0))).idxmax(), "yyyy_qq"]
                    for val in q_dict[first_vax]:
                        novax_inf_iter = novax_inf_iter[[x for x in inf_params.index if "infections_" in x]]
                        novax_predictions = np.dot(novax_inf_iter, inf_samples[i])
                        novax_inf_iter["pred"] = novax_predictions
                        novax_inf_iter = pd.concat([novax_inf_iter, inf_data["tot_pop"]], axis = 1)
                        q_string = "infections_yyyy_qq[T." + val + "]"
                        try:
                            novax_inf_iter.loc[(novax_inf_iter[country_string] == 1) & (novax_inf_iter[q_string] == 1), ("infections_L1_inf_pc")] = novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), "pred"].shift(1, fill_value = 0)
                            novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), "L1_tot_pop"] = novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), "tot_pop"].shift(1, fill_value = 1)
                            novax_inf_iter["L1_abs"] = novax_inf_iter["infections_L1_inf_pc"]*novax_inf_iter["L1_tot_pop"]
                            novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), "L1_cuml"] = novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), "L1_abs"].cumsum()
                            novax_inf_iter["pred_L1_cum_pc"] = novax_inf_iter["L1_cuml"]/novax_inf_iter["L1_tot_pop"]
                            novax_inf_iter.loc[(novax_inf_iter[country_string] == 1) & (novax_inf_iter[q_string] == 1), ("infections_L2_cum_inf_pc")] = novax_inf_iter.loc[(novax_inf_iter[country_string] == 1), ("pred_L1_cum_pc")].shift(1, fill_value = 0)
                        except:
                            continue
                except:
                    continue
            
            if depvar == "inf_mean" or depvar == "daily_deaths":
                #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
                nopfz_exog = nopfz_inf_iter.copy()
                #set those vax parameters to 0.
                nopfz_exog = nopfz_exog[[x for x in mean_params.index if "infections_" in x]]
                nopfz_exog.columns = nopfz_exog.columns.str.replace("infections_", prefix)
                
                #create a "novax" design matrix (i.e., to set vax parameters to 0)
                novax_exog = novax_inf_iter.copy()
                #set those vax parameters to 0.
                novax_exog = novax_exog[[x for x in mean_params.index if "infections_" in x]]
                novax_exog.columns = novax_exog.columns.str.replace("infections_", prefix)
                
            elif depvar == "gdp_gap":
                matching_rows = list(inf_data[inf_data.isin(reg_data.to_dict(orient='list')).all(axis=1)].index)
                inf_in_nopfz = nopfz_inf_iter.loc[matching_rows].reset_index()
                inf_in_novax = novax_inf_iter.loc[matching_rows].reset_index()
                
                #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
                nopfz_exog = inf_in_nopfz.copy()
                #set those vax parameters to 0.
                nopfz_exog.columns = nopfz_exog.columns.str.replace("infections_", prefix)
                nopfz_exog = nopfz_exog[[x for x in mean_params.index if prefix in x]]
                
                #create a "novax" design matrix (i.e., to set vax parameters to 0)
                novax_exog = inf_in_novax.copy()
                #set those vax parameters to 0.
                novax_exog.columns = novax_exog.columns.str.replace("infections_", prefix)
                novax_exog = novax_exog[[x for x in mean_params.index if prefix in x]]
            
            #predict inf_mean values using the original design matrix and the i-th iteration of parameter estimates
            vax_predictions = np.dot(vax_exog, dep_samples[i])   
            #predict inf_mean valeus using the nopfz design matrix and the i-th iteration of parameter estimates 
            nopfz_predictions = np.dot(nopfz_exog, dep_samples[i])
            #predict inf_mean valeus using the nopfz design matrix and the i-th iteration of parameter estimates
            novax_predictions = np.dot(novax_exog, dep_samples[i])
            #add the predictions to the data frame
            reg_data["pred_vax"] = vax_predictions
            reg_data["pred_nopfz"] = nopfz_predictions
            reg_data["pred_novax"] = novax_predictions
            if depvar == "inf_mean" or depvar == "daily_deaths":
                #calculate averted infections for each country-quarter
                reg_data[f"averted_{depvar}_pfz"] = (reg_data["pred_nopfz"] - reg_data["pred_vax"])*reg_data["tot_pop"]
                reg_data[f"averted_{depvar}_allvax"] = (reg_data["pred_novax"] - reg_data["pred_vax"])*reg_data["tot_pop"]
            else:
                reg_data[f"averted_{depvar}_pfz"] = (reg_data["pred_vax"] - reg_data["pred_nopfz"])*reg_data["gdp_projected_usd"]
                reg_data[f"averted_{depvar}_allvax"] = (reg_data["pred_vax"] - reg_data["pred_novax"])*reg_data["gdp_projected_usd"]
            #add df values to the df list
            averted_df_list[0].append(pd.DataFrame(reg_data[["country", "yyyy_qq", f"averted_{depvar}_pfz"]]))
            averted_df_list[1].append(pd.DataFrame(reg_data[["country", "yyyy_qq", f"averted_{depvar}_allvax"]]))
            #sum over all country-quarters to get total averted infections in the i-th iteration
            averted_pfz = reg_data[f"averted_{depvar}_pfz"].sum()
            averted_allvax = reg_data[f"averted_{depvar}_allvax"].sum()
            #add the i-th value of averted infections to the list of averted infections
            averted_outcome_list[0].append(averted_pfz)
            averted_outcome_list[1].append(averted_allvax)
        #after the for loop finishes, we have 10,000 values of estimated averted infections in our list.
        #find the 2.5th and 97.5th percentile values among these 10,000 to get the 95% interval.
        self.percentiles_pfz = np.percentile(averted_outcome_list[0], [2.5, 50, 97.5])
        self.percentiles_allvax = np.percentile(averted_outcome_list[1], [2.5, 50, 97.5])
        self.outcome_list = averted_outcome_list
        self.df_list = averted_df_list

    def run_annual_gdp_psa(self, data, n_samp = 1000):
        annual_data = qdata[qdata["type"] == "annual"]
        gdp_usd["year"] = gdp_usd["date"].str[:4].astype(int)
        pcgdp2019 = gdp_usd[(gdp_usd["year"] == 2019) & (gdp_usd["type"] == "annual")]
        pcgdp2019 = pcgdp2019.groupby("country")[["gdp_observed_usd"]].sum().reset_index()
        pcgdp2019 = pcgdp2019.rename(columns = {"gdp_observed_usd": "gdp2019"})
        pop2019 = pd.read_stata("../input/national_population_2019.dta")
        pcgdp2019 = pcgdp2019.merge(pop2019, how = "left", on = "country")
        pcgdp2019["pcgdp2019"] = pcgdp2019["gdp2019"]/pcgdp2019["tot_pop"]

        annual_data = annual_data.merge(pcgdp2019[["country", "pcgdp2019"]], how = "left", on = "country")
        
        annual_gaps = annual_data.groupby(["country", "year"])[["gdp_gap"]].mean().reset_index()

        # Pivot the DataFrame to have years as columns and 'value' as values
        annual_gaps = annual_gaps.pivot(index='country', columns='year', values='gdp_gap')

        # Calculate the difference between the years 2021 and 2020
        annual_gaps['g2021_g2020'] = annual_gaps[2021] - annual_gaps[2020]
        
        annual_data["n"] = annual_data["inf_mean"]*annual_data["tot_pop"]
        annual_data["d"] = annual_data["daily_deaths"]*annual_data["tot_pop"]

        for c in annual_data.country.unique():
            annual_data.loc[annual_data["country"] == c, "cn"] = annual_data.loc[annual_data["country"] == c, "n"].cumsum()
            annual_data.loc[annual_data["country"] == c, "cd"] = annual_data.loc[annual_data["country"] == c, "d"].cumsum()
        
        annual_data["cn"] = annual_data["cn"]/annual_data["tot_pop"]
        annual_data["cd"] = annual_data["cd"]/annual_data["tot_pop"]
        annual_data["cv_np"] = annual_data["cum_uptake_notpfz"]
        annual_data["cv_p"] = annual_data["cum_uptake_pfizer"]
        annual_countries = annual_data.loc[(annual_data["yyyy_qq"] == "2021_Q1") & (annual_data["cum_uptake"] > 0), "country"].unique()
        annual_data = annual_data[annual_data.country.isin(annual_countries)]

        annual_data2021Q4 = annual_data[annual_data["yyyy_qq"] == "2021_Q4"]
        annual_data2020Q4 = annual_data[annual_data["yyyy_qq"] == "2020_Q4"]


        annual_reg_df = annual_gaps.merge(annual_data2021Q4[["country", "cv_np", "cv_p"]], on = "country", how = "outer")
        annual_reg_df = annual_reg_df.merge(annual_data2020Q4[["country", "cn", "cd"]], on = "country", how = "outer")

        annual_reg_df = annual_reg_df.rename(columns = {2020: "g2020", 2021: "g2021", "cv_np": "cv_np2021Q4",  "cv_p": "cv_p2021Q4", "cn": "cn2020Q4", "cd": "cd2020Q4"})
        annual_reg_df = annual_reg_df.dropna(subset = ["g2021", "g2020", "cv_np2021Q4", "cv_p2021Q4", "cn2020Q4"], how = "any").reset_index(drop = True)
        
        formula = "g2021_g2020 ~ g2020 + cv_np2021Q4 + cv_p2021Q4 + cn2020Q4"
        annual_gdp_mod = smf.ols(formula, annual_reg_df)
        annual_gdp_res = annual_gdp_mod.fit(cov_type = "HC1")
        
        #extract the mean parameter coefficients and covariance matrix from regression
        mean_params = annual_gdp_res.params
        cov_params = annual_gdp_res.cov_params()
        
        #using those parameters, take 10000 draws of parameter estimates from a multivariate normal distribution
        mvn = multivariate_normal(mean = mean_params, cov = cov_params, allow_singular = True, seed = 102015)
        samples = pd.DataFrame(mvn.rvs(size = n_samp)).T
        samples.index = mean_params.index
        
        #grab the design matrix from the model
        vax_exog = pd.DataFrame(annual_gdp_res.model.exog)
        #label the columns in the design matrix
        vax_exog.columns = mean_params.index
        
        #create an empty list to put in values of estimated averted outcome
        averted_outcome_list = list([[], []])
        averted_df_list = list([[], []])
        
        #loop over each of the 1,000 iterations of parameter estimates
        #create a "nopfz" design matrix (i.e., to set vax parameters to 0)
        nopfz_exog = vax_exog.copy()
        #set those vax parameters to 0.
        nopfz_exog["cv_p2021Q4"] = 0
        
        #create a "novax" design matrix (i.e., to set vax parameters to 0)
        novax_exog = vax_exog.copy()
        #set those vax parameters to 0.
        novax_exog["cv_p2021Q4"] = 0
        novax_exog["cv_np2021Q4"] = 0
        
        for i in samples.columns:
            #predict inf_mean values using the original design matrix and the i-th iteration of parameter estimates
            vax_predictions = np.dot(vax_exog, samples[i])   
            #predict inf_mean valeus using the nopfz design matrix and the i-th iteration of parameter estimates 
            nopfz_predictions = np.dot(nopfz_exog, samples[i])
            #predict inf_mean valeus using the nopfz design matrix and the i-th iteration of parameter estimates
            novax_predictions = np.dot(novax_exog, samples[i])
            
            #add the predictions to the data frame
            annual_reg_df["pred_vax"] = vax_predictions
            annual_reg_df["pred_nopfz"] = nopfz_predictions
            annual_reg_df["pred_novax"] = novax_predictions
            
            gdp2021 = gdp_usd[gdp_usd["year"] == 2021]
            gdp2021 = gdp2021.groupby("country")[["gdp_projected_usd"]].sum().reset_index()
            gdp_value = annual_reg_df.merge(gdp2021, on = "country", how = "left")
            
            gdp_value["gdp_vax"] = (gdp_value["pred_vax"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
            gdp_value["gdp_novax"] = (gdp_value["pred_novax"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
            gdp_value["gdp_nopfz"] = (gdp_value["pred_nopfz"]+gdp_value["g2020"])*gdp_value["gdp_projected_usd"]
            
            gdp_value["averted_gdp_gap_allvax"] = gdp_value["gdp_vax"] - gdp_value["gdp_novax"]
            gdp_value["averted_gdp_gap_pfz"] = gdp_value["gdp_vax"] - gdp_value["gdp_nopfz"]

            #add df values to the df list
            averted_df_list[0].append(pd.DataFrame(gdp_value[["country", "averted_gdp_gap_pfz"]]))
            averted_df_list[1].append(pd.DataFrame(gdp_value[["country", "averted_gdp_gap_allvax"]]))
            #sum over all country-quarters to get total averted infections in the i-th iteration
            averted_pfz = gdp_value["averted_gdp_gap_pfz"].sum()
            averted_allvax = gdp_value["averted_gdp_gap_allvax"].sum()
            #add the i-th value of averted infections to the list of averted infections
            averted_outcome_list[0].append(averted_pfz)
            averted_outcome_list[1].append(averted_allvax)
        #after the for loop finishes, we have 10,000 values of estimated averted infections in our list.
        #find the 2.5th and 97.5th percentile values among these 10,000 to get the 95% interval.
        self.annual_gdp_list = averted_outcome_list
        self.annual_gdp_df_list = averted_df_list
        
inf = SUR_model()
inf.run_quarterly_basecase(depvar="inf_mean", data = qdata)
inf_df = inf.results_data

deaths = SUR_model()
deaths.run_quarterly_basecase(depvar="daily_deaths", data = qdata)
death_df = deaths.results_data

gdp_q = SUR_model()
gdp_q.run_quarterly_basecase(depvar="gdp_gap", data = qdata)
gdp_q_df = gdp_q.results_data

gdp_a = SUR_model()
gdp_a.run_annual_gdp(data = qdata)
gdp_a_df = gdp_a.annual_results_data

combined_df = gdp_q_df[["country", "yyyy_qq", "averted_gdp_gap_pfz", "averted_gdp_gap_allvax"]].merge(death_df[["country", "yyyy_qq", "averted_daily_deaths_pfz", "averted_daily_deaths_allvax"]], how = "outer", on = ["country", "yyyy_qq"])
combined_df = combined_df.merge(inf_df, how = "outer", on = ["country", "yyyy_qq"])
combined_df = combined_df.merge(qalys, on = ["country", "yyyy_qq"], how = "left")
combined_df = combined_df.merge(costs, on = ["country", "yyyy_qq"], how = "left")
combined_df = combined_df.merge(fullincome, on = "country", how = "left")

def compute_vov(df):
    df["averted_nf_pfz"] = df["averted_inf_mean_pfz"] - df["averted_daily_deaths_pfz"]
    df["averted_nf_allvax"] = df["averted_inf_mean_allvax"] - df["averted_daily_deaths_allvax"]
    
    df["pfz_nonfatal_qalys"] = df["averted_nf_pfz"]*df["Q_nonfatal"]
    df["allvax_nonfatal_qalys"] = df["averted_nf_allvax"]*df["Q_nonfatal"]
    df["pfz_fatal_qalys"] = df["averted_daily_deaths_pfz"]*df["Q_fatal"]
    df["allvax_fatal_qalys"] = df["averted_daily_deaths_allvax"]*df["Q_fatal"]
    
    df["pfz_all_qalys"] = df["pfz_nonfatal_qalys"] + df["pfz_fatal_qalys"]
    df["allvax_all_qalys"] = df["allvax_nonfatal_qalys"] + df["allvax_fatal_qalys"]
    
    df["pfz_nonfatal_monetized_fullincome"] = df["pfz_nonfatal_qalys"]*df["fullincome"]
    df["allvax_nonfatal_monetized_fullincome"] = df["allvax_nonfatal_qalys"]*df["fullincome"]
    df["pfz_fatal_monetized_fullincome"] = df["pfz_fatal_qalys"]*df["fullincome"]
    df["allvax_fatal_monetized_fullincome"] = df["allvax_fatal_qalys"]*df["fullincome"]
    
    df["pfz_all_monetized_fullincome"] = df["pfz_nonfatal_monetized_fullincome"] + df["pfz_fatal_monetized_fullincome"]
    df["allvax_all_monetized_fullincome"] = df["allvax_nonfatal_monetized_fullincome"] + df["allvax_fatal_monetized_fullincome"]
        
    df["pfz_direct_costs"] = df["averted_inf_mean_pfz"]*df["nonfatal_los_cost"]
    df["pfz_indirect_costs_nonfatal"] = df["averted_nf_pfz"]*df["indirect_cost_nonfatal"]
    df["pfz_indirect_costs_fatal"] = df["averted_daily_deaths_pfz"]*df["indirect_cost_fatal"]

    df["allvax_direct_costs"] = df["averted_inf_mean_allvax"]*df["nonfatal_los_cost"]
    df["allvax_indirect_costs_nonfatal"] = df["averted_nf_allvax"]*df["indirect_cost_nonfatal"]
    df["allvax_indirect_costs_fatal"] = df["averted_daily_deaths_allvax"]*df["indirect_cost_fatal"]

    df["pfz_indirect_costs"] = df["pfz_indirect_costs_nonfatal"] + df["pfz_indirect_costs_fatal"]
    df["allvax_indirect_costs"] = df["allvax_indirect_costs_nonfatal"] + df["allvax_indirect_costs_fatal"]
    
    df["pfz_unpaid_loss_nonfatal"] = df["averted_nf_pfz"]*df["nonfatal_unpaid_work_loss"]
    df["pfz_averted_costs"] = df["pfz_unpaid_loss_nonfatal"] + df["pfz_direct_costs"]

    df["allvax_unpaid_loss_nonfatal"] = df["averted_nf_allvax"]*df["nonfatal_unpaid_work_loss"]
    df["allvax_averted_costs"] = df["allvax_unpaid_loss_nonfatal"] + df["allvax_direct_costs"]
    
    df["pfz_health_value"] = (df["pfz_all_monetized_fullincome"] + df["pfz_averted_costs"])
    df["allvax_health_value"] = (df["allvax_all_monetized_fullincome"] + df["allvax_averted_costs"])
        
    df["pfz_vov"] = (df["pfz_health_value"]).add(df["averted_gdp_gap_pfz"], fill_value=0)
    df["allvax_vov"] = (df["allvax_health_value"]).add(df["averted_gdp_gap_allvax"], fill_value=0)
    return df

vov_df = compute_vov(combined_df)
pfz_value = vov_df["pfz_vov"].sum()
allvax_value = vov_df["allvax_vov"].sum()
vov_df["uptake_pfizer_doses"] = vov_df["uptake_pfizer"]*vov_df["tot_pop"]
vov_df["uptake_doses"] = vov_df["uptake"]*vov_df["tot_pop"]

keep_cols = list(vov_df.loc[:, "averted_inf_mean_pfz":"allvax_vov"].columns) + list(["averted_gdp_gap_pfz",
                                           "averted_gdp_gap_allvax", "averted_daily_deaths_pfz",
                                           "averted_daily_deaths_allvax", "uptake_pfizer_doses",
                                           "uptake_doses"])
country_quarter_vov = vov_df.loc[:, (list(["country", "yyyy_qq"]) + list(keep_cols))]

country_vov = vov_df.groupby(["country"])[keep_cols].sum().reset_index()
country_vov = country_vov.merge(gdp_a_df[["country", "gdp_allvax", "gdp_pfizer"]], on = "country", how = "outer")
country_vov["pfz_full_vov"] = country_vov["pfz_vov"].add(country_vov["gdp_pfizer"], fill_value=0)
country_vov["allvax_full_vov"] = country_vov["allvax_vov"].add(country_vov["gdp_allvax"], fill_value=0)

keep_cols = list(keep_cols) + list(["pfz_full_vov", "allvax_full_vov", "uptake_pfizer_doses", "uptake_doses", "gdp_pfizer", "gdp_allvax"])
overall_vov = country_vov.copy()
overall_vov["country"] = "global"
global_vov = overall_vov.groupby(["country"])[keep_cols].sum()

sur_doses_df = qdata[qdata["yyyy_qq"] != "2021_Q4"]
sur_doses_df["uptake_doses"] = sur_doses_df["uptake"]*sur_doses_df["tot_pop"]
sur_doses_df["uptake_pfizer_doses"] = sur_doses_df["uptake_pfizer"]*sur_doses_df["tot_pop"]

health_doses = sur_doses_df.merge(inf_df[["country", "yyyy_qq"]], on = ["country", "yyyy_qq"], how = "right")
health_pfizer_doses = health_doses["uptake_pfizer_doses"].sum()
health_allvax_doses = health_doses["uptake_doses"].sum()

q_gdp_doses = sur_doses_df.merge(gdp_q_df[["country", "yyyy_qq"]], on = ["country", "yyyy_qq"], how = "right")
q_gdp_pfizer_doses = q_gdp_doses["uptake_pfizer_doses"].sum()
q_gdp_allvax_doses = q_gdp_doses["uptake_doses"].sum()

a_gdp_pfizer_doses = (gdp_a.annual_data["cv_p"]*gdp_a.annual_data["tot_pop"]).sum()
a_gdp_allvax_doses = ((gdp_a.annual_data["cv_np"] + gdp_a.annual_data["cv_p"])*gdp_a.annual_data["tot_pop"]).sum()

global_vov["pfz_health_value_perdose"] = global_vov["pfz_health_value"]/health_pfizer_doses
global_vov["pfz_qgdp_value_perdose"] = global_vov["averted_gdp_gap_pfz"]/q_gdp_pfizer_doses
global_vov["pfz_agdp_value_perdose"] = global_vov["gdp_pfizer"]/a_gdp_pfizer_doses
pfz_gdp_value = [global_vov["pfz_qgdp_value_perdose"].values[0], global_vov["pfz_agdp_value_perdose"].values[0]]
pfz_gdp_doses = [q_gdp_pfizer_doses, a_gdp_pfizer_doses]
global_vov["pfz_gdp_value_perdose"] = np.average(pfz_gdp_value, weights = pfz_gdp_doses)

global_vov["allvax_health_value_perdose"] = global_vov["allvax_health_value"]/health_allvax_doses
global_vov["allvax_qgdp_value_perdose"] = global_vov["averted_gdp_gap_allvax"]/q_gdp_allvax_doses
global_vov["allvax_agdp_value_perdose"] = global_vov["gdp_allvax"]/a_gdp_allvax_doses
allvax_gdp_value = [global_vov["allvax_qgdp_value_perdose"].values[0], global_vov["allvax_agdp_value_perdose"].values[0]]
allvax_gdp_doses = [q_gdp_allvax_doses, a_gdp_allvax_doses]
global_vov["allvax_gdp_value_perdose"] = np.average(allvax_gdp_value, weights = allvax_gdp_doses)

global_vov["pfz_vov_perdose"] = global_vov["pfz_health_value_perdose"] + global_vov["pfz_gdp_value_perdose"]
global_vov["allvax_vov_perdose"] = global_vov["allvax_health_value_perdose"] + global_vov["allvax_gdp_value_perdose"]

pop2019 = pd.read_stata("../input/national_population_2019.dta")
allvax_health_countries = inf_df.country.unique()
pfizer_health_countries = country_vov.loc[(country_vov["averted_inf_mean_pfz"] != 0) & (country_vov["averted_inf_mean_pfz"].notna()), "country"].unique()
allvax_health_pop = pop2019.loc[pop2019.country.isin(allvax_health_countries), "tot_pop"].sum()
pfizer_health_pop = pop2019.loc[pop2019.country.isin(pfizer_health_countries), "tot_pop"].sum()

allvax_qgdp_countries = gdp_q_df.country.unique()
pfizer_qgdp_countries = country_vov.loc[(country_vov["averted_gdp_gap_pfz"] != 0) & (country_vov["averted_gdp_gap_pfz"].notna()), "country"].unique()
allvax_qgdp_pop = pop2019.loc[pop2019.country.isin(allvax_qgdp_countries), "tot_pop"].sum()
pfizer_qgdp_pop = pop2019.loc[pop2019.country.isin(pfizer_qgdp_countries), "tot_pop"].sum()

allvax_agdp_countries = gdp_a.annual_results_data.country.unique()
pfizer_agdp_countries = country_vov.loc[(country_vov["gdp_pfizer"] != 0) & (country_vov["gdp_pfizer"].notna()), "country"].unique()
allvax_agdp_pop = pop2019.loc[pop2019.country.isin(allvax_agdp_countries), "tot_pop"].sum()
pfizer_agdp_pop = pop2019.loc[pop2019.country.isin(pfizer_agdp_countries), "tot_pop"].sum()

global_vov["pfz_health_value_percapita"] = global_vov["pfz_health_value"]/pfizer_health_pop
global_vov["pfz_qgdp_value_percapita"] = global_vov["averted_gdp_gap_pfz"]/pfizer_qgdp_pop
global_vov["pfz_agdp_value_percapita"] = global_vov["gdp_pfizer"]/pfizer_agdp_pop
pfz_gdp_value = [global_vov["pfz_qgdp_value_percapita"].values[0], global_vov["pfz_agdp_value_percapita"].values[0]]
pfz_gdp_pop = [pfizer_qgdp_pop, pfizer_agdp_pop]
global_vov["pfz_gdp_value_percapita"] = np.average(pfz_gdp_value, weights = pfz_gdp_pop)

global_vov["allvax_health_value_percapita"] = global_vov["allvax_health_value"]/allvax_health_pop
global_vov["allvax_qgdp_value_percapita"] = global_vov["averted_gdp_gap_allvax"]/allvax_qgdp_pop
global_vov["allvax_agdp_value_percapita"] = global_vov["gdp_allvax"]/allvax_agdp_pop
allvax_gdp_value = [global_vov["allvax_qgdp_value_percapita"].values[0], global_vov["allvax_agdp_value_percapita"].values[0]]
allvax_gdp_pop = [allvax_qgdp_pop, allvax_agdp_pop]
global_vov["allvax_gdp_value_percapita"] = np.average(allvax_gdp_value, weights = allvax_gdp_pop)

global_vov["pfz_vov_percapita"] = global_vov["pfz_health_value_percapita"] + global_vov["pfz_gdp_value_percapita"]
global_vov["allvax_vov_percapita"] = global_vov["allvax_health_value_percapita"] + global_vov["allvax_gdp_value_percapita"]

global_vov.to_excel("../output/sur_recursive_and_gdp_subsamples_nodsct_global_vov.xlsx")

recursive_inf = inf.comp_inf_lags
recursive_inf.to_excel("../output/sur_recursive_and_gdp_subsamples_nodsct_comp_inf.xlsx")

# %% PSA
"""
sur_inf = SUR_model()
sur_inf.run_quarterly_psa(depvar = "inf_mean", n_samp = 1000)
sur_inf_dfs = sur_inf.df_list  
    
sur_deaths = SUR_model()
sur_deaths.run_quarterly_psa(depvar = "daily_deaths", n_samp = 1000)
sur_deaths_dfs = sur_deaths.df_list 

sur_gdp_q = SUR_model()
sur_gdp_q.run_quarterly_psa(depvar = "gdp_gap", n_samp = 1000)
sur_gdp_q_dfs = sur_gdp_q.df_list 

sur_gdp_a = SUR_model()
sur_gdp_a.run_annual_gdp_psa(data = qdata, n_samp = 1000)
sur_gdp_a_dfs = sur_gdp_a.annual_gdp_df_list 

sur_pfz_combined_dfs = list()
for i in range(len(sur_inf_dfs[0])):
    pfz_df = sur_inf_dfs[0][i].merge(sur_deaths_dfs[0][i], on = ["country", "yyyy_qq"],
                                 how = "outer")
    pfz_df = pfz_df.merge(sur_gdp_q_dfs[0][i], on = ["country", "yyyy_qq"],
                                 how = "outer")
    sur_pfz_combined_dfs.append(pfz_df)
    
sur_allvax_combined_dfs = list()
for i in range(len(sur_inf_dfs[1])):
    allvax_df = sur_inf_dfs[1][i].merge(sur_deaths_dfs[1][i], on = ["country", "yyyy_qq"],
                                 how = "outer")
    allvax_df = allvax_df.merge(sur_gdp_q_dfs[1][i], on = ["country", "yyyy_qq"],
                                 how = "outer")
    sur_allvax_combined_dfs.append(allvax_df)
    
sur_combined_dfs = list()
for i in range(len(sur_pfz_combined_dfs)):
    combined_df = sur_pfz_combined_dfs[i].merge(sur_allvax_combined_dfs[i],
                                            on = ["country", "yyyy_qq"], how = "outer")
    combined_df = combined_df.merge(qalys, on = ["country", "yyyy_qq"], how = "left")
    combined_df = combined_df.merge(costs, on = ["country", "yyyy_qq"], how = "left")
    combined_df = combined_df.merge(fullincome, on = "country", how = "left")
    sur_combined_dfs.append(combined_df)
  
sur_vov_dfs = list()
for i in sur_combined_dfs:
    sur_vov_dfs.append(compute_vov(i))
    
sur_pfz_vov_list = list()
sur_allvax_vov_list = list()
for idx, df in enumerate(sur_vov_dfs):
    sur_pfz_value = df["pfz_vov"].sum()
    sur_allvax_value = df["allvax_vov"].sum()
    sur_pfz_full_value = sur_pfz_value + sur_gdp_a_dfs[0][idx].averted_gdp_gap_pfz.sum()
    sur_allvax_full_value = sur_allvax_value + sur_gdp_a_dfs[1][idx].averted_gdp_gap_allvax.sum()
    sur_pfz_vov_list.append(sur_pfz_full_value)
    sur_allvax_vov_list.append(sur_allvax_full_value)
    
sur_pfz_vov_percentiles = np.percentile(sur_pfz_vov_list, [2.5, 50, 97.5])
sur_allvax_vov_percentiles = np.percentile(sur_allvax_vov_list, [2.5, 50, 97.5])

sur_psa = pd.DataFrame(data = [sur_allvax_vov_percentiles, sur_pfz_vov_percentiles],
                       columns = ["2.5th percentile", "50th percentile", "97.5th percentile"],
                       index = ["All vaccines", "Pfizer-BioNTech vaccines"])
"""
writer = pd.ExcelWriter('../output/sur_recursive_and_gdp_subsamples_nodsct_output.xlsx', engine='xlsxwriter')

sur_info = pd.read_html(inf.results.summary.tables[0].as_html(), header = 0, index_col=0)[0]
sur_info.to_excel(writer, sheet_name='SUR_model_info')

inf_reg = pd.read_html(inf.results.summary.tables[1].as_html(), header = 0, index_col=0)[0]
inf_reg.to_excel(writer, sheet_name='infections_output')

death_reg = pd.read_html(inf.results.summary.tables[2].as_html(), header = 0, index_col=0)[0]
death_reg.to_excel(writer, sheet_name='deaths_output')

gdp_q.results.summary2().tables[0].to_excel(writer, sheet_name='quarterly_gdp_OLS_info')
gdp_q.results.summary2().tables[1].to_excel(writer, sheet_name='quarterly_gdp_output')

gdp_a.annual_results.summary2().tables[0].to_excel(writer, sheet_name='annual_gdp_OLS_info')
gdp_a.annual_results.summary2().tables[1].to_excel(writer, sheet_name='annual_gdp_output')

country_quarter_vov.to_excel(writer, sheet_name='country_quarter_vov')

country_vov.to_excel(writer, sheet_name = 'country_vov')

global_vov.to_excel(writer, sheet_name = 'global_vov')

#sur_psa.to_excel(writer, sheet_name = "psa_percentiles")

writer.save()

# %% calculate value components
"""
gdp_q_df["pandemic_gdp"] = gdp_q_df["gdp_projected_usd"] - (gdp_q_df["gdp_gap"]*gdp_q_df["gdp_projected_usd"])
gdp_q_df["vax_gdp"] = gdp_q_df["gdp_projected_usd"] - (gdp_q_df["pred_vax"]*gdp_q_df["gdp_projected_usd"])
gdp_q_df["novax_gdp"] = gdp_q_df["gdp_projected_usd"] - (gdp_q_df["pred_novax"]*gdp_q_df["gdp_projected_usd"])
gdp_q_df["nopfz_gdp"] = gdp_q_df["gdp_projected_usd"] - (gdp_q_df["pred_nopfz"]*gdp_q_df["gdp_projected_usd"])

gdp2020 = gdp_usd[gdp_usd["year"] == 2020]
gdp2020 = gdp2020.groupby("country")[["gdp_projected_usd"]].sum().reset_index()
gdp_a_df = gdp_a_df.merge(gdp2020, on = "country", how = "left", suffixes = ["_2021", "_2020"])

gdp_a_df["pandemic_gdp"] = (gdp_a_df["gdp_projected_usd_2020"]+gdp_a_df["gdp_projected_usd_2021"]) - (gdp_a_df["g2020"]*gdp_a_df["gdp_projected_usd_2020"]) - (gdp_a_df["g2021_g2020"]+gdp_a_df["g2020"])*gdp_a_df["gdp_projected_usd_2021"]
gdp_a_df["vax_gdp"] = gdp_a_df["gdp_projected_usd"] - (gdp_a_df["g2021_g2020_vax"]+gdp_a_df["g2020"])*gdp_a_df["gdp_projected_usd"]
gdp_a_df["novax_gdp"] = gdp_a_df["gdp_projected_usd"] - (gdp_a_df["g2021_g2020_novax"]+gdp_a_df["g2020"])*gdp_a_df["gdp_projected_usd"]
gdp_a_df["nopfz_gdp"] = gdp_a_df["gdp_projected_usd"] - (gdp_a_df["g2021_g2020_nopfz"]+gdp_a_df["g2020"])*gdp_a_df["gdp_projected_usd"]

pandemic_gdp_loss = gdp_q_df["pandemic_gdp"].sum() + gdp_a_df["pandemic_gdp"].sum()
predicted_gdp_loss = gdp_q_df["vax_gdp"].sum() + gdp_a_df["vax_gdp"].sum()
novax_gdp_loss = gdp_q_df["novax_gdp"].sum() + gdp_a_df["novax_gdp"].sum()
nopfz_gdp_loss = gdp_q_df["nopfz_gdp"].sum() + gdp_a_df["nopfz_gdp"].sum()

vax_gdp_gain = novax_gdp_loss - predicted_gdp_loss
pfz_gdp_gain = nopfz_gdp_loss - predicted_gdp_loss

inf_df["pandemic_inf"] = inf_df["inf_mean"]*inf_df["tot_pop"]
inf_df["vax_inf"] = inf_df["pred_vax"]*inf_df["tot_pop"]
inf_df["novax_inf"] = inf_df["pred_novax"]*inf_df["tot_pop"]
inf_df["nopfz_inf"] = inf_df["pred_nopfz"]*inf_df["tot_pop"]

pandemic_inf = inf_df["pandemic_inf"].sum()
predicted_inf = inf_df["vax_inf"].sum()
novax_inf = inf_df["novax_inf"].sum()
nopfz_inf = inf_df["nopfz_inf"].sum()

vax_inf_averted = novax_inf - predicted_inf
pfz_inf_averted = nopfz_inf - predicted_inf

death_df["pandemic_death"] = death_df["daily_deaths"]*death_df["tot_pop"]
death_df["vax_death"] = death_df["pred_vax"]*death_df["tot_pop"]
death_df["novax_death"] = death_df["pred_novax"]*death_df["tot_pop"]
death_df["nopfz_death"] = death_df["pred_nopfz"]*death_df["tot_pop"]

pandemic_death = death_df["pandemic_death"].sum()
predicted_death = death_df["vax_death"].sum()
novax_death = death_df["novax_death"].sum()
nopfz_death = death_df["nopfz_death"].sum()

vax_death_averted = novax_death - predicted_death
pfz_death_averted = nopfz_death - predicted_death

qaly_df = inf_df.merge(death_df[["country", "yyyy_qq", "pandemic_death", "vax_death", "novax_death", "nopfz_death"]],
                       on = ["country", "yyyy_qq"], how = "left")
qaly_df = qaly_df.merge(qalys, on = ["country", "yyyy_qq"], how = "left")
qaly_df["pandemic_nonfatal"] = qaly_df["pandemic_inf"] - qaly_df["pandemic_death"]
qaly_df["vax_nonfatal"] = qaly_df["vax_inf"] - qaly_df["vax_death"]
qaly_df["novax_nonfatal"] = qaly_df["novax_inf"] - qaly_df["novax_death"]
qaly_df["nopfz_nonfatal"] = qaly_df["nopfz_inf"] - qaly_df["nopfz_death"]

qaly_df["pandemic_qaly"] = (qaly_df["pandemic_death"]*qaly_df["Q_fatal"]) + (qaly_df["pandemic_nonfatal"]*qaly_df["Q_nonfatal"])
qaly_df["vax_qaly"] = (qaly_df["vax_death"]*qaly_df["Q_fatal"]) + (qaly_df["vax_nonfatal"]*qaly_df["Q_nonfatal"])
qaly_df["novax_qaly"] = (qaly_df["novax_death"]*qaly_df["Q_fatal"]) + (qaly_df["novax_nonfatal"]*qaly_df["Q_nonfatal"])
qaly_df["nopfz_qaly"] = (qaly_df["nopfz_death"]*qaly_df["Q_fatal"]) + (qaly_df["nopfz_nonfatal"]*qaly_df["Q_nonfatal"])

pandemic_qaly = qaly_df["pandemic_qaly"].sum()
predicted_qaly = qaly_df["vax_qaly"].sum()
novax_qaly = qaly_df["novax_qaly"].sum()
nopfz_qaly = qaly_df["nopfz_qaly"].sum()

vax_qaly_averted = novax_qaly - predicted_qaly
pfz_qaly_averted = nopfz_qaly - predicted_qaly

mqaly_df = qaly_df.merge(fullincome, on = "country", how = "left")
mqaly_df["pandemic_mqaly"] = mqaly_df["pandemic_qaly"]*mqaly_df["fullincome"]
mqaly_df["vax_mqaly"] = mqaly_df["vax_qaly"]*mqaly_df["fullincome"]
mqaly_df["novax_mqaly"] = mqaly_df["novax_qaly"]*mqaly_df["fullincome"]
mqaly_df["nopfz_mqaly"] = mqaly_df["nopfz_qaly"]*mqaly_df["fullincome"]

pandemic_mqaly = mqaly_df["pandemic_mqaly"].sum()
predicted_mqaly = mqaly_df["vax_mqaly"].sum()
novax_mqaly = mqaly_df["novax_mqaly"].sum()
nopfz_mqaly = mqaly_df["nopfz_mqaly"].sum()

vax_mqaly_averted = novax_mqaly - predicted_mqaly
pfz_mqaly_averted = nopfz_mqaly - predicted_mqaly

cost_df = qaly_df.merge(costs, on = ["country", "yyyy_qq"], how = "left")
cost_df["pandemic_direct"] = cost_df["pandemic_inf"]*cost_df["nonfatal_los_cost"]
cost_df["vax_direct"] = cost_df["vax_inf"]*cost_df["nonfatal_los_cost"]
cost_df["novax_direct"] = cost_df["novax_inf"]*cost_df["nonfatal_los_cost"]
cost_df["nopfz_direct"] = cost_df["nopfz_inf"]*cost_df["nonfatal_los_cost"]

pandemic_direct = cost_df["pandemic_direct"].sum()
predicted_direct = cost_df["vax_direct"].sum()
novax_direct = cost_df["novax_direct"].sum()
nopfz_direct = cost_df["nopfz_direct"].sum()

vax_direct_averted = novax_direct - predicted_direct
pfz_direct_averted = nopfz_direct - predicted_direct

cost_df["pandemic_indirect"] = cost_df["pandemic_nonfatal"]*cost_df["indirect_cost_nonfatal"]
cost_df["vax_indirect"] = cost_df["vax_nonfatal"]*cost_df["indirect_cost_nonfatal"]
cost_df["novax_indirect"] = cost_df["novax_nonfatal"]*cost_df["indirect_cost_nonfatal"]
cost_df["nopfz_indirect"] = cost_df["nopfz_nonfatal"]*cost_df["indirect_cost_nonfatal"]

pandemic_indirect = cost_df["pandemic_indirect"].sum()
predicted_indirect = cost_df["vax_indirect"].sum()
novax_indirect = cost_df["novax_indirect"].sum()
nopfz_indirect = cost_df["nopfz_indirect"].sum()

vax_indirect_averted = novax_indirect - predicted_indirect
pfz_indirect_averted = nopfz_indirect - predicted_indirect

pandemic_loss = pandemic_gdp_loss + pandemic_mqaly + pandemic_direct + pandemic_indirect
predicted_loss = predicted_gdp_loss + predicted_mqaly + predicted_direct + predicted_indirect
novax_loss = novax_gdp_loss + novax_mqaly + novax_direct + novax_indirect
nopfz_loss = nopfz_gdp_loss + nopfz_mqaly + nopfz_direct + nopfz_indirect

vax_value = novax_loss - predicted_loss
pfz_value = nopfz_loss - predicted_loss

pop2019 = pd.read_stata("../input/national_population_2019.dta")
pop2019 = pop2019[pop2019.country.isin(inf_df.country.unique())]
all_pop = pop2019.loc[pop2019.country.isin(country_vov.country.unique()), "tot_pop"].sum()

pandemic_loss_percapita = pandemic_loss/all_pop
predicted_loss_percapita = predicted_loss/all_pop
novax_loss_percapita = novax_loss/all_pop
nopfz_loss_percapita = nopfz_loss/all_pop

table3 = pd.DataFrame(columns = ["a", "b", "c", "d", "e", "f"], index = [
    "gdpq", "gdpa", "gdp", "gdp_pct", "inf", "death", "qaly", "mqaly", "mqaly_pct",
    "direct", "direct_pct", "indirect", "indirect_pct", "global",
    "percap", "perdose"])

table3.loc["gdpq", "a"] = gdp_q_df["pandemic_gdp"].sum()
table3.loc["gdpq", "b"] = gdp_q_df["vax_gdp"].sum()
table3.loc["gdpq", "c"] = gdp_q_df["novax_gdp"].sum()
table3.loc["gdpq", "d"] = gdp_q_df["nopfz_gdp"].sum()
table3.loc["gdpq", "e"] = gdp_q_df["novax_gdp"].sum() - gdp_q_df["vax_gdp"].sum()
table3.loc["gdpq", "f"] = gdp_q_df["nopfz_gdp"].sum() - gdp_q_df["vax_gdp"].sum()

table3.loc["gdpa", "a"] = gdp_a_df["pandemic_gdp"].sum()
table3.loc["gdpa", "b"] = gdp_a_df["vax_gdp"].sum()
table3.loc["gdpa", "c"] = gdp_a_df["novax_gdp"].sum()
table3.loc["gdpa", "d"] = gdp_a_df["nopfz_gdp"].sum()
table3.loc["gdpa", "e"] = gdp_a_df["novax_gdp"].sum() - gdp_a_df["vax_gdp"].sum()
table3.loc["gdpa", "f"] = gdp_a_df["nopfz_gdp"].sum() - gdp_a_df["vax_gdp"].sum()

table3.loc["gdp", "a"] = pandemic_gdp_loss
table3.loc["gdp", "b"] = predicted_gdp_loss
table3.loc["gdp", "c"] = novax_gdp_loss
table3.loc["gdp", "d"] = nopfz_gdp_loss
table3.loc["gdp", "e"] = vax_gdp_gain
table3.loc["gdp", "f"] = pfz_gdp_gain

table3.loc["inf", "a"] = pandemic_inf
table3.loc["inf", "b"] = predicted_inf
table3.loc["inf", "c"] = novax_inf
table3.loc["inf", "d"] = nopfz_inf
table3.loc["inf", "e"] = vax_inf_averted
table3.loc["inf", "f"] = pfz_inf_averted

table3.loc["death", "a"] = pandemic_death
table3.loc["death", "b"] = predicted_death
table3.loc["death", "c"] = novax_death
table3.loc["death", "d"] = nopfz_death
table3.loc["death", "e"] = vax_death_averted
table3.loc["death", "f"] = pfz_death_averted

table3.loc["qaly", "a"] = pandemic_qaly
table3.loc["qaly", "b"] = predicted_qaly
table3.loc["qaly", "c"] = novax_qaly
table3.loc["qaly", "d"] = nopfz_qaly
table3.loc["qaly", "e"] = vax_qaly_averted
table3.loc["qaly", "f"] = pfz_qaly_averted

table3.loc["mqaly", "a"] = pandemic_mqaly
table3.loc["mqaly", "b"] = predicted_mqaly
table3.loc["mqaly", "c"] = novax_mqaly
table3.loc["mqaly", "d"] = nopfz_mqaly
table3.loc["mqaly", "e"] = vax_mqaly_averted
table3.loc["mqaly", "f"] = pfz_mqaly_averted

table3.loc["direct", "a"] = pandemic_direct
table3.loc["direct", "b"] = predicted_direct
table3.loc["direct", "c"] = novax_direct
table3.loc["direct", "d"] = nopfz_direct
table3.loc["direct", "e"] = vax_direct_averted
table3.loc["direct", "f"] = pfz_direct_averted

table3.loc["indirect", "a"] = pandemic_indirect
table3.loc["indirect", "b"] = predicted_indirect
table3.loc["indirect", "c"] = novax_indirect
table3.loc["indirect", "d"] = nopfz_indirect
table3.loc["indirect", "e"] = vax_indirect_averted
table3.loc["indirect", "f"] = pfz_indirect_averted

table3.loc["global", "a"] = pandemic_loss
table3.loc["global", "b"] = predicted_loss
table3.loc["global", "c"] = novax_loss
table3.loc["global", "d"] = nopfz_loss
table3.loc["global", "e"] = vax_value
table3.loc["global", "f"] = pfz_value

table3.loc["percap", "a"] = pandemic_loss_percapita
table3.loc["percap", "b"] = predicted_loss_percapita
table3.loc["percap", "c"] = novax_loss_percapita
table3.loc["percap", "d"] = nopfz_loss_percapita
table3.loc["percap", "e"] = global_vov["allvax_vov_percapita"].values[0]
table3.loc["percap", "f"] = global_vov["pfz_vov_percapita"].values[0]

table3.loc["perdose", "e"] = global_vov["allvax_vov_perdose"].values[0]
table3.loc["perdose", "f"] = global_vov["pfz_vov_perdose"].values[0]

table3.loc["gdp_pct", "e"] = table3.loc["gdp", "e"]/table3.loc["global", "e"]
table3.loc["gdp_pct", "f"] = table3.loc["gdp", "f"]/table3.loc["global", "f"]

table3.loc["mqaly_pct", "e"] = table3.loc["mqaly", "e"]/table3.loc["global", "e"]
table3.loc["mqaly_pct", "f"] = table3.loc["mqaly", "f"]/table3.loc["global", "f"]

table3.loc["direct_pct", "e"] = table3.loc["direct", "e"]/table3.loc["global", "e"]
table3.loc["direct_pct", "f"] = table3.loc["direct", "f"]/table3.loc["global", "f"]

table3.loc["indirect_pct", "e"] = table3.loc["indirect", "e"]/table3.loc["global", "e"]
table3.loc["indirect_pct", "f"] = table3.loc["indirect", "f"]/table3.loc["global", "f"]

table3.index = ["Global GDP shortfall, quarterly data", "Global GDP shortfall, annual data", "Global GDP shortfall, all",
                "GDP share of value (%)", "Global infections", "Global deaths", "Global QALY losses",
                "Global Monetary value of QALY losses", "Monetized QALY share of value (%)",
                "Global direct costs", "Diret costs share of value (%)", "Global indirect costs",
                "Indirect costs share of value (%)", "Global total losses or value (GDP + monetary QALY + direct + indirect)",
                "Per capita total loss or value", "Per dose value"]

table3.columns = ["Pandemic (A)", "Predicted Pandemic (B)", "Predicted Zero Vaccination (C)", "Predicted Zero Pfizer-BioNTech Vaccination (D)",
                  "VoV (C-B)", "VoPFV (D-B)"]

table3.to_excel("../output/table3_jk.xlsx")


writer = pd.ExcelWriter('../output/tables2_and_3.xlsx', engine='xlsxwriter')


inf_reg = pd.read_html(inf.results.summary.tables[1].as_html(), header = 0, index_col=0)[0]
inf_reg.to_excel(writer, sheet_name='Table2 Infections')

death_reg = pd.read_html(inf.results.summary.tables[2].as_html(), header = 0, index_col=0)[0]
death_reg.to_excel(writer, sheet_name='Table2 Deaths')

gdp_q.results.summary2().tables[1].to_excel(writer, sheet_name='Table2 Quarterly GDP')

gdp_a.annual_results.summary2().tables[1].to_excel(writer, sheet_name='Table2 Annual GDP')

table3.to_excel(writer, sheet_name = "Table 3")

writer.save()
"""
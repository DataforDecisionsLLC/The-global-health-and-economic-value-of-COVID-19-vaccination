set more off
clear all
set type double
set matsize 5000
version 18.0

gl root   ".......\DB Work\"
gl output "$root\DATA"
cd        "$root"

////////////////////////////////////////////////////////////////////////////////
//////// 1. run the sureg and get the vector of mean estimates and the VCE /////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\sur_regbase_deaths_inf", clear

replace L1_mean_index=L1_mean_index/100

sureg ///
(daily_deaths L1_uptake_pfizer L2_cum_uptake_pfizer L1_uptake_other L2_cum_uptake_other L1_inf_mean L2_cum_inf_mean L1_mean_index time_7-time_13 country_2-country_145) ///
(inf_mean     L1_uptake_pfizer L2_cum_uptake_pfizer L1_uptake_other L2_cum_uptake_other L1_inf_mean L2_cum_inf_mean L1_mean_index time_7-time_13 country_2-country_145) , vce(robust)

matrix b = get(_b)
matrix V = get(VCE)
matrix T = r(table)

////////////////////////////////////////////////////////////////////////////////
////// 2. draw 1000 draws from the MVN distribution with means b and cov V /////
////////////////////////////////////////////////////////////////////////////////

clear
drawnorm ///
d_1 d_2 d_3 d_4 d_5 d_6 d_7 d_8 d_9 d_10 d_11 d_12 d_13 d_14 d_15 d_16 d_17 d_18 d_19 d_20 d_21 d_22 d_23 d_24 d_25 d_26 d_27 d_28 d_29 d_30 d_31 d_32 d_33 d_34 d_35 d_36 d_37 d_38 d_39 d_40 d_41 d_42 d_43 d_44 d_45 d_46 d_47 d_48 d_49 d_50 d_51 d_52 d_53 d_54 d_55 d_56 d_57 d_58 d_59 d_60 d_61 d_62 d_63 d_64 d_65 d_66 d_67 d_68 d_69 d_70 d_71 d_72 d_73 d_74 d_75 d_76 d_77 d_78 d_79 d_80 d_81 d_82 d_83 d_84 d_85 d_86 d_87 d_88 d_89 d_90 d_91 d_92 d_93 d_94 d_95 d_96 d_97 d_98 d_99 d_100 d_101 d_102 d_103 d_104 d_105 d_106 d_107 d_108 d_109 d_110 d_111 d_112 d_113 d_114 d_115 d_116 d_117 d_118 d_119 d_120 d_121 d_122 d_123 d_124 d_125 d_126 d_127 d_128 d_129 d_130 d_131 d_132 d_133 d_134 d_135 d_136 d_137 d_138 d_139 d_140 d_141 d_142 d_143 d_144 d_145 d_146 d_147 d_148 d_149 d_150 d_151 d_152 d_153 d_154 d_155 d_156 d_157 d_158 d_159 ///
i_1 i_2 i_3 i_4 i_5 i_6 i_7 i_8 i_9 i_10 i_11 i_12 i_13 i_14 i_15 i_16 i_17 i_18 i_19 i_20 i_21 i_22 i_23 i_24 i_25 i_26 i_27 i_28 i_29 i_30 i_31 i_32 i_33 i_34 i_35 i_36 i_37 i_38 i_39 i_40 i_41 i_42 i_43 i_44 i_45 i_46 i_47 i_48 i_49 i_50 i_51 i_52 i_53 i_54 i_55 i_56 i_57 i_58 i_59 i_60 i_61 i_62 i_63 i_64 i_65 i_66 i_67 i_68 i_69 i_70 i_71 i_72 i_73 i_74 i_75 i_76 i_77 i_78 i_79 i_80 i_81 i_82 i_83 i_84 i_85 i_86 i_87 i_88 i_89 i_90 i_91 i_92 i_93 i_94 i_95 i_96 i_97 i_98 i_99 i_100 i_101 i_102 i_103 i_104 i_105 i_106 i_107 i_108 i_109 i_110 i_111 i_112 i_113 i_114 i_115 i_116 i_117 i_118 i_119 i_120 i_121 i_122 i_123 i_124 i_125 i_126 i_127 i_128 i_129 i_130 i_131 i_132 i_133 i_134 i_135 i_136 i_137 i_138 i_139 i_140 i_141 i_142 i_143 i_144 i_145 i_146 i_147 i_148 i_149 i_150 i_151 i_152 i_153 i_154 i_155 i_156 i_157 i_158 i_159 ///
, n(1000) means(b) cov(V) seed(21507269)

qui des 
di "The number of rows is `r(N)' and the number of columns is `r(k)'"

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_sureg", replace

////////////////////////////////////////////////////////////////////////////////
//// 3. make the 1000 x 159 matrix that stacks the 155 coefficient estimates ///
////////////// from the death regression for each of the 1000 draws ////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_sureg", clear 
mkmat ///
d_1 d_2 d_3 d_4 d_5 d_6 d_7 d_8 d_9 d_10 d_11 d_12 d_13 d_14 d_15 d_16 d_17 d_18 d_19 d_20 d_21 d_22 d_23 d_24 d_25 d_26 d_27 d_28 d_29 d_30 d_31 d_32 d_33 d_34 d_35 d_36 d_37 d_38 d_39 d_40 d_41 d_42 d_43 d_44 d_45 d_46 d_47 d_48 d_49 d_50 d_51 d_52 d_53 d_54 d_55 d_56 d_57 d_58 d_59 d_60 d_61 d_62 d_63 d_64 d_65 d_66 d_67 d_68 d_69 d_70 d_71 d_72 d_73 d_74 d_75 d_76 d_77 d_78 d_79 d_80 d_81 d_82 d_83 d_84 d_85 d_86 d_87 d_88 d_89 d_90 d_91 d_92 d_93 d_94 d_95 d_96 d_97 d_98 d_99 d_100 d_101 d_102 d_103 d_104 d_105 d_106 d_107 d_108 d_109 d_110 d_111 d_112 d_113 d_114 d_115 d_116 d_117 d_118 d_119 d_120 d_121 d_122 d_123 d_124 d_125 d_126 d_127 d_128 d_129 d_130 d_131 d_132 d_133 d_134 d_135 d_136 d_137 d_138 d_139 d_140 d_141 d_142 d_143 d_144 d_145 d_146 d_147 d_148 d_149 d_150 d_151 d_152 d_153 d_154 d_155 d_156 d_157 d_158 d_159 , matrix(S_death)

clear 
svmat S_death

gen sim=_n
order sim 

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\S_death", replace

////////////////////////////////////////////////////////////////////////////////
/// 4. make the 1000 x 155 matrix that stacks the 155 coefficient estimates ////
////////// from the infection regression for each of the 1000 draws ////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\SUR\SIMULATIONS\sims_sureg", clear 

mkmat ///
i_1 i_2 i_3 i_4 i_5 i_6 i_7 i_8 i_9 i_10 i_11 i_12 i_13 i_14 i_15 i_16 i_17 i_18 i_19 i_20 i_21 i_22 i_23 i_24 i_25 i_26 i_27 i_28 i_29 i_30 i_31 i_32 i_33 i_34 i_35 i_36 i_37 i_38 i_39 i_40 i_41 i_42 i_43 i_44 i_45 i_46 i_47 i_48 i_49 i_50 i_51 i_52 i_53 i_54 i_55 i_56 i_57 i_58 i_59 i_60 i_61 i_62 i_63 i_64 i_65 i_66 i_67 i_68 i_69 i_70 i_71 i_72 i_73 i_74 i_75 i_76 i_77 i_78 i_79 i_80 i_81 i_82 i_83 i_84 i_85 i_86 i_87 i_88 i_89 i_90 i_91 i_92 i_93 i_94 i_95 i_96 i_97 i_98 i_99 i_100 i_101 i_102 i_103 i_104 i_105 i_106 i_107 i_108 i_109 i_110 i_111 i_112 i_113 i_114 i_115 i_116 i_117 i_118 i_119 i_120 i_121 i_122 i_123 i_124 i_125 i_126 i_127 i_128 i_129 i_130 i_131 i_132 i_133 i_134 i_135 i_136 i_137 i_138 i_139 i_140 i_141 i_142 i_143 i_144 i_145 i_146 i_147 i_148 i_149 i_150 i_151 i_152 i_153 i_154 i_155 i_156 i_157 i_158 i_159, matrix(S_inf)

clear 
svmat S_inf

gen sim=_n
order sim 

save "$root\REGRESSION RESULTS\SUR\SIMULATIONS\S_inf", replace

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// quarterly gdp ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\quarterly_gdp_regbase", clear

replace L1_mean_index=L1_mean_index/100
replace prevax_osi=prevax_osi/100

order country time yyyy_qq gdp_gap uptake* cum_* L1_* L2_*

qui des ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_51 , varlist

local ind = r(varlist) 
di "The independent variables are `ind'"

reg gdp_gap ///
L1_uptake_pfizer L2_cum_uptake_pfizer ///
L1_uptake_other  L2_cum_uptake_other ///
L1_inf_mean L2_cum_inf_mean ///
L1_mean_index ///
time_7-time_13 country_2-country_51, robust

matrix b = get(_b)
matrix V = get(VCE)

drawnorm `ind' constant, n(1000) means(b) cov(V) seed(21507269) clear

compress
save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sims_quarterly_gdp", replace

////////////////////////////////////////////////////////////////////////////////
///////////////////////////////// annual gdp ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

use "$output\IHME\annual_gdp_regbase", clear
assert yyyy_qq == "2021_Q4"

qui des     g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4, varlist

local ind = r(varlist) 
di "The independent variables are `ind'"

reg gdp_gap g2020 cum_uptake_other cum_uptake_pfizer cn2020Q4, robust

matrix b = get(_b)
matrix V = get(VCE)

drawnorm `ind' constant, n(1000) means(b) cov(V) seed(21507269) clear

compress
save "$root\REGRESSION RESULTS\ANNUAL & QUARTERLY GDP\sims_annual_gdp", replace

exit 
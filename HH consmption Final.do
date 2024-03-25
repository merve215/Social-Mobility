* =============================================================================
*
* Date : December 2023
* Paper: Why are we poorer than our parents? 
*		 A Cross-Country Analysis of Absolute Intergenerational Mobility 
*
* Database used : - rfinan_world_bank_data.dta
*                 - oecd_data_2.dta
*				  -
*				  -
*
*
*
* Output :        - HH_final_consumption_data.dta
*				  -
*			      -
*
*
*
* Key variables : 1) Final HouseHold Consumption
*				  	- Households and NPISHs Final consumption expenditure, PPP
*                 	- GDP per capita, PPP (current international $)
*                 	- Stock market capitalization to GDP (%)
*                 	- Private credit by deposit money banks and other financial institutions to GDP (%)
*                 2) Education
*				  -
*                 -
*.                3) Health
*
*
*
*
*
*===============================================================================


*======================= 1. HouseHold Final Consumption ========================

clear mata
capture log close
clear

						* Pulling up Dataset from worldbank
						*==================================


*world bank data - final consumption, gdp, privatecredit, financialwealth 
*help wbopendata

	wbopendata, indicator(NE.CON.PRVT.PP.CD; NY.GDP.PCAP.PP.CD; GFDD.DM.02; GFDD.DI.12 ) year(1990:2020) long clear

	rename ne_con_prvt_pp_cd hhconsp //Households and NPISHs Final consumption expenditure, PPP (currentinternational $)
	rename ny_gdp_pcap_pp_cd gdppc // GDP per capita, PPP (current international $)
	rename gfdd_dm_02 financialwealth // Stock market capitalization to GDP (%)
	rename gfdd_di_12 privatecredit //Private credit by deposit money banks and other financial institutions to GDP (%)
	drop countryname region regionname adminregion adminregionname incomelevelname lendingtype lendingtypename

	save "rfinan_world_bank_data.dta", replace
	

						* Pulling up Dataset from OECD
						*=================================

	clear
	ssc install moss
	ssc install sdmxuse
	sdmxuse dataflow OECD
	sdmxuse datastructure OECD, clear dataset(RHPI_TARGET) // National and Regional House Price Indices - Headline indicators
	sdmxuse data OECD, clear dataset(RHPI_TARGET) dimensions() start(1990) end(2020)

	*help sdmxuse
	keep if  var == "RHPI" // Real House Price Index
	keep if vintage == "VINTAGE_TOTAL"
	keep if  measure == "IXOB"

	drop if strpos(time, "Q") > 0 // to isolate yearly data
	drop if strpos(time, "-") > 0 // to isolate yearly data
	drop if regexm(reg_id, "[0-9]")

	rename value housingindex
	rename reg_id countrycode
	rename time year
	drop tl var vintage dwellings measure freq
	destring year, replace

	save "oecd_data_2.dta", replace


						* Merging the two dataset
						*=================================

	merge 1:1 countrycode year using "rfinan_world_bank_data.dta"
	keep if _merge == 3
	save "HH_final_consumption_data.dta", replace
	encode countrycode, gen(country)
	xtset country year
	summarize
	//missing observations for financial wealth 
	
	* general regression
	xi : regress hhconsp gdppc housingindex financialwealth privatecredit i.country
	
	* putting log for all variables 
	g lhhcons=log(hhconsp)
	g lgdp=log(gdppc)
	g lhousingindex=log(housingindex)
	g lfinancialwealth=log(financialwealth)
	g lprivatecredit=log(privatecredit)

	 
					    * Multicollinearity Analysis
						*=================================
	
	reg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth
	vif
	graph export "vif result.pdf", as(pdf) replace

	//Since none of the VIF of the regressors have higher than 10, it's not required to make further analysis.
 

						* Heteroscedasticity test
						*=================================

	regress lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth i.year

	predict residuals, residuals
	gen squared_residuals = residuals^2

	gen squared_lgdp = lgdp^2
	gen squared_lhousingindex = lhousingindex^2
	gen squared_lprivatecredit = lprivatecredit^2
	gen squared_lfinancialwealth = lfinancialwealth^2

	regress squared_residuals squared_lgdp squared_lhousingindex squared_lprivatecredit squared_lfinancialwealth

	test squared_lgdp squared_lhousingindex squared_lprivatecredit squared_lfinancialwealth
	
						* Residual normality
						*=================================
	*plot
	qnorm residuals 
	kdensity residuals, normal // The conformity of residuals to a normal distribution validates the efficacy of the model

	
						* Robustness Section
						*=================================
	
	*Pooled OLS
	xi : regress lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth
	estimates store OLS
	
	*Random Effects Model
	xtset country year
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth i.year, re
	estimates store REM
	xttest0

	// Since the P-value is less than 0.05 (prob>chi2=0.0000),the model is correctly specified.
	
	*Fixed Effects Model
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth i.year, fe
	estimates store FEM
	// Since the P-value is less than 0.05 (prob>F=0.0000),the model is correctly specified.

	estimates table OLS FEM REM, se
	esttab OLS FEM REM
	
	*Comparision of different estimated results	
	hausman FEM REM, sigmamore
	// Prob > chi2 = 0.0000 - implies fixed model preferrable (V_b-V_B is not positive definite)...

	* Test of overidentifying restrictions: fixed vs random effects
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth, re
	xtoverid // fe preferred, proceed with fe model

	
						* Regressions
						*=================================
	
	* logged regression with fixed effect
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth i.year, fe // fixed effect
	summarize
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth, fe 

	margins, dydx(*)
	marginsplot // plot 

	
		                 * Adding Control Variables
						 *=========================
						 
	*Regional Differences	
	encode  incomelevel, gen(regions) 
	tabulate regions
	xtreg lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth i.regions
	estimates store CV
	esttab 
	
	
						* Arellano-Bond Test for Autocorrelation
						*=================================

	xtabond lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth, lags(1)  
	// Despite one variable showing insignificance with a p-value above 0.05 in the Arellano-Bond dynamic panel-data estimation, the overall model remains significant with a higher Wald chi2 value. Additionally, thorough testing for multicollinearity and Heteroscedasticity (Pagan test) confirms the regression's significance. Considering this, while there's a minor setback with one variable, the model as a whole is still reliable and potentially useful for analysis.
	
	
	
	
						* Omitted variable bias
						*=================================

	xi : regress lhhcons lgdp lhousingindex lprivatecredit lfinancialwealth 
	estat ovtest
	//The model explains approximately 61.41% of the variation in the data according to both R-squared and adjusted R-squared values. However, the Ramsey RESET Test suggests evidence of additional variables that are impacting the dependent variable, indicating the presence of omitted variables in the model (p-value < 0.05). While this model helps identify variables influencing the dependent variable, further consideration of additional variables and improvements to the model might be required.


 
 
 
 
 
 
 
 
 
 
 
 
 
 
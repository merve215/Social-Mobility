* =============================================================================
* Output :        - Education expenditure - MERVE
*				  
*			      
*
*
*
* Key variables : 1) Final HouseHold Consumption
*                 	
*                 2) Education
*				  -Adjusted savings: education expenditure (current US$) 
*				  	- Tax revenue (current LCU)
*                 	- GDP per capita, PPP (current international $)
*                 	- Population ages 0-14 (% of to population)
*                	- Total Population

*.                3) Health
*
*
*
*
*
*===============================================================================


*======================= 2. Education Expenditure ==============================


clear mata
capture log close
clear

                        * Pulling up Dataset from Worldbank
						*==================================

wbopendata, indicator(NY.ADJ.AEDU.CD; GC.TAX.TOTL.CN; SP.POP.TOTL; SP.POP.0014.TO.ZS; NY.GDP.PCAP.PP.CD) year(1990:2020) long clear

rename ny_adj_aedu_cd educexpen
rename ny_gdp_pcap_pp_cd gdppc
rename sp_pop_totl tpop
rename sp_pop_0014_to_zs childpopperc
rename gc_tax_totl_cn taxrevenue

						*Setting the panel structure
						*===========================
						
encode countrycode, gen(country)
xtset country year

// strongly balanced=the dataset in general has no missing observations. In other words, every single cross-sectional entity can be matched with a particular time series entity and all of those data points are complete.

	gen per_capita_expenditure = educexpen / tpop
	gen per_capita_tax = taxrevenue / tpop
	by country: gen lagged_per_capita_expenditure = L.per_capita_expenditure
	
	g lper_capita_expenditure=log(per_capita_expenditure)
	g llagged_per_capita_expenditure=log(lagged_per_capita_expenditure)
	g lgdp=log(gdppc)
	g lper_capita_tax=log(per_capita_tax)
	g lchildpopperc=log(childpopperc)
	                   
summarize	
	
	                    *Multicollinearity Analysis
	                    *==========================
						
	reg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc
	vif

//Since none of the VIF of the regressors have higher than 10, it's not required to make further analysis.
	
	
						*I benefited from correlation plots: 
	
	tsset  country year
scatter per_capita_expenditure L.per_capita_expenditure, title("Scatter Plot of Variable and Its Lag") 

tsset  country year
scatter lper_capita_expenditure L.lper_capita_expenditure, title("Scatter Plot of Variable and Its Lag") 

// As observed a diagonal trend from the bottom-left to the top-right in the scatter plot, there is a strong positive correlation between the variable and its lag, both with the versions with logaritmic and non-logaritmic. Thus, lagged per capita expenditure was added to the model as one of the regressors.

	
	
	                     * ROBUSTNESS SECTION
						 *===================
	
	*Pooled OLS

	regress lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc
	estimates store OLS
	
	*Random Effects Model
	
	xtset country year
	xtreg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc, re
	estimates store REM
	
	// Since the P-value is less than 0.05 (prob>chi2=0.0000),the model is correctly specified.
	
	*Fixed Effects Model
	
	xtreg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc, fe
	estimates store FEM
	
	// Since the P-value is less than 0.05 (prob>F=0.0000),the model is correctly specified.
	
	
	*Comparision of different estimated results 

estimates table OLS FEM REM, se

	* Test for REM Random Effects Model or FEM Fixed Effects Model
	
	xtreg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc, fe
	estimates store FEM
	
	xtreg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc
	estimates store REM
	
	hausman FEM REM
	
	// Since Prob > chi2 = 0.0000, FEM is preferred, which accounts for time variation and country specified.
	
	                     * Adding Control Variables
						 *=========================
						 
	*Regional Differences
	
	encode  incomelevel, gen(regions) 
	tabulate regions
	xtreg lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc i.regions
	

					*Test for Heteroskedasticity Breusch-Pagan Test
					*==============================================
	
	regress lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc i.regions
	hettest llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc i.regions
	
	// Since Prob > chi2 = 0.0000, we can soundly reject the Null Hypothesis of homosckedasticity, which means potential of heteroskedasticity
	
					*Arellano-Bond Test for Autocorrelation
					*======================================

	xtabond lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc, lags(1)  // Dynamic panel model. Since the p-value (0.0463) is less than 0.05, you would reject the null hypothesis. There is evidence of autocorrelation in the first-differenced errors.
	
	
					*Omitted variable bias
					*======================
						 
	regress lper_capita_expenditure llagged_per_capita_expenditure lgdp lper_capita_tax lchildpopperc
	estat ovtest
	
	//   Prob > F = 0.3623, indicating no omitted variable bias
	
	
	
	
	
	
	




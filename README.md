# Overview

This repository contains code to process California REGEN results and output summary statistics and figures. This is performed with the following steps:

1. **extract_data** a python script which processes REGEN results into csv summary files saved in the *cleaned_data* folder
2. **plot_generation_capacity_investment** an R script which produces plots for, fittingly, annual generation, cumulative capacity, and investments each period.
3. **hour_and_segments** an R script which produces figures and summary statistics for hourly generation, load, and trade.
4. **mapping** (to be added) an R script which maps WECC results.

## Extract Data
Extract data reads the gdx files for a variety of REGEN run results and produces cleaned csv files for analysis.

> :warning: **Warning** The code automatically sets the working directory to the script location with *import modelpaths*. I have not tested this on other computers. If you have trouble, then replace with os.chdir(<SCRIPT_PATH>)

> :bulb: **NOTE** extract data runs for a single scenario. To change to a new scenario, update *scen* on **line 17**

> :bulb: **NOTE** Storage capacity and investment aggregate all storage power or energy values. Investment costs for storage are given only for lithium ion.

extract data currently produces the following outputs:
* **capcosts_usd2024** Average capital costs in California by technology (including storage) by year. Values are converted from 2010 dollars (used in REGEN) to 2024 dollars using the St Luis Fed GDP deflator. Costs are averaged by *TECH_SET* (see code starting on line 22 for TECH_SET description).
* **fom_costs_usd2024** Average fixed operating and maintenance costs in California by technology (does not include storage)
* **marginal_costs_usd2024** average marginal generation costs for California by technology and year. Marinal costs include fuel costs and variable costs, and include production tax credits and 45Q credits. For technologies such as wind, which have 0 variable costs and receive a PTC, the marginal cost will be negative.
* **reghional_emissions_mtco2** annual CO2 emissions by region and year. Aggregated california emissions are added as *California*.
* **ca_capacity** California capacity (GW) by technology and year. Includes storage technology energy and power capacity.
* **investment** yearly GW of capacity invested by technology and region (includes each region in WECC). Storage energy and power investments are added. **ca_investment** includes investments for California.
* **ca_hourly_mapping** hourly and segment values for load, generation, and availability factors for wind and solar by hour and year.
* **dispatch_by_segment_gwh** the segment and hourly dispatch in California by year and technology. storage charge and discharge is added as part of technologies.
* **trade_gw** hourly and segment imports and exports into and out of California.
> :bulb: **NOTE** the hour to segment mapping is based on a synthetic mapping for the pssm calculations from the create_hrep_\<year\>_default gdx file
* **generation_twh** and **capacity_gw** annual generation and capacity from the RegenReporting folder. Contains values by region and by aggregated region (California, WECC)

## Plot Generation, Capacity, Investment
> :warning: **Warning** make sure to change the *scen* on **line 18** to the scenario you want to create figures for.

> :bulb: **Note** color scheme for technologies saved in constants.R script.
* **capacity_plot** area plot of total capacity by technology and year for California. Includes line for peak load

* **geneartion_plot** area plot of total annual generation by technology and year for California.
* **investment_plot** stacked bar plot of investment (GW) in each 5-year increment.

## Plot Generation, Capacity, Investment
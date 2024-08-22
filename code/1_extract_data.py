# Code generates summary statistics for a REGEN run. extracts values REGEN output GDX files and puts into CSV files
import os
import pandas as pd
import gams.transfer as gt
# Model paths just runs line os.chdir(os.path.dirname(os.path.abspath(__file__)))
# VS code doesn't have __file__ when running in interactive mode, so need to import from another path.
# If this fails when you run it, then replace import model_paths with os.chdir(<PATH_TO_THIS_SCRIPT>)
import model_paths
import numpy as np
#____________________________________________
# Get file path and scenario name
main_folder = os.path.abspath("../../CA_REGEN_v0")
ragg = "allstate"
# Gives a list of scenarios. You can print them out to see which scenarios are available
scenarios = os.listdir(os.path.join(main_folder, "RegenCases", ragg))
print(scenarios)
#Update scenario name as needed
scen = "min_compliance"
output_folder = os.path.join("../", "cleaned_data", scen)
if not os.path.exists(output_folder):
    os.makedirs(output_folder)
#___________________________________________
TECH_SET = {
    'wind': 'Wind',
    'clcl': 'Coal',
    'cbcf': 'Bio',
    'cgcf': 'Gas-CC',
    'clng': 'Gas-CT',
    'ngcc': 'Gas-CC',
    'ngst': 'Gas-CT',
    'nggt': 'Gas-CT',
    'dfcc': 'Gas-CC',
    'dfgt': 'Hydrogen',
    'ptsg': 'Gas-CT',
    'ngcr': 'Gas CCS',
    'g2hc': 'Hydrogen',
    'g2ht': 'Hydrogen',
    'h2cc': 'Hydrogen',
    'h2gt': 'Hydrogen',
    'othc': 'Bio',
    'bioe': 'Bio',
    'bioc': 'Bio',
    'becs': 'Bio CCS',
    'ccs9': 'Coal CCS',
    'clch': 'Coal CCS',
    'ncch': 'Gas CCS',
    'nucl': 'Nuclear',
    'nuca': 'Nuclear',
    'hydr': 'Hydro',
    'geot': 'Geothermal',
    'wnos': 'Offshore Wind',
    'wnosd': "Offshore Wind",
    'pvft': 'Solar',
    'pvsx': 'Solar',
    'pvdx': 'Solar',
    'pvftm': 'Solar',
    'pvrf': 'Solar',
    'cspr': 'Solar',
    'enee': 'Energy Efficiency'
}
# REGEN uses October 2010 dollars. Pulled the GDP deflator from FRED website to convert to April 2024 dollars
# From St Louis Fed https://fred.stlouisfed.org/series/GDPDEF April deflator
DEFLATOR_2010_TO_2024 = 1.396161885

COLUMN_NAMES = {"i": "tech_class",  #generators
                "j": "tech_class",  #storage
                "v": "vintage",
                "t": "year",
                "r": "region",
                "s": "segment",
                "h": "hour",
                "f": "fuel"}

RE_TECH = ['Solar', "Wind", "Offshore Wind"]
#____________________________________________

def load_gdx_symbol(gdx_path: str, symbol: str) -> pd.DataFrame:
    """
    Load a symbol from a GDX file into a pandas dataframe.

    Parameters:
    gdx_path   (str)           : The path to the GDX file.
    symbol     (str)           : The symbol to load from the GDX file.
    level_only (bool, optional): If True, then marginal, lower, upper, and scale columns are dropped. Defaults to True.
    Returns:
    pd.DataFrame: The data from the symbol in a pandas dataframe.
    """
    if not os.path.exists(gdx_path):
        print(f"{gdx_path} does not exist.")
        return None

    try:
        df = gt.Container(gdx_path).data[symbol].records
    except KeyError:
        print(f"Error loading {symbol}. Check if {symbol} is in GDX file.")
        return None
    # Drop additional columns if needed loading a variable
    for col in ["marginal", "lower", "upper", "scale", "element_text"]:
        if col in df.columns:
            df.drop(columns=[col], inplace=True)

    return df

def get_tech(df: pd.DataFrame, techs: dict) -> pd.DataFrame:
    """
    Splits tech_class by "-" and maps to the techs dictionary.
    """
    df['tech'] = df['tech_class'].apply(lambda x: x.split("-")[0]).map(techs)
    return df

def current_dollars(df: pd.DataFrame, col: str, deflator: float = DEFLATOR_2010_TO_2024):
    """
    Converts a column of dollars from 2010 to 2024 dollars.
    """
    df[col] = df[col] * deflator
    return df

def subset_data(df: pd.DataFrame, colname: str, sub: list) -> pd.DataFrame:
    """
    Subset Dataframe for column to be in sub list
    """
    df = df[df[colname].isin(sub)]
    return df

def map_col(df: pd.DataFrame, col: str, mapping: dict) -> pd.DataFrame:
    """
    map column to map dictionary
    """
    df[col] = df[col].map(mapping)
    return df

def add_tech(df: pd.DataFrame, tech: str) -> pd.DataFrame:
    """
    Add tech column to dataframe
    """
    df["tech"] = tech
    return df

#____________________________________________


model_results_path = os.path.join(main_folder, "RegenCases", ragg, scen, "elec", "out", scen + ".elec.gdx")
report_path = os.path.join(main_folder, "RegenCases", ragg, scen, "elec", "report", scen + ".elec_rpt.gdx")
reporting_results_path = os.path.join(main_folder, "RegenReport", "Electric", ragg, scen + ".gdx")
enduse_folder = os.path.join(main_folder, "RegenData", "elec", ragg, "endusescen")
# Get regions in California
cal_r = load_gdx_symbol(model_results_path, "cal_r").r.values

# __________________________________________

# Capital Costs
capcosts = (
    # Load data from gdx
    load_gdx_symbol(model_results_path, "capcost")
    # Rename columns
        .rename(columns=COLUMN_NAMES)
    # Add tech column
        .pipe(get_tech, TECH_SET)
    # Subset regions to california regions
        .pipe(subset_data, "region", cal_r)
    # Get mean capital cost by tech and vintage
        .groupby(['tech', 'vintage'])
        .agg({"value": "mean"}).reset_index()
        .rename(columns = {"value": "capcost"})
    # Convert 2010 dollars to 2024 dollars
        .pipe(current_dollars, "capcost")
    # Pivot wider so that each year is a column
        .pivot_table(index = ['tech'], columns = 'vintage', values = 'capcost').reset_index()
    # Drop 2020 year (most techs are new so costs start in 2025)
        .drop(columns = ["2020"], axis = 1)
        .rename(columns = {"2050+": "2050"})
)

# capcosts.to_csv(os.path.join(output_folder, "capcosts_usd2024.csv"), index = False)

# Storage capital costs
capcost_storage_power = (
    load_gdx_symbol(model_results_path, "icg")
    .rename(columns = COLUMN_NAMES))
capcost_storage_power = capcost_storage_power[capcost_storage_power['tech_class'] == "li-ion"]
capcost_storage_power['tech_class'] = "li-ion-power"

capcost_storage_energy = load_gdx_symbol(model_results_path, "irg").rename(columns = COLUMN_NAMES)
capcost_storage_energy = capcost_storage_energy[capcost_storage_energy['tech_class']=="li-ion"]
capcost_storage_energy['tech_class'] = "li-ion-energy"
# combine power (size of inverter) and energy (size of battery) into single table
capcost_storage = (pd.concat([capcost_storage_power, capcost_storage_energy], axis=0, ignore_index=True)
                    .rename(columns={"tech_class": "tech", "value": "capcost"})
                    .pipe(current_dollars, "capcost")
                    .pivot_table(index = ['tech'], columns = 'year', values = 'capcost')
                    .reset_index()
)

pd.concat([capcosts, capcost_storage]).to_csv(os.path.join(output_folder, "capcosts_usd2024.csv"), index = False)
# _____________________________________________________________
# FOM and variable costs
fomcosts = (
    # Load data from gdx
    load_gdx_symbol(model_results_path, "fomcost")
    # Rename columns
        .rename(columns=COLUMN_NAMES)
    # Add tech column
        .pipe(get_tech, TECH_SET)
    # Subset regions to california regions
        .pipe(subset_data, "region", cal_r)
    # Get mean fom cost by tech and vintage
        .groupby(['tech', 'vintage'])
        .agg({"value": "mean"}).reset_index()
        .rename(columns = {"value": "fomcost"})
    # Convert 2010 dollars to 2024 dollars
        .pipe(current_dollars, "fomcost")
    # Pivot wider so that each year is a column
        .pivot_table(index = ['tech'], columns = 'vintage', values = 'fomcost').reset_index()
    # Drop 2020 year (most techs are new, so costs start in 2025)
        .drop(columns = ["2020"], axis = 1)
)
fomcosts.to_csv(os.path.join(output_folder, "fom_costs_usd2024.csv"), index = False)
# Generation marginal costs $/MWh
marginal_cost = (
    load_gdx_symbol(model_results_path, "icost")
        .rename(columns=COLUMN_NAMES)
        .pipe(subset_data, "region", cal_r)
        .pipe(get_tech, TECH_SET)
        .groupby(['tech', 'vintage'])
        .agg({"value": "mean"}).reset_index()
        .pipe(current_dollars, "value")
        .rename(columns={"value": "marginal_cost"})
)
marginal_cost.to_csv(os.path.join(output_folder, "marginal_costs_usd2024.csv"), index = False)
# _____________________________________________________________
# CO2 Emissions, measured in million metric tons
emissions_elec = (load_gdx_symbol(model_results_path, "CO2_ELEC")
                  .rename(columns={"r": "region", "t": "year", "level": "emissions"}))

emissions_elec["emissions"] = emissions_elec["emissions"] * 1000
# Calculate total emissions for all regions in California
emissions_california = (emissions_elec[emissions_elec['region'].isin(cal_r)]
                        .groupby(["year"]).agg({"emissions": "sum"})
                        .reset_index())
emissions_california["region"] = "California"

emissions_elec = (pd.concat([emissions_elec, emissions_california], axis=0, ignore_index=True)
    .pivot_table(index = ['region'], columns = 'year', values = 'emissions').reset_index())

emissions_elec.to_csv(os.path.join(output_folder, "regional_emissions_mtco2.csv"), index = False)
# _____________________________________________________________
# Generator and Storage capacity
storage_capacity = (load_gdx_symbol(model_results_path, "GC")
                    .rename(columns=COLUMN_NAMES)
                    .groupby(["region", "year"])
                    .agg({"level": "sum"})
                    .reset_index()
                    .rename(columns={"level": "capacity"})
                    .pipe(add_tech, "Storage-capacity")
                    )

storage_energy = (load_gdx_symbol(model_results_path, "GR")
                    .rename(columns=COLUMN_NAMES)
                    .groupby(["region", "year"])
                    .agg({"level": "sum"})
                    .reset_index()
                    .rename(columns={"level": "capacity"})
                    .pipe(add_tech, "Storage-energy")
                    )


capacity = (load_gdx_symbol(model_results_path, symbol="XC")
            .rename(columns=COLUMN_NAMES).rename(columns={"level": "capacity"})
            )

agg_capacity = (capacity
        # Aggregate vintages and tech classes
        .pipe(get_tech, TECH_SET)
        .groupby(["tech", "region", "year"])
        .agg({"capacity": "sum"})
        .reset_index()
)

cap_with_storage = pd.concat([agg_capacity, storage_capacity, storage_energy])
cap_with_storage.to_csv(os.path.join(output_folder, "capacity_by_region_gw.csv"), index = False)

ca_capacity = (cap_with_storage
               .pipe(subset_data, "region", cal_r)
               .groupby(["tech", "year"])
               .agg({"capacity": "sum"})
               .reset_index()
)
ca_capacity.to_csv(os.path.join(output_folder, "ca_capacity.csv"), index = False)
# _____________________________________________________________
# Generator and Storage Investments
storage_cap_investment = (load_gdx_symbol(model_results_path, "IGC")
                    .rename(columns=COLUMN_NAMES)
                    .groupby(["region", "year"])
                    .agg({"level": "sum"})
                    .reset_index()
                    .rename(columns={"level": "investment"})
                    .pipe(add_tech, "Storage-capacity")
                    )
storage_cap_investment = storage_cap_investment[storage_cap_investment["year"] != 2020]
# Adds all types of storage investments
storage_energy_investment = (load_gdx_symbol(model_results_path, "IGR")
                    .rename(columns=COLUMN_NAMES)
                    .groupby(["region", "year"])
                    .agg({"level": "sum"})
                    .reset_index()
                    .rename(columns={"level": "investment"})
                    .pipe(add_tech, "Storage-energy")
                    )
storage_energy_investment = storage_energy_investment[storage_energy_investment["year"] != 2020]

investment = (load_gdx_symbol(model_results_path, symbol="IX")
            .rename(columns=COLUMN_NAMES).rename(columns={"level": "investment"})
            # Aggregate vintages
            .groupby(["tech_class", "region", "year"])
            .agg({"investment": "sum"})
            .reset_index()
            .pipe(get_tech, TECH_SET)
            .groupby(["tech", "region", "year"])
            .agg({"investment": "sum"})
            .reset_index()
)

investment_with_storage = pd.concat([investment, storage_cap_investment, storage_energy_investment])
investment_with_storage.to_csv(os.path.join(output_folder, "investment_by_region_gw.csv"), index = False)

ca_investment = (investment_with_storage
               .pipe(subset_data, "region", cal_r)
               .groupby(["tech", "year"])
               .agg({"investment": "sum"})
               .reset_index()
)
ca_investment.to_csv(os.path.join(output_folder, "ca_investment.csv"), index = False)
#______________________________________________________

# Hourly mapping and segment mapping for load and availability factors

year_list = [2020, 2025, 2030, 2035, 2040, 2045, 2050]
hour_folder = os.path.join(main_folder, "RegenHours", ragg, "default", "out")
rep_hours = (
    pd.concat([load_gdx_symbol(os.path.join(hour_folder, f"create_hrep_{year}_default.gdx"), "hrep") for year in year_list])
    .rename(columns={"s":"segment","t": "year"})
    )

# Hourly load for California
h_load = (load_gdx_symbol(os.path.join(enduse_folder, f"segdata_8760_default.gdx"), "load_s")
          .rename(columns = COLUMN_NAMES).rename(columns = {"value":"load_h"})
        #   Get only CA regions
          .pipe(subset_data, "region", cal_r)
          .groupby(["year", "hour"])
          .agg({"load_h": "sum"})
          .reset_index()
          )

s_load = (load_gdx_symbol(os.path.join(enduse_folder, f"segdata_100_default.gdx"), "load_s")
          .rename(columns = COLUMN_NAMES).rename(columns = {"value":"load_s"})
        #   Get only CA regions
          .pipe(subset_data, "region", cal_r)
          .groupby(["year", "segment"])
          .agg({"load_s": "sum"})
          .reset_index()
          )

hydrogen_loads = (load_gdx_symbol(report_path, "dspsrpt_r")
                  .rename(columns = {"uni_0": "group", "s_1": "segment", "r_2": "region", "uni_3": "type", "t_4": "year", "value": "hydrogen_load"})
                  .pipe(subset_data, "group", ["demand"])
                  .pipe(subset_data, "type", ["h2prod_ht", "h2prod_ne", "h2prod_pa", "h2stortrn"])
                  .pipe(subset_data, "region", cal_r)
                  .groupby(["year", "segment"])
                  .agg({"hydrogen_load": "sum"})
                  .reset_index()
)
loads = (rep_hours
        .merge(h_load, on = ["year", "hour"]).rename(columns = {"load_h": "load_hour"})
        .merge(s_load, on = ["year", "segment"]).rename(columns = {"load_s": "load_segment"})
        .merge(hydrogen_loads, on = ["year", "segment"])
)
loads.to_csv(os.path.join(output_folder, "ca_loads.csv"), index = False)

af_h = (load_gdx_symbol(os.path.join(enduse_folder, f"segdata_8760_default.gdx"), "vrsc")
        .rename(columns={"h": "hour", "uni": "tech_class", "v": "vintage",
                         "r": "region", "t": "year", "value": "af_h"})
        .pipe(subset_data, "region", cal_r)
        .pipe(get_tech, TECH_SET)
        .merge(capacity, on = ["tech_class", "vintage", "region", "year"])
        # Keep only rows where tech is in renewable energy sub list
        .pipe(subset_data, "tech", RE_TECH)
        # # Add hourly generation as capacity * availability factor
        .pipe(lambda x: x.assign(generation_h = x.capacity * x.af_h))
        .assign(af_h_base = lambda x: x["af_h"])
        .groupby(["tech", "year", "hour"])
        .agg({"generation_h": "sum", "capacity": "sum", "af_h_base": "mean"})
        .reset_index()
        # Get average availability factor
        .pipe(lambda x: x.assign(af_h = x.generation_h / x.capacity))
        # Replace NaN values in af_h with af_h_base
        )
af_h["af_h"] = af_h["af_h"].fillna(af_h["af_h_base"])
af_h = af_h.drop(columns="af_h_base", axis=1)

af_s = (load_gdx_symbol(os.path.join(enduse_folder, f"segdata_100_default.gdx"), "vrsc")
        .rename(columns={"s": "segment", "uni": "tech_class", "v": "vintage",
                         "r": "region", "t": "year", "value": "af_s"})
        .pipe(subset_data, "region", cal_r)
        .pipe(get_tech, TECH_SET)
        .merge(capacity, on = ["tech_class", "vintage", "region", "year"])
        # Add hourly generation as capacity * availability factor
        .pipe(lambda x: x.assign(generation_s = x.capacity * x.af_s))
        .assign(af_s_base = lambda x: x["af_s"])
        .groupby(["tech", "year", "segment"])
        .agg({"generation_s": "sum", "capacity": "sum", "af_s_base": "mean"})
        .reset_index()
        # Get average availability factor
        .pipe(lambda x: x.assign(af_s = x.generation_s / x.capacity))
        # Keep only rows where tech is in renewable energy sub list
        .pipe(subset_data, "tech", RE_TECH)
        .drop(columns="capacity", axis=1)
        )
af_s["af_s"] = af_s["af_s"].fillna(af_s["af_s_base"])
af_s = af_s.drop(columns="af_s_base", axis=1)
# Merge all dataframes
df = (
    af_h
    .merge(rep_hours, on = ["year", "hour"])
    .merge(af_s, on = ["year", "segment", "tech"])
    .merge(h_load, on = ["year", "hour"])
    .merge(s_load, on = ["year", "segment"])
    .merge(hydrogen_loads, on = ["year", "segment"])
    .drop_duplicates()
    )
df["af_s"] = df["af_s"].fillna(0)
df["af_h"] = df["af_h"].fillna(0)
df.to_csv(os.path.join(output_folder, "ca_hourly_mapping.csv"), index = False)
#______________________________________________________
TYPE_TO_TECH = {"xnuc": "Nuclear", "nnuc": "Nuclear", "nuca": "Nuclear",
                "geot": "Geothermal", "hydr": "Hydro", "bioe": "Bio", "othc": "Bio", "h2": "Hydrogen",
                "becs": "Bio CCS", "xcol": "Coal", "ncol": "Coal", "clcs": "Coal CCS",
                "xngc": "Gas-CC", "nngc": "Gas-CC", "ngcs": "Gas CCS", "xngp": "Gas-CT", "nngp": "Gas-CT", "dfcap": "Gas-CT",
                "ptpk": "Gas-CT", "h2cc": "Hydrogen", "xwnd": "Wind", "nwnd": "Wind",
                "wnos": "Wind", "xspv": "Solar", "nspv": "Solar", "xcsp": "Solar",
                "ncsp": "Solar", "stor": "Storage", "rfpv": "Solar", "peakload": "Peak Load"}

gencap = (load_gdx_symbol(reporting_results_path, "gencaprpt")
          .rename(columns = {"uni_0":"region", "grc_1": "type", "t_2": "year", "uni_3": "unit"})
)
gencap["tech"] = (gencap["type"]
                  .str.replace(r'\d+', '', regex=True)
                  .map(TYPE_TO_TECH)
)
gencap = (gencap[gencap["tech"].notnull()]
          .groupby(["tech", "region", "unit", "year"])
          .agg({"value": "sum"})
          .reset_index()
)
generation = gencap[gencap["unit"] == "TWh"]
generation.to_csv(os.path.join(output_folder, "generation_twh.csv"), index = False)
cap = gencap[gencap["unit"] == "gw"]
cap.to_csv(os.path.join(output_folder, "capacity_gw.csv"), index = False)

#______________________________________________________
# Dispatch values

storage_charge = (load_gdx_symbol(model_results_path, "G")
                  .rename(columns = COLUMN_NAMES)
                  .pipe(subset_data, "region", cal_r)
                  .groupby(["year", "segment"])
                  .agg({"level": "sum"})
                  .reset_index()
                  .pipe(add_tech, "Storage-charge"))

storage_discharge = (load_gdx_symbol(model_results_path, "GD")
                  .rename(columns = COLUMN_NAMES)
                  .pipe(subset_data, "region", cal_r)
                  .groupby(["year", "segment"])
                  .agg({"level": "sum"})
                  .reset_index()
                  .pipe(add_tech, "Storage-discharge"))


gen_dispatch = (pd.concat([load_gdx_symbol(model_results_path, "X"), load_gdx_symbol(model_results_path, "X_45V")])
            .rename(columns = COLUMN_NAMES)
            .pipe(subset_data, "region", cal_r)
            .pipe(get_tech, TECH_SET)
            .groupby(["tech", "year", "segment"])
            .agg({"level": "sum"})
            .reset_index())

dispatch = pd.concat([gen_dispatch, storage_charge, storage_discharge]).merge(rep_hours, on = ["year", "segment"])

dispatch.to_csv(os.path.join(output_folder, "dispatch_by_segment_gwh.csv"), index = False)

STATE_MAPPING = {'BANC_TID': "ca", 'IID': "ca", 'LDWP': "ca", 'Other': "ca", 'PGE':"ca", 'SCE': "ca", 'SDGE': "ca",
                 'Oregon': "rest_of_wecc", 'Washington': "rest_of_wecc", 'Nevada': "rest_of_wecc", 'Arizona': "rest_of_wecc",
                 'New_Mexico': "rest_of_wecc", 'Utah': "rest_of_wecc", 'Colorado': "rest_of_wecc", 'Idaho': "rest_of_wecc",
                 'Montana': "rest_of_wecc", 'Wyoming': "rest_of_wecc"}

trade = (load_gdx_symbol(model_results_path, "E")
         .rename(columns = {"s_0": "segment", "r_1": "region_exp", "r_2": "region_imp", "t_3": "year", "level": "trade_gw"})
         .pipe(map_col, "region_exp", STATE_MAPPING)
         .pipe(map_col, "region_imp", STATE_MAPPING)
         .groupby(["year", "segment", "region_exp", "region_imp"])
            .agg({"trade_gw": "sum"})
            .reset_index()
            .merge(rep_hours, on = ["year", "segment"])
)
trade.to_csv(os.path.join(output_folder, "trade_gw.csv"), index = False)
# ___________________________________

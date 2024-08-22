# This file includes a series of functions to support plotting REGEN figures
# These scripts were written by Sean Ericson. Feel free to use them in your own projects at will.
# Please feel free to reach out with any questions or suggestions for improvement.
# If you find any of the code helpful or use them in your own project, consider mentioning this to Sean or to others,
# it is always nice to know something you made was useful to someone else.
# _____________________________________________________________________________
rm(list = ls())
setwd(file.path(dirname(rstudioapi::getSourceEditorContext()$path)))
library(tidyverse)

source("constants.R")

MAX_GEN = 600
Y_GEN_BREAKS = 100
MAX_CAP = 300
Y_CAP_BREAKS = 50
# _____________________________________________________________________________
# Change scen for each scenario run
scenarios = c("reference", "base", "min_compliance", "base_highh2")
figures_folder = file.path("..", "figures", "facets")
# Create the figures folder if it doesn't exist
if (!dir.exists(figures_folder)) {
  dir.create(figures_folder)
}

data_folder = file.path("..", "cleaned_data")

investments = plyr::ldply(scenarios, function(scen) {
    df = read_csv(file.path(data_folder, scen, "ca_investment.csv")) %>%
            mutate(scenario = scen)
    return(df)
    }) %>%
  mutate(tech = if_else(tech %in% c("Storage-capacity"), "Storage", tech)) %>%
  filter(year != 2020) %>%
  mutate(tech = factor(tech, levels = TECH_ORDER)) %>%
  filter(!is.na(tech)) %>%
  group_by(scenario, year, tech) %>%
  summarize(investment = sum(investment))

invest_2040 = investments %>%
    filter(year <= 2040) %>%
    group_by(scenario, tech) %>%
    summarize(investment = sum(investment))

ggplot(invest_2040, aes(x = scenario, y = investment, fill = tech)) +
        geom_bar(stat = "identity") +
        scale_fill_manual(values = TECH_COLORS, breaks = rev(names(TECH_COLORS))) +
        scale_x_discrete("Scenario", expand = c(0.02,0.02)) +
        scale_y_continuous("Cumulative Investment (GW)", expand = c(0,0),
                          breaks = seq(from = 10, to = 125, by = 25)) +
        labs(fill=element_blank(), linetype = element_blank())

ggsave(file.path(figures_folder, "cumulative_investment_2040.png"), height = PLOT_HEIGHT, width = PLOT_WIDTH, units = "in", dpi = DPI)
###

capacity = plyr::ldply(scenarios, function(scen) {
    df = read_csv(file.path(data_folder, scen, "capacity_gw.csv")) %>%
            filter(region == "CA") %>%
            mutate(scenario = scen)
    return(df)
    })

cap = capacity  %>%
    filter(!(tech %in% c("Peak Load"))) %>%
  mutate(tech = factor(tech, levels = TECH_ORDER)) %>%
  filter(year %in% c(2030, 2040, 2050))

peak_load = capacity %>%
    filter(tech == "Peak Load") %>%
  filter(year %in% c(2030, 2040, 2050))

ggplot(cap, aes(x = scenario, y = value, fill = tech)) +
        geom_bar(stat = "identity") +
        geom_point(data = peak_load, size = 2) +
        # scale_linetype_manual(values = c("longdash")) +
        scale_fill_manual(values = TECH_COLORS, breaks = rev(names(TECH_COLORS))) +
        scale_x_discrete("Scenario", expand = c(0,0)) +
        theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
        scale_y_continuous("Capacity (GW)", expand = c(0,0),
                          breaks = seq(from = Y_CAP_BREAKS, to = MAX_CAP, by = Y_CAP_BREAKS)) +
        labs(fill=element_blank(), linetype = element_blank()) +
        facet_wrap(~year)
ggsave(file.path(figures_folder, "capacity_by_scenario.png"), height = PLOT_HEIGHT, width = PLOT_WIDTH, units = "in", dpi = DPI)

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
#TODO, now that we have multiple scenarios, we should loop through them.
# Could also be good to move some of these operations into functions (say a plot_capacity function?)

scen = "base_highh2"
figures_folder = file.path("..", "figures", scen)
# Create the figures folder if it doesn't exist
if (!dir.exists(figures_folder)) {
  dir.create(figures_folder)
}
data_folder = file.path("..", "cleaned_data", scen)

# _____________________________________________________________________________
# Generation plot
generation_raw = read_csv(file.path(data_folder, "generation_twh.csv"))

gen = generation_raw %>%
  filter(region == "CA") %>%
  filter(!(tech %in% c("Storage", "Peak Load"))) %>%
  mutate(tech = factor(tech, levels = TECH_ORDER))

ggplot(gen, aes(x = year, y = value, fill = tech)) +
        geom_area() +
        scale_fill_manual(values = TECH_COLORS) +
        scale_x_continuous("Year", breaks = seq(2020, 2050, 5), expand = c(0,0)) +
        scale_y_continuous("Annual Generation (TWh)", expand = c(0,0), breaks = seq(from = Y_GEN_BREAKS, to = MAX_GEN, by = Y_GEN_BREAKS)) +
        labs(fill=element_blank(), linetype = element_blank())

ggsave(file.path(figures_folder, "generation_plot.png"), height = PLOT_HEIGHT, width = PLOT_WIDTH, units = "in", dpi = DPI)
# _____________________________________________________________________________
# Capacity plot
capacity_raw = read_csv(file.path(data_folder, "capacity_gw.csv"))
cap = capacity_raw %>%
  filter(region == "CA") %>%
  filter(!(tech %in% c("Peak Load"))) %>%
  mutate(tech = factor(tech, levels = TECH_ORDER))

peak_load = capacity_raw %>%
  filter(region == "CA", tech == "Peak Load")

ggplot(cap, aes(x = year, y = value, fill = tech)) +
        geom_area() +
        geom_line(data = peak_load, linewidth = 1.5, aes(linetype = tech)) +
        scale_linetype_manual(values = c("longdash")) +
        scale_fill_manual(values = TECH_COLORS, breaks = rev(names(TECH_COLORS))) +
        scale_x_continuous("Year", breaks = seq(2020, 2050, 5), expand = c(0,0)) +
        scale_y_continuous("Capacity (GW)", expand = c(0,0),
                          breaks = seq(from = Y_CAP_BREAKS, to = MAX_CAP, by = Y_CAP_BREAKS)) +
        labs(fill=element_blank(), linetype = element_blank())

ggsave(file.path(figures_folder, "capacity_plot.png"), height = PLOT_HEIGHT, width = PLOT_WIDTH, units = "in", dpi = DPI)

# _____________________________________________________________________________
# Investment plot
investment =  read_csv(file.path(data_folder, "ca_investment.csv")) %>%
  mutate(tech = if_else(tech %in% c("Storage-capacity"), "Storage", tech)) %>%
  filter(year != 2020) %>%
  mutate(tech = factor(tech, levels = TECH_ORDER)) %>%
  filter(!is.na(tech)) %>%
  group_by(year, tech) %>%
  summarize(investment = sum(investment))

ggplot(investment, aes(x = year, y = investment, fill = tech)) +
        geom_bar(stat = "identity") +
        scale_fill_manual(values = TECH_COLORS, breaks = rev(names(TECH_COLORS))) +
        scale_x_continuous("Year", breaks = seq(2025, 2050, 5), expand = c(0.02,0.02)) +
        scale_y_continuous("Investment (GW)", expand = c(0,0),
                          breaks = seq(from = 10, to = 50, by = 10)) +
        labs(fill=element_blank(), linetype = element_blank())

ggsave(file.path(figures_folder, "investment_plot.png"), height = PLOT_HEIGHT, width = PLOT_WIDTH, units = "in", dpi = DPI)


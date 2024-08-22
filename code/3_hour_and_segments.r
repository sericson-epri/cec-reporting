rm(list = ls())
setwd(file.path(dirname(rstudioapi::getSourceEditorContext()$path)))
library(tidyverse)
source("constants.R")

scen = "base_highh2"
cleaned_data_folder = file.path("..", "cleaned_data", scen)
figures_folder = file.path("..", "figures", scen)
# Use 2026 times because year starts on the same day as REGEN times
times = seq(as.POSIXct("2026-01-01 00:00:00"), as.POSIXct("2026-12-31 23:00:00"), by = "hour")
# Hourly load, generation, and af
raw_data = read_csv(file.path(cleaned_data_folder, "ca_hourly_mapping.csv"))

# hour is the 8760 hourly value, and segment is the 100 segments REGEN uses for modeling
df = raw_data %>%
    rename(generation_hour = "generation_h", af_hour = "af_h", load_hour = "load_h",
           generation_segment = "generation_s", af_segment = "af_s", load_segment = load_s,
           capacity_hour = "capacity") %>%
    mutate(capacity_segment = capacity_hour) %>%
    # Add hydrogen loads to model
    mutate(load_segment = load_segment + hydrogen_load,
           load_hour = load_hour + hydrogen_load) %>%
    pivot_longer(cols = c(generation_hour, generation_segment, af_hour, af_segment,
                         load_hour, load_segment, capacity_hour, capacity_segment),
                 names_to = "id", values_to = "value") %>%
    separate(id, into = c("type", "aggregation"), sep = "_")

df_hour = df %>%
    filter(aggregation == "hour") %>%
    select(-aggregation) %>%
    pivot_wider(names_from = type, values_from = value) %>%
    pivot_longer(cols = c(generation, capacity, af), names_to = "type", values_to = "value") %>%
    pivot_wider(names_from = tech, values_from = value) %>%
    group_by(year, hour) %>%
    mutate(net_load = load - Solar[which(type == "generation")] - Wind[which(type == "generation")]) %>%
    ungroup() %>%
    group_by(year, type) %>%
    mutate(order_id = rank(-net_load))

normalized_df = df_hour %>%
    filter(type == "generation") %>%
    group_by(year) %>%
    mutate(load_norm = load/max(load), net_load_norm = net_load/max(load), solar = Solar / max(load), wind = Wind / max(load)) %>%
    ungroup() %>%
    mutate(time = times[hour], month = month(time), day = day(time), hour_of_day = hour(time),
           month_name = month(time, label = TRUE))

hourly_load_norm = normalized_df %>%
    group_by(year, hour_of_day) %>%
    summarize(Load = mean(load_norm), `Net Load` = pmax(0, mean(net_load_norm)), solar = mean(solar)) %>%
    pivot_longer(cols = c(Load, `Net Load`), names_to = "type", values_to = "value") %>%
    filter(year != 2050)

ggplot(hourly_load_norm, aes(x = hour_of_day, y = value, color = type)) +
    geom_area(aes(x = hour_of_day, y = solar / 2, fill = "Solar"), inherit.aes = FALSE, alpha = 0.75) +
    scale_fill_manual(element_blank(), values = c("Solar" = "#cdaf04")) +
    # geom_rect(aes(xmin = 8, xmax = 17, ymin = -Inf, ymax = Inf), fill = "#cdaf04", alpha = 0.2, color = NA) +
    geom_line(lwd = 1.5) +
    scale_color_manual(element_blank(), values = c("Load" = "#989898", "Net Load" = "blue3")) +
    scale_x_continuous("Hour of Day", breaks = seq(0, 20, 4)) +
    scale_y_continuous("Per Unit Value", expand = c(0,0), limits = c(0, 0.7)) +
    theme(legend.position = "top") +
    facet_wrap(~year)
ggsave(file.path(figures_folder, "hourly_load_norm.png"), width = 10, height = 10, units = "in", dpi = 700)

#__________________________________________________
# Calculate capacity factors based on top 25 net load hours
num_hours_ranking = 25
rank = df_hour %>%
    arrange(type, order_id) %>%
    filter(order_id <= num_hours_ranking) %>%
    group_by(year, type) %>%
    summarize(load = mean(load), net_load = mean(net_load), solar = mean(Solar), wind = mean(Wind)) %>%
    arrange(type)
View(rank)
write_csv(rank, file.path(cleaned_data_folder, "capacity_factors_top_25.csv"))

rank_1 = df_hour %>%
    arrange(type, order_id) %>%
    filter(order_id <= 1) %>%
    group_by(year, type) %>%
    summarize(load = mean(load), net_load = mean(net_load), solar = mean(Solar), wind = mean(Wind)) %>%
    arrange(type)
# View(rank_1)
# __________________________________________________________
# Comparison between hourly and segments
ts = df %>%
    pivot_wider(names_from = tech, values_from = value) %>%
    filter(type %in% c("af", "load")) %>%
    group_by(year, hour, aggregation) %>%
    mutate(Load = Wind[which(type == "load")]) %>%
    ungroup() %>%
    filter(type == "af") %>%
    select(-type) %>%
    mutate(time = times[hour]) %>%
    mutate(month = month(time), day = day(time),
           hour_of_day = hour(time), month_name = month(time, label = TRUE))


month_ts = ts %>%
    group_by(year, month, aggregation) %>%
    summarize(Wind = mean(Wind), Solar = mean(Solar), Load = mean(Load), month_name = first(month_name)) %>%
    filter(year != 2020)

ggplot(month_ts, aes(x = month, y = Load, color = aggregation)) +
    geom_line(linewidth = 1.25) +
    facet_wrap(~year) +
    scale_x_continuous(breaks = seq(2,12,3), labels = month.abb[seq(2,12,3)]) +
    scale_color_manual(element_blank(), values = AGG_COLORS) +
    theme(legend.position = "top") +
    scale_y_continuous("California Average Load (GW)")

ggsave(file.path(figures_folder, "monthly_load_comparison_by_year.png"),
       width = 10, height = 10, units = "in", dpi = 700)

###
ordered_loads = ts %>%
    group_by(year, aggregation) %>%
    arrange(desc(Load)) %>%
    mutate(order_hour = 1:n()) %>%
    filter(year != 2020) %>%
    # Drop single outlier in 2040
    # TODO inspect data for what causes outlier
    filter(Load > 5)

ggplot(ordered_loads, aes(x = order_hour, y = Load, color = aggregation)) +
    geom_line(size = 1.25) +
    facet_wrap(~year) +
    scale_x_continuous("Percent of Hours", breaks = seq(0,8760, 2190), labels = c(0, 0.25, 0.5, 0.75, 1)) +
    # theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
    scale_color_manual(element_blank(), values =AGG_COLORS) +
    theme(legend.position = "top") +
    scale_y_continuous("California Ordered Load (GW)", limits = c(0, 100))

ggsave(file.path(figures_folder, "compare_hour_to_segment_loads.png"),
         width = 10, height = 10, units = "in", dpi = 300)

#Ordered Solar plot
ordered_solar = ts %>%
    group_by(year, aggregation) %>%
    arrange(desc(Solar)) %>%
    mutate(order_hour = 1:n()) %>%
    filter(year != 2020)

ggplot(ordered_solar, aes(x = order_hour, y = Solar, color = aggregation)) +
    geom_line(size = 1.25) +
    facet_wrap(~year) +
    scale_x_continuous("Percent of Hours", breaks = seq(0,8760, 2190), labels = c(0, 0.25, 0.5, 0.75, 1)) +
    # theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
    scale_color_manual(element_blank(), values =AGG_COLORS) +
    theme(legend.position = "top") +
    scale_y_continuous("CA Average Solar Availability", limits = c(0, 1))

ggsave(file.path(figures_folder, "compare_hour_to_segment_solar.png"),
         width = 10, height = 10, units = "in", dpi = 300)

#Ordered Wind
ordered_wind = ts %>%
    group_by(year, aggregation) %>%
    arrange(desc(Wind)) %>%
    mutate(order_hour = 1:n()) %>%
    filter(year != 2020)

ggplot(ordered_wind, aes(x = order_hour, y = Wind, color = aggregation)) +
    geom_line(size = 1.25) +
    facet_wrap(~year) +
    scale_x_continuous("Percent of Hours", breaks = seq(0,8760, 2190), labels = c(0, 0.25, 0.5, 0.75, 1)) +
    # theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
    scale_color_manual(element_blank(), values =AGG_COLORS) +
    theme(legend.position = "top") +
    scale_y_continuous("CA Average Wind Availability", limits = c(0, 1))

ggsave(file.path(figures_folder, "compare_hour_to_segment_wind.png"),
         width = 10, height = 10, units = "in", dpi = 300)

# __________________________________________________________

dispatch = read_csv(file.path(cleaned_data_folder, "dispatch_by_segment_gwh.csv")) %>%
    filter(year != 2020) %>%
    filter(!(tech %in% c("Coal", "Coal CCS", "Gas CCS", "Energy Efficiency")))

storage_charge = dispatch %>% filter(tech == "Storage-charge") %>%
    select(year, segment, hour, storage_carge = "level")

dispatch = dispatch %>%
    filter(tech != "Storage-charge") %>%
    mutate(tech = if_else(tech == "Storage-discharge", "Storage", tech)) %>%
    # mutate(time = times[hour], month = month(time), day = day(time), hour_of_day = hour(time),
           month_name = month(time, label = TRUE)) %>%
    mutate(tech = factor(tech, levels = TECH_ORDER))


trade = read_csv(file.path(cleaned_data_folder, "trade_gw.csv")) %>%
    group_by(year, hour) %>%
    summarize(imports = sum(trade_gw[(region_imp == "ca") & (region_exp != "ca")]),
              exports = sum(trade_gw[(region_exp == "ca") & (region_imp != "ca")])) %>%
    ungroup() %>%
    mutate(net_imports = imports - exports) %>%
    filter(year != 2020)

load = read_csv(file.path(cleaned_data_folder, "ca_loads.csv")) %>%
    filter(year != 2020)


### Plot dispatch by hour
dispatch_hours = dispatch %>%
    group_by(tech, year, hour_of_day) %>%
    summarize(level = mean(level)) %>%
    ungroup()


ggplot(dispatch %>% filter(year == 2025, hour < 121), aes(x = hour, y = level, fill = tech)) +
        geom_area() +
        scale_fill_manual(values = TECH_COLORS) +
        # facet_wrap(~month, labeller = labeller(month = month.abb)) +
        scale_y_continuous("Annual Generation (TWh)", expand = c(0,0),
            breaks = seq(from = 10, to = 60, by = 10)) +
        scale_x_continuous("hour", breaks = seq(0, 120, 24), expand = c(0,0))


dispatch_ordered = read_csv(file.path(cleaned_data_folder, "dispatch_by_segment_gwh.csv")) %>%
    # filter(year != 2020) %>%
    unique() %>%
    filter(!(tech %in% c("Coal", "Coal CCS", "Gas CCS", "Energy Efficiency"))) %>%
    filter(tech != "Storage-charge") %>%
    mutate(tech = if_else(tech == "Storage-discharge", "Storage", tech)) %>%
    mutate(tech = factor(tech, levels = TECH_ORDER)) %>%
    group_by(year, hour) %>%
    mutate(total_gen = sum(level)) %>%
    ungroup() %>% group_by(year, tech) %>%
    mutate(gen_ntile = ntile(total_gen, 10)) %>%
    ungroup() %>% group_by(year, tech, gen_ntile) %>%
    summarize(generation = mean(level)) %>%
    group_by(year, gen_ntile) %>%
    mutate(pct_gen = generation / sum(generation))


ggplot(dispatch_ordered %>% filter(year == 2020), aes(x = gen_ntile, y = pct_gen, fill = tech)) +
        geom_bar(stat = "identity") +
        scale_fill_manual(element_blank(), values = TECH_COLORS) +
        # facet_wrap(~month, labeller = labeller(month = month.abb)) +
        scale_y_continuous("Percent of Generation", expand = c(0,0), labels = scales::percent_format()) +
        scale_x_continuous("Geneartion Decile", breaks = 1:10, expand = c(0,0))
ggsave(file.path(figures_folder, "Generation Decile 2020.png"),
         width = 8, height = 6, units = "in", dpi = 300)

ggplot(dispatch_ordered %>% filter(year == 2040), aes(x = gen_ntile, y = pct_gen, fill = tech)) +
        geom_bar(stat = "identity") +
        scale_fill_manual(element_blank(), values = TECH_COLORS) +
        # facet_wrap(~month, labeller = labeller(month = month.abb)) +
        scale_y_continuous("Percent of Generation", expand = c(0,0), labels = scales::percent_format()) +
        scale_x_continuous("Generation Decile", breaks = 1:10, expand = c(0,0))
ggsave(file.path(figures_folder, "Generation Decile 2040.png"),
         width = 8, height = 6, units = "in", dpi = 300)

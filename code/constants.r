theme_set(theme_classic() +
  theme(axis.text = element_text(size = 16),
        axis.title = element_text(size = 20),
        legend.text = element_text(size = 14),
        # strip.background = element_blank(),
        strip.text = element_text(size = 16, face = "bold")
        )
)

AGG_COLORS = c("hour" = "black", "segment" = "#c91804")

PLOT_HEIGHT = 6
PLOT_WIDTH  = 8
DPI = 700
START_YEAR = 2020

MaxColVal = 255
TECH_COLORS = c(
   "Nuclear"    = rgb(127, 127, 127, maxColorValue = MaxColVal),
   "Geothermal" = rgb(217, 150, 148, maxColorValue = MaxColVal),
   "Hydro"      = rgb(75 , 172, 198, maxColorValue = MaxColVal),
   "Bio"  = rgb(119, 147, 60 , maxColorValue = MaxColVal),
   "Bio CCS"    = rgb(196, 215, 155, maxColorValue = MaxColVal),
   "Coal"       = rgb(64 , 104, 156, maxColorValue = MaxColVal),
   "Coal CCS"   = rgb(185, 205, 229, maxColorValue = MaxColVal),
   "Gas-CC"     = rgb(247, 150,  70, maxColorValue = MaxColVal),
   "Gas-CT"     = rgb(250, 186, 134, maxColorValue = MaxColVal),
   "Gas CCS"    = rgb(252, 213, 181, maxColorValue = MaxColVal),
   "Hydrogen"   = rgb(239, 113, 224, maxColorValue = MaxColVal),
   "Wind"       = rgb(146, 208,  80, maxColorValue = MaxColVal),
   "Solar"      = rgb(255, 197,   0, maxColorValue = MaxColVal),
   "Storage"    = rgb(112,  48, 160, maxColorValue = MaxColVal)
)

TECH_ORDER = rev(names(TECH_COLORS))

TECH_SUB = c("100% Hydrogen combined cycle" = "Hydrogen", "100% Hydrogen gas turbine" = "Hydrogen",
             "Biomass cofire" = "Bio", "Biomass with 90% capture" = "Bio CCS",
               "Coal" = "Coal", "Coal converted to biomass" = "Bio", "Coal retrofit with 95% capture" = "Coal CCS",
               "Community Solar" = "Solar", "Concentrated Solar Power (thermal)" = "Solar", "Conventional hydro" = "Hydro",
               "Converted NG steam" = "Gas-CT", "Dedicated biomass generation" = "Bio", "Dual Fuel combined cycle (NG Diesel or H2)" = "Gas-CC",
               "Dual Fuel gas turbine (NG Diesel or H2)" = "Gas-CT", "Existing biomass and other" = "Bio",
               "Gas cofire" = "Gas-CC", "Geothermal" = "Geothermal", "Lithium_Ion-capacity" = "Storage", "Energy Efficiency" = "DROP",
               "Lithium_Ion-energy" = "DROP", "NG combined cycle" = "Gas-CC", "NG gas turbine" = "Gas-CT", "NG steam" = "Gas-CT",
               "NGCC CCS retrofit (95% capture)" = "Gas CCS", "NGCC converted to be H2" = "Hydrogen", "NGGT converted to be H2" = "Hydrogen",
               "New Coal with CCS (99% capture)" = "Coal CCS", "New NGCC with CCS (97% capture)" = "Gas CCS",
               "Nuclear Advanced" = "Nuclear", "Nuclear Gen III" = "Nuclear", "Petroleum steam gas turbine or IC" = "Gas-CT",
               "Pumped_Hydro-capacity" = "DROP", "Pumped_Hydro-energy" = "DROP", "Rooftop Solar PV" = "Solar",
               "Utility Double Axis PV" = "Solar", "Utility Fixed Tilt PV" = "Solar", "Utility Single Axis PV" = "Solar",
               "Wind" = "Wind")

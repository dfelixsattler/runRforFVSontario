# FVS Ontario workflow: build scenarios from one shared jack-pine stand.
workflow_source_file <- tryCatch(sys.frame(1)$ofile, error = function(error) NULL)
if (is.null(workflow_source_file) || !nzchar(workflow_source_file)) {
  workflow_directory <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
} else {
  workflow_directory <- dirname(normalizePath(workflow_source_file, winslash = "/", mustWork = TRUE))
}
source(file.path(workflow_directory, "fvs_ontario_interactive.R"))

# Shared stand inputs. Every scenario below starts from this same stand.
species <- "jack_pine"
stems_per_ha <- 1900
origin <- "planted"
site_index <- 18.29
site_species <- "jack_pine"
site_species_origin <- "natural"
projection_years <- 120
# Results stay beside the cloned workflow and are excluded from Git.
output_root <- file.path(workflow_directory, "fvs_runs", "fvs_essa_fs2022_4")
fvs_essa_executable <- Sys.getenv(
  "FVS_ONTARIO_EXECUTABLE",
  unset = "C:/fvs_essa/FVSon.exe"
)
fvs_legacy_home <- Sys.getenv(
  "FVS_ONTARIO_LEGACY_HOME",
  unset = "C:/Program Files (x86)/FVSOntario"
)

if (!file.exists(fvs_essa_executable)) {
  stop("FVS executable was not found: ", fvs_essa_executable, call. = FALSE)
}

# Chunk 1: baseline, untreated stand.
baseline_results <- fvs_run(
  species = species,
  stems_per_ha = stems_per_ha,
  origin = origin,
  site_index = site_index,
  site_species = site_species,
  site_species_origin = site_species_origin,
  projection_years = projection_years,
  run_id = "jack_pine_baseline",
  output_directory = file.path(output_root, "jack_pine_baseline"),
  fvs_executable = fvs_essa_executable
)

View(baseline_results$species_yield)
View(baseline_results$stand_yield)
print(plot_fvs_yield(baseline_results, metric = "all"))

# Chunk 2: baseline plus a commercial thinning.
# At age 40, thin from below and retain 1,000 stems/ha.
jack_pine_thinning <- fvs_thin(
  trigger_value = 40,
  trigger = "age",
  direction = "below",
  target = 1000,
  target_type = "stems"
)

thinned_results <- fvs_run(
  species = species,
  stems_per_ha = stems_per_ha,
  origin = origin,
  site_index = site_index,
  site_species = site_species,
  site_species_origin = site_species_origin,
  projection_years = projection_years,
  run_id = "jack_pine_thinned",
  output_directory = file.path(output_root, "jack_pine_thinned"),
  treatments = jack_pine_thinning,
  fvs_executable = fvs_essa_executable
)

View(thinned_results$stand_yield)
print(plot_fvs_yield(thinned_results, metric = "stems"))
print(plot_fvs_yield(thinned_results, metric = "all"))

# Compare completed standing-volume trajectories; this does not alter either FVS run.
thinning_comparison <- plot_fvs_scenario_comparison(
  baseline_results,
  thinned_results,
  baseline_label = "Unthinned",
  treatment_label = "Thinned at age 40",
  metric = "all"
)
print(thinning_comparison)

# Chunk 3: baseline plus an SDIMAX sensitivity assumption.
# First inspect the model's default SDI for planted jack pine.
jack_pine_defaults <- fvs_species_defaults(species, origin)
print(jack_pine_defaults)

# This is a sensitivity-test value, not a recommended calibration value.
modified_sdi <- fvs_sdimax(
  species = species,
  maximum_sdi = 750,
  origin = origin
)

sdimax_results <- fvs_run(
  species = species,
  stems_per_ha = stems_per_ha,
  origin = origin,
  site_index = site_index,
  site_species = site_species,
  site_species_origin = site_species_origin,
  projection_years = projection_years,
  run_id = "jack_pine_sdimax",
  output_directory = file.path(output_root, "jack_pine_sdimax"),
  stand_modifiers = modified_sdi,
  fvs_executable = fvs_essa_executable
)

View(sdimax_results$stand_yield)
print(plot_fvs_yield(sdimax_results, metric = "all"))

# Chunk 4: baseline plus a BAMAX sensitivity assumption.
# BAMAX is in ft2/ac. Do not combine it with SDIMAX: FVS uses BAMAX instead.
modified_bamax <- fvs_bamax(maximum_basal_area_ft2_ac = 200)

bamax_results <- fvs_run(
  species = species,
  stems_per_ha = stems_per_ha,
  origin = origin,
  site_index = site_index,
  site_species = site_species,
  site_species_origin = site_species_origin,
  projection_years = projection_years,
  run_id = "jack_pine_bamax",
  output_directory = file.path(output_root, "jack_pine_bamax"),
  stand_modifiers = modified_bamax,
  fvs_executable = fvs_essa_executable
)

View(bamax_results$stand_yield)
print(plot_fvs_yield(bamax_results, metric = "all"))

# Chunk 5: mixed natural stand to assess species composition through time.
# All four species are present at establishment; this tests differential growth
# and mortality rather than regeneration of a new species.
succession_species <- c(
  "trembling_aspen",
  "white_birch",
  "white_spruce",
  "black_spruce"
)
succession_stems_per_ha <- c(1000, 1000, 200, 200)

succession_results <- fvs_run(
  species = succession_species,
  stems_per_ha = succession_stems_per_ha,
  origin = "natural",
  site_index = 16,
  site_species = "trembling_aspen",
  site_species_origin = "natural",
  projection_years = projection_years,
  run_id = "aspen_birch_spruce_composition",
  output_directory = file.path(output_root, "aspen_birch_spruce_composition"),
  fvs_executable = fvs_essa_executable
)

View(succession_results$species_yield)
View(succession_results$stand_yield)
print(plot_fvs_yield(succession_results, metric = "all"))

# Chunk 6: project the bundled mature red-oak inventory.
# The inventory records do not supply site information; treat this red-oak
# site index of 16 m as a starting assumption to refine for a real stand.
red_oak_inventory <- file.path(fvs_legacy_home, "Work", "RedOak.tre")

if (!file.exists(red_oak_inventory)) {
  stop("Bundled red-oak inventory was not found: ", red_oak_inventory, call. = FALSE)
}

red_oak_results <- run_fvs_ontario_scenario(
  run_id = "red_oak_inventory",
  description = "Bundled RedOak inventory",
  output_directory = file.path(output_root, "red_oak_inventory"),
  inventory_year = 2026,
  forest_type = 915,
  site_species_code = 34,
  site_index = 16,
  projection_years = projection_years,
  inventory_file = red_oak_inventory,
  origin = "natural",
  fvs_executable = fvs_essa_executable
)

View(red_oak_results$species_yield)
View(red_oak_results$stand_yield)
print(plot_fvs_yield(red_oak_results, metric = "all"))

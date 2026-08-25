# FVS Ontario workflow: build scenarios from one shared jack-pine stand.
#
# BEFORE RUNNING
# 1. Download FVSon.exe from https://www.essa.com/explore-essa/tools/fvsprognosis/
#    and place it at C:/fvs_essa/FVSon.exe  (or set FVS_ONTARIO_EXECUTABLE to its
#    actual path before sourcing this script).
# 2. Open this file inside the cloned runRforFVS RStudio project, or set the
#    working directory to the runRforFVS folder.
# 3. Run the chunks below in order, or source the whole file.
#
.resolve_workflow_dir <- function() {
  # 1. RStudio interactive document context
  path <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) NULL)
  if (!is.null(path) && nzchar(path))
    return(dirname(normalizePath(path, winslash = "/", mustWork = FALSE)))
  # 2. sys.frame path (works when sourced from another script)
  path <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(path) && nzchar(path)) {
    d <- dirname(normalizePath(path, winslash = "/", mustWork = FALSE))
    if (file.exists(file.path(d, "fvs_helpers.R"))) return(d)
  }
  # 3. Working directory (last resort — validated)
  d <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (file.exists(file.path(d, "fvs_helpers.R"))) return(d)
  stop("Cannot locate fvs_helpers.R. Set your working directory to the runRforFVS folder.")
}
workflow_directory <- .resolve_workflow_dir()
source(file.path(workflow_directory, "fvs_helpers.R"))

# ---- Shared stand inputs -------------------------------------------------------
# Every scenario below projects the same planted jack pine stand.
species            <- "jack_pine"
stems_per_ha       <- 1900
origin             <- "planted"
site_index         <- 18.29
site_species       <- "jack_pine"
site_species_origin <- "planted"
projection_years   <- 120

output_root <- file.path(workflow_directory, "fvs_runs", "fvs_essa_fs2022_4")
fvs_essa_executable <- Sys.getenv("FVS_ONTARIO_EXECUTABLE", unset = "C:/fvs_essa/FVSon.exe")
if (!file.exists(fvs_essa_executable))
  stop("FVS executable was not found: ", fvs_essa_executable, call. = FALSE)


# ---- Step 1: Baseline (untreated stand) ----------------------------------------
baseline_results <- fvs_run(
  species             = species,
  stems_per_ha        = stems_per_ha,
  origin              = origin,
  site_index          = site_index,
  site_species        = site_species,
  site_species_origin = site_species_origin,
  projection_years    = projection_years,
  run_id              = "jack_pine_baseline",
  output_directory    = file.path(output_root, "jack_pine_baseline"),
  fvs_executable      = fvs_essa_executable
)

View(baseline_results$species_yield)
View(baseline_results$stand_yield)
print(plot_fvs_yield(baseline_results, metric = "all"))


# ---- Step 2: Commercial thinning at age 40 ------------------------------------
# Thin from below; retain 1 000 stems/ha.
jack_pine_thinning <- fvs_thin(
  trigger_value = 40,
  trigger       = "age",
  direction     = "below",
  target        = 1000,
  target_type   = "stems"
)

thinned_results <- fvs_run(
  species             = species,
  stems_per_ha        = stems_per_ha,
  origin              = origin,
  site_index          = site_index,
  site_species        = site_species,
  site_species_origin = site_species_origin,
  projection_years    = projection_years,
  run_id              = "jack_pine_thinned",
  output_directory    = file.path(output_root, "jack_pine_thinned"),
  treatments          = jack_pine_thinning,
  fvs_executable      = fvs_essa_executable
)

View(thinned_results$stand_yield)
print(plot_fvs_yield(thinned_results, metric = "stems"))
print(plot_fvs_yield(thinned_results, metric = "all"))


# ---- Step 3: Thinned vs baseline comparison ------------------------------------
thinning_comparison <- plot_fvs_scenario_comparison(
  baseline_results,
  thinned_results,
  baseline_label  = "Unthinned",
  treatment_label = "Thinned at age 40",
  metric          = "all"
)
print(thinning_comparison)


# ---- Step 4: Sensitivity — maximum SDI ----------------------------------------
# Inspect the default SDI for this species/origin before overriding.
jack_pine_defaults <- fvs_species_defaults(species, origin)
print(jack_pine_defaults)

# 750 is a sensitivity-test value, not a calibrated recommendation.
sdimax_results <- fvs_run(
  species             = species,
  stems_per_ha        = stems_per_ha,
  origin              = origin,
  site_index          = site_index,
  site_species        = site_species,
  site_species_origin = site_species_origin,
  projection_years    = projection_years,
  run_id              = "jack_pine_sdimax",
  output_directory    = file.path(output_root, "jack_pine_sdimax"),
  stand_modifiers     = fvs_sdimax(species, maximum_sdi = 750, origin = origin),
  fvs_executable      = fvs_essa_executable
)

View(sdimax_results$stand_yield)
print(plot_fvs_yield(sdimax_results, metric = "all"))


# ---- Step 5: Sensitivity — maximum basal area ---------------------------------
# BAMAX is in ft²/ac. Do not combine with SDIMAX: FVS ignores SDIMAX when BAMAX is set.
bamax_results <- fvs_run(
  species             = species,
  stems_per_ha        = stems_per_ha,
  origin              = origin,
  site_index          = site_index,
  site_species        = site_species,
  site_species_origin = site_species_origin,
  projection_years    = projection_years,
  run_id              = "jack_pine_bamax",
  output_directory    = file.path(output_root, "jack_pine_bamax"),
  stand_modifiers     = fvs_bamax(maximum_basal_area_ft2_ac = 200),
  fvs_executable      = fvs_essa_executable
)

View(bamax_results$stand_yield)
print(plot_fvs_yield(bamax_results, metric = "all"))


# ---- Step 6: Mixed-species natural stand (succession) -------------------------
# All species are present at establishment; watch how composition shifts over time.
succession_results <- fvs_run(
  species             = c("trembling_aspen", "white_birch", "white_spruce", "black_spruce"),
  stems_per_ha        = c(1000, 1000, 200, 200),
  origin              = "natural",
  site_index          = 16,
  site_species        = "trembling_aspen",
  site_species_origin = "natural",
  projection_years    = projection_years,
  run_id              = "aspen_birch_spruce_composition",
  output_directory    = file.path(output_root, "aspen_birch_spruce_composition"),
  fvs_executable      = fvs_essa_executable
)

View(succession_results$species_yield)
View(succession_results$stand_yield)
print(plot_fvs_yield(succession_results, metric = "all"))


# ---- Step 7: Existing inventory — red oak .tre file ---------------------------
# Site index of 16 m is a starting assumption; refine for a real stand.
red_oak_inventory <- file.path(workflow_directory, "inventories", "RedOak.tre")
if (!file.exists(red_oak_inventory))
  stop("Bundled red-oak inventory was not found: ", red_oak_inventory, call. = FALSE)

red_oak_results <- run_fvs_ontario_scenario(
  run_id           = "red_oak_inventory",
  description      = "Bundled RedOak inventory",
  output_directory = file.path(output_root, "red_oak_inventory"),
  inventory_year   = 2026,
  forest_type      = 915,
  site_species_code = 34,
  site_index       = 16,
  projection_years = projection_years,
  inventory_file   = red_oak_inventory,
  origin           = "natural",
  fvs_executable   = fvs_essa_executable
)

View(red_oak_results$species_yield)
View(red_oak_results$stand_yield)
print(plot_fvs_yield(red_oak_results, metric = "all"))


# ---- Step 8: Boreal mixedwood (Aw/Sb/Pj) across three site indices -----------
mix_si_vals <- c(12, 16, 20)   # Aw site index (m at BH age 50): low / medium / high

aw_sb_pj_results <- lapply(mix_si_vals, function(si) {
  fvs_run(
    species             = c("trembling_aspen", "black_spruce", "jack_pine"),
    stems_per_ha        = c(1000, 200, 200),
    origin              = "natural",
    site_index          = si,
    site_species        = "trembling_aspen",
    site_species_origin = "natural",
    projection_years    = 120,
    time_step_years     = 5,
    run_id              = paste0("aw_sb_pj_si", si),
    output_directory    = file.path(output_root, paste0("aw_sb_pj_si", si)),
    fvs_executable      = fvs_essa_executable
  )
})
names(aw_sb_pj_results) <- paste0("SI_", mix_si_vals)

for (si in mix_si_vals) {
  print(
    plot_fvs_yield(aw_sb_pj_results[[paste0("SI_", si)]], metric = "gross_merchantable") +
      ggplot2::ggtitle(paste0("Aw/Sb/Pj \u2014 natural, SI = ", si, " m (Aw)"))
  )
}

View(aw_sb_pj_results$SI_16$species_yield)

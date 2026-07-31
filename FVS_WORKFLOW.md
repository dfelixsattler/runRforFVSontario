# FVS Ontario RStudio Workflow

Use the argument-driven workflow in `my_test_workflow_fvsontario.R` for repeatable RStudio scenarios. It creates a baseline, a thinning scenario, and separate density-sensitivity scenarios from one shared set of stand inputs.

## Start in RStudio

Open `my_test_workflow_fvsontario.R`, edit the shared inputs at the top, and run the chunks you need. The script loads all helpers itself:

```r
source("fvs_ontario_interactive.R")
```

Open the cloned repository as the RStudio project or set it as the working directory first. The supplied workflow writes results under `fvs_runs/`, which Git ignores. Each scenario uses its own `run_id` and output directory so its FVS files and CSV outputs remain separate.

### Modern ESSA executable

The current test workflow uses the modern ESSA Ontario build:

```r
fvs_essa_executable <- Sys.getenv(
	"FVS_ONTARIO_EXECUTABLE",
	unset = "C:/fvs_essa/FVSon.exe"
)
```

`my_test_workflow_fvsontario.R` passes this setting to every `fvs_run()` call. A short baseline smoke test completed successfully with `ON (FS2022.4)`, `RV:20221118`, and produced parseable `.out`, `.lst`, `.sum`, and yield CSV files. Keep the legacy installation intact and use a separate output folder when comparing versions.

The workflow defaults to `fvs_runs/fvs_essa_fs2022_4` under the cloned repository. Set `FVS_ONTARIO_EXECUTABLE` when the modern executable is installed elsewhere.

### Reload after changes

RStudio keeps previously sourced functions in memory. After changes to any FVS helper, rerun:

```r
source("fvs_ontario_interactive.R")
```

before running individual scenario chunks. `fvs_run()` now stops when FVS exits with a nonzero status or leaves incomplete report files, rather than parsing a partial projection. If it stops, inspect the `.out` report and rerun the scenario after correcting the inputs.

## Current Scenario Sequence

| Step | Functions | What it does |
| --- | --- | --- |
| 1. Baseline | `fvs_run()` | Projects the untreated regenerated stand. |
| 2. Thinning | `fvs_thin()` then `fvs_run()` | Runs the validated age-triggered, from-below thinning to a residual stems/ha target. |
| 3. Comparison | `plot_fvs_scenario_comparison()` | Overlays completed untreated and thinned stand totals. It does not change either FVS projection. |
| 4. SDIMAX sensitivity | `fvs_sdimax()` then `fvs_run()` | Tests a species-level maximum-SDI assumption. |
| 5. BAMAX sensitivity | `fvs_bamax()` then `fvs_run()` | Tests a stand-level maximum-basal-area assumption. |
| 6. Species composition | `fvs_run()` then `plot_fvs_yield()` | Projects a mixed stand to assess species-specific growth and mortality through time. |

For the current planted jack-pine example, the shared inputs are the species, initial stems/ha, origin, site index, site species, projection length, and `output_root`.

## Baseline Projection

Use `fvs_run()` for a new regenerated stand:

```r
baseline_results <- fvs_run(
	species = "jack_pine",
	stems_per_ha = 1900,
	origin = "planted",
	site_index = 18.29,
	site_species = "jack_pine",
	site_species_origin = "natural",
	projection_years = 120,
	run_id = "jack_pine_baseline",
	output_directory = file.path("fvs_runs", "jack_pine_baseline")
)

print(plot_fvs_yield(baseline_results, metric = "all"))
```

For planted jack pine, the validated site-species setting is `site_species_origin = "natural"`, which writes the natural jack-pine site code used by SimProg.

## Thinning Scenario

The supported treatment is one thinning from below at a stand age with a residual stems/ha target:

```r
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
	treatments = jack_pine_thinning
)
```

This writes the SimProg-validated `THINBTA` treatment into the generated `.key` file. The current helper does not support arbitrary harvest prescriptions, thinning from above, or unvalidated trigger types.

## Compare Untreated and Thinned Results

Run this only after both scenarios have completed:

```r
thinning_comparison <- plot_fvs_scenario_comparison(
	baseline_results,
	thinned_results,
	baseline_label = "Unthinned",
	treatment_label = "Thinned at age 40",
	metric = "all"
)
print(thinning_comparison)
```

The comparison shows standing stems/ha, gross merchantable volume, total volume, and basal area. It is a reporting step only; it does not rerun or modify FVS.

## Density Sensitivities

Use either `SDIMAX` or `BAMAX` in a single scenario, never both together. FVS uses `BAMAX` when both are supplied and ignores explicit `SDIMAX` records.

```r
modified_sdi <- fvs_sdimax(
	species = "jack_pine",
	maximum_sdi = 750,
	origin = "planted"
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
	stand_modifiers = modified_sdi
)
```

Use `fvs_bamax(maximum_basal_area_ft2_ac = 200)` for a separate BAMAX scenario. BAMAX uses its native FVS unit of square feet per acre.

## Mixed-Species Composition Test

The workflow includes a natural four-species test stand with aspen site index of $16\ \mathrm{m}$:

```r
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

print(plot_fvs_yield(succession_results, metric = "all"))
```

`fvs_run()` is the normal execution path for this scenario: it creates the FVS input files, runs `FVSon.exe`, validates the reports, and returns `succession_results`. Use that returned object for the tables and plot above. Do not follow a successful `fvs_run()` with `fvs_load_run()`; loading a tree list is only for importing an archived or externally produced FVS run without executing FVS.

This test evaluates changes in the relative abundance, basal area, and volume of species that are all present at establishment. It does not model recruitment of a new species; the current workflow has no automatic regeneration setup.

## Import Existing FVS Runs and Inventories

### Bundled red-oak inventory

The bundled `RedOak.tre` file can be projected directly as an existing inventory:

```r
red_oak_results <- run_fvs_ontario_scenario(
	run_id = "red_oak_inventory",
	description = "Bundled RedOak inventory",
	output_directory = file.path(output_root, "red_oak_inventory"),
	inventory_year = 2026,
	forest_type = 915,
	site_species_code = 34,
	site_index = 16,
	projection_years = projection_years,
	inventory_file = file.path("inventories", "RedOak.tre"),
	origin = "natural",
	fvs_executable = fvs_essa_executable
)

print(plot_fvs_yield(red_oak_results, metric = "all"))
```

The repository includes this sample inventory, and the scenario runs it with the configured modern FVS executable. The runner creates a fresh staged copy in the scenario output folder before invoking FVS. The `.tre` file supplies tree records, not stand site data, so the red-oak site index of $16\ \mathrm{m}$ and inventory year are starting assumptions to revise for an actual stand.

Use `fvs_load_run()` to extract yield tables from an existing `.lst` file without running FVS again:

```r
existing_results <- fvs_load_run(
	"C:/path/to/existing_run.lst",
	output_directory = "C:/path/to/extracted_results"
)
print(plot_fvs_yield(existing_results, metric = "all"))
```

For a new run from an existing `.tre` inventory, use the advanced `run_fvs_ontario_scenario()` function or the menu-based `run_interactive_fvs_ontario()` helper. The menu builder is useful for baseline exploration; treatment scenarios should use `fvs_thin()` and `fvs_run()`.

## Output Files

| File | Role |
| --- | --- |
| `.tre` | Input inventory tree list for an existing-inventory scenario. |
| `.key` | Generated FVS keyword/control file. It records site conditions, regeneration or inventory settings, modifiers, and treatments. |
| `.rsp` | Generated response file that tells FVS which files to open. |
| `.out` | Main readable FVS report, including the keyword echo, activity schedule, stand composition, and model messages. |
| `.lst` | Complete projected tree list. The parser uses it for by-species and stand yield results. |
| `.sum` | Compact FVS stand-total summary. Use it to cross-check the parser or inspect FVS growth, mortality, and removals. |
| `_species_yield.csv` | Parsed species-level stems/ha, gross merchantable volume, total volume, and basal area by year and age. |
| `_stand_yield.csv` | Parsed stand totals for the same measures. |
| `_species_yield_ggplot.png` | Optional plot written only when `save_plots = TRUE`. |

`.cut` files are not treatment inputs to the current R workflow. They are FVS cut-list outputs and are not required for `fvs_thin()`.

## More Detail

See `FVS_R_REFERENCE.md` for a quick index and detailed argument descriptions for every user-facing function.

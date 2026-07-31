# FVS Ontario R Function Reference

Load all FVS helpers before using them:

```r
source("fvs_ontario_interactive.R")
```

## Quick Function Index

These are the functions intended for regular use.

| Function | What it does |
| --- | --- |
| `fvs_regeneration()` | Converts species names, origins, and starting densities into an FVS regeneration table. Usually called automatically by `fvs_run()`. |
| `fvs_species_defaults()` | Returns the FVS species code and default maximum SDI for one or more species. |
| `fvs_thin()` | Defines the validated age-triggered, from-below thinning treatment with a residual stems/ha target. |
| `fvs_sdimax()` | Defines species-level maximum SDI assumptions for a sensitivity scenario. |
| `fvs_bamax()` | Defines a stand-level maximum basal-area assumption for a sensitivity scenario. |
| `fvs_run()` | Creates a regenerated stand, runs FVS Ontario, extracts yield tables, and returns results. |
| `fvs_load_run()` | Reads and extracts results from an existing FVS `.lst` file without rerunning FVS. |
| `run_fvs_ontario_scenario()` | Advanced runner for a regenerated stand or an existing `.tre` inventory. |
| `run_interactive_fvs_ontario()` | Opens menu prompts for building a scenario interactively. |
| `extract_fvs_species_yield()` | Parses an FVS tree-list report into species and stand yield tables. |
| `build_fvs_species_yield_plot()` | Low-level plot builder for species and stand yield data frames. |
| `plot_fvs_yield()` | Plots a result returned by `fvs_run()` or `fvs_load_run()`. |
| `plot_fvs_scenario_comparison()` | Overlays stand totals from an untreated and a treatment scenario. |
| `plot_fvs_species_yield()` | Plots previously written species and stand yield CSV files. |

Internal helpers not normally called directly: `fvs_treatment_lines()`, `fvs_stand_modifier_lines()`, `choose_regeneration_species()`, `ask_text()`, `ask_number()`, and `parse_number()`.

## `fvs_regeneration()`

Creates the regeneration table used by `fvs_run()`.

```r
fvs_regeneration(species, stems_per_ha, origin = c("natural", "planted"))
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `species` | Character vector | One or more names: `black_spruce`, `white_spruce`, `jack_pine`, `white_pine`, `red_pine`, `trembling_aspen`, `balsam_fir`, `white_birch`, or `tamarack`. Spaces and capitalization are accepted. |
| `stems_per_ha` | Positive numeric vector | Initial density for each species, in stems/ha. Its length must equal `species`. |
| `origin` | `"natural"` or `"planted"` | Regeneration origin. Planting is supported only for black spruce, white spruce, jack pine, white pine, and red pine. |

Returns a data frame with FVS Ontario species codes and density.

## `fvs_species_defaults()`

Returns the FVS Ontario species code and built-in maximum SDI value for each supported species.

```r
fvs_species_defaults(species, origin = c("natural", "planted"))
```

```r
fvs_species_defaults(
  species = c("black_spruce", "white_spruce"),
  origin = "planted"
)
```

The returned data frame has `label`, `species_code`, and `default_sdi`. These defaults are from the installed FVS Ontario model. They are useful for inspection and sensitivity-analysis setup; leaving `stand_modifiers = NULL` is still the normal way to use FVS defaults in a run.

## `fvs_thin()`

Defines the verified SimProg treatment pattern: one thinning from below at a stand age, retaining a specified stems/ha target. It reproduces the `THINBTA` keyword structure exported by the manual jack-pine thinning run.

```r
fvs_thin(
  trigger_value,
  trigger = c("age", "year", "basal_area", "top_height", "qmd"),
  direction = c("below", "above"),
  target,
  target_type = c("basal_area", "stems"),
  min_dbh_cm = 0,
  max_dbh_cm = 999,
  min_height_m = 0,
  max_height_m = 999,
  cutting_efficiency = 1
)
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `trigger_value` | Numeric | Threshold at which the treatment is scheduled. Its unit depends on `trigger`. |
| `trigger` | `"age"` only | Stand age in years. Other trigger types are not yet validated. |
| `direction` | `"below"` only | Removes smaller eligible trees first. |
| `target` | Positive numeric | Desired residual condition. Units depend on `target_type`. |
| `target_type` | `"stems"` only | Treat `target` as residual density in stems/ha. |
| `min_dbh_cm`, `max_dbh_cm` | Numeric | DBH range in cm eligible for removal. Trees outside the range remain. |
| `min_height_m`, `max_height_m` | Numeric | Height range in m eligible for removal. Trees outside the range remain. |
| `cutting_efficiency` | Number in $(0, 1]$ | Proportion removed from each selected record while FVS works toward the target. Leave at `1` unless a partial removal is intentional. |

The function writes `AGE GE age AND AGE LE (age+CENDYEAR-YEAR)` and `THINBTA`, matching the successful manual run. FVS Ontario expects the target in stems/ha and the DBH/height eligibility limits in cm/m for this SimProg-generated form.

## `fvs_sdimax()`

Sets the species-level FVS maximum stand density index before the inventory is read. This affects density-related mortality, normal stocking, and some thinning calculations. It can substantially change projected yields.

```r
fvs_sdimax(
  species,
  maximum_sdi = NULL,
  origin = c("natural", "planted"),
  mortality_threshold = NULL,
  maximum_density_threshold = NULL
)
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `species` | Character vector | Species names accepted by `fvs_regeneration()`. |
| `maximum_sdi` | `NULL` or positive numeric vector | Maximum SDI for each supplied species. `NULL` uses the FVS Ontario defaults returned by `fvs_species_defaults()`. A supplied vector must have the same length as `species`. |
| `origin` | `"natural"` or `"planted"` | Selects the matching FVS Ontario species codes. |
| `mortality_threshold` | `NULL` or one number $\geq 10$ | Optional percentage of maximum density at which density-related mortality starts. It is written only on the first `SDIMAX` record, as required by FVS. |
| `maximum_density_threshold` | `NULL` or one number $\leq 95$ | Optional percentage of theoretical maximum density at actual maximum density. It is also written only on the first record. |

Example: use separate maximum SDI values for planted black and white spruce:

```r
spruce_sdi <- fvs_sdimax(
  species = c("black_spruce", "white_spruce"),
  maximum_sdi = c(1800, 1900),
  origin = "planted"
)
```

To explicitly create `SDIMAX` records using the model defaults, omit `maximum_sdi`:

```r
spruce_default_sdi <- fvs_sdimax(
  species = c("black_spruce", "white_spruce"),
  origin = "planted"
)
```

## `fvs_bamax()`

Sets FVS's stand-level maximum basal-area assumption.

```r
fvs_bamax(maximum_basal_area_ft2_ac)
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `maximum_basal_area_ft2_ac` | One positive number | Maximum basal area in square feet per acre. This is the native `BAMAX` keyword unit. |

Use the returned object as `stand_modifiers` in `fvs_run()`:

```r
bamax_sensitivity <- fvs_bamax(200)
```

`BAMAX` and `SDIMAX` must be tested in separate scenarios. FVS uses `BAMAX` to derive density behavior and ignores explicit `SDIMAX` records when both are set. The R helper stops with an error if both are combined.

## `fvs_run()`

Runs a regenerated FVS Ontario stand and extracts its yield tables.

```r
fvs_run(
  species,
  stems_per_ha,
  origin = c("natural", "planted"),
  site_index,
  site_species = species[1L],
  site_species_origin = origin,
  inventory_year = 2026,
  projection_years = 100,
  time_step_years = 5,
  run_id = "fvs_run",
  output_directory = file.path(getwd(), "fvs_output"),
  treatments = NULL,
  save_plots = FALSE,
  fvs_executable = file.path(fvs_legacy_home, "Model", "FVSOntario.exe")
)
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `species`, `stems_per_ha`, `origin` | See `fvs_regeneration()` | Defines the new regenerated stand. |
| `site_index` | Positive number | Site index in metres. |
| `site_species` | One selected species name | Species used to interpret `site_index`. Defaults to the first species. |
| `site_species_origin` | `"natural"` or `"planted"` | Origin used for the site-species code. For the validated planted jack-pine run, use `"natural"`, matching SimProg's site species code 1. |
| `inventory_year` | Integer year | Establishment year for the regenerated stand. |
| `projection_years` | Positive integer | Projection duration. Must divide evenly by `time_step_years`. |
| `time_step_years` | Positive integer | FVS growth/output interval in years. |
| `run_id` | Character string | Run name used for generated file names. |
| `output_directory` | Existing or new folder path | Folder for the FVS keyword, response, report, CSV, and optional plot files. |
| `stand_modifiers` | `NULL`, one `fvs_sdimax()` or `fvs_bamax()` result | Stand-level FVS settings written before tree data is read. Do not combine `BAMAX` and `SDIMAX`. |
| `treatments` | `NULL`, one `fvs_thin()` result, or a list of them | Validated only for the age-triggered, from-below, residual-stems/ha `THINBTA` treatment. |
| `save_plots` | `TRUE` or `FALSE` | Write a PNG yield plot in addition to returning the ggplot object. |
| `fvs_executable` | Path to an FVS Ontario `.exe` | Executable to run. Set this to a separately installed newer version when testing compatibility. |

Returns an invisible list with `species_yield`, `stand_yield`, `plot`, and `files`.

```r
spruce_sdi <- fvs_sdimax(c("black_spruce", "white_spruce"), c(1800, 1900), "planted")

results <- fvs_run(
  species = c("black_spruce", "white_spruce"),
  stems_per_ha = c(1000, 800),
  origin = "planted",
  site_index = 18,
  projection_years = 120,
  stand_modifiers = spruce_sdi,
  fvs_executable = Sys.getenv("FVS_ONTARIO_EXECUTABLE"),
  output_directory = file.path("fvs_runs", "spruce_mix")
)
```

Validated planted jack-pine thinning example:

```r
jack_pine_thinning <- fvs_thin(
  trigger_value = 40,
  target = 1000,
  target_type = "stems"
)

jack_pine_thinned <- fvs_run(
  species = "jack_pine",
  stems_per_ha = 1900,
  origin = "planted",
  site_index = 18.29,
  site_species = "jack_pine",
  site_species_origin = "natural",
  projection_years = 120,
  treatments = jack_pine_thinning
)

print(plot_fvs_yield(jack_pine_thinned, metric = "stems"))
```

## `fvs_load_run()`

Imports an existing FVS tree-list report without rerunning FVS.

```r
fvs_load_run(tree_list_file, output_directory = dirname(tree_list_file), save_plots = FALSE)
```

| Argument | Accepts | Meaning |
| --- | --- | --- |
| `tree_list_file` | Path to an existing `.lst` file | The FVS detailed tree-list report to parse. |
| `output_directory` | Folder path | Destination for the extracted species and stand CSV files. |
| `save_plots` | `TRUE` or `FALSE` | Write a PNG yield plot. |

Returns the same kind of invisible result list as `fvs_run()`.

## Plot Functions

```r
plot_fvs_yield(results, metric = c("gross_merchantable", "total_volume", "basal_area", "stems", "all"))
```

Plots a result returned by `fvs_run()`, `fvs_load_run()`, or `run_fvs_ontario_scenario()`. It returns a ggplot object. Use `print()` in a script.

```r
yield_plot <- plot_fvs_yield(results, metric = "basal_area")
print(yield_plot)
```

Use `metric = "stems"` to show stems/ha. With `metric = "all"`, the plot contains gross merchantable volume, total volume, basal area, and stems/ha in separate panels.

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

Overlays stand totals from two completed scenarios. It runs after both FVS simulations and does not change a projection, treatment, or generated keyword file. Use the stems/ha panel to verify the thinning event, then compare gross merchantable and total volume across later ages.

```r
plot_fvs_species_yield(species_csv, stand_csv, output_file = NULL)
```

Plots previously created species and stand CSV files. If `stand_csv` is omitted, it is inferred from the species CSV name. Set `output_file` to a `.png` path to write an image.

## Advanced Functions

`run_fvs_ontario_scenario()` is the low-level runner used by `fvs_run()`. Use it when projecting an existing `.tre` inventory rather than creating a regenerated stand. It requires `run_id`, `description`, `output_directory`, `inventory_year`, `forest_type`, `site_species_code`, `site_index`, and either `inventory_file` or `regeneration`.

`run_interactive_fvs_ontario()` starts the menu-driven scenario builder. It is useful for exploration, while `fvs_run()` is preferred for reproducible scripts.

## Treatment Notes

A `.cut` file is FVS output listing trees removed by a treatment. It is not supplied to `fvs_run()` as a harvest prescription. The treatment definition belongs in the generated `.key` file and is created here by `fvs_thin()`.

# runRforFVS

An RStudio workflow for running FVS Ontario projections, extracting species-level yield tables, and plotting yield over age. FVS executables, inventories, and generated results are not included.

## Requirements

- R with `ggplot2` installed.
- A local FVS Ontario installation. The workflow was tested with the modern ESSA executable at `C:/fvs_essa/FVSon.exe`.
- The legacy FVS Ontario installation if you want to run the bundled `RedOak.tre` inventory scenario.

## Use On A New Computer

1. Clone this repository and open its folder in RStudio.
2. Install the plotting dependency once:

```r
install.packages("ggplot2")
```

3. Configure the FVS locations for the current R session when they differ from the defaults:

```r
Sys.setenv(FVS_ONTARIO_EXECUTABLE = "C:/path/to/FVSon.exe")
Sys.setenv(FVS_ONTARIO_LEGACY_HOME = "C:/path/to/FVSOntario")
```

4. Open and source `my_test_workflow_fvsontario.R`. It runs the configured baseline, thinning, density-sensitivity, mixed-species, and red-oak inventory scenarios.

Results are written under `fvs_runs/` and are intentionally ignored by Git.

## Files

- `my_test_workflow_fvsontario.R`: RStudio scenarios to run directly.
- `fvs_ontario_interactive.R`: FVS keyword writing, execution, and import helpers.
- `fvs_species_yield.R`: Tree-list parser and yield-table writer.
- `fvs_species_yield_ggplot.R`: Species and scenario-comparison plots.
- `FVS_WORKFLOW.md`, `FVS_R_REFERENCE.md`, and `FVS_KEYWORD_GUIDE.md`: operational and function references.
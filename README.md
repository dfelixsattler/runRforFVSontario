# runRforFVSontario

> **Work in progress.** The workflow is functional but the repo is under active development.

An RStudio workflow for running FVS Ontario projections, extracting species-level yield tables, and plotting yield over age. FVS executables and generated results are not included; four validated sample inventories are included under `inventories/`.

## Requirements

- R with `ggplot2` installed.
- The modern FVS Ontario executable (`FVSon.exe`) from ESSA Technologies. See **Getting FVSon.exe** below.

## Getting FVSon.exe

1. Go to <https://www.essa.com/explore-essa/tools/fvsprognosis/> and download `FVSon.exe` from the **Downloads** table.
2. Create the folder `C:/fvs_essa/` and copy `FVSon.exe` into it.

If you install it somewhere else, set the environment variable `FVS_ONTARIO_EXECUTABLE` to the full path before running any scenario:

```r
Sys.setenv(FVS_ONTARIO_EXECUTABLE = "D:/path/to/FVSon.exe")
```

## Use On A New Computer

1. Clone this repository and open its `.Rproj` file in RStudio (File → Open Project).
2. Install the plotting dependency once:

```r
install.packages("ggplot2")
```

3. Download and place `FVSon.exe` as described above.
4. Open `workflow_ontario_examples.R` and run the steps in order. The script loads all helper files automatically.

Results are written under `fvs_runs/` and are intentionally ignored by Git.

## Files

- `workflow_ontario_examples.R`: Main entry point — run this to execute all scenarios.
- `fvs_helpers.R`: Helper functions for building keyword files, running FVS, and extracting results.
- `fvs_species_yield.R`: Tree-list parser and yield-table writer.
- `fvs_species_yield_ggplot.R`: Species and scenario-comparison plots.
- `inventories/`: Red oak, tolerant hardwood, white-pine mixedwood, and boreal mixedwood examples. See `inventories/README.md` for their starting assumptions.
- `FVS_WORKFLOW.md`, `FVS_R_REFERENCE.md`, and `FVS_KEYWORD_GUIDE.md`: operational and function references.

## Author

Derek Sattler — [derek.sattler@nrcan-rncan.gc.ca](mailto:derek.sattler@nrcan-rncan.gc.ca)  
Natural Resources Canada / Ressources naturelles Canada

## Licence

[![Licence: MIT](https://img.shields.io/badge/Licence-MIT-yellow.svg)](LICENSE)

© His Majesty the King in Right of Canada, as represented by the Minister of Natural Resources, 2026.  
Released under the [MIT License](LICENSE).